from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    command_is_commit,
    extract_event_transcript_path,
    git_changed_file_signatures,
    now_iso,
    update_state,
    tool_may_edit_files,
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
    tool_name = ""
    if isinstance(event, dict):
        tool_name = str(event.get("tool_name", event.get("tool", "")))

    transcript_path = extract_event_transcript_path(event)
    command_lower = command.lower()
    may_edit_files = tool_may_edit_files(tool_name, command)

    def apply_state(state):
        if not state.get("active"):
            return

        event_seq = append_event(state, "PreToolUse.Bash", {"command": command[:240]})

        agents = state.get("turn", {}).get("agents", {})
        coder_pass_open = bool(agents.get("coder_started")) and not bool(agents.get("coder_stopped"))
        track_for_edit_signature = coder_pass_open and may_edit_files
        actor = ""
        if transcript_path:
            actor = str(
                state.get("turn", {})
                .get("tool_call_actors", {})
                .get(str(transcript_path), "")
            )
        state["turn"]["pre_tool_signature"] = {
            "seq": event_seq if track_for_edit_signature else None,
            "signature": git_changed_file_signatures() if track_for_edit_signature else [],
            "coder_pass_open": coder_pass_open,
            "tool_name": str(tool_name),
            "tool_may_edit_files": bool(may_edit_files),
            "command": command[:200],
            "actor": actor,
            "transcript_path": str(transcript_path) if transcript_path else "",
            "at": now_iso(),
        }

        if command_is_commit(command_lower):
            state["turn"]["pending_commit"] = {
                "seq": event_seq,
                "snapshot_signature": git_changed_file_signatures(),
                "at": command[:40],
            }

    update_state(apply_state)
    print(json.dumps({}))


if __name__ == "__main__":
    main()
