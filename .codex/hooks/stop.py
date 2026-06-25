from __future__ import annotations

import json
from typing import Any

from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    changed_signatures_delta,
    signatures_match,
    git_changed_file_signatures,
    git_changed_files,
    update_state,
)


def _signature_list(value: Any) -> list[str]:
    if isinstance(value, list) and all(isinstance(item, str) and "|" in item for item in value):
        return value
    return []


def _verification_signature(turn: dict[str, Any]) -> list[str]:
    return _signature_list(turn.get("verification", {}).get("snapshot_signature"))


def _commit_signature(turn: dict[str, Any]) -> list[str]:
    return _signature_list(turn.get("commit", {}).get("snapshot_signature"))


def _commit_command_recorded(turn: dict[str, Any]) -> bool:
    commands = turn.get("commit", {}).get("commands")
    return bool(commands) or bool(turn.get("commit", {}).get("done"))


def _normalize_coder_passes(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _latest_completed_coder_pass(coder_passes: list[dict[str, Any]]) -> dict[str, Any] | None:
    latest = None
    latest_seq = -1
    for pass_record in coder_passes:
        stop_seq = pass_record.get("stop_seq")
        if isinstance(stop_seq, int) and stop_seq > latest_seq:
            latest_seq = stop_seq
            latest = pass_record
    return latest


def _passes_with_start_after_seq(
    coder_passes: list[dict[str, Any]],
    seq: int,
) -> list[dict[str, Any]]:
    matches: list[dict[str, Any]] = []
    for pass_record in coder_passes:
        start_seq = pass_record.get("start_seq")
        if isinstance(start_seq, int) and start_seq > seq:
            matches.append(pass_record)
    return sorted(matches, key=lambda item: item.get("start_seq", -1))


def _latest_completed_pass(passes: list[dict[str, Any]]) -> dict[str, Any] | None:
    completed = [record for record in passes if isinstance(record.get("stop_seq"), int)]
    if not completed:
        return None
    return sorted(completed, key=lambda item: item.get("stop_seq", -1))[-1]


def _task_id_record(record: dict[str, Any], field: str) -> tuple[str | None, int]:
    task_id_key = f"{field}_task_id"
    count_key = f"{field}_task_id_count"
    task_id = record.get(task_id_key)
    count = record.get(count_key)
    if not isinstance(count, int):
        return None, 0
    if isinstance(task_id, str) and task_id and count == 1:
        return task_id, 1
    return None, count


def _task_id_required(record: dict[str, Any], field: str) -> bool:
    task_id, count = _task_id_record(record, field)
    return bool(task_id) and count == 1


def _signature_for_record(record: dict[str, Any], field: str) -> list[str]:
    return _signature_list(record.get(field))


def _start_snapshot_recorded(record: dict[str, Any]) -> bool:
    return bool(record.get("start_snapshot_recorded"))


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
    return not signatures_match(current_signature, baseline_signature)


def _signature_stale(expected: list[str], current: list[str]) -> bool:
    return bool(expected) and not signatures_match(expected, current)


def _reviewer_passed(turn: dict[str, Any]) -> bool:
    reviewer_seq = turn.get("agents", {}).get("reviewer_last_seq")
    if not isinstance(reviewer_seq, int):
        return False
    if turn.get("agents", {}).get("reviewer_last_blocking"):
        return False
    return True


def _coder_signature(turn: dict[str, Any]) -> list[str]:
    coder_signature = _signature_list(turn.get("agents", {}).get("coder_last_snapshot_signature"))
    if coder_signature:
        return coder_signature

    passes = _normalize_coder_passes(turn.get("agents", {}).get("coder_passes"))
    latest_pass = _latest_completed_coder_pass(passes)
    if latest_pass:
        return _signature_for_record(latest_pass, "stop_snapshot_signature")
    return []


def _missing_requirements(state: dict[str, Any], current_signature: list[str]) -> list[str]:
    turn = state.get("turn", {})
    agents = turn.get("agents", {})
    verification = turn.get("verification", {})
    missing: list[str] = []
    commit_recorded = _commit_command_recorded(turn)
    if not state.get("active"):
        return missing

    baseline_signature = turn.get("files_changed_signature_at_start", [])
    if not isinstance(baseline_signature, list):
        baseline_signature = []

    work_signature, using_commit_snapshot = _work_signature(turn, current_signature)
    work_delta = bool(changed_signatures_delta(baseline_signature, work_signature))
    changed_since_start = bool(changed_signatures_delta(baseline_signature, current_signature))
    work_detected = bool(turn.get("implementation_oriented")) or bool(changed_since_start) or work_delta or bool(commit_recorded)
    requires_commit = bool(work_delta) and bool(turn.get("commit_requested"))

    if not work_detected:
        return missing

    coder_passes = _normalize_coder_passes(agents.get("coder_passes"))
    if not coder_passes:
        coder_last_seq = agents.get("coder_last_seq")
        fallback_task_id = None
        if isinstance(agents.get("coder_last_task_id"), str):
            fallback_task_id = agents.get("coder_last_task_id")
        coder_passes = [
            {
                "start_seq": agents.get("coder_start_seq"),
                "start_task_id": fallback_task_id,
                "start_task_id_count": 1 if fallback_task_id else 0,
                "start_snapshot_signature": [],
                "start_snapshot_recorded": False,
                "stop_seq": coder_last_seq,
                "stop_task_id": fallback_task_id,
                "stop_task_id_count": 1 if fallback_task_id else 0,
                "stop_snapshot_signature": _coder_signature(turn),
            }
        ]

    if not agents.get("coder_started"):
        missing.append("coder subagent not started")
    elif not agents.get("coder_stopped"):
        missing.append("coder subagent has not completed a pass")

    current_task_id = turn.get("current_task_id")
    if agents.get("coder_started") and not current_task_id:
        missing.append("coder task id not recorded")

    latest_coder_pass = _latest_completed_coder_pass(coder_passes)
    if not latest_coder_pass and agents.get("coder_stopped"):
        missing.append("coder has no completed pass record")

    incomplete_passes: list[dict[str, Any]] = []
    for idx, pass_record in enumerate(coder_passes, start=1):
        pass_idx = f"pass {idx}"
        start_task_id, start_count = _task_id_record(pass_record, "start")
        if not _task_id_required(pass_record, "start"):
            missing.append(f"{pass_idx} missing exactly one Task ID")
        if start_task_id and current_task_id and start_task_id != current_task_id:
            missing.append(f"{pass_idx} task ID does not match current task")
        if start_count != 1:
            missing.append(f"{pass_idx} missing start task id count validation")
        if not isinstance(pass_record.get("start_seq"), int):
            missing.append(f"{pass_idx} missing start sequence")
        start_signature = _signature_for_record(pass_record, "start_snapshot_signature")
        if not _start_snapshot_recorded(pass_record):
            missing.append(f"{pass_idx} missing start snapshot recording evidence")
        if not start_signature and not _start_snapshot_recorded(pass_record):
            missing.append(f"{pass_idx} missing start snapshot signature")
        if isinstance(pass_record.get("stop_seq"), int):
            stop_signature = _signature_for_record(pass_record, "stop_snapshot_signature")
            if not stop_signature:
                missing.append(f"{pass_idx} missing stop snapshot signature")
        else:
            incomplete_passes.append(pass_record)

    if incomplete_passes:
        missing.append("one or more coder passes missing a stop event")

    coder_signature = _coder_signature(turn)
    if agents.get("coder_stopped"):
        if not coder_signature:
            missing.append("coder completion snapshot not recorded")
        elif _signature_stale(work_signature, coder_signature):
            missing.append("final work signature does not match latest coder output")

    remediation_required_after_seq = agents.get("remediation_required_after_seq")
    if isinstance(remediation_required_after_seq, int):
        remediation_starts = _passes_with_start_after_seq(coder_passes, remediation_required_after_seq)
        if not remediation_starts:
            missing.append("blocking reviewer requires a new coder remediation pass")
        else:
            blocker_signature = _signature_list(agents.get("blocking_reviewer_snapshot_signature"))
            remediation_completed = [record for record in remediation_starts if isinstance(record.get("stop_seq"), int)]
            remediation_for_signature_check: dict[str, Any] | None = None
            if remediation_completed:
                remediation_for_signature_check = _latest_completed_pass(remediation_completed)
            elif remediation_starts:
                remediation_for_signature_check = remediation_starts[-1]
            if blocker_signature and remediation_for_signature_check:
                remediation_start_signature = _signature_for_record(
                    remediation_for_signature_check,
                    "start_snapshot_signature",
                )
                if _signature_stale(blocker_signature, remediation_start_signature):
                    missing.append("remediation coder pass started after working tree changed since blocking review")
            remediation_completed = [record for record in remediation_starts if isinstance(record.get("stop_seq"), int)]
            if not remediation_completed:
                missing.append("remediation coder pass has not completed after blocking reviewer")
            else:
                latest_remediation_pass = sorted(
                    remediation_completed,
                    key=lambda item: item.get("stop_seq", -1),
                )[-1]
                remediation_task_id, remediation_task_count = _task_id_record(latest_remediation_pass, "start")
                if not (remediation_task_id and remediation_task_count == 1):
                    missing.append("remediation coder task id missing or ambiguous")
                elif current_task_id and remediation_task_id != current_task_id:
                    missing.append("remediation coder task id does not match current task")
                state["turn"]["agents"]["remediation_coder_last_seq"] = latest_remediation_pass.get("stop_seq")
                state["turn"]["agents"]["remediation_coder_task_id"] = remediation_task_id

                remediation_start_seq = latest_remediation_pass.get("start_seq")
                if isinstance(remediation_start_seq, int):
                    state["turn"]["agents"]["remediation_coder_start_seq"] = remediation_start_seq

    if agents.get("main_agent_file_edit_detected"):
        missing.append("main agent performed file-edit tool actions while a coder pass was open")

    if not _reviewer_passed(turn):
        missing.append("reviewer has not completed a non-blocking pass")
    else:
        review_signature = agents.get("reviewer_last_snapshot_signature", [])
        reviewer_work_signature = work_signature if requires_commit else current_signature
        if requires_commit and _signature_stale(reviewer_work_signature, review_signature):
            missing.append("reviewer snapshot does not match final verification/committed signature")
        elif not requires_commit and turn.get("verification", {}).get("run"):
            if _signature_stale(_verification_signature(turn), review_signature):
                missing.append("reviewer snapshot does not match final verification snapshot")

        reviewer_seq = agents.get("reviewer_last_seq")
        verification_seq = verification.get("last_seq")
        latest_stop_seq = latest_coder_pass.get("stop_seq") if latest_coder_pass else None

        if isinstance(latest_stop_seq, int) and isinstance(reviewer_seq, int) and reviewer_seq <= latest_stop_seq:
            missing.append("reviewer pass must occur after latest coder pass")
        elif not isinstance(reviewer_seq, int):
            missing.append("reviewer pass must occur after coder activity")
        if isinstance(verification_seq, int) and isinstance(reviewer_seq, int) and reviewer_seq <= verification_seq:
            missing.append("reviewer pass must occur after successful verification")

    verification_signature = _verification_signature(turn)
    if not verification.get("run"):
        missing.append("verification command not recorded")
    else:
        verification_seq = verification.get("last_seq")
        latest_stop_seq = latest_coder_pass.get("stop_seq") if latest_coder_pass else None
        if (
            isinstance(verification_seq, int)
            and isinstance(latest_stop_seq, int)
            and verification_seq <= latest_stop_seq
        ):
            missing.append("verification must run after latest coder pass")

        if (
            isinstance(remediation_required_after_seq, int)
            and isinstance(verification_seq, int)
            and isinstance(agents.get("remediation_coder_last_seq"), int)
            and verification_seq <= agents["remediation_coder_last_seq"]
        ):
            missing.append("verification must run after remediation coder pass")

        verification_work_signature = work_signature if (requires_commit and using_commit_snapshot) else current_signature
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
        elif isinstance(agents.get("reviewer_last_seq"), int) and int(commit.get("last_seq")) <= int(agents["reviewer_last_seq"]):
            missing.append("commit must occur after reviewer approval")
        elif _signature_stale(_commit_signature(turn), verification_signature):
            missing.append("committed work does not match verified snapshot")
        if _post_commit_has_uncommitted_change(current_signature, baseline_signature):
            missing.append("post-commit working tree includes uncommitted changes")

    return missing


def main() -> None:
    event = json.loads(sys.stdin.read() or "{}")
    output = {"missing": []}

    def apply_state(state):
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
        commit_recorded = _commit_command_recorded(turn)

        missing: list[str] = []
        if turn.get("triggered") and (
            turn.get("implementation_oriented") or changed_since_start or commit_recorded
        ):
            missing = _missing_requirements(state, changed_signature)
        output["missing"] = missing

    update_state(apply_state)

    missing = output["missing"]

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
