from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    changed_signatures_delta,
    signatures_match,
    git_changed_file_signatures,
    load_state,
    git_changed_files,
    save_state,
)


def _signature_list(value: Any) -> list[str]:
    if isinstance(value, list) and all(isinstance(item, str) and "|" in item for item in value):
        return value
    return []


def _verification_signature(turn: dict[str, Any]) -> list[str]:
    return _signature_list(turn.get("verification", {}).get("snapshot_signature"))


def _commit_signature(turn: dict[str, Any]) -> list[str]:
    return _signature_list(turn.get("commit", {}).get("snapshot_signature"))


def _work_signature(turn: dict[str, Any], current_signature: list[str]) -> tuple[list[str], bool]:
    commit = turn.get("commit", {})
    commit_signature = _commit_signature(turn)
    has_valid_pre_tool_commit_snapshot = (
        bool(commit.get("done"))
        and bool(commit.get("snapshot_from_pre_tool"))
        and bool(commit_signature)
    )
    if has_valid_pre_tool_commit_snapshot:
        return commit_signature, True

    if bool(commit.get("done")):
        verification_signature = _verification_signature(turn)
        if verification_signature:
            return verification_signature, False
        reviewer_signature = _signature_list(turn.get("agents", {}).get("reviewer_last_snapshot_signature", []))
        if reviewer_signature:
            return reviewer_signature, False

    return current_signature, False


def _post_commit_has_uncommitted_change(current_signature: list[str], baseline_signature: list[str]) -> bool:
    current_set = set(current_signature)
    baseline_set = set(baseline_signature)
    return bool(current_set - baseline_set)


def _signature_stale(expected: list[str], current: list[str]) -> bool:
    return bool(expected) and not signatures_match(expected, current)


def _reviewer_passed(turn: dict[str, Any]) -> bool:
    reviewer_seq = turn.get("agents", {}).get("reviewer_last_seq")
    if not isinstance(reviewer_seq, int):
        return False
    if turn.get("agents", {}).get("reviewer_last_blocking"):
        return False
    return True


def _missing_requirements(state: dict[str, Any], current_signature: list[str]) -> list[str]:
    turn = state.get("turn", {})
    missing: list[str] = []
    if not state.get("active"):
        return missing

    baseline_signature = turn.get("files_changed_signature_at_start", [])
    if not isinstance(baseline_signature, list):
        baseline_signature = []

    work_signature, using_commit_snapshot = _work_signature(turn, current_signature)
    work_delta = bool(changed_signatures_delta(baseline_signature, work_signature))
    changed_since_start = bool(changed_signatures_delta(baseline_signature, current_signature))
    work_detected = bool(turn.get("implementation_oriented")) or bool(changed_since_start) or work_delta
    requires_commit = bool(work_delta) and bool(turn.get("commit_requested"))

    if not work_detected:
        return missing

    if not turn.get("agents", {}).get("coder_started"):
        missing.append("coder subagent not started")

    if not _reviewer_passed(turn):
        missing.append("reviewer has not completed a non-blocking pass")
    else:
        review_signature = turn.get("agents", {}).get("reviewer_last_snapshot_signature", [])
        reviewer_work_signature = work_signature if requires_commit else current_signature
        if requires_commit and _signature_stale(reviewer_work_signature, review_signature):
            missing.append("reviewer snapshot does not match final verification/committed signature")
        elif not requires_commit and turn.get("verification", {}).get("run"):
            if _signature_stale(_verification_signature(turn), review_signature):
                missing.append("reviewer snapshot does not match final verification snapshot")

        coder_seq = turn.get("agents", {}).get("coder_start_seq")
        reviewer_seq = turn.get("agents", {}).get("reviewer_last_seq")
        if isinstance(coder_seq, int) and isinstance(reviewer_seq, int) and reviewer_seq <= coder_seq:
            missing.append("reviewer pass must occur after coder activity")
        elif isinstance(coder_seq, int) and not isinstance(reviewer_seq, int):
            missing.append("reviewer pass must occur after coder activity")

    verification = turn.get("verification", {})
    verification_signature = _verification_signature(turn)
    if not verification.get("run"):
        missing.append("verification command not recorded")
    else:
        verification_work_signature = work_signature if requires_commit and using_commit_snapshot else current_signature
        if _signature_stale(verification_work_signature, verification_signature):
            missing.append("verification snapshot is stale relative to final work signature")

    if requires_commit and not turn.get("commit", {}).get("done"):
        missing.append("commit command not completed after file changes")
    elif requires_commit:
        commit = turn.get("commit", {})
        has_valid_pre_tool_commit_signature = bool(commit.get("snapshot_from_pre_tool")) and bool(_commit_signature(turn))
        if not has_valid_pre_tool_commit_signature:
            missing.append("commit missing pre-tool snapshot")
        elif commit.get("last_seq") is None or verification.get("last_seq") is None:
            missing.append("commit must occur after successful verification")
        elif int(commit.get("last_seq")) <= int(verification.get("last_seq")):
            missing.append("commit must occur after successful verification")
        elif _signature_stale(_commit_signature(turn), verification_signature):
            missing.append("committed work does not match verified snapshot")
        if _post_commit_has_uncommitted_change(current_signature, baseline_signature):
            missing.append("post-commit working tree includes uncommitted changes")

    return missing


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    state = load_state()

    turn = state.get("turn", {})
    changed_now = git_changed_files()
    changed_signature = git_changed_file_signatures()
    turn["files_changed_current"] = changed_now
    turn["files_changed_signature_current"] = changed_signature
    append_event(state, "Stop", {"input_keys": sorted(event.keys()) if isinstance(event, dict) else []})

    changed_since_start = False
    if state.get("active"):
        baseline_signature = turn.get("files_changed_signature_at_start", [])
        if not isinstance(baseline_signature, list):
            baseline_signature = []
        changed_since_start = bool(changed_signatures_delta(baseline_signature, changed_signature))

    missing: list[str] = []
    if turn.get("triggered") and (turn.get("implementation_oriented") or changed_since_start):
        missing = _missing_requirements(state, changed_signature)

    save_state(state)

    if missing:
        print(
            json.dumps(
                {
                    "decision": "block",
                    "reason": "Orchestration closure gate failed: " + "; ".join(missing),
                }
            )
        )
        return

    print(json.dumps({}))


if __name__ == "__main__":
    main()
