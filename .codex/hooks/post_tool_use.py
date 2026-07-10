from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    signature_paths,
    command_is_commit,
    changed_signatures_delta,
    command_match_verification,
    extract_completed_agent_paths,
    extract_encoded_task_name_identity,
    extract_transcript_session_identity,
    git_changed_file_signatures,
    now_iso,
    parse_tool_exit_code,
    update_state,
)


def _is_list_agents_tool(value: object) -> bool:
    compact = re.sub(r"[^a-z0-9]+", "", str(value or "").lower())
    return compact == "collaborationlistagents"


def _without_completed_agent_text(value: object, depth: int = 6) -> object:
    if depth <= 0:
        return None
    if isinstance(value, str):
        stripped = value.strip()
        if not (
            (stripped.startswith("{") and stripped.endswith("}"))
            or (stripped.startswith("[") and stripped.endswith("]"))
        ):
            return value
        try:
            decoded = json.loads(stripped)
        except json.JSONDecodeError:
            return value
        return _without_completed_agent_text(decoded, depth - 1)
    if isinstance(value, list):
        return [
            _without_completed_agent_text(item, depth - 1)
            for item in value
        ]
    if isinstance(value, dict):
        return {
            key: (
                ""
                if str(key).lower() == "completed"
                else _without_completed_agent_text(item, depth - 1)
            )
            for key, item in value.items()
        }
    return value


def _close_completed_coder_pass(
    state: dict,
    completed_agent_paths: set[str],
    event_seq: int,
) -> None:
    if not completed_agent_paths:
        return
    turn = state.get("turn", {})
    agents = turn.get("agents", {})
    coder_passes = agents.get("coder_passes")
    if not isinstance(coder_passes, list):
        return

    matching_pass = None
    task_id = ""
    start_seq = None
    for candidate in reversed(coder_passes):
        if not isinstance(candidate, dict) or isinstance(candidate.get("stop_seq"), int):
            continue
        candidate_task_id = candidate.get("start_task_id")
        candidate_start_seq = candidate.get("start_seq")
        if (
            not isinstance(candidate_task_id, str)
            or not candidate_task_id.strip()
            or candidate.get("start_task_id_count") != 1
            or not isinstance(candidate_start_seq, int)
        ):
            continue
        transcript_path = candidate.get("agent_transcript_path")
        if not isinstance(transcript_path, str) or not transcript_path.strip():
            continue
        identity = extract_transcript_session_identity(transcript_path)
        if not isinstance(identity, dict) or identity.get("is_subagent") is not True:
            continue
        agent_path = identity.get("agent_path")
        if not isinstance(agent_path, str) or agent_path not in completed_agent_paths:
            continue

        agent_name = agent_path.rsplit("/", 1)[-1]
        encoded_identity = extract_encoded_task_name_identity(agent_name)
        if "__" in agent_name and encoded_identity is None:
            continue
        if encoded_identity is not None and encoded_identity != (
            "coder",
            candidate_task_id.strip(),
            1,
        ):
            continue
        matching_pass = candidate
        task_id = candidate_task_id.strip()
        start_seq = candidate_start_seq
        break

    if matching_pass is None or not isinstance(start_seq, int):
        return

    snapshot_signature = git_changed_file_signatures()
    matching_pass["stop_seq"] = event_seq
    matching_pass["stop_task_id"] = task_id
    matching_pass["stop_task_id_count"] = 1
    matching_pass["stop_snapshot_signature"] = snapshot_signature
    matching_pass["completion_source"] = "list_agents"

    agents["coder_started"] = True
    agents["coder_stopped"] = True
    agents["coder_last_seq"] = event_seq
    agents["coder_last_snapshot_signature"] = snapshot_signature
    agents["coder_last_task_id"] = task_id
    turn["current_task_id"] = task_id

    remediation_after = agents.get("remediation_required_after_seq")
    remediation_task_id = agents.get("remediation_required_task_id")
    is_remediation = (
        agents.get("remediation_coder_start_seq") == start_seq
        or (
            isinstance(remediation_after, int)
            and start_seq > remediation_after
            and remediation_task_id == task_id
        )
    )
    if is_remediation:
        agents["remediation_coder_start_seq"] = start_seq
        agents["remediation_coder_last_seq"] = event_seq
        agents["remediation_coder_task_id"] = task_id


def _normalize_command(tool_input: dict | object) -> str:
    if not isinstance(tool_input, dict):
        return ""

    raw_command = tool_input.get("command", "")
    if raw_command is None:
        return ""

    return str(raw_command)


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")

    tool_input = event.get("tool_input") if isinstance(event, dict) else None
    command = _normalize_command(tool_input)
    command_lower = command.lower()
    tool_name = ""
    if isinstance(event, dict):
        tool_name = str(event.get("tool_name", event.get("tool", "")))
    tool_response = event.get("tool_response") if isinstance(event, dict) else None
    if _is_list_agents_tool(tool_name):
        exit_code = parse_tool_exit_code(
            {
                "tool_response": _without_completed_agent_text(tool_response),
            }
        )
    else:
        exit_code = parse_tool_exit_code(event)

    def apply_state(state):
        if not state.get("active"):
            return

        event_seq = append_event(
            state,
            "PostToolUse.Bash",
            {
                "command": command[:240],
                "exit_code": exit_code,
                "tool_name": tool_name[:120],
            },
        )

        if command_match_verification(command_lower):
            state["turn"]["verification"]["run"] = exit_code == 0
            state["turn"]["verification"]["commands"].append(
                {"at": now_iso(), "command": command, "exit_code": exit_code}
            )
            if exit_code == 0:
                state["turn"]["verification"]["last_seq"] = event_seq
                state["turn"]["verification"]["at"] = now_iso()
                state["turn"]["verification"]["snapshot_signature"] = git_changed_file_signatures()
                state["turn"]["verification"]["snapshot"] = signature_paths(state["turn"]["verification"]["snapshot_signature"])

        if command_is_commit(command_lower):
            pending_commit = state["turn"].get("pending_commit", {})
            pending_signature = pending_commit.get("snapshot_signature") if isinstance(pending_commit, dict) else []
            state["turn"]["commit"]["commands"].append(
                {"at": now_iso(), "command": command, "exit_code": exit_code}
            )
            if exit_code == 0:
                use_pending_signature = (
                    isinstance(pending_signature, list)
                    and bool(pending_signature)
                    and any(isinstance(item, str) and "|" in item for item in pending_signature)
                )
                state["turn"]["commit"]["done"] = True
                state["turn"]["commit"]["last_seq"] = event_seq
                state["turn"]["commit"]["at"] = now_iso()
                state["turn"]["commit"]["snapshot_signature"] = pending_signature if use_pending_signature else git_changed_file_signatures()
                state["turn"]["commit"]["snapshot"] = signature_paths(state["turn"]["commit"]["snapshot_signature"])
                state["turn"]["commit"]["snapshot_from_pre_tool"] = bool(use_pending_signature)
                if isinstance(pending_commit, dict):
                    state["turn"]["pending_commit"] = {
                        "seq": None,
                        "snapshot_signature": [],
                    }

            state["turn"]["pending_commit"] = {"seq": None, "snapshot_signature": []}

        pre_tool_signature = state["turn"].get("pre_tool_signature", {})
        if not isinstance(pre_tool_signature, dict):
            pre_tool_signature = {}
        pre_signature = pre_tool_signature.get("signature")
        pre_seq = pre_tool_signature.get("seq")
        pre_tool_name = pre_tool_signature.get("tool_name", "")
        pre_tool_actor = str(pre_tool_signature.get("actor", "")).strip()
        pre_command = str(pre_tool_signature.get("command", ""))[:200]
        pre_tool_may_edit = bool(pre_tool_signature.get("tool_may_edit_files"))
        if (
            exit_code == 0
            and pre_tool_actor == "coordinator"
            and _is_list_agents_tool(pre_tool_name)
            and _is_list_agents_tool(tool_name)
        ):
            _close_completed_coder_pass(
                state,
                extract_completed_agent_paths(tool_response),
                event_seq,
            )
        if pre_seq is not None and isinstance(pre_signature, list) and pre_tool_may_edit:
            post_signature = git_changed_file_signatures()
            is_coordinator = pre_tool_actor == "coordinator"
            tool_edit_detected = bool(
                pre_tool_signature.get("coder_pass_open")
                and changed_signatures_delta(pre_signature, post_signature)
            )
            if tool_edit_detected and is_coordinator:
                agents = state.get("turn", {}).get("agents", {})
                agents["main_agent_file_edit_detected"] = True
                events = agents.get("main_agent_file_edit_events")
                if isinstance(events, list):
                    events.append(
                        {
                            "at": now_iso(),
                            "tool_name": pre_tool_name or tool_name,
                            "tool_pre_seq": pre_seq,
                            "tool_post_seq": event_seq,
                            "command": pre_command,
                            "actor": pre_tool_actor,
                        }
                    )
            state["turn"]["pre_tool_signature"] = {
                "seq": None,
                "signature": [],
                "coder_pass_open": False,
                "tool_name": "",
                "command": "",
                "actor": "",
                "at": now_iso(),
                "transcript_path": "",
                "tool_may_edit_files": False,
            }

    update_state(apply_state)
    print(json.dumps({}))


if __name__ == "__main__":
    main()
