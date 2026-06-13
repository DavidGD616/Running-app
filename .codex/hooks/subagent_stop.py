from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    classify_agent,
    extract_prompt_text,
    git_changed_file_signatures,
    load_state,
    parse_tool_exit_code,
    save_state,
)


BLOCKING_PATTERNS = [
    r"\brequest[_\-\s]?changes\b",
    r"\bresolution required",
    r"\bresolved? after",
    r"\bmust fix",
    r"\bmust address",
    r"\bmajor\b",
    r"\bcritical\b",
]

NON_BLOCKING_PATTERNS = [
    r"\bno\s+blocking\s+findings\b",
    r"\boverall\s+assessment:\s*approve\b",
]


def looks_blocking(text: str) -> bool:
    lowered = text.lower()
    if re.search(r"\bnot\s+approved\b", lowered):
        return True
    if re.search(r"\boverall\s+assessment:\s*request[_\-\s]?changes\b", lowered):
        return True
    has_non_blocking = any(re.search(p, lowered) for p in NON_BLOCKING_PATTERNS)
    has_blocking = any(re.search(p, lowered) for p in BLOCKING_PATTERNS)
    if has_non_blocking and not has_blocking:
        return False
    return has_blocking


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    state = load_state()
    if not state.get("active"):
        print(json.dumps({}))
        return

    agent = classify_agent(event)
    summary = extract_prompt_text(event)

    event_seq = append_event(state, "SubagentStop", {"agent": agent, "summary_excerpt": summary[:200]})
    state["turn"]["events"] = state["turn"]["events"][-40:]
    code = parse_tool_exit_code(event)

    if agent == "reviewer":
        state["turn"]["agents"]["reviewer_stopped"] = True
        blocking = looks_blocking(summary)
        reviewer_snapshot_signature = git_changed_file_signatures()
        state["turn"]["agents"]["reviewer_stops"].append(
            {
                "at": datetime.utcnow().isoformat() + "Z",
                "text": summary[:400],
                "blocking": blocking,
                "seq": event_seq,
                "snapshot_signature": reviewer_snapshot_signature,
            }
        )
        state["turn"]["agents"]["reviewer_last_seq"] = event_seq
        state["turn"]["agents"]["reviewer_last_snapshot_signature"] = reviewer_snapshot_signature
        state["turn"]["agents"]["reviewer_last_blocking"] = blocking
    elif agent == "coder":
        state["turn"]["agents"]["coder_started"] = True
    save_state(state)

    # Keep output minimal unless blocking/continuation details are required.
    if agent == "reviewer" and code != 0:
        print(json.dumps({"decision": "block", "reason": f"reviewer tool_exit={code}"}))
        return
    print(json.dumps({}))


if __name__ == "__main__":
    main()
