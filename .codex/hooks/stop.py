from __future__ import annotations

import json
import re
from typing import Any

from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    command_is_commit,
    command_match_verification,
    changed_signatures_delta,
    extract_internal_subagent_prompt_from_transcript,
    extract_task_ids_from_prompt_lines,
    extract_task_ids,
    recover_successful_exec_calls_from_transcript,
    extract_task_id_from_subagent_transcript,
    now_iso,
    signatures_match,
    signature_paths,
    git_changed_file_signatures,
    git_changed_files,
    git_commit_first_parent,
    git_head_commit,
    git_is_ancestor,
    infer_internal_subagent_role_from_transcript,
    strict_agent_session_identity,
    update_state,
)
from subagent_stop import (
    EXACT_NON_BLOCKING_FINDINGS_TEXT,
    looks_blocking as reviewer_text_looks_blocking,
)


INTERNAL_SUBAGENT_PROMPT_SENTINEL_MARKER = re.compile(
    r"(?im)^\s*Codex-Orchestrator-Internal-Subagent:\s*([A-Za-z0-9._-]+)\s*$"
)


LEGACY_REVIEWER_NO_FINDINGS_TEXT = EXACT_NON_BLOCKING_FINDINGS_TEXT
MAX_LEGACY_REVIEWER_TRANSCRIPT_BYTES = 8 * 1024 * 1024
MAX_LEGACY_REVIEWER_TRANSCRIPT_RECORDS = 10_000
MAX_LEGACY_REVIEWER_TRANSCRIPT_LINE_BYTES = 1024 * 1024
SUBAGENT_TASK_ID_PROMPT_LINE_PATTERN = re.compile(
    r"(?im)^\s*(?:[-*]\s*)?task\s*id\s*:\s*([A-Za-z0-9][A-Za-z0-9._-]*)\s*$",
    re.IGNORECASE,
)


def _task_text_matches(text: str, task_id: str | None) -> bool:
    if not task_id:
        return True
    task_ids = extract_task_ids_from_prompt_lines(text)
    return task_ids == [task_id]


def _normalize_reviewer_stops(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _response_message_text(payload: dict[str, Any]) -> str | None:
    if payload.get("type") != "message" or payload.get("role") != "assistant":
        return None
    if payload.get("phase") not in ("final", "final_answer"):
        return None

    content = payload.get("content")
    if not isinstance(content, list) or len(content) != 1:
        return None
    item = content[0]
    if not isinstance(item, dict) or item.get("type") not in ("output_text", "text"):
        return None
    value = item.get("text")
    return value if isinstance(value, str) and value.strip() else None


def _legacy_reviewer_final_text_from_transcript(value: Any) -> str | None:
    """Read one bounded official JSONL transcript and return its final answer.

    The parser deliberately recognizes only terminal agent-message shapes. It
    never joins message fragments or falls back to arbitrary transcript text.
    Any malformed record makes the transcript unusable as approval evidence.
    """
    if not isinstance(value, str) or not value.strip():
        return None

    path = Path(value).expanduser()
    try:
        if path.suffix != ".jsonl" or not path.is_file() or path.is_symlink():
            return None
        if path.stat().st_size > MAX_LEGACY_REVIEWER_TRANSCRIPT_BYTES:
            return None

        event_final: str | None = None
        response_final: str | None = None
        task_complete_final: str | None = None
        with path.open("r", encoding="utf-8") as handle:
            for record_count, line in enumerate(handle, start=1):
                if record_count > MAX_LEGACY_REVIEWER_TRANSCRIPT_RECORDS:
                    return None
                if len(line.encode("utf-8")) > MAX_LEGACY_REVIEWER_TRANSCRIPT_LINE_BYTES:
                    return None
                record = json.loads(line)
                if not isinstance(record, dict):
                    return None
                payload = record.get("payload")
                if not isinstance(payload, dict):
                    continue

                if record.get("type") == "event_msg":
                    payload_type = payload.get("type")
                    if payload_type == "agent_message" and payload.get("phase") in (
                        "final", "final_answer",
                    ):
                        message = payload.get("message")
                        if isinstance(message, str) and message.strip():
                            event_final = message
                    elif payload_type == "task_complete":
                        message = payload.get("last_agent_message")
                        if isinstance(message, str) and message.strip():
                            task_complete_final = message
                elif record.get("type") == "response_item":
                    message = _response_message_text(payload)
                    if message is not None:
                        response_final = message
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
        return None

    return task_complete_final or response_final or event_final


def _coordinator_transcript_paths(turn: dict[str, Any]) -> list[str]:
    actors = turn.get("tool_call_actors", {})
    if not isinstance(actors, dict):
        return []
    return [
        path for path, role in actors.items()
        if isinstance(path, str) and path.strip() and role == "coordinator"
    ]


def _reviewer_transcript_has_correlated_provenance(
    turn: dict[str, Any],
    task_id: str,
    reviewer_stop: dict[str, Any],
    reviewer_pass: dict[str, Any],
    transcript_path: str,
    *,
    require_persisted_start: bool,
) -> bool:
    """Require role, task, session, spawn, and (for legacy) start correlation."""
    identity = strict_agent_session_identity(transcript_path, "reviewer")
    if not isinstance(identity, dict) or identity.get("task_id") != task_id:
        return False
    if reviewer_pass.get("agent_identity") != identity.get("identity"):
        return False
    pass_name = reviewer_pass.get("agent_name")
    if isinstance(pass_name, str) and pass_name != identity.get("agent_name"):
        return False

    coordinator_paths = _coordinator_transcript_paths(turn)
    spawn_evidence = turn.get("collaboration_spawn_evidence", [])
    if not isinstance(spawn_evidence, list):
        return False
    inferred_role = infer_internal_subagent_role_from_transcript(
        transcript_path,
        coordinator_transcript_paths=coordinator_paths,
        collaboration_spawn_evidence=spawn_evidence,
    )
    recovered_task_id, recovered_count = extract_task_id_from_subagent_transcript(
        transcript_path,
        agent="reviewer",
        coordinator_transcript_paths=coordinator_paths,
        collaboration_spawn_evidence=spawn_evidence,
    )
    if (
        inferred_role != "reviewer"
        or recovered_task_id != task_id
        or recovered_count != 1
    ):
        return False

    # If a plaintext internal prompt exists, it must independently carry the
    # reviewer sentinel and exactly one matching canonical Task ID. Opaque
    # prompts are accepted only through the spawn/session correlation above.
    prompt = extract_internal_subagent_prompt_from_transcript(
        transcript_path,
        agent="reviewer",
        coordinator_transcript_paths=coordinator_paths,
    )
    if prompt:
        if extract_task_ids_from_prompt_lines(prompt) != [task_id]:
            return False
        if infer_internal_subagent_role_from_transcript(
            transcript_path,
            coordinator_transcript_paths=coordinator_paths,
            collaboration_spawn_evidence=spawn_evidence,
        ) != "reviewer":
            return False

    if not require_persisted_start:
        return True

    stop_seq = reviewer_stop.get("seq")
    correlated_spawn = any(
        isinstance(evidence, dict)
        and evidence.get("role") == "reviewer"
        and evidence.get("task_id") == task_id
        and evidence.get("task_id_count") == 1
        and evidence.get("task_name") == identity.get("agent_name")
        and evidence.get("expected_agent_path") == identity.get("agent_path")
        and evidence.get("coordinator_thread_id") == identity.get("parent_thread_id")
        and evidence.get("expected_child_depth") == identity.get("depth")
        and isinstance(evidence.get("seq"), int)
        and isinstance(stop_seq, int)
        and evidence["seq"] < stop_seq
        for evidence in spawn_evidence
    )
    if not correlated_spawn:
        return False
    usage = turn.get("agent_identity_usage", {})
    reviewer_usage = usage.get("reviewer", {}) if isinstance(usage, dict) else {}
    start = reviewer_usage.get(identity["identity"]) if isinstance(reviewer_usage, dict) else None
    if not isinstance(start, dict):
        return False
    return (
        start.get("task_id") == task_id
        and start.get("seq") == stop_seq
        and start.get("stopped") is True
    )


def _reviewer_approval_transcript_path(
    turn: dict[str, Any],
    task_id: str,
    reviewer_stop: dict[str, Any],
    reviewer_pass: dict[str, Any],
) -> str | None:
    official_path = reviewer_stop.get("official_agent_transcript_path")
    pass_official_path = reviewer_pass.get("official_agent_transcript_path")
    if (
        isinstance(official_path, str)
        and official_path.strip()
        and official_path == pass_official_path
        and _reviewer_transcript_has_correlated_provenance(
            turn, task_id, reviewer_stop, reviewer_pass, official_path,
            require_persisted_start=False,
        )
    ):
        return official_path

    # The sole generic-path compatibility exception is the known seq-973
    # record, which predates the distinct official field. Approval prose alone
    # is insufficient: persisted reviewer start/session/spawn evidence must
    # all identify this exact role, task, sequence, and transcript.
    generic_path = reviewer_stop.get("agent_transcript_path")
    if (
        reviewer_stop.get("seq") == 973
        and isinstance(generic_path, str)
        and generic_path.strip()
        and _reviewer_transcript_has_correlated_provenance(
            turn, task_id, reviewer_stop, reviewer_pass, generic_path,
            require_persisted_start=True,
        )
    ):
        return generic_path
    return None


def _normalized_ledger_reviewer_passes(
    turn: dict[str, Any], task_id: str, ledger: dict[str, Any],
) -> list[dict[str, Any]]:
    """Normalize one legacy false blocker without mutating persisted state.

    Older hook versions classified the unambiguous phrase "No blocking or
    non-blocking findings" as blocking because a generic substring pattern
    matched ``blocking findings``.  A matching reviewer-stop record provides
    task, sequence, and snapshot evidence. Only the current strict terminal
    APPROVE contract or the exact historical no-findings sentence can repair
    a legacy pass.
    """
    passes = [
        dict(item) for item in ledger.get("reviewer_passes", [])
        if isinstance(item, dict)
    ]
    reviewer_stops = _normalize_reviewer_stops(
        turn.get("agents", {}).get("reviewer_stops", [])
        if isinstance(turn.get("agents"), dict) else []
    )
    stops_by_seq = {
        item.get("seq"): item
        for item in reviewer_stops
        if isinstance(item.get("seq"), int)
        and item.get("task_id") == task_id
        and item.get("task_id_count") == 1
    }

    for reviewer_pass in passes:
        if reviewer_pass.get("blocking") is not True:
            continue
        reviewer_stop = stops_by_seq.get(reviewer_pass.get("seq"))
        if not isinstance(reviewer_stop, dict):
            continue
        transcript_path = _reviewer_approval_transcript_path(
            turn, task_id, reviewer_stop, reviewer_pass,
        )
        if transcript_path:
            final_text = _legacy_reviewer_final_text_from_transcript(transcript_path)
            is_non_blocking = bool(
                final_text and not reviewer_text_looks_blocking(final_text)
            )
        else:
            is_non_blocking = False
        if is_non_blocking:
            reviewer_pass["blocking"] = False

    return passes


def _latest_reviewer_stop(reviewer_stops: list[dict[str, Any]]) -> dict[str, Any] | None:
    latest: dict[str, Any] | None = None
    latest_seq = -1
    for reviewer_stop in _normalize_reviewer_stops(reviewer_stops):
        stop_seq = reviewer_stop.get("seq")
        if not isinstance(stop_seq, int):
            continue
        if reviewer_stop.get("blocking") is True:
            continue
        if stop_seq > latest_seq:
            latest_seq = stop_seq
            latest = reviewer_stop
    return latest


def _reviewer_stop_task_id(
    reviewer_stop: dict[str, Any],
    expected_task_id: str | None,
) -> str | None:
    if not isinstance(reviewer_stop, dict):
        return None

    task_id = reviewer_stop.get("task_id")
    if isinstance(task_id, str):
        task_id = task_id.strip()
    task_id_count = reviewer_stop.get("task_id_count")
    if isinstance(task_id, str) and task_id and isinstance(task_id_count, int) and task_id_count == 1:
        return task_id

    text = str(reviewer_stop.get("text", ""))
    inferred_ids = extract_task_ids_from_prompt_lines(text)

    if expected_task_id:
        if expected_task_id in inferred_ids and len(inferred_ids) == 1:
            return expected_task_id
        return None

    if len(inferred_ids) == 1:
        return inferred_ids[0]

    return None


def _extract_prompt_task_id_with_count(
    text: str,
) -> tuple[str | None, int]:
    if not isinstance(text, str):
        return None, 0

    task_ids = [
        value.strip()
        for value in SUBAGENT_TASK_ID_PROMPT_LINE_PATTERN.findall(text)
        if isinstance(value, str) and value.strip()
    ]
    if len(task_ids) != 1:
        return None, len(task_ids)
    return task_ids[0], 1


def _reviewer_passed_reason(turn: dict[str, Any]) -> str | None:
    agents = turn.get("agents", {})
    if not isinstance(agents, dict):
        return "reviewer has not completed a non-blocking pass"

    reviewer_seq = agents.get("reviewer_last_seq")
    if not isinstance(reviewer_seq, int):
        return "reviewer has not completed a non-blocking pass"
    if agents.get("reviewer_last_blocking"):
        return "reviewer has not completed a non-blocking pass"

    latest_reviewer_stop = _latest_reviewer_stop(agents.get("reviewer_stops", []))
    if not isinstance(latest_reviewer_stop, dict):
        return "reviewer has not completed a non-blocking pass"

    current_task_id = turn.get("current_task_id")
    if isinstance(current_task_id, str):
        current_task_id = current_task_id.strip() or None

    reviewer_task_id = _reviewer_stop_task_id(latest_reviewer_stop, current_task_id)
    if not reviewer_task_id:
        if current_task_id:
            return (
                f"reviewer approval missing explicit Task ID matching current task ({current_task_id})"
            )
        return "reviewer approval missing explicit Task ID"

    if current_task_id and reviewer_task_id != current_task_id:
        return (
            "reviewer approval task ID "
            f"({reviewer_task_id}) does not match current task ({current_task_id})"
        )

    return None


def _latest_matching_reviewer_approval_seq(
    reviewer_stops: list[dict[str, Any]],
    after_seq: int,
    expected_task_id: str | None,
) -> int | None:
    latest_seq: int | None = None

    for reviewer_stop in _normalize_reviewer_stops(reviewer_stops):
        stop_seq = reviewer_stop.get("seq")
        if not isinstance(stop_seq, int):
            continue
        if stop_seq <= after_seq:
            continue
        if reviewer_stop.get("blocking") is True:
            continue

        if expected_task_id is None:
            continue

        stop_task_id = _reviewer_stop_task_id(reviewer_stop, expected_task_id)
        if stop_task_id != expected_task_id:
            continue

        latest_seq = stop_seq

    return latest_seq


def _find_reviewer_approval_seq(
    transcript_records: list[dict[str, Any]],
    transcript_floor: int,
    task_id: str | None,
) -> int | None:
    if not isinstance(transcript_records, list):
        return None

    marker_seq: int | None = None
    for index, record in enumerate(transcript_records, start=1):
        if index <= transcript_floor:
            continue
        payload = record.get("payload") if isinstance(record, dict) else None
        if not isinstance(payload, dict):
            continue
        texts = _collect_reviewer_approval_text(payload)
        if not texts:
            continue

        text_chunks = [str(item).strip() for item in texts if isinstance(item, str) and str(item).strip()]
        if not text_chunks:
            continue

        merged_text = "\n".join(text_chunks)
        if task_id and not _task_text_matches(merged_text, task_id):
            continue

        if not reviewer_text_looks_blocking(merged_text):
            marker_seq = index
            break

    return marker_seq


def _max_transcript_seq(commands: Any) -> int | None:
    if not isinstance(commands, list):
        return None

    max_seq: int | None = None
    for command in commands:
        if not isinstance(command, dict):
            continue
        transcript_seq = command.get("transcript_seq")
        if not isinstance(transcript_seq, int):
            continue
        if max_seq is None or transcript_seq > max_seq:
            max_seq = transcript_seq
    return max_seq


def _iter_transcript_records(path: str) -> list[dict[str, Any]]:
    transcript = Path(path)
    if not transcript.exists():
        return []

    records: list[dict[str, Any]] = []
    try:
        with transcript.open("r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(record, dict):
                    records.append(record)
    except OSError:
        return []
    return records


def _collect_text(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        out: list[str] = []
        for item in value:
            out.extend(_collect_text(item))
        return out
    if isinstance(value, dict):
        out = []
        for child in value.values():
            out.extend(_collect_text(child))
        return out
    return []


def _looks_like_json_container(value: str) -> bool:
    if not isinstance(value, str):
        return False
    stripped = value.strip()
    if not stripped:
        return False
    return (
        stripped.startswith("{") and stripped.endswith("}")
        or stripped.startswith("[") and stripped.endswith("]")
    )


def _unescape_reviewer_text(value: str) -> str:
    if not isinstance(value, str) or "\\n" not in value:
        return value
    try:
        return value.encode("utf-8").decode("unicode_escape")
    except UnicodeError:
        return value


def _collect_output_text(value: Any, max_depth: int = 2) -> list[str]:
    if max_depth < 0:
        return []

    if isinstance(value, str):
        raw = value
        if _looks_like_json_container(raw):
            try:
                parsed = json.loads(raw)
            except json.JSONDecodeError:
                return [raw]
            return _collect_output_text(parsed, max_depth - 1)
        return [_unescape_reviewer_text(raw)]

    if isinstance(value, list):
        out: list[str] = []
        for item in value:
            out.extend(_collect_output_text(item, max_depth=max_depth))
        return out

    if isinstance(value, dict):
        out: list[str] = []
        for child in value.values():
            out.extend(_collect_output_text(child, max_depth=max_depth))
        return out

    return []


def _collect_reviewer_approval_text(payload: dict[str, Any]) -> list[str]:
    payload_type = str(payload.get("type", "")).lower()
    if payload_type == "function_call":
        return []

    if "output" in payload:
        return [
            item
            for item in _collect_output_text(payload.get("output"))
            if isinstance(item, str) and item.strip()
        ]

    if payload_type == "function_call_output":
        return []

    return [
        item
        for item in _collect_text(payload)
        if isinstance(item, str) and item.strip()
    ]


def _extract_spawn_agent_arguments(
    arguments: Any,
) -> dict[str, Any] | None:
    if isinstance(arguments, dict):
        return arguments

    if isinstance(arguments, str):
        try:
            parsed = json.loads(arguments)
        except json.JSONDecodeError:
            return None
        if isinstance(parsed, dict):
            return parsed
        return None

    return None


def _spawn_agent_message_matches_coder_task(
    message: Any,
    task_id: str | None,
) -> bool:
    if not isinstance(message, str):
        return False

    sentinel = INTERNAL_SUBAGENT_PROMPT_SENTINEL_MARKER.search(message)
    if not sentinel or sentinel.group(1).lower() != "coder":
        return False

    prompt_task_id, prompt_task_id_count = _extract_prompt_task_id_with_count(message)
    if prompt_task_id_count != 1:
        return False

    if task_id and prompt_task_id != task_id:
        return False

    return True


def _message_record_matches_coder_task(
    record: dict[str, Any],
    task_id: str | None,
) -> bool:
    if not isinstance(record, dict):
        return False

    payload = record.get("payload", record)
    if not isinstance(payload, dict):
        return False

    payload_type = str(payload.get("type", "")).lower()
    texts: list[str] = []

    if payload_type == "message":
        if str(payload.get("role", "")).lower() != "user":
            return False

        content = payload.get("content")
        if isinstance(content, str):
            texts.append(content)
        elif isinstance(content, list):
            chunks: list[str] = []
            for chunk in content:
                if isinstance(chunk, str):
                    chunks.append(chunk)
                elif isinstance(chunk, dict):
                    chunk_text = chunk.get("text")
                    if isinstance(chunk_text, str):
                        chunks.append(chunk_text)
                    elif isinstance(chunk.get("content"), str):
                        chunks.append(str(chunk.get("content")))
            if chunks:
                texts.append("\n".join(chunks))
        elif isinstance(content, dict):
            if isinstance(content.get("text"), str):
                texts.append(str(content.get("text")))
            elif isinstance(content.get("content"), str):
                texts.append(str(content.get("content")))
    elif payload_type == "user_message":
        message_text = payload.get("message")
        if isinstance(message_text, str):
            texts.append(message_text)

    for text in texts:
        if _spawn_agent_message_matches_coder_task(text, task_id):
            return True

    return False


def _find_transcript_floor_for_coder_pass(
    transcript_path: str,
    task_id: str | None,
) -> int | None:
    if not transcript_path:
        return None

    records = _iter_transcript_records(transcript_path)
    if not records:
        return None

    candidate_floors: list[int] = []
    task_hint = str(task_id) if task_id else None

    for index, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            continue
        payload = record.get("payload")
        if not isinstance(payload, dict):
            continue

        payload_type = str(payload.get("type", "")).lower()
        if (
            payload_type == "function_call"
            and str(payload.get("name", "")).lower() == "spawn_agent"
        ):
            arguments = _extract_spawn_agent_arguments(payload.get("arguments"))
            if arguments is None:
                continue

            if str(arguments.get("agent_type", "")).lower() != "coder":
                continue

            if _spawn_agent_message_matches_coder_task(arguments.get("message"), task_hint):
                candidate_floors.append(index)
                continue

        if _message_record_matches_coder_task(payload, task_hint):
            candidate_floors.append(index)

    if not candidate_floors:
        return None

    if task_hint is None:
        return candidate_floors[-1]

    for floor in reversed(candidate_floors):
        if _find_reviewer_approval_seq(records, floor, task_hint) is not None:
            return floor

    return candidate_floors[-1]


def _signature_list(value: Any) -> list[str]:
    if isinstance(value, list) and all(isinstance(item, str) and "|" in item for item in value):
        return value
    return []


def _verification_signature(turn: dict[str, Any]) -> list[str]:
    return _signature_list(turn.get("verification", {}).get("snapshot_signature"))


def _commit_signature(turn: dict[str, Any]) -> list[str]:
    return _signature_list(turn.get("commit", {}).get("snapshot_signature"))


def _commit_command_recorded(turn: dict[str, Any]) -> bool:
    commands = turn.get("commit", {}).get("commands")
    return bool(commands) or bool(turn.get("commit", {}).get("done"))


def _normalize_coder_passes(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _latest_completed_coder_pass(coder_passes: list[dict[str, Any]]) -> dict[str, Any] | None:
    latest = None
    latest_seq = -1
    for pass_record in coder_passes:
        stop_seq = pass_record.get("stop_seq")
        if isinstance(stop_seq, int) and stop_seq > latest_seq:
            latest_seq = stop_seq
            latest = pass_record
    return latest


def _passes_with_start_after_seq(
    coder_passes: list[dict[str, Any]],
    seq: int,
) -> list[dict[str, Any]]:
    matches: list[dict[str, Any]] = []
    for pass_record in coder_passes:
        start_seq = pass_record.get("start_seq")
        if isinstance(start_seq, int) and start_seq > seq:
            matches.append(pass_record)
    return sorted(matches, key=lambda item: item.get("start_seq", -1))


def _earliest_completed_pass_after_seq(
    coder_passes: list[dict[str, Any]],
    seq: int,
) -> dict[str, Any] | None:
    completed = [
        pass_record
        for pass_record in coder_passes
        if isinstance(pass_record, dict)
        and isinstance(pass_record.get("start_seq"), int)
        and pass_record.get("start_seq") > seq
        and isinstance(pass_record.get("stop_seq"), int)
    ]
    if not completed:
        return None
    return sorted(completed, key=lambda item: item.get("start_seq", -1))[0]


def _infer_remediation_required_task_id(
    agents: dict[str, Any],
    coder_passes: list[dict[str, Any]],
    remediation_after_seq: int,
) -> str | None:
    remediation_required_task_id = agents.get("remediation_required_task_id")
    if isinstance(remediation_required_task_id, str):
        remediation_required_task_id = remediation_required_task_id.strip()
        if remediation_required_task_id:
            return remediation_required_task_id

    candidates = _passes_with_start_after_seq(coder_passes, remediation_after_seq)
    completed_candidates: list[dict[str, Any]] = []
    for pass_record in candidates:
        if not isinstance(pass_record, dict):
            continue
        if not isinstance(pass_record.get("stop_seq"), int):
            continue
        completed_candidates.append(pass_record)

    candidates = completed_candidates
    for pass_record in candidates:
        task_id, count = _task_id_record(pass_record, "start")
        if task_id and count == 1:
            return task_id
    return None


def _remediation_candidates_for_blocker(
    coder_passes: list[dict[str, Any]],
    agents: dict[str, Any],
    remediation_after_seq: int,
) -> tuple[list[dict[str, Any]], str | None]:
    remediation_candidates = _passes_with_start_after_seq(coder_passes, remediation_after_seq)
    remediation_required_task_id = _infer_remediation_required_task_id(
        agents,
        remediation_candidates,
        remediation_after_seq,
    )
    if remediation_required_task_id:
        remediation_candidates = _passes_with_exact_task_id(
            remediation_candidates,
            remediation_required_task_id,
        )
    return remediation_candidates, remediation_required_task_id


def _remediation_block_resolved(
    coder_passes: list[dict[str, Any]],
    agents: dict[str, Any],
    remediation_after_seq: int,
) -> bool:
    if not isinstance(remediation_after_seq, int):
        return False

    reviewer_seq = agents.get("reviewer_last_seq")
    if not isinstance(reviewer_seq, int):
        return False
    if agents.get("reviewer_last_blocking"):
        return False

    remediation_candidates, blocker_task_id = _remediation_candidates_for_blocker(
        coder_passes,
        agents,
        remediation_after_seq,
    )

    latest_completed = _latest_completed_pass(remediation_candidates)
    if not latest_completed:
        return False

    completed_stop_seq = latest_completed.get("stop_seq")
    if not isinstance(completed_stop_seq, int):
        return False

    reviewer_approval_seq = _latest_matching_reviewer_approval_seq(
        _normalize_reviewer_stops(agents.get("reviewer_stops", [])),
        completed_stop_seq,
        blocker_task_id,
    )
    if not isinstance(reviewer_approval_seq, int):
        return False

    return reviewer_approval_seq > completed_stop_seq


def _passes_with_exact_task_id(
    coder_passes: list[dict[str, Any]],
    task_id: str | None,
) -> list[dict[str, Any]]:
    if not task_id:
        return [item for item in coder_passes if isinstance(item, dict)]

    exact_matches: list[dict[str, Any]] = []
    for pass_record in coder_passes:
        if not isinstance(pass_record, dict):
            continue
        candidate_task_id, candidate_count = _task_id_record(pass_record, "start")
        if candidate_task_id == task_id and candidate_count == 1:
            exact_matches.append(pass_record)
    return exact_matches


def _latest_relevant_coder_passes(
    coder_passes: list[dict[str, Any]],
    agents: dict[str, Any],
) -> list[dict[str, Any]]:
    if not isinstance(coder_passes, list):
        return []

    remediation_after_seq = agents.get("remediation_required_after_seq")
    if isinstance(remediation_after_seq, int):
        if not _remediation_block_resolved(coder_passes, agents, remediation_after_seq):
            remediation_candidates, _ = _remediation_candidates_for_blocker(
                coder_passes,
                agents,
                remediation_after_seq,
            )
            if remediation_candidates:
                completed = [
                    record
                    for record in remediation_candidates
                    if isinstance(record.get("stop_seq"), int)
                ]
                if completed:
                    return [sorted(completed, key=lambda item: item.get("stop_seq", -1))[-1]]
                return [sorted(remediation_candidates, key=lambda item: item.get("start_seq", -1))[-1]]
            return []

    completed_passes = [record for record in coder_passes if isinstance(record.get("stop_seq"), int)]
    if completed_passes:
        return [sorted(completed_passes, key=lambda item: item.get("stop_seq", -1))[-1]]

    open_passes = [
        pass_record
        for pass_record in coder_passes
        if isinstance(pass_record.get("start_seq"), int)
    ]
    if open_passes:
        return [sorted(open_passes, key=lambda item: item.get("start_seq", -1))[-1]]
    return []


def _latest_completed_pass(passes: list[dict[str, Any]]) -> dict[str, Any] | None:
    completed = [record for record in passes if isinstance(record.get("stop_seq"), int)]
    if not completed:
        return None
    return sorted(completed, key=lambda item: item.get("stop_seq", -1))[-1]


def _task_id_record(record: dict[str, Any], field: str) -> tuple[str | None, int]:
    task_id_key = f"{field}_task_id"
    count_key = f"{field}_task_id_count"
    task_id = record.get(task_id_key)
    count = record.get(count_key)
    if not isinstance(count, int):
        return None, 0
    if isinstance(task_id, str) and task_id and count == 1:
        return task_id, 1
    return None, count


def _task_id_required(record: dict[str, Any], field: str) -> bool:
    task_id, count = _task_id_record(record, field)
    return bool(task_id) and count == 1


def _signature_for_record(record: dict[str, Any], field: str) -> list[str]:
    return _signature_list(record.get(field))


def _start_snapshot_recorded(record: dict[str, Any]) -> bool:
    return bool(record.get("start_snapshot_recorded"))


def _work_signature(turn: dict[str, Any], current_signature: list[str]) -> tuple[list[str], bool]:
    commit = turn.get("commit", {})
    commit_signature = _commit_signature(turn)
    has_valid_pre_tool_commit_snapshot = (
        bool(commit.get("done"))
        and bool(commit.get("snapshot_from_pre_tool"))
        and bool(commit_signature)
    )
    if has_valid_pre_tool_commit_snapshot:
        return commit_signature, True

    if bool(commit.get("done")):
        verification_signature = _verification_signature(turn)
        if verification_signature:
            return verification_signature, False
        reviewer_signature = _signature_list(turn.get("agents", {}).get("reviewer_last_snapshot_signature", []))
        if reviewer_signature:
            return reviewer_signature, False

    return current_signature, False


def _recovery_verification_signature(
    turn: dict[str, Any],
    current_signature: list[str],
    relevant_pass: dict[str, Any] | None,
    reviewer_seq: int | None,
) -> list[str]:
    if isinstance(relevant_pass, dict):
        stop_signature = _signature_for_record(relevant_pass, "stop_snapshot_signature")
        if stop_signature:
            return stop_signature

    agents = turn.get("agents", {})
    if not isinstance(agents, dict):
        return current_signature

    if not isinstance(reviewer_seq, int):
        return current_signature

    review_snapshot = _signature_list(agents.get("reviewer_last_snapshot_signature", []))
    if not review_snapshot:
        return current_signature

    if agents.get("reviewer_last_blocking"):
        return current_signature

    relevant_stop_seq = 0
    if isinstance(relevant_pass, dict):
        stop_seq = relevant_pass.get("stop_seq")
        if isinstance(stop_seq, int):
            relevant_stop_seq = stop_seq

    if reviewer_seq > relevant_stop_seq:
        return review_snapshot

    return current_signature


def _signature_by_path(signatures: list[str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for signature in signatures:
        if not isinstance(signature, str):
            continue
        parts = signature.split("|", 2)
        if len(parts) != 3:
            continue
        out[parts[1]] = signature
    return out


def _post_commit_has_uncommitted_change(
    current_signature: list[str],
    baseline_signature: list[str],
    commit_signature: list[str],
) -> bool:
    baseline_by_path = _signature_by_path(baseline_signature)
    current_by_path = _signature_by_path(current_signature)
    commit_by_path = _signature_by_path(commit_signature)

    for path, signature in current_by_path.items():
        baseline_signature_for_path = baseline_by_path.get(path)
        if baseline_signature_for_path is None:
            # A path not seen at baseline is newly dirty after commit.
            return True

        commit_signature_for_path = commit_by_path.get(path)
        if commit_signature_for_path is not None and signature != commit_signature_for_path:
            # A committed path that is still dirty now (including returning to baseline)
            # indicates post-commit uncommitted work.
            return True

        if signature != baseline_signature_for_path:
            return True

    return False


def _signature_stale(expected: list[str], current: list[str]) -> bool:
    return bool(expected) and not signatures_match(expected, current)


def _reviewer_passed(turn: dict[str, Any]) -> bool:
    return _reviewer_passed_reason(turn) is None


def _coder_signature(turn: dict[str, Any]) -> list[str]:
    coder_signature = _signature_list(turn.get("agents", {}).get("coder_last_snapshot_signature"))
    if coder_signature:
        return coder_signature

    passes = _normalize_coder_passes(turn.get("agents", {}).get("coder_passes"))
    latest_pass = _latest_completed_coder_pass(passes)
    if latest_pass:
        return _signature_for_record(latest_pass, "stop_snapshot_signature")
    return []


def _backfill_pass_tasks_from_subagent_starts(state: dict[str, Any]) -> None:
    turn = state.get("turn", {})
    agents = turn.get("agents", {})
    coder_passes = agents.get("coder_passes")
    if not isinstance(coder_passes, list):
        return

    events = turn.get("events", [])
    if not isinstance(events, list):
        return

    start_records: dict[int, str] = {}
    stop_records: dict[int, str] = {}
    for event in events:
        if not isinstance(event, dict):
            continue
        details = event.get("details")
        if not isinstance(details, dict) or details.get("agent") != "coder":
            continue
        seq = event.get("seq")
        if not isinstance(seq, int):
            continue

        if event.get("event") == "SubagentStart":
            raw = details.get("raw")
            if not isinstance(raw, dict):
                continue
            transcript_path = raw.get("transcript_path")
            if isinstance(transcript_path, str) and transcript_path:
                start_records[seq] = transcript_path
        elif event.get("event") == "SubagentStop":
            transcript_path = details.get("agent_transcript_path")
            if isinstance(transcript_path, str) and transcript_path:
                stop_records[seq] = transcript_path

    for pass_record in coder_passes:
        if not isinstance(pass_record, dict):
            continue

        start_seq = pass_record.get("start_seq")
        if not isinstance(start_seq, int):
            continue

        transcript_paths: list[str] = []
        agent_transcript_path = pass_record.get("agent_transcript_path")
        if isinstance(agent_transcript_path, str) and agent_transcript_path:
            transcript_paths.append(agent_transcript_path)

        stop_seq = pass_record.get("stop_seq")
        if isinstance(stop_seq, int) and stop_seq in stop_records:
            transcript_paths.append(stop_records[stop_seq])
        if start_seq in start_records:
            transcript_paths.append(start_records[start_seq])

        recovered_task_id: str | None = None
        recovered_count = 0
        for transcript_path in dict.fromkeys(transcript_paths):
            recovered_task_id, recovered_count = extract_task_id_from_subagent_transcript(
                transcript_path,
                agent="coder",
            )
            if recovered_task_id and recovered_count == 1:
                break
        if recovered_task_id and recovered_count == 1:
            pass_record["start_task_id"] = recovered_task_id
            pass_record["start_task_id_count"] = recovered_count

            if pass_record.get("stop_seq") is not None:
                pass_record["stop_task_id"] = recovered_task_id
                pass_record["stop_task_id_count"] = recovered_count
            turn["current_task_id"] = recovered_task_id
            agents["coder_last_task_id"] = recovered_task_id
            if agents.get("remediation_coder_start_seq") == start_seq:
                agents["remediation_coder_task_id"] = recovered_task_id


def _find_transcript_path_for_stop(state: dict[str, Any]) -> str:
    if not isinstance(state, dict):
        return ""

    turn = state.get("turn", {})
    if not isinstance(turn, dict):
        return ""

    events = turn.get("events", [])
    if not isinstance(events, list):
        return ""

    latest: tuple[int, str] | None = None

    for offset, event in enumerate(events, start=1):
        if not isinstance(event, dict):
            continue
        if event.get("event") == "Stop":
            details = event.get("details")
            if isinstance(details, dict):
                path = details.get("transcript_path")
                if isinstance(path, str) and path:
                    order = event.get("seq")
                    if not isinstance(order, int):
                        order = offset
                    if latest is None or order >= latest[0]:
                        latest = (order, str(path))
            path = event.get("transcript_path")
            if isinstance(path, str) and path:
                order = event.get("seq")
                if not isinstance(order, int):
                    order = offset
                if latest is None or order >= latest[0]:
                    latest = (order, str(path))

    return latest[1] if latest else ""


def _recover_coder_evidence_from_transcript(
    state: dict[str, Any],
    current_signature: list[str],
    required_commit: bool,
) -> None:
    if not isinstance(state, dict):
        return

    transcript_path = _find_transcript_path_for_stop(state)
    if not transcript_path:
        return

    turn = state.get("turn", {})
    if not isinstance(turn, dict):
        return

    agents = turn.get("agents", {})
    verification = turn.get("verification", {})
    commit = turn.get("commit", {})
    if not isinstance(verification, dict) or not isinstance(commit, dict):
        return

    transcript_records = _iter_transcript_records(transcript_path)
    if not transcript_records:
        return

    coder_passes = _normalize_coder_passes(agents.get("coder_passes", []))
    relevant_passes = _latest_relevant_coder_passes(coder_passes, agents)
    relevant_pass = relevant_passes[0] if relevant_passes else None
    latest_relevant_stop_seq = 0
    if isinstance(relevant_pass, dict):
        stop_seq = relevant_pass.get("stop_seq")
        if isinstance(stop_seq, int):
            latest_relevant_stop_seq = stop_seq
        else:
            start_seq = relevant_pass.get("start_seq")
            if isinstance(start_seq, int):
                latest_relevant_stop_seq = start_seq

    relevant_task_id, _ = _task_id_record(relevant_pass or {}, "start") if isinstance(relevant_pass, dict) else (None, 0)
    if not relevant_task_id:
        relevant_task_id = turn.get("current_task_id")
    transcript_floor = _find_transcript_floor_for_coder_pass(transcript_path, relevant_task_id)
    if transcript_floor is None:
        return

    reviewer_seq = agents.get("reviewer_last_seq")
    if not isinstance(reviewer_seq, int):
        reviewer_seq = None

    reviewer_has_state = isinstance(reviewer_seq, int)
    reviewer_approval_seq = _find_reviewer_approval_seq(
        transcript_records,
        transcript_floor,
        relevant_task_id if isinstance(relevant_task_id, str) else None,
    )

    verification_transcript_seq = _max_transcript_seq(verification.get("commands"))

    execution_records = recover_successful_exec_calls_from_transcript(transcript_path)
    if not execution_records:
        return

    recovery_verification_signature = _recovery_verification_signature(
        turn,
        current_signature,
        relevant_pass,
        reviewer_seq,
    )

    synthetic_seq_floor = max(latest_relevant_stop_seq, 0)
    verification_last_seq = verification.get("last_seq")
    if isinstance(verification_last_seq, int):
        synthetic_seq_floor = max(synthetic_seq_floor, verification_last_seq)
    commit_last_seq = commit.get("last_seq")
    if isinstance(commit_last_seq, int):
        synthetic_seq_floor = max(synthetic_seq_floor, commit_last_seq)

    def _next_seq(
        floor: int,
        must_exceed: int | None = None,
        must_precede: int | None = None,
    ) -> int | None:
        next_seq = max(floor + 1, must_exceed + 1 if isinstance(must_exceed, int) else floor + 1)
        if isinstance(must_precede, int) and next_seq >= must_precede:
            return None
        return next_seq

    for record in execution_records:
        transcript_seq = record.get("transcript_seq")
        if not isinstance(transcript_seq, int) or transcript_seq <= transcript_floor:
            continue

        command = str(record.get("command", "")).lower()
        exit_code = record.get("exit_code")
        if exit_code != 0:
            continue

        if not verification.get("run") and command_match_verification(command):
            if reviewer_approval_seq is not None:
                if transcript_seq >= reviewer_approval_seq:
                    continue
            elif reviewer_has_state:
                continue

            next_seq = _next_seq(
                synthetic_seq_floor,
                must_precede=reviewer_seq if isinstance(reviewer_seq, int) and reviewer_seq > 0 else None,
            )
            if next_seq is None:
                continue

            if not isinstance(verification.get("commands"), list):
                verification["commands"] = []

            verification["run"] = True
            verification["commands"].append(
                {
                    "at": now_iso(),
                    "command": command,
                    "exit_code": 0,
                    "source": "transcript",
                    "transcript_seq": record.get("transcript_seq"),
                }
            )
            verification["last_seq"] = next_seq
            verification["at"] = now_iso()
            verification["snapshot_signature"] = list(recovery_verification_signature)
            verification["snapshot"] = signature_paths(recovery_verification_signature)
            verification_transcript_seq = transcript_seq
            synthetic_seq_floor = next_seq

        if required_commit and not commit.get("done") and command_is_commit(command):
            verification_last_seq = verification.get("last_seq")
            if not isinstance(verification_last_seq, int) or not verification.get("run"):
                continue

            if not isinstance(reviewer_seq, int) or agents.get("reviewer_last_blocking"):
                continue
            if reviewer_approval_seq is None:
                continue
            if not isinstance(transcript_seq, int):
                continue
            if transcript_seq <= reviewer_approval_seq:
                continue
            if isinstance(verification_transcript_seq, int) and transcript_seq <= verification_transcript_seq:
                continue

            verification_signature = _verification_signature(turn)
            if not verification_signature:
                continue

            next_seq = _next_seq(
                synthetic_seq_floor,
                must_exceed=max(verification_last_seq, reviewer_seq),
                must_precede=None,
            )
            if not isinstance(next_seq, int):
                continue

            if not isinstance(commit.get("commands"), list):
                commit["commands"] = []
            commit["done"] = True
            commit["commands"].append(
                {
                    "at": now_iso(),
                    "command": command,
                    "exit_code": 0,
                    "source": "transcript",
                    "transcript_seq": record.get("transcript_seq"),
                }
            )
            commit["last_seq"] = next_seq
            commit["at"] = now_iso()
            commit["snapshot_signature"] = list(verification_signature)
            commit["snapshot"] = signature_paths(commit["snapshot_signature"])
            commit["snapshot_from_pre_tool"] = True

    turn["agents"] = agents
    turn["verification"] = verification
    turn["commit"] = commit


def _missing_requirements(state: dict[str, Any], current_signature: list[str]) -> list[str]:
    turn = state.get("turn", {})
    agents = turn.get("agents", {})
    verification = turn.get("verification", {})
    missing: list[str] = []
    commit_recorded = _commit_command_recorded(turn)
    if not state.get("active"):
        return missing

    task_ledgers = turn.get("task_ledgers")
    if isinstance(task_ledgers, dict) and task_ledgers:
        return _missing_task_ledger_requirements(turn)

    # Legacy aggregate state remains readable, but a newly observed malformed
    # coder/reviewer session cannot fall back to that compatibility path.
    strict_start_violations = [
        str(item.get("message"))
        for item in turn.get("lifecycle_violations", [])
        if isinstance(item, dict) and item.get("message")
    ]
    missing.extend(strict_start_violations)

    baseline_signature = turn.get("files_changed_signature_at_start", [])
    if not isinstance(baseline_signature, list):
        baseline_signature = []

    work_signature, using_commit_snapshot = _work_signature(turn, current_signature)
    work_delta = bool(changed_signatures_delta(baseline_signature, work_signature))
    changed_since_start = bool(changed_signatures_delta(baseline_signature, current_signature))
    work_detected = bool(turn.get("implementation_oriented")) or bool(changed_since_start) or work_delta or bool(commit_recorded)
    requires_commit = bool(work_delta) and bool(turn.get("commit_requested"))

    if not work_detected:
        return missing

    coder_passes = _normalize_coder_passes(agents.get("coder_passes"))
    relevant_passes = _latest_relevant_coder_passes(coder_passes, agents)
    relevant_pass = relevant_passes[0] if relevant_passes else None
    latest_relevant_completed_pass = (
        _latest_completed_pass(relevant_passes) if relevant_passes else None
    )
    remediation_required_after_seq = agents.get("remediation_required_after_seq")

    latest_relevant_stop_seq: int | None = None
    if relevant_pass is not None:
        stop_seq = relevant_pass.get("stop_seq")
        if isinstance(stop_seq, int):
            latest_relevant_stop_seq = stop_seq
        else:
            start_seq = relevant_pass.get("start_seq")
            if isinstance(start_seq, int):
                latest_relevant_stop_seq = start_seq

    relevant_task_id, relevant_task_count = _task_id_record(relevant_pass or {}, "start")
    if not isinstance(relevant_task_count, int):
        relevant_task_count = 0
    anchored_current_task_id = turn.get("current_task_id")
    if relevant_task_count == 1 and relevant_task_id:
        anchored_current_task_id = relevant_task_id

    if not agents.get("coder_started"):
        missing.append("coder subagent not started")
    elif not agents.get("coder_stopped"):
        missing.append("coder subagent has not completed a pass")

    current_task_id = anchored_current_task_id
    if agents.get("coder_started") and not current_task_id:
        missing.append("coder task id not recorded")

    latest_coder_pass = _latest_completed_coder_pass(coder_passes)
    if not relevant_pass and agents.get("coder_stopped"):
        missing.append("coder has no completed pass record")

    if relevant_pass is not None:
        pass_label = "relevant coder pass"
        start_task_id, start_count = _task_id_record(relevant_pass, "start")
        if not _task_id_required(relevant_pass, "start"):
            missing.append(f"{pass_label} missing exactly one Task ID")
        if start_task_id and current_task_id and start_task_id != current_task_id:
            missing.append(f"{pass_label} task ID does not match current task")
        if start_count != 1:
            missing.append(f"{pass_label} task ID count is not exactly one")
        if not isinstance(relevant_pass.get("start_seq"), int):
            missing.append(f"{pass_label} missing start sequence")
        start_signature = _signature_for_record(relevant_pass, "start_snapshot_signature")
        if not _start_snapshot_recorded(relevant_pass):
            missing.append(f"{pass_label} missing start snapshot recording evidence")
        if not start_signature and not _start_snapshot_recorded(relevant_pass):
            missing.append(f"{pass_label} missing start snapshot signature")
        if isinstance(relevant_pass.get("stop_seq"), int):
            stop_signature = _signature_for_record(relevant_pass, "stop_snapshot_signature")
            if not stop_signature:
                missing.append(f"{pass_label} missing stop snapshot signature")
        else:
            missing.append("relevant coder pass has not completed")

    latest_remediation_passes: list[dict[str, Any]] = []
    remediation_required_task_id = None
    if isinstance(remediation_required_after_seq, int):
        blocked_by_task = agents.get("remediation_required_task_id")
        if isinstance(blocked_by_task, str):
            blocked_by_task = blocked_by_task.strip() or None
        remediation_resolved = _remediation_block_resolved(
            coder_passes,
            agents,
            remediation_required_after_seq,
        )
        if remediation_resolved:
            pass
        else:
            missing.append("remediation and subsequent non-blocking reviewer pass for blocker task is incomplete")
            latest_remediation_passes, remediation_required_task_id = _remediation_candidates_for_blocker(
                coder_passes,
                agents,
                remediation_required_after_seq,
            )
            if not latest_remediation_passes:
                if blocked_by_task:
                    missing.append("remediation coder pass for blocker task was not found")
                    missing.append("blocking reviewer requires a new coder remediation pass")
                else:
                    missing.append("blocking reviewer requires a new coder remediation pass")
            if latest_remediation_passes:
                blocker_signature = _signature_list(agents.get("blocking_reviewer_snapshot_signature"))
                remediation_latest_completed = _latest_completed_pass(latest_remediation_passes)
                remediation_for_signature_check = _earliest_completed_pass_after_seq(
                    latest_remediation_passes,
                    remediation_required_after_seq,
                )
                if remediation_for_signature_check is None:
                    remediation_for_signature_check = sorted(
                        latest_remediation_passes,
                        key=lambda item: item.get("start_seq", -1),
                    )[0]
                if blocker_signature and remediation_for_signature_check:
                    remediation_start_signature = _signature_for_record(
                        remediation_for_signature_check,
                        "start_snapshot_signature",
                    )
                    if _signature_stale(blocker_signature, remediation_start_signature):
                        missing.append(
                            "remediation coder pass started after working tree changed since blocking review",
                        )
                if not remediation_latest_completed:
                    missing.append("remediation coder pass has not completed after blocking reviewer")
                else:
                    remediation_task_id, remediation_task_count = _task_id_record(
                        remediation_latest_completed,
                        "start",
                    )
                    if not (remediation_task_id and remediation_task_count == 1):
                        missing.append("remediation coder task id missing or ambiguous")
                    elif remediation_required_task_id and remediation_task_id != remediation_required_task_id:
                        missing.append("remediation coder task id does not match blocker task")
                    state["turn"]["agents"]["remediation_coder_last_seq"] = remediation_latest_completed.get("stop_seq")
                    state["turn"]["agents"]["remediation_coder_task_id"] = remediation_task_id

                    remediation_start_seq = remediation_latest_completed.get("start_seq")
                    if isinstance(remediation_start_seq, int):
                        state["turn"]["agents"]["remediation_coder_start_seq"] = remediation_start_seq

    coder_signature = _coder_signature(turn)
    if agents.get("coder_stopped"):
        if not coder_signature:
            missing.append("coder completion snapshot not recorded")
        elif _signature_stale(work_signature, coder_signature):
            if latest_relevant_completed_pass:
                latest_signature = _signature_for_record(latest_relevant_completed_pass, "stop_snapshot_signature")
                if _signature_stale(work_signature, latest_signature):
                    missing.append("final work signature does not match relevant coder output")

    coordinator_file_edits = any(
        isinstance(event, dict) and event.get("actor") == "coordinator"
        for event in agents.get("main_agent_file_edit_events", [])
    )
    if coordinator_file_edits:
        missing.append("main agent performed file-edit tool actions while a coder pass was open")

    reviewer_pass_issue = _reviewer_passed_reason(turn)
    if reviewer_pass_issue is not None:
        missing.append(reviewer_pass_issue)
    else:
        review_signature = agents.get("reviewer_last_snapshot_signature", [])
        reviewer_work_signature = work_signature if requires_commit else current_signature
        if requires_commit and _signature_stale(reviewer_work_signature, review_signature):
            missing.append("reviewer snapshot does not match final verification/committed signature")
        elif not requires_commit and turn.get("verification", {}).get("run"):
            if _signature_stale(_verification_signature(turn), review_signature):
                missing.append("reviewer snapshot does not match final verification snapshot")

        reviewer_seq = agents.get("reviewer_last_seq")
        verification_seq = verification.get("last_seq")
        latest_stop_seq = latest_relevant_stop_seq

        if isinstance(latest_stop_seq, int) and isinstance(reviewer_seq, int) and reviewer_seq <= latest_stop_seq:
            missing.append("reviewer pass must occur after latest coder pass")
        elif not isinstance(reviewer_seq, int):
            missing.append("reviewer pass must occur after coder activity")
        if isinstance(verification_seq, int) and isinstance(reviewer_seq, int) and reviewer_seq <= verification_seq:
            missing.append("reviewer pass must occur after successful verification")

    verification_signature = _verification_signature(turn)
    if not verification.get("run"):
        missing.append("verification command not recorded")
    else:
        verification_seq = verification.get("last_seq")
        latest_stop_seq = latest_relevant_stop_seq
        if (
            isinstance(verification_seq, int)
            and isinstance(latest_stop_seq, int)
            and verification_seq <= latest_stop_seq
        ):
            missing.append("verification must run after latest coder pass")

        if (
            isinstance(remediation_required_after_seq, int)
            and isinstance(verification_seq, int)
            and isinstance(agents.get("remediation_coder_last_seq"), int)
            and verification_seq <= agents["remediation_coder_last_seq"]
        ):
            missing.append("verification must run after remediation coder pass")

        verification_work_signature = work_signature if (requires_commit and using_commit_snapshot) else current_signature
        if _signature_stale(verification_work_signature, verification_signature):
            missing.append("verification snapshot is stale relative to final work signature")

    if requires_commit and not turn.get("commit", {}).get("done"):
        missing.append("commit command not completed after file changes")
    elif requires_commit:
        commit = turn.get("commit", {})
        has_valid_pre_tool_commit_signature = bool(commit.get("snapshot_from_pre_tool")) and bool(_commit_signature(turn))
        if not has_valid_pre_tool_commit_signature:
            missing.append("commit missing pre-tool snapshot")
        elif commit.get("last_seq") is None or verification.get("last_seq") is None:
            missing.append("commit must occur after successful verification")
        elif int(commit.get("last_seq")) <= int(verification.get("last_seq")):
            missing.append("commit must occur after successful verification")
        elif isinstance(agents.get("reviewer_last_seq"), int) and int(commit.get("last_seq")) <= int(agents["reviewer_last_seq"]):
            missing.append("commit must occur after reviewer approval")
        elif _signature_stale(_commit_signature(turn), verification_signature):
            missing.append("committed work does not match verified snapshot")
        if _post_commit_has_uncommitted_change(
            current_signature,
            baseline_signature,
            _commit_signature(turn),
        ):
            missing.append("post-commit working tree includes uncommitted changes")

    return missing


def _approved_same_task_commits_before(
    ledger: dict[str, Any], before_seq: int,
    reviewer_passes: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    """Return the uninterrupted approved commit chain preceding a coder pass."""
    baseline_head = str(ledger.get("baseline_head", "")).strip()
    expected_head = baseline_head
    previous_commit_seq = -1
    accepted: list[dict[str, Any]] = []

    reference_passes = [
        item for item in ledger.get("coder_passes", [])
        if isinstance(item, dict) and isinstance(item.get("start_seq"), int)
        and item["start_seq"] <= before_seq
    ]
    reference_pass = (
        max(reference_passes, key=lambda item: item["start_seq"])
        if reference_passes else None
    )
    reference_head = (
        str(reference_pass.get("start_head", "")).strip()
        if reference_pass else ""
    ) or git_head_commit()

    commits = sorted(
        (
            item for item in ledger.get("commits", [])
            if isinstance(item, dict) and isinstance(item.get("seq"), int)
            and item["seq"] < before_seq
            and _commit_is_in_active_ancestry(item, reference_head)
        ),
        key=lambda item: item["seq"],
    )
    passes = [
        item for item in ledger.get("coder_passes", [])
        if isinstance(item, dict) and isinstance(item.get("start_seq"), int)
        and isinstance(item.get("stop_seq"), int)
    ]
    verifications = [
        item for item in ledger.get("verifications", [])
        if isinstance(item, dict) and isinstance(item.get("seq"), int)
    ]
    reviews = [
        item for item in (
            reviewer_passes
            if reviewer_passes is not None
            else ledger.get("reviewer_passes", [])
        )
        if isinstance(item, dict) and isinstance(item.get("seq"), int)
    ]

    for commit in commits:
        commit_seq = commit["seq"]
        cycle_passes = [
            item for item in passes
            if previous_commit_seq < item["start_seq"]
            and item["stop_seq"] < commit_seq
        ]
        if not cycle_passes:
            break
        coder_pass = max(cycle_passes, key=lambda item: item["stop_seq"])
        first_coder_pass = min(cycle_passes, key=lambda item: item["start_seq"])

        cycle_reviews = [
            item for item in reviews
            if previous_commit_seq < item["seq"] < commit_seq
        ]
        if not cycle_reviews:
            break
        approval = max(cycle_reviews, key=lambda item: item["seq"])
        if approval.get("blocking") is not False:
            break

        blocking_reviews = [
            item for item in cycle_reviews if item.get("blocking") is True
        ]
        if blocking_reviews:
            latest_blocker = max(blocking_reviews, key=lambda item: item["seq"])
            if coder_pass["start_seq"] <= latest_blocker["seq"]:
                break

        verified = [
            item for item in verifications
            if coder_pass["stop_seq"] < item["seq"] < approval["seq"]
        ]
        if not verified:
            break
        verification = max(verified, key=lambda item: item["seq"])

        coder_snapshot = coder_pass.get("stop_snapshot_signature")
        verification_snapshot = verification.get("snapshot_signature")
        review_snapshot = approval.get("snapshot_signature")
        commit_snapshot = commit.get("snapshot_signature")
        post_commit_snapshot = commit.get("post_snapshot_signature")
        coder_start_snapshot = first_coder_pass.get("start_snapshot_signature")
        cycle_baseline_snapshot = (
            coder_start_snapshot
            if isinstance(coder_start_snapshot, list)
            else ledger.get("baseline_signature")
        )
        snapshots = (
            coder_snapshot, verification_snapshot, review_snapshot, commit_snapshot,
        )
        if not all(isinstance(snapshot, list) and snapshot for snapshot in snapshots):
            break
        if not (
            signatures_match(coder_snapshot, verification_snapshot)
            and signatures_match(verification_snapshot, review_snapshot)
            and signatures_match(verification_snapshot, commit_snapshot)
        ):
            break
        if (
            not isinstance(cycle_baseline_snapshot, list)
            or not isinstance(post_commit_snapshot, list)
            or not signatures_match(cycle_baseline_snapshot, post_commit_snapshot)
        ):
            break

        coder_start_head = str(coder_pass.get("start_head", "")).strip()
        commit_hash = str(commit.get("hash", "")).strip()
        head_before = str(commit.get("head_before", "")).strip()
        first_parent = str(commit.get("first_parent", "")).strip()
        if coder_start_head and coder_start_head != expected_head:
            break
        if (
            not commit_hash
            or not expected_head
            or head_before != expected_head
            or first_parent != head_before
            or commit_hash == head_before
        ):
            break

        # Synthetic ledgers use descriptive hashes and cannot be checked against
        # Git. For real object IDs, never trust recorded parent metadata alone:
        # require both the actual first parent and live ancestry to agree with
        # the uninterrupted task baseline.
        real_hash = re.compile(r"[0-9a-fA-F]{40,64}").fullmatch
        if real_hash(commit_hash) and real_hash(expected_head) and real_hash(first_parent):
            if git_commit_first_parent(commit_hash) != first_parent:
                break
            if not git_is_ancestor(expected_head, commit_hash):
                break

        accepted.append(commit)
        previous_commit_seq = commit_seq
        expected_head = commit_hash

    return accepted


_REAL_GIT_HASH_PATTERN = re.compile(r"[0-9a-fA-F]{40,64}")
_ORDERING_VIOLATION_PATTERN = re.compile(
    r"^task [a-z0-9_]+ started before changed task [a-z0-9_]+ "
    r"received its approved(?: task-sized)? commit$"
)


def _is_real_git_hash(value: Any) -> bool:
    return bool(_REAL_GIT_HASH_PATTERN.fullmatch(str(value or "").strip()))


def _commit_is_in_active_ancestry(
    commit: dict[str, Any], reference_head: str,
) -> bool:
    """Treat synthetic fixtures as active; prove real commits by live ancestry."""
    commit_hash = str(commit.get("hash", "")).strip()
    if not (_is_real_git_hash(commit_hash) and _is_real_git_hash(reference_head)):
        return True
    return git_is_ancestor(commit_hash, reference_head)


def _head_is_active_ancestor(candidate: str, reference_head: str) -> bool:
    if not (_is_real_git_hash(candidate) and _is_real_git_hash(reference_head)):
        return candidate == reference_head
    return git_is_ancestor(candidate, reference_head)


def _cycle_context(
    ledger: dict[str, Any], final_coder: dict[str, Any], current_head: str,
    reviewer_passes: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Locate the accepted active-history cycle containing ``final_coder``.

    A rewritten-away attempt is excluded only when Git can prove that its real
    commit is absent from both the recovery coder's start ancestry and final
    ancestry. Synthetic records remain strict because their ancestry cannot be
    independently established.
    """
    final_start_seq = final_coder.get("start_seq")
    cycle_end_seq = (
        final_start_seq
        if isinstance(final_start_seq, int)
        else final_coder.get("stop_seq")
    )
    if not isinstance(cycle_end_seq, int):
        cycle_end_seq = 2**63 - 1
    final_start_head = str(final_coder.get("start_head", "")).strip()
    if not final_start_head:
        # A recovery coder can start while an older hook version is active and
        # therefore lack start_head. Once its active commit exists, the normal
        # first-parent checks make head_before the authoritative cycle start.
        later_active_commits = [
            item for item in ledger.get("commits", [])
            if isinstance(item, dict) and isinstance(item.get("seq"), int)
            and item["seq"] > cycle_end_seq
            and _commit_is_in_active_ancestry(item, current_head)
        ]
        if later_active_commits:
            first_later_commit = min(
                later_active_commits, key=lambda item: item["seq"]
            )
            inferred_head = str(
                first_later_commit.get("head_before", "")
            ).strip()
            if _is_real_git_hash(inferred_head):
                final_start_head = inferred_head
        else:
            final_start_head = current_head
    ancestry_head = final_start_head or current_head
    prior_commits = [
        item for item in ledger.get("commits", [])
        if isinstance(item, dict) and isinstance(item.get("seq"), int)
        and isinstance(final_start_seq, int) and item["seq"] < final_start_seq
        and str(item.get("hash", "")).strip()
        and (
            _commit_is_in_active_ancestry(item, ancestry_head)
            or _commit_is_in_active_ancestry(item, current_head)
        )
    ]
    approved_prior = (
        _approved_same_task_commits_before(
            ledger, final_start_seq, reviewer_passes=reviewer_passes,
        )
        if isinstance(final_start_seq, int) else []
    )
    approved_prior = [
        item for item in approved_prior
        if _commit_is_in_active_ancestry(item, current_head)
    ]
    prior_commit = (
        max(approved_prior, key=lambda item: item["seq"])
        if approved_prior else None
    )
    prior_commit_hash = str(prior_commit.get("hash", "")).strip() if prior_commit else ""
    baseline_head = str(ledger.get("baseline_head", "")).strip()

    restarted = bool(
        final_start_head
        and baseline_head
        and _is_real_git_hash(final_start_head)
        and _is_real_git_hash(baseline_head)
        and not _head_is_active_ancestor(baseline_head, final_start_head)
        and not prior_commits
    )
    cycle_baseline_head = (
        prior_commit_hash
        or (final_start_head if restarted else baseline_head)
    )
    prior_boundary = prior_commit["seq"] if prior_commit else -1
    candidates = [
        item for item in ledger.get("coder_passes", [])
        if isinstance(item, dict) and isinstance(item.get("start_seq"), int)
        and prior_boundary < item["start_seq"] <= cycle_end_seq
        and (
            item is final_coder
            or (
                not restarted
                and not str(item.get("start_head", "")).strip()
            )
            or str(item.get("start_head", "")).strip() == cycle_baseline_head
        )
    ]
    first_coder = (
        min(candidates, key=lambda item: item["start_seq"])
        if candidates else final_coder
    )
    first_snapshot = first_coder.get("start_snapshot_signature")
    baseline_snapshot = (
        first_snapshot
        if isinstance(first_snapshot, list)
        else ledger.get("baseline_signature")
    )
    return {
        "active_prior_commits": prior_commits,
        "approved_prior_commits": approved_prior,
        "prior_commit": prior_commit,
        "baseline_head": cycle_baseline_head,
        "baseline_snapshot": baseline_snapshot,
        "effective_start_seq": first_coder.get("start_seq"),
        "restarted": restarted,
    }


def _missing_task_ledger_requirements(turn: dict[str, Any]) -> list[str]:
    """Validate every strict-name chunk independently.

    Evidence is deliberately never borrowed between Task IDs.  This makes a
    final aggregate review/commit unable to close earlier chunks.
    """
    missing: list[str] = []
    ledgers = turn.get("task_ledgers", {})
    seen_commit_hashes: dict[str, str] = {}
    accepted_commit_seqs: dict[str, int] = {}
    accepted_commits: dict[str, dict[str, Any]] = {}

    coordinator_file_edits = any(
        isinstance(event, dict) and event.get("actor") == "coordinator"
        for event in turn.get("agents", {}).get("main_agent_file_edit_events", [])
    )
    if coordinator_file_edits:
        missing.append("main agent performed file-edit tool actions while a coder pass was open")

    for violation in turn.get("lifecycle_violations", []):
        if isinstance(violation, dict) and violation.get("message"):
            message = str(violation["message"])
            # Ordering is re-derived below from the effective active-history
            # cycle. A permanently recorded warning from abandoned history
            # must not make recovery impossible.
            if not _ORDERING_VIOLATION_PATTERN.fullmatch(message):
                missing.append(message)

    current_head = git_head_commit()
    effective_starts: dict[str, int] = {}

    for task_id, ledger in ledgers.items():
        if not isinstance(ledger, dict):
            continue
        prefix = f"task {task_id}"
        passes = [item for item in ledger.get("coder_passes", []) if isinstance(item, dict)]
        completed = [item for item in passes if isinstance(item.get("stop_seq"), int)]
        if not passes:
            missing.append(f"{prefix} coder subagent not started")
            continue
        if len({item.get("agent_identity") for item in passes}) != len(passes):
            missing.append(f"{prefix} reused a coder agent/session")
        if not completed:
            missing.append(f"{prefix} coder subagent has not completed a pass")
            continue

        latest = max(completed, key=lambda item: item["stop_seq"])
        final_coder_seq = latest["stop_seq"]
        changed = bool(ledger.get("changed"))
        reviews = _normalized_ledger_reviewer_passes(turn, task_id, ledger)
        blocking_reviews = [
            item for item in reviews
            if item.get("blocking") is True and isinstance(item.get("seq"), int)
        ]
        blocking_seq = (
            max(item["seq"] for item in blocking_reviews)
            if blocking_reviews else None
        )
        if isinstance(blocking_seq, int):
            remediation = [
                item for item in completed
                if isinstance(item.get("start_seq"), int)
                and item["start_seq"] > blocking_seq
            ]
            if not remediation:
                missing.append(f"{prefix} blocking review requires a brand-new coder remediation pass")
            else:
                latest = max(remediation, key=lambda item: item["stop_seq"])
                final_coder_seq = latest["stop_seq"]

        cycle = _cycle_context(
            ledger, latest, current_head, reviewer_passes=reviews,
        )
        effective_start_seq = cycle.get("effective_start_seq")
        if isinstance(effective_start_seq, int):
            effective_starts[task_id] = effective_start_seq

        verifications = [
            item for item in ledger.get("verifications", [])
            if isinstance(item, dict) and isinstance(item.get("seq"), int)
            and item["seq"] > final_coder_seq
        ]
        if not verifications:
            missing.append(f"{prefix} verification must run after its final coder pass")
            verification_seq = None
        else:
            verification_seq = max(item["seq"] for item in verifications)
            latest_verification = max(verifications, key=lambda item: item["seq"])
            coder_snapshot = latest.get("stop_snapshot_signature")
            verification_snapshot = latest_verification.get("snapshot_signature")
            if (
                isinstance(coder_snapshot, list) and coder_snapshot
                and isinstance(verification_snapshot, list) and verification_snapshot
                and not signatures_match(coder_snapshot, verification_snapshot)
            ):
                missing.append(f"{prefix} verification snapshot does not match final coder output")

        if len({item.get("agent_identity") for item in reviews}) != len(reviews):
            missing.append(f"{prefix} reused a reviewer agent/session")
        approvals = [
            item for item in reviews
            if item.get("blocking") is False
            and isinstance(item.get("seq"), int)
            and isinstance(verification_seq, int)
            and item["seq"] > verification_seq
        ]
        if not approvals:
            missing.append(f"{prefix} needs a fresh non-blocking reviewer after verification")
            approval_seq = None
        else:
            approval_seq = max(item["seq"] for item in approvals)
            approval = max(approvals, key=lambda item: item["seq"])
            review_snapshot = approval.get("snapshot_signature")
            if (
                verifications
                and isinstance(review_snapshot, list) and review_snapshot
                and isinstance(latest_verification.get("snapshot_signature"), list)
                and latest_verification.get("snapshot_signature")
                and not signatures_match(
                    latest_verification["snapshot_signature"], review_snapshot
                )
            ):
                missing.append(f"{prefix} reviewer snapshot does not match verified output")

        if not changed:
            continue
        commits = [
            item for item in ledger.get("commits", [])
            if isinstance(item, dict) and isinstance(item.get("seq"), int)
            and isinstance(approval_seq, int) and item["seq"] > approval_seq
        ]
        if not commits:
            missing.append(f"{prefix} requires its own task-sized commit after approval")
            continue
        commit = max(commits, key=lambda item: item["seq"])
        accepted_commit_seqs[task_id] = commit["seq"]
        accepted_commits[task_id] = commit
        commit_hash = str(commit.get("hash", "")).strip()
        final_coder_start_seq = latest.get("start_seq")
        prior_commits = cycle["active_prior_commits"]
        approved_prior_commits = cycle["approved_prior_commits"]
        prior_commit = cycle["prior_commit"]
        prior_commit_hash = str(prior_commit.get("hash", "")).strip() if prior_commit else ""
        if prior_commits:
            latest_prior_commit = max(prior_commits, key=lambda item: item["seq"])
            if (
                prior_commit is None
                or latest_prior_commit["seq"] != prior_commit["seq"]
                or str(latest_prior_commit.get("hash", "")).strip() != prior_commit_hash
            ):
                missing.append(
                    f"{prefix} sequential baseline includes an unapproved same-task commit"
                )
        coder_start_head = str(latest.get("start_head", "")).strip()
        cycle_baseline_head = str(cycle["baseline_head"] or "")
        if coder_start_head and coder_start_head != cycle_baseline_head:
            missing.append(
                f"{prefix} coder start HEAD is not its previously approved same-task baseline"
            )
        head_before = str(commit.get("head_before", "")).strip()
        first_parent = str(commit.get("first_parent", "")).strip()
        if not commit_hash:
            missing.append(f"{prefix} commit hash not recorded")
        elif cycle_baseline_head and head_before != cycle_baseline_head:
            missing.append(f"{prefix} commit did not advance its recorded baseline HEAD")
        elif cycle_baseline_head and commit_hash == cycle_baseline_head:
            missing.append(f"{prefix} commit did not advance its recorded baseline HEAD")
        elif head_before and commit_hash == head_before:
            missing.append(f"{prefix} commit did not advance HEAD")
        elif not head_before or first_parent != head_before:
            missing.append(
                f"{prefix} commit must be a normal first-parent child of its recorded pre-commit HEAD"
            )
        elif commit_hash in seen_commit_hashes and seen_commit_hashes[commit_hash] != task_id:
            missing.append(
                f"tasks {seen_commit_hashes[commit_hash]} and {task_id} cannot share aggregate commit {commit_hash}"
            )
        else:
            seen_commit_hashes[commit_hash] = task_id

        commit_snapshot = commit.get("snapshot_signature")
        post_commit_snapshot = commit.get("post_snapshot_signature")
        baseline_snapshot = cycle["baseline_snapshot"]
        verified_snapshot = (
            latest_verification.get("snapshot_signature") if verifications else None
        )
        if not isinstance(commit_snapshot, list) or not commit_snapshot:
            missing.append(f"{prefix} empty commit snapshot cannot satisfy task-sized commit gate")
        elif (
            isinstance(verified_snapshot, list)
            and verified_snapshot
            and not signatures_match(verified_snapshot, commit_snapshot)
        ):
            missing.append(f"{prefix} commit snapshot does not match verified coder output")
        if (
            isinstance(baseline_snapshot, list)
            and isinstance(verified_snapshot, list)
            and not changed_signatures_delta(baseline_snapshot, verified_snapshot)
        ):
            missing.append(f"{prefix} verified output has no task change beyond its baseline snapshot")
        if (
            isinstance(baseline_snapshot, list)
            and isinstance(post_commit_snapshot, list)
            and not signatures_match(baseline_snapshot, post_commit_snapshot)
        ):
            missing.append(f"{prefix} commit did not consume exactly the verified task change")

    ordered_tasks: list[tuple[int, str, dict[str, Any]]] = []
    for task_id, ledger in ledgers.items():
        if not isinstance(ledger, dict):
            continue
        effective_start = effective_starts.get(task_id)
        if isinstance(effective_start, int):
            ordered_tasks.append((effective_start, task_id, ledger))
    ordered_tasks.sort()
    for index, (_, task_id, ledger) in enumerate(ordered_tasks[:-1]):
        if not ledger.get("changed"):
            continue
        commit_seq = accepted_commit_seqs.get(task_id)
        for later_start, later_task_id, _ in ordered_tasks[index + 1:]:
            if not isinstance(commit_seq, int) or commit_seq >= later_start:
                missing.append(
                    f"task {later_task_id} started before changed task {task_id} received its approved task-sized commit"
                )

    # Real Git object IDs get a final live ancestry check. This catches a later
    # amend/reset/rebase that removes a previously accepted task commit even if
    # all task-local snapshots still look valid.
    if re.fullmatch(r"[0-9a-fA-F]{40,64}", current_head):
        for task_id, commit in accepted_commits.items():
            commit_hash = str(commit.get("hash", "")).strip()
            if not re.fullmatch(r"[0-9a-fA-F]{40,64}", commit_hash):
                continue
            recorded_parent = str(commit.get("first_parent", "")).strip()
            actual_parent = git_commit_first_parent(commit_hash)
            if actual_parent != recorded_parent:
                missing.append(f"task {task_id} recorded commit parent does not match Git history")
            if not git_is_ancestor(commit_hash, current_head):
                missing.append(f"task {task_id} commit is no longer an ancestor of final HEAD")

    return list(dict.fromkeys(missing))


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    output = {"missing": []}

    def apply_state(state):
        turn = state.get("turn", {})
        changed_now = git_changed_files()
        changed_signature = git_changed_file_signatures()
        turn["files_changed_current"] = changed_now
        turn["files_changed_signature_current"] = changed_signature
        transcript_path = ""
        if isinstance(event, dict):
            transcript_path = str(event.get("transcript_path", "")) or str(event.get("raw", {}).get("transcript_path", ""))
        append_event(state, "Stop", {"input_keys": sorted(event.keys()) if isinstance(event, dict) else [], "transcript_path": transcript_path})

        changed_since_start = False
        if state.get("active"):
            baseline_signature = turn.get("files_changed_signature_at_start", [])
            if not isinstance(baseline_signature, list):
                baseline_signature = []
            changed_since_start = bool(changed_signatures_delta(baseline_signature, changed_signature))
        commit_recorded = _commit_command_recorded(turn)

        missing: list[str] = []
        if turn.get("triggered") and (
            turn.get("implementation_oriented") or changed_since_start or commit_recorded
        ):
            _backfill_pass_tasks_from_subagent_starts(state)
            required_commit = bool(turn.get("commit_requested"))
            _recover_coder_evidence_from_transcript(state, changed_signature, required_commit)
            missing = _missing_requirements(state, changed_signature)
        output["missing"] = missing

    update_state(apply_state)

    missing = output["missing"]

    if missing:
        print(
            json.dumps(
                {
                    "decision": "block",
                    "reason": "Orchestration closure gate failed: " + "; ".join(missing),
                }
            )
        )
        return

    print(json.dumps({}))


if __name__ == "__main__":
    main()
