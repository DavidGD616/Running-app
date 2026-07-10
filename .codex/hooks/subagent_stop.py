from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    extract_event_transcript_path,
    classify_agent,
    extract_task_id_from_subagent_transcript,
    extract_task_ids,
    extract_task_ids_from_prompt_lines,
    extract_prompt_text,
    git_changed_file_signatures,
    parse_tool_exit_code,
    update_state,
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
    r"^Overall Assessment: (APPROVE|REQUEST_CHANGES|NEEDS_DISCUSSION)$"
)
NON_BLOCKING_APPROVE_TRAILING_PATTERNS = (
    r"\bno\s+blocking\s+findings\b",
    r"\bno\s+pending\s+fixes?\s+remain\b",
    r"\ball\s+issues\s+resolved\s+after\s+remediation\b",
    r"\bissues\s+resolved\s+after\s+remediation\b",
    r"\bno\s+critical\s+issues\b.*\bno\s+major\s+issues\b",
)
SEVERITY_FINDING_HEADER_RE = re.compile(
    r"^\s*(?:[-*]\s*)?(?:#{1,6}\s*)?"
    r"(critical|major|high)(?:\s+(?:issues?|findings?|risks?))?"
    r"(?:\s*(?:\([^\n)]*\)|[^\w\s:#-]+))*\s*(?::\s*|-\s+)(.+?)\s*$",
    re.IGNORECASE,
)
SEVERITY_SECTION_HEADER_RE = re.compile(
    r"^\s*(?:#{1,6}\s*)?(?:critical|major|high)"
    r"(?:\s+(?:issues?|findings?|risks?))?"
    r"(?:\s*(?:\([^\n)]*\)|[^\w\s:#-]+))*\s*:?[ \t]*$",
    re.IGNORECASE,
)
REVIEW_SECTION_HEADER_RE = re.compile(
    r"^\s*(?:#{1,6}\s*)?(?:"
    r"(?:critical|major|high|medium|minor|low)(?:\s+(?:issues?|findings?|risks?))?"
    r"|positive\s+observations?|verification|summary|recommendations?|notes?"
    r")(?:\s*(?:\([^\n)]*\)|[^\w\s:#-]+))*\s*:?[ \t]*$",
    re.IGNORECASE,
)
SEVERITY_NO_ISSUE_BODY_RE = re.compile(
    r"^(?:none|n/?a|no\s+issues?|no\s+issues?\s+found|no\s+findings?|not\s+applicable)$",
    re.IGNORECASE,
)
def _extract_coder_task_info(
    event: dict[str, Any],
    state: dict[str, Any],
    open_pass: dict[str, Any] | None,
) -> tuple[str | None, int, bool]:
    summary = extract_prompt_text(event)

    task_ids = extract_task_ids_from_prompt_lines(summary)
    if not task_ids:
        task_ids = extract_task_ids(summary)
    if task_ids:
        task_id = task_ids[0] if len(task_ids) == 1 else None
        return task_id, len(task_ids), False

    transcript_path = extract_event_transcript_path(event)
    if transcript_path:
        recovered_task_id, recovered_count = extract_task_id_from_subagent_transcript(
            transcript_path,
            agent="coder",
        )
        if recovered_task_id and recovered_count == 1:
            return recovered_task_id, recovered_count, True

    if open_pass is not None and open_pass.get("start_seq") is not None:
        start_seq = open_pass.get("start_seq")
        start_raw = _find_coder_start_raw_from_events(
            state,
            start_seq if isinstance(start_seq, int) else None,
        )
        if isinstance(start_raw, dict):
            raw = start_raw.get("raw")
            transcript_path = str(raw.get("transcript_path", "")) if isinstance(raw, dict) else ""
            recovered_task_id, recovered_count = extract_task_id_from_subagent_transcript(
                transcript_path,
                agent="coder",
            )
            if recovered_task_id and recovered_count == 1:
                return recovered_task_id, recovered_count, True

    return None, 0, False


def _extract_reviewer_task_info(
    event: dict[str, Any],
    state: dict[str, Any],
) -> tuple[str | None, int]:
    summary = extract_prompt_text(event)
    task_ids = extract_task_ids_from_prompt_lines(summary)
    if task_ids:
        if len(task_ids) == 1:
            return task_ids[0], 1
        return None, len(task_ids)

    transcript_path = extract_event_transcript_path(event)
    if transcript_path:
        recovered_task_id, recovered_count = extract_task_id_from_subagent_transcript(
            transcript_path,
            agent="reviewer",
        )
        if recovered_task_id and recovered_count == 1:
            return recovered_task_id, recovered_count

    return None, 0


def _find_coder_start_raw_from_events(state: dict[str, Any], start_seq: int | None) -> dict[str, Any] | None:
    if not isinstance(start_seq, int):
        return None

    candidates = state.get("turn", {}).get("events", [])
    best: dict[str, Any] | None = None
    best_seq: int | None = None

    for event in candidates:
        if not isinstance(event, dict) or event.get("event") != "SubagentStart":
            continue
        details = event.get("details")
        if not isinstance(details, dict) or details.get("agent") != "coder":
            continue

        event_seq = event.get("seq")
        if not isinstance(event_seq, int):
            continue

        if event_seq == start_seq:
            return details

        if event_seq < start_seq and best_seq is not None and event_seq <= best_seq:
            continue

        if event_seq < start_seq and (best_seq is None or event_seq > best_seq):
            best = details
            best_seq = event_seq

    return best


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
        match = OVERALL_ASSESSMENT_LINE_PATTERN.match(line)
        if match:
            results.append((idx, (match.group(1) or ""), line))
    return results


def _normalize_assessment_line(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").strip().lower())


def _is_explicit_no_issue_value(value: str) -> bool:
    normalized = re.sub(r"\s+", " ", (value or "").strip().lower()).strip()
    if not normalized:
        return False
    normalized = re.sub(r"^(?:[-*+]\s*|\d+[.)]\s*)", "", normalized)
    normalized = normalized.replace("`", "").replace("*", "").replace("_", "")
    normalized = normalized.strip("`'\"().,;:!?)-")
    return bool(SEVERITY_NO_ISSUE_BODY_RE.fullmatch(normalized))


def _has_blocking_severity_findings(value: str) -> bool:
    lines = (value or "").splitlines()
    index = 0
    while index < len(lines):
        raw_line = lines[index]
        match = SEVERITY_FINDING_HEADER_RE.match(raw_line.strip())
        if match:
            body = match.group(2).strip()
            if not _is_explicit_no_issue_value(body):
                return True
            index += 1
            continue

        if not SEVERITY_SECTION_HEADER_RE.match(raw_line.strip()):
            index += 1
            continue

        index += 1
        while index < len(lines):
            body_line = lines[index].strip()
            if not body_line:
                index += 1
                continue
            if REVIEW_SECTION_HEADER_RE.match(body_line):
                break
            if not _is_explicit_no_issue_value(body_line):
                return True
            index += 1
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
    if verdict != "APPROVE":
        return True

    paragraphs = _split_paragraphs(text)
    if not paragraphs:
        return True

    final_paragraph = paragraphs[-1]
    if len(final_paragraph) != 1:
        return True
    if final_paragraph[0] != "Overall Assessment: APPROVE":
        return True

    review_body = "\n".join(lines[:verdict_line_index])
    if _has_blocking_severity_findings(review_body):
        return True
    if _has_blocking_approve_followups(review_body):
        return True

    return False


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    agent = classify_agent(event)
    summary = extract_prompt_text(event)
    agent_transcript_path = extract_event_transcript_path(event)
    code = parse_tool_exit_code(event)

    decision = {}

    def apply_state(state):
        nonlocal decision
        if not state.get("active"):
            return

        event_seq = append_event(
            state,
            "SubagentStop",
            {
                "agent": agent,
                "summary_excerpt": summary[:200],
                "agent_transcript_path": agent_transcript_path,
            },
        )
        state["turn"]["events"] = state["turn"]["events"][-40:]

        if agent == "reviewer":
            state["turn"]["agents"]["reviewer_stopped"] = True
            blocking = looks_blocking(summary)
            reviewer_snapshot_signature = git_changed_file_signatures()
            reviewer_task_id, reviewer_task_id_count = _extract_reviewer_task_info(
                event,
                state,
            )
            if blocking:
                state["turn"]["agents"]["blocking_reviewer_seq"] = event_seq
                state["turn"]["agents"]["blocking_reviewer_snapshot_signature"] = reviewer_snapshot_signature
                state["turn"]["agents"]["remediation_required_after_seq"] = event_seq
                blocked_task_id = state["turn"].get("current_task_id")
                blocked_task_ids: list[str] = []
                if isinstance(blocked_task_id, str):
                    blocked_task_id = blocked_task_id.strip()
                    if blocked_task_id:
                        blocked_task_ids = [blocked_task_id]
                if not blocked_task_ids:
                    blocked_task_ids = extract_task_ids(summary)
                state["turn"]["agents"]["remediation_required_task_id"] = (
                    blocked_task_ids[0] if len(blocked_task_ids) == 1 else None
                )
                state["turn"]["agents"]["remediation_coder_start_seq"] = None
                state["turn"]["agents"]["remediation_coder_last_seq"] = None
                state["turn"]["agents"]["remediation_coder_task_id"] = None
            reviewer_stops = state["turn"]["agents"].get("reviewer_stops")
            if not isinstance(reviewer_stops, list):
                reviewer_stops = []
                state["turn"]["agents"]["reviewer_stops"] = reviewer_stops
            state["turn"]["agents"]["reviewer_stops"].append(
                {
                    "at": datetime.utcnow().isoformat() + "Z",
                    "text": summary[:400],
                    "blocking": blocking,
                    "seq": event_seq,
                    "task_id": reviewer_task_id if reviewer_task_id_count == 1 else None,
                    "task_id_count": reviewer_task_id_count,
                    "agent_transcript_path": agent_transcript_path,
                    "snapshot_signature": reviewer_snapshot_signature,
                }
            )
            state["turn"]["agents"]["reviewer_last_seq"] = event_seq
            state["turn"]["agents"]["reviewer_last_snapshot_signature"] = reviewer_snapshot_signature
            state["turn"]["agents"]["reviewer_last_blocking"] = blocking
        elif agent == "coder":
            coder_snapshot_signature = git_changed_file_signatures()
            agents = state["turn"]["agents"]
            agents["coder_started"] = True
            agents["coder_stopped"] = True
            agents["coder_last_seq"] = event_seq
            agents["coder_last_snapshot_signature"] = coder_snapshot_signature

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

            task_id, task_id_count, recovered_from_start = _extract_coder_task_info(event, state, open_pass)
            if recovered_from_start and isinstance(open_pass, dict) and task_id_count == 1:
                if open_pass.get("start_task_id_count") != 1:
                    open_pass["start_task_id"] = task_id
                    open_pass["start_task_id_count"] = task_id_count
                if open_pass.get("stop_task_id_count") != 1:
                    open_pass["stop_task_id"] = task_id
                    open_pass["stop_task_id_count"] = task_id_count
            if (
                open_pass is not None
                and task_id
                and task_id_count == 1
                and open_pass.get("start_task_id_count") != 1
            ):
                open_pass["start_task_id"] = task_id
                open_pass["start_task_id_count"] = task_id_count
            if task_id and (not state["turn"].get("current_task_id") or state["turn"]["current_task_id"] != task_id):
                state["turn"]["current_task_id"] = task_id

            agents["coder_last_task_id"] = task_id if task_id_count == 1 else None

            if open_pass is not None:
                open_pass["stop_seq"] = event_seq
                open_pass["stop_task_id"] = task_id
                open_pass["stop_task_id_count"] = task_id_count
                open_pass["agent_transcript_path"] = agent_transcript_path
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
                        "agent_transcript_path": agent_transcript_path,
                        "stop_snapshot_signature": coder_snapshot_signature,
                    }
                )

        if agent == "reviewer" and code != 0:
            decision = {"decision": "block", "reason": f"reviewer tool_exit={code}"}

    update_state(apply_state)

    if decision:
        print(json.dumps(decision))
        return
    print(json.dumps({}))


if __name__ == "__main__":
    main()
