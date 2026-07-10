from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    _extract_internal_sentinel,
    append_event,
    default_state,
    extract_event_transcript_path,
    extract_prompt_text,
    normalize_agent,
    update_state,
    is_internal_subagent_prompt,
    new_turn,
    classify_agent,
)


def classify_actor(event: dict[str, object], prompt_text: str) -> str:
    if not isinstance(event, dict):
        return "other"

    agent = classify_agent(event)
    if agent != "other":
        return agent

    sentinel = _extract_internal_sentinel(prompt_text or "")
    if sentinel:
        return normalize_agent(sentinel)
    return "other"


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")

    prompt_text = extract_prompt_text(event)
    transcript_path = extract_event_transcript_path(event)
    internal_prompt = is_internal_subagent_prompt(event, prompt_text)

    if internal_prompt:
        actor = classify_actor(event, prompt_text)

        def apply_internal_prompt(state):
            if transcript_path:
                tool_call_actors = state["turn"].setdefault("tool_call_actors", {})
                if isinstance(tool_call_actors, dict):
                    tool_call_actors[str(transcript_path)] = actor

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

        if transcript_path:
            tool_call_actors = state["turn"].setdefault("tool_call_actors", {})
            if isinstance(tool_call_actors, dict):
                tool_call_actors[str(transcript_path)] = "coordinator"

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
