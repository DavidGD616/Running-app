import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    default_state,
    extract_prompt_text,
    load_state,
    new_turn,
    save_state,
)


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    state = load_state()

    prompt_text = extract_prompt_text(event)
    turn = new_turn(prompt_text)

    active = bool(turn["triggered"])
    if active:
        state.update(
            {
                "active": True,
                "last_turn_id": turn["turn_id"],
                "last_prompt_text": prompt_text,
                "turn": turn,
            }
        )
        append_event(state, "UserPromptSubmit.triggered", {"triggered": True})
    else:
        state["active"] = False
        state["last_prompt_text"] = prompt_text
        state["turn"] = default_state()["turn"]
        append_event(state, "UserPromptSubmit.no_trigger", {})

    state["turn"]["files_changed_at_start"] = turn["files_changed_at_start"]
    state["turn"]["files_changed_current"] = turn["files_changed_current"]
    state["turn"]["files_changed_signature_at_start"] = turn["files_changed_signature_at_start"]
    state["turn"]["files_changed_signature_current"] = turn["files_changed_signature_current"]
    state["turn"]["commit"]["snapshot_signature"] = []
    state["turn"]["commit"]["snapshot_from_pre_tool"] = False
    state["turn"]["pending_commit"] = {"seq": None, "snapshot_signature": []}
    save_state(state)

    output = {}
    hook_output = {"hookEventName": "UserPromptSubmit"}
    if active:
        hook_output["additionalContext"] = (
            f"Orchestrator mode active (triggered). "
            f"implementation_oriented={turn['implementation_oriented']}, "
            f"commit_requested={turn['commit_requested']}."
        )
    output["hookSpecificOutput"] = hook_output
    print(json.dumps(output))


if __name__ == "__main__":
    main()
