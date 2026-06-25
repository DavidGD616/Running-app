from __future__ import annotations

import json
import sys
import re
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    classify_agent,
    extract_prompt_text,
    extract_task_id,
    load_state,
    save_state,
    git_changed_file_signatures,
)


TASK_ID_PATTERN = re.compile(r"(?i)\btask\s*id:\s*([a-z0-9_.-]+)\b")


def extract_task_ids(text: str) -> list[str]:
    if not isinstance(text, str):
        return []
    return [value.strip() for value in TASK_ID_PATTERN.findall(text)]


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    state = load_state()

    agent = classify_agent(event)
    prompt_text = extract_prompt_text(event)
    task_ids = extract_task_ids(prompt_text)
    if not task_ids:
        task_ids = extract_task_ids(json.dumps(event))
    task_id = task_ids[0] if len(task_ids) == 1 else None
    if not task_id:
        task_id = extract_task_id(prompt_text) or extract_task_id(json.dumps(event))
    task_id_count = len(task_ids) if task_ids else 0
    snapshot_signature = git_changed_file_signatures()

    if not state.get("active"):
        print(json.dumps({}))
        return

    if state["turn"].get("triggered"):
        seq = append_event(state, "SubagentStart", {"agent": agent, "task_id": task_id, "raw": event})
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
                }
            )
            state["turn"]["agents"]["coder_last_task_id"] = task_id if task_id_count == 1 else None
            if task_id and not state["turn"].get("current_task_id"):
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
        save_state(state)

    print(json.dumps({}))


if __name__ == "__main__":
    main()
