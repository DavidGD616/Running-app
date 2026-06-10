from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    signature_paths,
    command_is_commit,
    command_match_verification,
    git_changed_file_signatures,
    load_state,
    now_iso,
    parse_tool_exit_code,
    save_state,
)


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    state = load_state()
    if not state.get("active"):
        print(json.dumps({}))
        return

    tool_input = event.get("tool_input", {}) if isinstance(event, dict) else {}
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    exit_code = parse_tool_exit_code(event)
    command_lower = command.lower()

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

    save_state(state)
    print(json.dumps({}))


if __name__ == "__main__":
    main()
