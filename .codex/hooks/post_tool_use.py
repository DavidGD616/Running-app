from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    signature_paths,
    command_is_commit,
    changed_signatures_delta,
    command_match_verification,
    git_changed_file_signatures,
    now_iso,
    parse_tool_exit_code,
    update_state,
)


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
    exit_code = parse_tool_exit_code(event)
    command_lower = command.lower()
    tool_name = ""
    if isinstance(event, dict):
        tool_name = str(event.get("tool_name", event.get("tool", "")))

    def apply_state(state):
        if not state.get("active"):
            return

        event_seq = append_event(
            state,
            "PostToolUse.Bash",
            {"command": command[:240], "exit_code": exit_code},
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
        if isinstance(pre_tool_signature, dict):
            pre_signature = pre_tool_signature.get("signature")
            pre_seq = pre_tool_signature.get("seq")
        pre_tool_name = pre_tool_signature.get("tool_name", "")
        pre_tool_actor = str(pre_tool_signature.get("actor", "")).strip()
        pre_command = str(pre_tool_signature.get("command", ""))[:200]
        pre_tool_may_edit = bool(pre_tool_signature.get("tool_may_edit_files"))
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
