from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    classify_agent,
    extract_task_ids_from_prompt_lines,
    extract_prompt_text,
    extract_task_id_from_subagent_transcript,
    extract_event_transcript_path,
    git_changed_file_signatures,
    record_lifecycle_violation,
    register_strict_agent_start,
    require_strict_agent_session_identity,
    validate_strict_prompt_identity,
    update_state,
)


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    agent = classify_agent(event)
    prompt_text = extract_prompt_text(event)
    task_ids = extract_task_ids_from_prompt_lines(prompt_text)
    task_id = task_ids[0] if len(task_ids) == 1 else None
    if not task_id:
        transcript_path = ""
        raw = event.get("raw") if isinstance(event, dict) else None
        if isinstance(raw, dict):
            transcript_path = str(raw.get("transcript_path", ""))

        if not transcript_path:
            transcript_path = str(event.get("transcript_path", ""))

        recovered_task_id, recovered_count = extract_task_id_from_subagent_transcript(
            transcript_path,
            agent=agent,
        )
        if recovered_task_id and recovered_count == 1:
            task_id = recovered_task_id
            task_ids = [recovered_task_id]

    task_id_count = len(task_ids) if task_ids else 0
    snapshot_signature = git_changed_file_signatures()
    transcript_path = extract_event_transcript_path(event)

    def apply_state(state):
        nonlocal task_id, task_id_count
        if not state.get("active"):
            return

        if state["turn"].get("triggered"):
            seq = append_event(state, "SubagentStart", {"agent": agent, "task_id": task_id, "raw": event})
            strict_identity = None
            if agent in {"coder", "reviewer"}:
                if transcript_path:
                    strict_identity = require_strict_agent_session_identity(
                        state["turn"], agent, transcript_path,
                    )
                else:
                    record_lifecycle_violation(
                        state["turn"], None,
                        f"new {agent} session must use strict name "
                        f"{agent}__<canonical_task_id>[__<nonce>] and matching Task ID evidence",
                    )
                if strict_identity is None:
                    return
                if not validate_strict_prompt_identity(
                    state["turn"], strict_identity, prompt_text,
                ):
                    return
                strict_identity = register_strict_agent_start(
                    state["turn"], agent, transcript_path, seq, snapshot_signature
                )
                if strict_identity is None:
                    return
                task_id = strict_identity["task_id"]
                task_id_count = 1
            if agent == "coder":
                state["turn"]["agents"]["coder_started"] = True
                state["turn"]["agents"]["coder_stopped"] = False
                state["turn"]["agents"]["coder_start_seq"] = seq
                if "coder_passes" not in state["turn"]["agents"] or not isinstance(state["turn"]["agents"]["coder_passes"], list):
                    state["turn"]["agents"]["coder_passes"] = []
                state["turn"]["agents"]["coder_passes"].append(
                    {
                        "start_seq": seq,
                        "start_task_id": task_id if task_id_count == 1 else None,
                        "start_task_id_count": task_id_count,
                        "start_snapshot_signature": snapshot_signature,
                        "start_snapshot_recorded": True,
                        "agent_identity": strict_identity["identity"] if strict_identity else None,
                        "agent_transcript_path": transcript_path,
                    }
                )
                state["turn"]["agents"]["coder_last_task_id"] = task_id if task_id_count == 1 else None
                if task_id and (
                    strict_identity is not None or not state["turn"].get("current_task_id")
                ):
                    state["turn"]["current_task_id"] = task_id
                remediation_after_seq = state["turn"]["agents"].get("remediation_required_after_seq")
                if isinstance(remediation_after_seq, int) and seq > remediation_after_seq:
                    state["turn"]["agents"]["remediation_coder_start_seq"] = seq
                    state["turn"]["agents"]["remediation_coder_task_id"] = task_id if task_id_count == 1 else None
            elif agent == "researcher":
                state["turn"]["agents"]["researcher_started"] = True
            elif agent == "explorer":
                state["turn"]["agents"]["explorer_started"] = True
            elif agent == "scribe":
                state["turn"]["agents"]["scribe_started"] = True
            elif agent != "other":
                state["turn"]["agents"][f"{agent}_started"] = True
            state["turn"]["events"] = state["turn"]["events"][-40:]

    update_state(apply_state)

    print(json.dumps({}))


if __name__ == "__main__":
    main()
