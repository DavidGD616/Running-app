from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import append_event, classify_agent, load_state, save_state


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    state = load_state()

    agent = classify_agent(event)
    if not state.get("active"):
        print(json.dumps({}))
        return

    if state["turn"].get("triggered"):
        seq = append_event(state, "SubagentStart", {"agent": agent, "raw": event})
        if agent == "coder":
            state["turn"]["agents"]["coder_started"] = True
            state["turn"]["agents"]["coder_start_seq"] = seq
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
