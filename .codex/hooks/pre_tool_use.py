from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    command_is_commit,
    git_changed_file_signatures,
    load_state,
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
    command_lower = str(command).lower()

    event_seq = append_event(state, "PreToolUse.Bash", {"command": str(command)[:240]})

    if command_is_commit(command_lower):
        state["turn"]["pending_commit"] = {
            "seq": event_seq,
            "snapshot_signature": git_changed_file_signatures(),
            "at": command[:40],
        }

    save_state(state)
    print(json.dumps({}))


if __name__ == "__main__":
    main()
