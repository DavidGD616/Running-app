import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    default_state,
    extract_prompt_text,
    update_state,
    is_internal_subagent_prompt,
    new_turn,
)


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")

    prompt_text = extract_prompt_text(event)
    internal_prompt = is_internal_subagent_prompt(event, prompt_text)
    if internal_prompt:
        def apply_internal_prompt(state):
            append_event(
                state,
                "UserPromptSubmit.internal_prompt_ignored",
                {"agent_hint": "detected", "previous_active": bool(state.get("active"))},
            )

        update_state(apply_internal_prompt)
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit"}}))
        return

    turn = new_turn(prompt_text)

    def apply_turn(state):
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
            state["last_turn_id"] = None
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

    update_state(apply_turn)

    output = {}
    hook_output = {"hookEventName": "UserPromptSubmit"}
    if bool(turn["triggered"]):
        hook_output["additionalContext"] = (
            f"Orchestrator mode active (triggered). "
            f"implementation_oriented={turn['implementation_oriented']}, "
            f"commit_requested={turn['commit_requested']}."
        )
    output["hookSpecificOutput"] = hook_output
    print(json.dumps(output))


if __name__ == "__main__":
    main()
