from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from orchestrator_state import (
    append_event,
    collaboration_spawn_session_boundary,
    collaboration_spawn_diagnostics,
    command_is_commit,
    extract_collaboration_spawn_identity,
    extract_event_transcript_path,
    extract_internal_subagent_prompt_from_transcript,
    git_changed_file_signatures,
    git_head_commit,
    infer_internal_subagent_role_from_transcript,
    now_iso,
    register_strict_agent_start,
    require_strict_agent_session_identity,
    validate_strict_prompt_identity,
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


def _tool_input_key_names(tool_input: dict | object) -> list[str]:
    if not isinstance(tool_input, dict):
        return []
    return sorted(str(key)[:80] for key in tool_input)[:30]


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

        turn = state.get("turn", {})
        agents = turn.get("agents", {})
        actors = turn.get("tool_call_actors")
        if not isinstance(actors, dict):
            actors = {}
            turn["tool_call_actors"] = actors

        actor = ""
        inferred_actor_pending = False
        spawn_evidence = turn.get("collaboration_spawn_evidence")
        if not isinstance(spawn_evidence, list):
            spawn_evidence = []
            turn["collaboration_spawn_evidence"] = spawn_evidence
        if transcript_path:
            actor = str(actors.get(str(transcript_path), ""))
            if not actor:
                coordinator_transcript_paths = [
                    path
                    for path, mapped_actor in actors.items()
                    if mapped_actor == "coordinator"
                ]
                inferred_actor = infer_internal_subagent_role_from_transcript(
                    transcript_path,
                    coordinator_transcript_paths=coordinator_transcript_paths,
                    collaboration_spawn_evidence=spawn_evidence,
                )
                if inferred_actor:
                    actor = inferred_actor
                    inferred_actor_pending = True

        signature_snapshot: list[str] | None = None

        def current_signature() -> list[str]:
            nonlocal signature_snapshot
            if signature_snapshot is None:
                signature_snapshot = git_changed_file_signatures()
            return list(signature_snapshot)

        should_open_coder_pass = bool(
            turn.get("triggered")
            and actor == "coder"
            and (
                not bool(agents.get("coder_started"))
                or bool(agents.get("coder_stopped"))
            )
        )
        if should_open_coder_pass:
            coordinator_transcript_paths = [
                path
                for path, mapped_actor in actors.items()
                if mapped_actor == "coordinator"
            ]
            strict_identity = require_strict_agent_session_identity(
                turn, "coder", transcript_path,
            )
            if strict_identity is None:
                return
            strict_prompt = extract_internal_subagent_prompt_from_transcript(
                transcript_path,
                agent="coder",
                coordinator_transcript_paths=coordinator_transcript_paths,
            )
            if not validate_strict_prompt_identity(
                turn,
                strict_identity,
                strict_prompt,
                record_task_violation=False,
            ):
                return

            task_id = strict_identity["task_id"]
            task_id_count = 1
            start_snapshot_signature = current_signature()
            start_seq = append_event(
                state,
                "SubagentStart",
                {
                    "agent": "coder",
                    "task_id": task_id if task_id_count == 1 else None,
                    "agent_transcript_path": str(transcript_path),
                    "recovered_from_pre_tool": True,
                },
            )
            strict_identity = register_strict_agent_start(
                turn, "coder", transcript_path, start_seq, start_snapshot_signature
            )
            if strict_identity is None:
                return
            if inferred_actor_pending:
                actors[str(transcript_path)] = actor
            agents["coder_started"] = True
            agents["coder_stopped"] = False
            agents["coder_start_seq"] = start_seq
            coder_passes = agents.get("coder_passes")
            if not isinstance(coder_passes, list):
                coder_passes = []
                agents["coder_passes"] = coder_passes
            coder_passes.append(
                {
                    "start_seq": start_seq,
                    "start_task_id": task_id if task_id_count == 1 else None,
                    "start_task_id_count": task_id_count,
                    "start_snapshot_signature": start_snapshot_signature,
                    "start_snapshot_recorded": True,
                    "agent_transcript_path": str(transcript_path),
                    "recovered_from_pre_tool": True,
                    "agent_identity": strict_identity["identity"] if strict_identity else None,
                }
            )
            agents["coder_last_task_id"] = task_id if task_id_count == 1 else None
            if task_id and task_id_count == 1:
                turn["current_task_id"] = task_id

            remediation_after_seq = agents.get("remediation_required_after_seq")
            if isinstance(remediation_after_seq, int) and start_seq > remediation_after_seq:
                agents["remediation_coder_start_seq"] = start_seq
                agents["remediation_coder_task_id"] = (
                    task_id if task_id_count == 1 else None
                )
        elif inferred_actor_pending:
            actors[str(transcript_path)] = actor

        spawn_diagnostics = collaboration_spawn_diagnostics(event)
        event_details = {
            "command": command[:240],
            "actor": actor,
            "transcript_path": str(transcript_path) if transcript_path else "",
            "tool_name": tool_name[:120],
            "tool_input_keys": _tool_input_key_names(tool_input),
        }
        event_details.update(spawn_diagnostics)
        event_seq = append_event(
            state,
            "PreToolUse.Bash",
            event_details,
        )

        spawn_identity = extract_collaboration_spawn_identity(event)
        if actor == "coordinator" and spawn_identity and transcript_path:
            spawn_role, spawn_task_id, spawn_task_id_count, spawn_task_name = spawn_identity
            session_boundary = collaboration_spawn_session_boundary(
                transcript_path,
                spawn_task_name,
            )
            if session_boundary is not None:
                spawn_evidence[:] = [
                    evidence
                    for evidence in spawn_evidence
                    if not (
                        isinstance(evidence, dict)
                        and evidence.get("coordinator_transcript_path") == str(transcript_path)
                        and evidence.get("task_name") == spawn_task_name
                    )
                ]
                evidence_record = {
                    "seq": event_seq,
                    "coordinator_transcript_path": str(transcript_path),
                    "task_name": spawn_task_name,
                    "role": spawn_role,
                    "task_id": spawn_task_id if spawn_task_id_count == 1 else None,
                    "task_id_count": spawn_task_id_count,
                    "identity_source": (
                        "prompt_sentinel"
                        if spawn_diagnostics.get("message_kind")
                        == "plaintext_sentinel"
                        else "encoded_task_name"
                    ),
                    "message_kind": spawn_diagnostics.get("message_kind"),
                }
                evidence_record.update(session_boundary)
                spawn_evidence.append(evidence_record)
            turn["collaboration_spawn_evidence"] = spawn_evidence[-25:]

        coder_pass_open = bool(agents.get("coder_started")) and not bool(agents.get("coder_stopped"))
        track_for_edit_signature = coder_pass_open and may_edit_files
        state["turn"]["pre_tool_signature"] = {
            "seq": event_seq if track_for_edit_signature else None,
            "signature": current_signature() if track_for_edit_signature else [],
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
                "snapshot_signature": current_signature(),
                "head_before": git_head_commit(),
                "at": command[:40],
            }

    update_state(apply_state)
    print(json.dumps({}))


if __name__ == "__main__":
    main()
