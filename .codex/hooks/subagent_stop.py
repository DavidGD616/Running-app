from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    classify_agent,
    extract_prompt_text,
    extract_task_id,
    git_changed_file_signatures,
    load_state,
    parse_tool_exit_code,
    save_state,
)


BLOCKING_PATTERNS = [
    r"\bi\s+can(?:not|'t)\s+approve\b",
    r"\bnot\s*-?\s*approved\b",
    r"\bcannot\s+approve\b",
    r"\bresolution required",
    r"\bmust[- ]?fix\b",
    r"\bmust\b.*\bto\s+be\s+fixed\b",
    r"\bmust[- ]address",
    r"\bmust be addressed",
    r"\bneeds? to be fixed\b",
    r"\bneeds? fixing\b",
    r"\bblocking\s+(?:issue|issues|finding|findings|blocker|blockers)\b",
    r"\bi cannot approve this yet\b",
    r"\bnot approved until tests are added\b",
    r"\bblocking issue remains\b",
]

OVERALL_ASSESSMENT_LINE_PATTERN = re.compile(
    r"(?im)^\s*(?:[-*]\s*)?overall\s+assessment:\s*(approve|request\s+changes|needs\s+discussion)\s*$"
)
NON_BLOCKING_APPROVE_TRAILING_PATTERNS = (
    r"\bno\s+blocking\s+findings\b",
    r"\bno\s+pending\s+fixes?\s+remain\b",
    r"\ball\s+issues\s+resolved\s+after\s+remediation\b",
    r"\bissues\s+resolved\s+after\s+remediation\b",
    r"\bno\s+critical\s+issues\b.*\bno\s+major\s+issues\b",
)
SEVERITY_FINDING_HEADER_RE = re.compile(
    r"^\s*(?:[-*]\s*)?(critical|major|high)(?:\s+risk)?\s*(?::\s*|-\s*)(.+?)\s*$",
    re.IGNORECASE,
)
SEVERITY_NO_ISSUE_BODY_RE = re.compile(
    r"^(?:none|n/?a|no\s+issues?|no\s+issues?\s+found|no\s+findings?|not\s+applicable)$",
    re.IGNORECASE,
)
TASK_ID_PATTERN = re.compile(r"(?i)\btask\s*id:\s*([a-z0-9_.-]+)\b")


def extract_task_ids(text: str) -> list[str]:
    if not isinstance(text, str):
        return []
    return [value.strip() for value in TASK_ID_PATTERN.findall(text)]


def _extract_coder_task_info(event: dict) -> tuple[str | None, int]:
    summary = extract_prompt_text(event)
    event_json = json.dumps(event)

    task_ids = extract_task_ids(summary)
    if not task_ids:
        task_ids = extract_task_ids(event_json)

    task_id = task_ids[0] if len(task_ids) == 1 else None
    task_id_count = len(task_ids) if task_ids else 0

    if not task_id:
        task_id = extract_task_id(summary) or extract_task_id(event_json)

    return task_id, task_id_count


def _split_paragraphs(text: str) -> list[list[str]]:
    lines = text.splitlines()
    out: list[list[str]] = []
    current: list[str] = []
    for raw_line in lines:
        if raw_line.strip() == "":
            if current:
                out.append(current)
                current = []
            continue
        current.append(raw_line.strip())
    if current:
        out.append(current)
    return out


def _assessment_lines(text: str) -> list[tuple[int, str, str]]:
    results: list[tuple[int, str, str]] = []
    for idx, line in enumerate(text.splitlines()):
        match = OVERALL_ASSESSMENT_LINE_PATTERN.match(line.strip())
        if match:
            results.append((idx, (match.group(1) or "").lower(), line.strip()))
    return results


def _normalize_assessment_line(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").strip().lower())


def _is_explicit_no_issue_value(value: str) -> bool:
    normalized = re.sub(r"\s+", " ", (value or "").strip().lower()).strip()
    if not normalized:
        return False
    normalized = normalized.strip("`'\"().,;:!?)-")
    return bool(SEVERITY_NO_ISSUE_BODY_RE.fullmatch(normalized))


def _has_blocking_severity_findings(value: str) -> bool:
    for raw_line in (value or "").splitlines():
        match = SEVERITY_FINDING_HEADER_RE.match(raw_line.strip())
        if not match:
            continue
        body = match.group(2).strip()
        if not _is_explicit_no_issue_value(body):
            return True
    return False


def _has_blocking_approve_followups(value: str) -> bool:
    for raw_line in (value or "").splitlines():
        normalized = _normalize_assessment_line(raw_line)
        if not normalized:
            continue
        if _is_explicit_no_issue_value(normalized):
            continue
        if any(re.search(pattern, normalized) for pattern in NON_BLOCKING_APPROVE_TRAILING_PATTERNS):
            continue
        if "no blocking findings" in normalized:
            continue
        if any(re.search(pattern, normalized) for pattern in BLOCKING_PATTERNS):
            return True
    return False


def looks_blocking(text: str) -> bool:
    text = text or ""
    lines = text.splitlines()
    assessments = _assessment_lines(text)
    if len(assessments) != 1:
        return True

    verdict_line_index, verdict, verdict_line = assessments[0]
    if verdict != "approve":
        return True

    paragraphs = _split_paragraphs(text)
    if not paragraphs:
        return True

    final_paragraph = _normalize_assessment_line("\n".join(paragraphs[-1]))
    if _normalize_assessment_line(verdict_line) != final_paragraph:
        return True

    review_body = "\n".join(lines[:verdict_line_index])
    if _has_blocking_severity_findings(review_body):
        return True
    if _has_blocking_approve_followups(review_body):
        return True

    return False


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    state = load_state()
    if not state.get("active"):
        print(json.dumps({}))
        return

    agent = classify_agent(event)
    summary = extract_prompt_text(event)

    event_seq = append_event(state, "SubagentStop", {"agent": agent, "summary_excerpt": summary[:200]})
    state["turn"]["events"] = state["turn"]["events"][-40:]
    code = parse_tool_exit_code(event)

    if agent == "reviewer":
        state["turn"]["agents"]["reviewer_stopped"] = True
        blocking = looks_blocking(summary)
        reviewer_snapshot_signature = git_changed_file_signatures()
        if blocking:
            state["turn"]["agents"]["blocking_reviewer_seq"] = event_seq
            state["turn"]["agents"]["blocking_reviewer_snapshot_signature"] = reviewer_snapshot_signature
            state["turn"]["agents"]["remediation_required_after_seq"] = event_seq
            state["turn"]["agents"]["remediation_coder_start_seq"] = None
            state["turn"]["agents"]["remediation_coder_last_seq"] = None
            state["turn"]["agents"]["remediation_coder_task_id"] = None
        state["turn"]["agents"]["reviewer_stops"].append(
            {
                "at": datetime.utcnow().isoformat() + "Z",
                "text": summary[:400],
                "blocking": blocking,
                "seq": event_seq,
                "snapshot_signature": reviewer_snapshot_signature,
            }
        )
        state["turn"]["agents"]["reviewer_last_seq"] = event_seq
        state["turn"]["agents"]["reviewer_last_snapshot_signature"] = reviewer_snapshot_signature
        state["turn"]["agents"]["reviewer_last_blocking"] = blocking
    elif agent == "coder":
        task_id, task_id_count = _extract_coder_task_info(event)
        coder_snapshot_signature = git_changed_file_signatures()
        agents = state["turn"]["agents"]
        agents["coder_started"] = True
        agents["coder_stopped"] = True
        agents["coder_last_seq"] = event_seq
        agents["coder_last_snapshot_signature"] = coder_snapshot_signature
        agents["coder_last_task_id"] = task_id if task_id_count == 1 else None
        if task_id and not state["turn"].get("current_task_id"):
            state["turn"]["current_task_id"] = task_id

        coder_passes = agents.get("coder_passes")
        if not isinstance(coder_passes, list):
            coder_passes = []
            agents["coder_passes"] = coder_passes

        open_pass = None
        for idx in range(len(coder_passes) - 1, -1, -1):
            candidate = coder_passes[idx]
            if not isinstance(candidate, dict):
                continue
            if isinstance(candidate.get("stop_seq"), int):
                continue
            open_pass = candidate
            break

        if open_pass is not None:
            open_pass["stop_seq"] = event_seq
            open_pass["stop_task_id"] = task_id
            open_pass["stop_task_id_count"] = task_id_count
            open_pass["stop_snapshot_signature"] = coder_snapshot_signature
        else:
            coder_passes.append(
                {
                    "start_seq": None,
                    "start_task_id": task_id,
                    "start_task_id_count": task_id_count,
                    "start_snapshot_signature": [],
                    "start_snapshot_recorded": False,
                    "stop_seq": event_seq,
                    "stop_task_id": task_id,
                    "stop_task_id_count": task_id_count,
                    "stop_snapshot_signature": coder_snapshot_signature,
                }
            )
    save_state(state)

    # Keep output minimal unless blocking/continuation details are required.
    if agent == "reviewer" and code != 0:
        print(json.dumps({"decision": "block", "reason": f"reviewer tool_exit={code}"}))
        return
    print(json.dumps({}))


if __name__ == "__main__":
    main()
