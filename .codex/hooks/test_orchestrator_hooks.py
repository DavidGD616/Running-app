from __future__ import annotations

import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

import sys

sys.path.append(str(Path(__file__).resolve().parent))

import orchestrator_state
import stop
import pre_tool_use
import post_tool_use
import subagent_stop
import subagent_start
import user_prompt_submit


VALID_OPAQUE_MESSAGE = (
    "gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "AAAAAAAAAAAAAAAAAAAAAA=="
)


class OrchestratorHookTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self._tempdir.cleanup)

        self.state_dir = Path(self._tempdir.name) / ".codex" / ".orchestrator-state"
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.state_file = self.state_dir / "state.json"

        patcher_state_dir = patch.object(orchestrator_state, "STATE_DIR", self.state_dir)
        patcher_state_file = patch.object(orchestrator_state, "STATE_FILE", self.state_file)
        patcher_state_dir.start()
        patcher_state_file.start()
        self.addCleanup(patcher_state_dir.stop)
        self.addCleanup(patcher_state_file.stop)

    def _write_transcript(self, records: list[dict[str, Any]]) -> Path:
        transcript_number = len(list(Path(self._tempdir.name).glob("transcript-*.jsonl")))
        path = Path(self._tempdir.name) / f"transcript-{transcript_number}.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for record in records:
                handle.write(json.dumps(record))
                handle.write("\n")
        return path

    def _run_hook(self, module, event: dict[str, Any]) -> str:
        with patch("sys.stdin", io.StringIO(json.dumps(event))):
            with patch("sys.stdout", new=io.StringIO()) as stdout:
                module.main()
                return stdout.getvalue()

    def _load_state(self) -> dict[str, Any]:
        return orchestrator_state.load_state()

    def _git(self, repo: Path, *args: str) -> str:
        return subprocess.check_output(
            ["git", *args], cwd=repo, text=True, stderr=subprocess.STDOUT,
        ).strip()

    def _new_git_history_repo(self) -> tuple[Path, str]:
        repo = Path(self._tempdir.name) / "history-repo"
        repo.mkdir()
        self._git(repo, "init", "-q")
        self._git(repo, "config", "user.name", "Hook Tests")
        self._git(repo, "config", "user.email", "hooks@example.test")
        (repo / "history.txt").write_text("base\n", encoding="utf-8")
        self._git(repo, "add", "history.txt")
        self._git(repo, "commit", "-q", "-m", "base")
        return repo, self._git(repo, "rev-parse", "HEAD")

    def _set_active_turn_state(self, path_to_actor: dict[str, str] | None = None) -> None:
        turn = orchestrator_state.new_turn("orchestrator implement task with task id: TASK-BASE")
        state = orchestrator_state.default_state()
        state["active"] = True
        state["turn"] = turn
        state["turn"]["agents"]["coder_started"] = True
        state["turn"]["agents"]["coder_stopped"] = False
        if path_to_actor:
            state["turn"]["tool_call_actors"] = dict(path_to_actor)
        orchestrator_state.save_state(state, with_lock=False)

    def _set_unstarted_active_turn_state(
        self,
        path_to_actor: dict[str, str] | None = None,
    ) -> None:
        state = orchestrator_state.default_state()
        state["active"] = True
        state["turn"]["triggered"] = True
        state["turn"]["implementation_oriented"] = True
        state["turn"]["commit_requested"] = True
        if path_to_actor:
            state["turn"]["tool_call_actors"] = dict(path_to_actor)
        orchestrator_state.save_state(state, with_lock=False)

    def _write_role_transcript(self, role: str, task_id: str) -> Path:
        return self._write_transcript(
            [
                {
                    "payload": {
                        "type": "user_message",
                        "message": (
                            f"Codex-Orchestrator-Internal-Subagent: {role}\n"
                            f"Task ID: {task_id}\n\n"
                            "Bounded task instructions."
                        ),
                    }
                }
            ]
        )

    def _write_correlated_role_transcripts(
        self,
        role: str,
        task_id: str,
        task_name: str,
    ) -> tuple[Path, Path]:
        coordinator_thread_id = f"coordinator-{task_name}"
        coordinator_path = self._write_coordinator_transcript(
            coordinator_thread_id,
            [
                {
                    "payload": {
                        "type": "function_call",
                        "name": "spawn_agent",
                        "namespace": "collaboration",
                        "arguments": json.dumps(
                            {
                                "task_name": task_name,
                                "message": (
                                    f"Codex-Orchestrator-Internal-Subagent: {role}\n"
                                    f"Task ID: {task_id}\n\n"
                                    "Bounded task instructions."
                                ),
                            }
                        ),
                    }
                }
            ],
        )
        subagent_path = self._write_spawned_subagent_transcript(
            task_name,
            parent_thread_id=coordinator_thread_id,
        )
        return coordinator_path, subagent_path

    def _write_coordinator_transcript(
        self,
        thread_id: str = "coordinator-thread",
        extra_records: list[dict[str, Any]] | None = None,
    ) -> Path:
        records: list[dict[str, Any]] = [
            {
                "type": "session_meta",
                "payload": {
                    "id": thread_id,
                    "source": "cli",
                },
            }
        ]
        records.extend(extra_records or [])
        return self._write_transcript(records)

    def _write_spawned_subagent_transcript(
        self,
        task_name: str,
        extra_records: list[dict[str, Any]] | None = None,
        *,
        parent_thread_id: str = "coordinator-thread",
        depth: int = 1,
        agent_path: str | None = None,
        thread_id: str | None = None,
    ) -> Path:
        records: list[dict[str, Any]] = [
            {
                "type": "session_meta",
                "payload": {
                    "id": thread_id or f"subagent-{task_name}-{depth}",
                    "source": {
                        "subagent": {
                            "thread_spawn": {
                                "parent_thread_id": parent_thread_id,
                                "depth": depth,
                                "agent_path": agent_path or f"/root/{task_name}",
                            }
                        }
                    }
                },
            }
        ]
        records.extend(extra_records or [])
        return self._write_transcript(records)

    def _pre_tool_event(self, transcript_path: Path, command: str = "rg TODO .") -> dict[str, Any]:
        return {
            "hook_event_name": "PreToolUse",
            "tool_name": "exec_command",
            "tool_input": {"command": command},
            "raw": {"transcript_path": str(transcript_path)},
        }

    def _spawn_tool_event(
        self,
        coordinator_path: Path,
        role: str,
        task_id: str,
        task_name: str,
    ) -> dict[str, Any]:
        return {
            "hook_event_name": "PreToolUse",
            "tool_name": "collaboration.spawn_agent",
            "tool_input": {
                "task_name": task_name,
                "fork_turns": "all",
                "message": (
                    f"Codex-Orchestrator-Internal-Subagent: {role}\n"
                    f"Task ID: {task_id}\n\n"
                    "Bounded task instructions."
                ),
            },
            "raw": {"transcript_path": str(coordinator_path)},
        }

    def _transcript_only_stop_event(
        self,
        transcript_path: Path,
        summary: str,
    ) -> dict[str, Any]:
        return {
            "hook_event_name": "SubagentStop",
            "agent_id": "collaboration-agent",
            "agent_type": "default",
            "last_assistant_message": summary,
            "agent_transcript_path": str(transcript_path),
        }

    def _list_agents_pre_event(self, coordinator_path: Path) -> dict[str, Any]:
        return {
            "hook_event_name": "PreToolUse",
            "tool_name": "collaborationlist_agents",
            "tool_input": {},
            "raw": {"transcript_path": str(coordinator_path)},
        }

    def _list_agents_post_event(
        self,
        coordinator_path: Path,
        agents: list[dict[str, Any]],
    ) -> dict[str, Any]:
        return {
            "hook_event_name": "PostToolUse",
            "tool_name": "collaborationlist_agents",
            "tool_input": {},
            "tool_response": {
                "result": json.dumps({"agents": agents}),
            },
            "raw": {"transcript_path": str(coordinator_path)},
        }

    def _set_open_coder_pass_for_list_agents(
        self,
        coordinator_path: Path,
        coder_path: Path,
        task_id: str,
    ) -> None:
        state = orchestrator_state.default_state()
        state["active"] = True
        turn = state["turn"]
        turn["triggered"] = True
        turn["implementation_oriented"] = True
        turn["current_task_id"] = task_id
        turn["event_seq"] = 20
        turn["tool_call_actors"] = {
            str(coordinator_path): "coordinator",
            str(coder_path): "coder",
        }
        agents = turn["agents"]
        agents["coder_started"] = True
        agents["coder_stopped"] = False
        agents["coder_start_seq"] = 10
        agents["coder_last_task_id"] = task_id
        agents["coder_passes"] = [
            {
                "start_seq": 10,
                "start_task_id": task_id,
                "start_task_id_count": 1,
                "start_snapshot_recorded": True,
                "start_snapshot_signature": ["M_|app.py|before"],
                "agent_transcript_path": str(coder_path),
            }
        ]
        agents["remediation_required_after_seq"] = 5
        agents["remediation_required_task_id"] = task_id
        agents["remediation_coder_start_seq"] = 10
        agents["remediation_coder_task_id"] = task_id
        orchestrator_state.save_state(state, with_lock=False)

    def _build_stop_gate_state(self, coordinator_edit_event: dict[str, Any] | None) -> dict[str, Any]:
        state = orchestrator_state.default_state()
        state["active"] = True
        turn = state["turn"]
        turn["implementation_oriented"] = True
        turn["files_changed_signature_at_start"] = ["100|app.py|A"]
        turn["current_task_id"] = "TASK-BASE"

        agents = turn["agents"]
        agents["coder_started"] = True
        agents["coder_stopped"] = True
        agents["coder_passes"] = [
            {
                "start_seq": 10,
                "stop_seq": 11,
                "start_task_id": "TASK-BASE",
                "start_task_id_count": 1,
                "start_snapshot_recorded": True,
                "start_snapshot_signature": ["100|app.py|A"],
                "stop_snapshot_signature": ["100|app.py|A"],
            },
        ]
        agents["coder_last_snapshot_signature"] = ["100|app.py|A"]
        agents["reviewer_last_seq"] = 12
        agents["reviewer_stops"] = [
            {
                "seq": 12,
                "blocking": False,
                "task_id": "TASK-BASE",
                "task_id_count": 1,
            },
        ]

        turn["verification"]["run"] = True
        turn["verification"]["last_seq"] = 13

        events: list[dict[str, Any]] = []
        if coordinator_edit_event is not None:
            events.append(coordinator_edit_event)
        agents["main_agent_file_edit_events"] = events
        agents["main_agent_file_edit_detected"] = bool(events)

        return state

    def _strict_ledger(
        self,
        task_id: str,
        *,
        coder_identity: str,
        reviewer_identity: str,
        commit_hash: str | None,
        changed: bool = True,
        offset: int = 0,
        baseline_head: str | None = None,
    ) -> dict[str, Any]:
        recorded_head = baseline_head or f"base-{task_id}"
        ledger = orchestrator_state.ensure_task_ledger({}, task_id)  # type: ignore[arg-type]
        ledger.update(
            {
                "changed": changed,
                "baseline_head": recorded_head,
                "baseline_signature": [],
                "coder_passes": [
                    {
                        "start_seq": offset + 1,
                        "stop_seq": offset + 2,
                        "agent_identity": coder_identity,
                        "stop_snapshot_signature": [f"100|{task_id}.py|work"],
                    }
                ],
                "verifications": [
                    {
                        "seq": offset + 3,
                        "snapshot_signature": [f"100|{task_id}.py|work"],
                        "post_snapshot_signature": [],
                    }
                ],
                "reviewer_passes": [
                    {
                        "seq": offset + 4,
                        "agent_identity": reviewer_identity,
                        "blocking": False,
                        "snapshot_signature": [f"100|{task_id}.py|work"],
                    }
                ],
                "commits": (
                    [{
                        "seq": offset + 5,
                        "hash": commit_hash,
                        "head_before": recorded_head,
                        "first_parent": recorded_head,
                        "snapshot_signature": [f"100|{task_id}.py|work"],
                    }]
                    if commit_hash is not None
                    else []
                ),
            }
        )
        return ledger

    def test_extract_task_id_from_nested_custom_tool_call_prefers_role(self) -> None:
        transcript_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": "Codex-Orchestrator-Internal-Subagent: explorer\nTask ID: EXPL-001",
                    }
                },
                {
                    "payload": {
                        "type": "custom_tool_call",
                        "name": "functions.exec",
                        "input": json.dumps(
                            {
                                "name": "spawn_agent",
                                "message": "Codex-Orchestrator-Internal-Subagent: coder\nTask ID: CODEC-101",
                            }
                        ),
                    }
                },
            ]
        )

        recovered_task_id, recovered_count = orchestrator_state.extract_task_id_from_subagent_transcript(
            transcript_path,
            agent="coder",
        )

        self.assertEqual("CODEC-101", recovered_task_id)
        self.assertEqual(1, recovered_count)

    def test_reviewer_task_id_recovered_from_agent_transcript_when_summary_missing(self) -> None:
        agent_transcript_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "function_call",
                        "name": "functions.exec",
                        "arguments": json.dumps(
                            {
                                "name": "spawn_agent",
                                "agent_type": "reviewer",
                                "message": "Codex-Orchestrator-Internal-Subagent: reviewer\nTask ID: REV-77",
                            }
                        ),
                    }
                }
            ]
        )
        parent_transcript_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "function_call",
                        "name": "functions.exec",
                        "arguments": json.dumps(
                            {
                                "name": "spawn_agent",
                                "agent_type": "reviewer",
                                "message": "Codex-Orchestrator-Internal-Subagent: reviewer\nTask ID: WRONG-PARENT",
                            }
                        ),
                    }
                }
            ]
        )

        event: dict[str, Any] = {
            "hook_event_name": "SubagentStop",
            "agent_id": "reviewer-agent-1",
            "agent_type": "reviewer",
            "last_assistant_message": "Reviewer completed",
            "agent_transcript_path": str(agent_transcript_path),
            "transcript_path": str(parent_transcript_path),
        }
        task_id, count = subagent_stop._extract_reviewer_task_info(event, {})

        self.assertEqual("REV-77", task_id)
        self.assertEqual(1, count)
        self.assertEqual(
            str(agent_transcript_path),
            orchestrator_state.extract_event_transcript_path(event),
        )

    def test_reviewer_task_id_recovery_fails_when_only_non_matching_sentinel_or_text_exists(self) -> None:
        transcript_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": "Task ID: COORD-01",
                    }
                },
                {
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": "Codex-Orchestrator-Internal-Subagent: explorer\nTask ID: EXPL-77",
                    }
                },
            ]
        )

        recovered_task_id, recovered_count = orchestrator_state.extract_task_id_from_subagent_transcript(
            transcript_path,
            agent="reviewer",
        )

        self.assertIsNone(recovered_task_id)
        self.assertEqual(0, recovered_count)

    def test_subagent_stop_persists_official_agent_transcript_path(self) -> None:
        coordinator_path, agent_transcript_path = self._write_correlated_role_transcripts(
            "reviewer", "review_42", "reviewer__review_42",
        )
        self._set_active_turn_state({str(coordinator_path): "coordinator"})

        event: dict[str, Any] = {
            "hook_event_name": "SubagentStop",
            "agent_id": "reviewer-agent-42",
            "agent_type": "reviewer",
            "last_assistant_message": "Overall Assessment: APPROVE",
            "agent_transcript_path": str(agent_transcript_path),
            "transcript_path": str(Path(self._tempdir.name) / "parent.jsonl"),
        }
        with patch.object(subagent_stop, "git_changed_file_signatures", return_value=[]):
            self._run_hook(subagent_stop, event)

        reviewer_stop = self._load_state()["turn"]["agents"]["reviewer_stops"][-1]
        self.assertEqual("review_42", reviewer_stop["task_id"])
        self.assertEqual(
            str(agent_transcript_path),
            reviewer_stop["agent_transcript_path"],
        )

    def test_stop_backfill_prefers_persisted_agent_transcript_path(self) -> None:
        agent_transcript_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "user_message",
                        "message": (
                            "Codex-Orchestrator-Internal-Subagent: coder\n"
                            "Task ID: CODER-AGENT-9"
                        ),
                    }
                }
            ]
        )
        parent_transcript_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "user_message",
                        "message": (
                            "Codex-Orchestrator-Internal-Subagent: coder\n"
                            "Task ID: WRONG-PARENT"
                        ),
                    }
                }
            ]
        )
        state = orchestrator_state.default_state()
        state["turn"]["agents"]["coder_passes"] = [
            {
                "start_seq": 1,
                "start_task_id": None,
                "start_task_id_count": 0,
                "stop_seq": 2,
                "stop_task_id": None,
                "stop_task_id_count": 0,
                "agent_transcript_path": str(agent_transcript_path),
            }
        ]
        state["turn"]["events"] = [
            {
                "event": "SubagentStart",
                "seq": 1,
                "details": {
                    "agent": "coder",
                    "raw": {"transcript_path": str(parent_transcript_path)},
                },
            },
            {
                "event": "SubagentStop",
                "seq": 2,
                "details": {
                    "agent": "coder",
                    "agent_transcript_path": str(agent_transcript_path),
                },
            },
        ]

        stop._backfill_pass_tasks_from_subagent_starts(state)

        coder_pass = state["turn"]["agents"]["coder_passes"][0]
        self.assertEqual("CODER-AGENT-9", coder_pass["start_task_id"])
        self.assertEqual("CODER-AGENT-9", coder_pass["stop_task_id"])

    def test_user_prompt_submit_records_internal_actor_by_transcript_path(self) -> None:
        orchestrator_state.save_state(orchestrator_state.default_state(), with_lock=False)
        coord_path = Path(self._tempdir.name) / "coord.jsonl"
        coder_path = Path(self._tempdir.name) / "coder.jsonl"

        self._run_hook(
            user_prompt_submit,
            {
                "prompt": "orchestrator implement task",
                "raw": {"transcript_path": str(coord_path)},
            },
        )
        self._run_hook(
            user_prompt_submit,
            {
                "agent": "coder",
                "prompt": "Codex-Orchestrator-Internal-Subagent: coder\nTask ID: CODE-7",
                "raw": {"transcript_path": str(coder_path)},
            },
        )

        state = self._load_state()
        actors = state["turn"].get("tool_call_actors", {})

        self.assertEqual("coordinator", actors.get(str(coord_path)))
        self.assertEqual("coder", actors.get(str(coder_path)))

    def test_main_agent_file_edit_detected_only_for_coordinator_actor(self) -> None:
        coord_path = Path(self._tempdir.name) / "coordinator-tool.jsonl"
        coder_path = Path(self._tempdir.name) / "coder-tool.jsonl"
        event = {
            "tool_input": {"command": "touch coordinator_file.tmp"},
            "raw": {"transcript_path": str(coord_path)},
        }
        coder_event = {
            "tool_input": {"command": "touch coder_file.tmp"},
            "raw": {"transcript_path": str(coder_path)},
        }

        self._set_active_turn_state({str(coord_path): "coordinator", str(coder_path): "coder"})
        with patch.object(pre_tool_use, "git_changed_file_signatures", side_effect=[["100|coordinator_file.tmp|A"], ["100|coordinator_file.tmp|A"]]):
            self._run_hook(pre_tool_use, event)
        with patch.object(post_tool_use, "git_changed_file_signatures", return_value=["100|coordinator_file.tmp|B"]):
            self._run_hook(post_tool_use, event)

        state = self._load_state()
        coordinator_agents = state["turn"]["agents"]
        self.assertTrue(coordinator_agents["main_agent_file_edit_detected"])
        events = coordinator_agents.get("main_agent_file_edit_events", [])
        self.assertEqual(1, len(events))
        self.assertEqual("coordinator", events[0]["actor"])

        self._set_active_turn_state({str(coord_path): "coordinator", str(coder_path): "coder"})
        with patch.object(pre_tool_use, "git_changed_file_signatures", side_effect=[["100|coder_file.tmp|A"], ["100|coder_file.tmp|A"]]):
            self._run_hook(pre_tool_use, coder_event)
        with patch.object(post_tool_use, "git_changed_file_signatures", return_value=["100|coder_file.tmp|B"]):
            self._run_hook(post_tool_use, coder_event)

        state = self._load_state()
        coder_agents = state["turn"]["agents"]
        self.assertFalse(coder_agents["main_agent_file_edit_detected"])
        self.assertEqual([], coder_agents.get("main_agent_file_edit_events", []))

    def test_non_strict_recovered_coder_pre_tool_records_violation_without_lifecycle_mutation(self) -> None:
        coder_path = self._write_role_transcript("coder", "recovered_non_strict")
        self._set_unstarted_active_turn_state()
        before = self._load_state()["turn"]

        with patch.object(
            pre_tool_use,
            "git_changed_file_signatures",
            return_value=["M_|app.py|before"],
        ):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))

        turn = self._load_state()["turn"]
        self.assertTrue(any(
            "new coder session must use strict name" in item["message"]
            for item in turn["lifecycle_violations"]
        ))
        self.assertEqual(before["agents"], turn["agents"])
        self.assertEqual(before["current_task_id"], turn["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], turn["agent_identity_usage"])
        self.assertEqual(before["task_ledgers"], turn["task_ledgers"])
        self.assertEqual(before["tool_call_actors"], turn["tool_call_actors"])
        self.assertEqual(before["events"], turn["events"])

    def test_invalid_strict_recovered_coder_prompt_does_not_mutate_lifecycle(self) -> None:
        coordinator_path, coder_path = self._write_correlated_role_transcripts(
            "coder",
            "different_task",
            "coder__recovered_strict__bad",
        )
        self._set_unstarted_active_turn_state(
            {str(coordinator_path): "coordinator"},
        )
        before = self._load_state()["turn"]

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))

        turn = self._load_state()["turn"]
        self.assertTrue(any(
            "does not exactly match encoded" in item["message"]
            for item in turn["lifecycle_violations"]
        ))
        self.assertEqual(before["agents"], turn["agents"])
        self.assertEqual(before["current_task_id"], turn["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], turn["agent_identity_usage"])
        self.assertEqual(before["task_ledgers"], turn["task_ledgers"])
        self.assertEqual(before["tool_call_actors"], turn["tool_call_actors"])
        self.assertEqual(before["events"], turn["events"])

    def test_valid_strict_recovered_coder_pre_tool_opens_one_pass_idempotently(self) -> None:
        task_id = "recovered_valid"
        coordinator_path, coder_path = self._write_correlated_role_transcripts(
            "coder",
            task_id,
            f"coder__{task_id}__one",
        )
        self._set_unstarted_active_turn_state(
            {str(coordinator_path): "coordinator"},
        )

        with patch.object(
            pre_tool_use,
            "git_changed_file_signatures",
            return_value=["M_|app.py|before"],
        ):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))
            self._run_hook(
                pre_tool_use,
                self._pre_tool_event(coder_path, "sed -n '1,20p' app.py"),
            )

        turn = self._load_state()["turn"]
        agents = turn["agents"]
        self.assertTrue(agents["coder_started"])
        self.assertFalse(agents["coder_stopped"])
        self.assertEqual("coder", turn["tool_call_actors"][str(coder_path)])
        self.assertEqual(task_id, turn["current_task_id"])
        self.assertEqual(1, len(agents["coder_passes"]))
        coder_pass = agents["coder_passes"][0]
        self.assertIsInstance(coder_pass["start_seq"], int)
        self.assertEqual(task_id, coder_pass["start_task_id"])
        self.assertEqual(1, coder_pass["start_task_id_count"])
        self.assertTrue(coder_pass["start_snapshot_recorded"])
        self.assertEqual(["M_|app.py|before"], coder_pass["start_snapshot_signature"])
        self.assertEqual(1, len(turn["task_ledgers"][task_id]["coder_passes"]))

    def test_plaintext_correlation_rejects_nested_agent_path_collision(self) -> None:
        coordinator_path, _ = self._write_correlated_role_transcripts(
            "coder",
            "ROOT-DIRECT-CHILD",
            "coder__same_leaf",
        )
        nested_path = self._write_spawned_subagent_transcript(
            "coder__same_leaf",
            parent_thread_id="coordinator-coder__same_leaf",
            depth=2,
            agent_path="/root/other/coder__same_leaf",
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, self._pre_tool_event(nested_path))

        turn = self._load_state()["turn"]
        self.assertNotIn(str(nested_path), turn["tool_call_actors"])
        self.assertFalse(turn["agents"]["coder_started"])
        self.assertEqual([], turn["agents"]["coder_passes"])

    def test_captured_spawn_requires_exact_direct_child_session_identity(self) -> None:
        task_name = "coder__session_boundary"
        task_id = "session_boundary"
        coordinator_thread_id = "trusted-coordinator-thread"
        coordinator_path = self._write_coordinator_transcript(coordinator_thread_id)

        cases = (
            (
                "nested-path",
                {
                    "parent_thread_id": coordinator_thread_id,
                    "depth": 2,
                    "agent_path": f"/root/other/{task_name}",
                },
            ),
            (
                "wrong-parent",
                {
                    "parent_thread_id": "different-coordinator-thread",
                    "depth": 1,
                    "agent_path": f"/root/{task_name}",
                },
            ),
            (
                "wrong-depth",
                {
                    "parent_thread_id": coordinator_thread_id,
                    "depth": 2,
                    "agent_path": f"/root/{task_name}",
                },
            ),
        )

        for label, metadata in cases:
            with self.subTest(case=label):
                child_path = self._write_spawned_subagent_transcript(
                    task_name,
                    **metadata,
                )
                self._set_unstarted_active_turn_state(
                    {str(coordinator_path): "coordinator"},
                )
                opaque_spawn = self._spawn_tool_event(
                    coordinator_path,
                    "coder",
                    task_id,
                    task_name,
                )
                opaque_spawn["tool_input"]["message"] = VALID_OPAQUE_MESSAGE

                with patch.object(
                    pre_tool_use,
                    "git_changed_file_signatures",
                    return_value=[],
                ):
                    self._run_hook(pre_tool_use, opaque_spawn)
                    self._run_hook(pre_tool_use, self._pre_tool_event(child_path))

                turn = self._load_state()["turn"]
                self.assertNotIn(str(child_path), turn["tool_call_actors"])
                self.assertFalse(turn["agents"]["coder_started"])
                self.assertEqual([], turn["agents"]["coder_passes"])

    def test_recovered_start_does_not_persist_unbounded_pre_tool_event(self) -> None:
        marker = "SENSITIVE-NON-COMMAND-MARKER-9471"
        coordinator_thread_id = "privacy-coordinator-thread"
        task_name = "coder__privacy_boundary"
        coordinator_path = self._write_coordinator_transcript(coordinator_thread_id)
        coder_path = self._write_spawned_subagent_transcript(
            task_name,
            parent_thread_id=coordinator_thread_id,
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        spawn_event = self._spawn_tool_event(
            coordinator_path,
            "coder",
            "privacy_boundary",
            task_name,
        )
        spawn_event["tool_input"]["message"] = VALID_OPAQUE_MESSAGE
        coder_event = self._pre_tool_event(coder_path)
        coder_event["tool_input"]["private"] = {"secret": marker}
        coder_event["unrelated"] = {"nested": [marker]}

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, spawn_event)
            self._run_hook(pre_tool_use, coder_event)

        serialized_state = self.state_file.read_text(encoding="utf-8")
        self.assertNotIn(marker, serialized_state)

    def test_list_agents_completion_closes_exact_coder_pass_idempotently(self) -> None:
        marker = "SENSITIVE-COMPLETED-TEXT-6208 exit_code: 77"
        task_id = "list_agents_completion"
        task_name = f"coder__{task_id}__c1"
        coordinator_path = self._write_coordinator_transcript()
        coder_path = self._write_spawned_subagent_transcript(task_name)
        self._set_open_coder_pass_for_list_agents(
            coordinator_path,
            coder_path,
            task_id,
        )
        response_agents = [
            {"agent_name": "/root", "agent_status": "running"},
            {
                "agent_name": f"/root/{task_name}",
                "agent_status": {"completed": marker},
            },
        ]

        with patch.object(
            post_tool_use,
            "git_changed_file_signatures",
            return_value=["M_|app.py|after"],
        ):
            self._run_hook(pre_tool_use, self._list_agents_pre_event(coordinator_path))
            self._run_hook(
                post_tool_use,
                self._list_agents_post_event(coordinator_path, response_agents),
            )

        state = self._load_state()
        agents = state["turn"]["agents"]
        coder_pass = agents["coder_passes"][0]
        completion_seq = coder_pass["stop_seq"]
        self.assertEqual(state["turn"]["events"][-1]["seq"], completion_seq)
        self.assertEqual(task_id, coder_pass["stop_task_id"])
        self.assertEqual(1, coder_pass["stop_task_id_count"])
        self.assertEqual("list_agents", coder_pass["completion_source"])
        self.assertEqual(["M_|app.py|after"], coder_pass["stop_snapshot_signature"])
        self.assertTrue(agents["coder_stopped"])
        self.assertEqual(completion_seq, agents["coder_last_seq"])
        self.assertEqual(completion_seq, agents["remediation_coder_last_seq"])
        self.assertNotIn(marker, self.state_file.read_text(encoding="utf-8"))

        with patch.object(
            post_tool_use,
            "git_changed_file_signatures",
            return_value=["M_|app.py|later"],
        ):
            self._run_hook(pre_tool_use, self._list_agents_pre_event(coordinator_path))
            self._run_hook(
                post_tool_use,
                self._list_agents_post_event(coordinator_path, response_agents),
            )

        repeated_agents = self._load_state()["turn"]["agents"]
        self.assertEqual(1, len(repeated_agents["coder_passes"]))
        self.assertEqual(
            completion_seq,
            repeated_agents["coder_passes"][0]["stop_seq"],
        )
        self.assertEqual(completion_seq, repeated_agents["coder_last_seq"])

    def test_list_agents_completion_rejects_nonmatching_or_running_agents(self) -> None:
        task_id = "exact_status_path"
        task_name = f"coder__{task_id}"
        coordinator_path = self._write_coordinator_transcript()
        coder_path = self._write_spawned_subagent_transcript(task_name)
        self._set_open_coder_pass_for_list_agents(
            coordinator_path,
            coder_path,
            task_id,
        )
        response_agents = [
            {
                "agent_name": f"/root/other/{task_name}",
                "agent_status": {"completed": "same leaf, wrong full path"},
            },
            {
                "agent_name": "/root/coder__different_task",
                "agent_status": {"completed": "unmatched coder"},
            },
            {
                "agent_name": f"/root/reviewer__{task_id}",
                "agent_status": {
                    "completed": "Codex-Orchestrator-Internal-Subagent: coder",
                },
            },
            {
                "agent_name": f"/root/{task_name}",
                "agent_status": "running",
            },
        ]

        self._run_hook(pre_tool_use, self._list_agents_pre_event(coordinator_path))
        self._run_hook(
            post_tool_use,
            self._list_agents_post_event(coordinator_path, response_agents),
        )

        exact_completed = [
            {
                "agent_name": f"/root/{task_name}",
                "agent_status": {"completed": "must not authorize itself"},
            }
        ]
        self._run_hook(pre_tool_use, self._list_agents_pre_event(coder_path))
        self._run_hook(
            post_tool_use,
            self._list_agents_post_event(coordinator_path, exact_completed),
        )
        self._run_hook(pre_tool_use, self._list_agents_pre_event(coordinator_path))
        failed_event = self._list_agents_post_event(
            coordinator_path,
            exact_completed,
        )
        failed_event["tool_response"]["ok"] = False
        self._run_hook(post_tool_use, failed_event)

        agents = self._load_state()["turn"]["agents"]
        self.assertFalse(agents["coder_stopped"])
        self.assertNotIn("stop_seq", agents["coder_passes"][0])
        self.assertFalse(agents["reviewer_stopped"])
        self.assertEqual([], agents["reviewer_stops"])

    def test_agent_path_correlation_rejects_unmatched_coordinator_spawn(self) -> None:
        coordinator_path, coder_path = self._write_correlated_role_transcripts(
            "coder",
            "WRONG-TASK",
            "different_agent",
        )
        coder_path = self._write_spawned_subagent_transcript(
            "expected_agent",
            [
                {
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": (
                            "Codex-Orchestrator-Internal-Subagent: explorer\n"
                            "Task ID: UNTRUSTED-FORK-HISTORY"
                        ),
                    }
                }
            ],
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))

        turn = self._load_state()["turn"]
        self.assertNotIn(str(coder_path), turn["tool_call_actors"])
        self.assertFalse(turn["agents"]["coder_started"])
        self.assertEqual([], turn["agents"]["coder_passes"])

    def test_exact_root_child_correlation_wins_over_forked_parent_history(self) -> None:
        coordinator_path, coder_path = self._write_correlated_role_transcripts(
            "coder", "current_coder", "coder__current_coder",
        )
        coder_path = self._write_spawned_subagent_transcript(
            "coder__current_coder",
            [
                {
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": (
                            "Codex-Orchestrator-Internal-Subagent: explorer\n"
                            "Task ID: FORKED-PARENT-HISTORY"
                        ),
                    }
                }
            ],
            parent_thread_id="coordinator-coder__current_coder",
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))

        turn = self._load_state()["turn"]
        self.assertEqual("coder", turn["tool_call_actors"][str(coder_path)])
        self.assertEqual(
            "current_coder",
            turn["agents"]["coder_passes"][0]["start_task_id"],
        )

    def test_transcript_role_inference_rejects_unrecognized_first_sentinel(self) -> None:
        transcript_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "user_message",
                        "message": (
                            "Codex-Orchestrator-Internal-Subagent: coordinator\n"
                            "Task ID: NOT-A-SUBAGENT"
                        ),
                    }
                },
                {
                    "payload": {
                        "type": "user_message",
                        "message": (
                            "Codex-Orchestrator-Internal-Subagent: coder\n"
                            "Task ID: MUST-NOT-WIN"
                        ),
                    }
                },
            ]
        )

        self.assertIsNone(
            orchestrator_state.infer_internal_subagent_role_from_transcript(
                transcript_path,
            )
        )

    def test_same_coder_transcript_followup_after_stop_opens_second_pass(self) -> None:
        coordinator_path, coder_path = self._write_correlated_role_transcripts(
            "coder", "recover_202", "coder__recover_202",
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))
        with patch.object(
            subagent_stop,
            "git_changed_file_signatures",
            return_value=["M_|app.py|pass-one"],
        ):
            self._run_hook(
                subagent_stop,
                self._transcript_only_stop_event(coder_path, "First coder pass complete."),
            )
        with patch.object(
            pre_tool_use,
            "git_changed_file_signatures",
            return_value=["M_|app.py|pass-one"],
        ):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path, "rg FIXME ."))

        turn = self._load_state()["turn"]
        agents = turn["agents"]
        self.assertEqual(2, len(agents["coder_passes"]))
        self.assertIsInstance(agents["coder_passes"][0]["stop_seq"], int)
        self.assertIsNone(agents["coder_passes"][1].get("stop_seq"))
        self.assertFalse(agents["coder_stopped"])
        self.assertTrue(any(
            "coder agent/session reused" in item["message"]
            for item in turn["lifecycle_violations"]
        ))

    def test_transcript_only_coder_stop_closes_recovered_pass(self) -> None:
        coordinator_path, coder_path = self._write_correlated_role_transcripts(
            "coder", "recover_303", "coder__recover_303",
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))
        with patch.object(
            subagent_stop,
            "git_changed_file_signatures",
            return_value=["M_|app.py|after"],
        ):
            self._run_hook(
                subagent_stop,
                self._transcript_only_stop_event(coder_path, "Coder work complete."),
            )

        agents = self._load_state()["turn"]["agents"]
        self.assertTrue(agents["coder_stopped"])
        self.assertEqual(1, len(agents["coder_passes"]))
        coder_pass = agents["coder_passes"][0]
        self.assertIsInstance(coder_pass["stop_seq"], int)
        self.assertEqual("recover_303", coder_pass["stop_task_id"])
        self.assertEqual(1, coder_pass["stop_task_id_count"])
        self.assertEqual(str(coder_path), coder_pass["agent_transcript_path"])

    def test_transcript_only_reviewer_stop_records_strict_approval(self) -> None:
        coordinator_path, reviewer_path = self._write_correlated_role_transcripts(
            "reviewer", "recover_404", "reviewer__recover_404",
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        state = self._load_state()
        state["turn"]["current_task_id"] = "recover_404"
        orchestrator_state.save_state(state, with_lock=False)

        with patch.object(
            subagent_stop,
            "git_changed_file_signatures",
            return_value=["M_|app.py|reviewed"],
        ):
            self._run_hook(
                subagent_stop,
                self._transcript_only_stop_event(
                    reviewer_path,
                    "No findings.\n\nOverall Assessment: APPROVE",
                ),
            )

        agents = self._load_state()["turn"]["agents"]
        self.assertTrue(agents["reviewer_stopped"])
        self.assertFalse(agents["reviewer_last_blocking"])
        reviewer_stop = agents["reviewer_stops"][-1]
        self.assertEqual("recover_404", reviewer_stop["task_id"])
        self.assertEqual(1, reviewer_stop["task_id_count"])
        self.assertFalse(reviewer_stop["blocking"])

    def test_coordinator_path_is_not_inferred_from_embedded_spawn_prompt(self) -> None:
        coordinator_path = self._write_transcript(
            [
                {
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "content": "orchestrator implement the requested change",
                    }
                },
                {
                    "payload": {
                        "type": "custom_tool_call",
                        "name": "spawn_agent",
                        "input": json.dumps(
                            {
                                "message": (
                                    "Codex-Orchestrator-Internal-Subagent: coder\n"
                                    "Task ID: MUST-NOT-OPEN"
                                )
                            }
                        ),
                    }
                },
            ]
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, self._pre_tool_event(coordinator_path))

        turn = self._load_state()["turn"]
        self.assertEqual("coordinator", turn["tool_call_actors"][str(coordinator_path)])
        self.assertFalse(turn["agents"]["coder_started"])
        self.assertEqual([], turn["agents"]["coder_passes"])

    def test_recovered_lifecycle_satisfies_full_stop_gate_sequence(self) -> None:
        task_id = "captured_gate"
        coder_task_name = f"coder__{task_id}__c1"
        reviewer_task_name = f"reviewer__{task_id}__r2"
        coordinator_path = self._write_coordinator_transcript()
        coder_path = self._write_spawned_subagent_transcript(coder_task_name)
        reviewer_path = self._write_spawned_subagent_transcript(reviewer_task_name)
        work_signature = ["M_|app.py|implemented"]
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(
                pre_tool_use,
                self._spawn_tool_event(
                    coordinator_path,
                    "coder",
                    task_id,
                    coder_task_name,
                ),
            )
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))
        with patch.object(
            pre_tool_use,
            "git_changed_file_signatures",
            return_value=work_signature,
        ):
            self._run_hook(
                pre_tool_use,
                self._spawn_tool_event(
                    coordinator_path,
                    "reviewer",
                    task_id,
                    reviewer_task_name,
                ),
            )
        with patch.object(
            post_tool_use,
            "git_changed_file_signatures",
            return_value=work_signature,
        ):
            self._run_hook(
                pre_tool_use,
                self._list_agents_pre_event(coordinator_path),
            )
            self._run_hook(
                post_tool_use,
                self._list_agents_post_event(
                    coordinator_path,
                    [
                        {
                            "agent_name": f"/root/{coder_task_name}",
                            "agent_status": {"completed": "Coder work complete."},
                        },
                        {
                            "agent_name": f"/root/{reviewer_task_name}",
                            "agent_status": "running",
                        },
                    ],
                ),
            )
        with patch.object(
            post_tool_use,
            "git_changed_file_signatures",
            return_value=work_signature,
        ):
            self._run_hook(
                post_tool_use,
                {
                    "tool_input": {"command": "python3 -m unittest"},
                    "tool_response": {"exit_code": 0},
                    "raw": {"transcript_path": str(coordinator_path)},
                },
            )
        with patch.object(
            subagent_stop,
            "git_changed_file_signatures",
            return_value=work_signature,
        ):
            self._run_hook(
                subagent_stop,
                self._transcript_only_stop_event(
                    reviewer_path,
                    "No findings.\n\nOverall Assessment: APPROVE",
                ),
            )
        with patch.object(
            pre_tool_use,
            "git_changed_file_signatures",
            return_value=work_signature,
        ):
            self._run_hook(
                pre_tool_use,
                self._pre_tool_event(coordinator_path, "git commit -m 'verified change'"),
            )
        with patch.object(post_tool_use, "git_changed_file_signatures", return_value=[]), patch.object(
            post_tool_use, "git_head_commit", return_value="captured-gate-commit"
        ), patch.object(
            post_tool_use, "git_commit_first_parent",
            return_value=orchestrator_state.git_head_commit(),
        ):
            self._run_hook(
                post_tool_use,
                {
                    "tool_input": {"command": "git commit -m 'verified change'"},
                    "tool_response": {"exit_code": 0},
                    "raw": {"transcript_path": str(coordinator_path)},
                },
            )

        state = self._load_state()
        self.assertEqual([], stop._missing_requirements(state, []))

    def test_authoritative_wrapped_spawn_event_records_identity_and_opens_coder_pass(self) -> None:
        coordinator_path = self._write_coordinator_transcript()
        coder_path = self._write_spawned_subagent_transcript("coder__wrapped_coder")
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        wrapped_event = {
            "hook_event_name": "PreToolUse",
            "tool_name": "functions.collaboration.spawn_agent",
            "tool_input": {
                "arguments": json.dumps(
                    {
                        "task_name": "coder__wrapped_coder",
                        "message": (
                            "Codex-Orchestrator-Internal-Subagent: coder\n"
                            "Task ID: wrapped_coder\n\n"
                            "Bounded task instructions."
                        ),
                    }
                ),
            },
            "raw": {"transcript_path": str(coordinator_path)},
        }

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, wrapped_event)
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))

        turn = self._load_state()["turn"]
        evidence = turn["collaboration_spawn_evidence"]
        self.assertEqual(1, len(evidence))
        self.assertEqual("coder", evidence[0]["role"])
        self.assertEqual("wrapped_coder", evidence[0]["task_id"])
        coder_pass = turn["agents"]["coder_passes"][0]
        self.assertIsInstance(coder_pass["start_seq"], int)
        self.assertTrue(coder_pass["start_snapshot_recorded"])
        self.assertEqual("wrapped_coder", coder_pass["start_task_id"])
        self.assertEqual(str(coder_path), coder_pass["agent_transcript_path"])

    def test_codex_hook_compact_collaboration_spawn_name_is_recognized(self) -> None:
        coordinator_path = self._write_coordinator_transcript()
        coder_path = self._write_spawned_subagent_transcript("coder__compact_coder")
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        event = {
            "hook_event_name": "PreToolUse",
            "tool_name": "collaborationspawn_agent",
            "tool_input": {
                "task_name": "coder__compact_coder",
                "message": (
                    "Codex-Orchestrator-Internal-Subagent: coder\n"
                    "Task ID: compact_coder"
                ),
            },
            "raw": {"transcript_path": str(coordinator_path)},
        }

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, event)
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))

        turn = self._load_state()["turn"]
        self.assertEqual("coder", turn["tool_call_actors"][str(coder_path)])
        coder_pass = turn["agents"]["coder_passes"][0]
        self.assertIsInstance(coder_pass["start_seq"], int)
        self.assertEqual("compact_coder", coder_pass["start_task_id"])
        self.assertTrue(coder_pass["start_snapshot_recorded"])

    def test_opaque_spawn_uses_strict_encoded_task_name_and_safe_diagnostics(self) -> None:
        coordinator_path = self._write_coordinator_transcript()
        task_name = "coder__pr27_hook_lifecycle_compat"
        coder_path = self._write_spawned_subagent_transcript(task_name)
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        event = {
            "hook_event_name": "PreToolUse",
            "tool_name": "collaborationspawn_agent",
            "tool_input": {
                "task_name": task_name,
                "message": VALID_OPAQUE_MESSAGE,
            },
            "raw": {"transcript_path": str(coordinator_path)},
        }

        with patch.object(
            pre_tool_use,
            "git_changed_file_signatures",
            return_value=["M_|hook.py|before"],
        ):
            self._run_hook(pre_tool_use, event)

        spawn_turn = self._load_state()["turn"]
        spawn_details = spawn_turn["events"][-1]["details"]
        self.assertEqual("opaque_encrypted", spawn_details["message_kind"])
        self.assertTrue(spawn_details["task_name_present"])
        self.assertNotIn(VALID_OPAQUE_MESSAGE, json.dumps(spawn_details))
        self.assertEqual(
            {
                "coordinator_transcript_path": str(coordinator_path),
                "coordinator_agent_path": "/root",
                "coordinator_depth": 0,
                "coordinator_thread_id": "coordinator-thread",
                "expected_agent_path": f"/root/{task_name}",
                "expected_child_depth": 1,
                "identity_source": "encoded_task_name",
                "message_kind": "opaque_encrypted",
                "role": "coder",
                "seq": spawn_turn["collaboration_spawn_evidence"][0]["seq"],
                "task_id": "pr27_hook_lifecycle_compat",
                "task_id_count": 1,
                "task_name": task_name,
            },
            spawn_turn["collaboration_spawn_evidence"][0],
        )

        with patch.object(
            pre_tool_use,
            "git_changed_file_signatures",
            return_value=["M_|hook.py|before"],
        ):
            self._run_hook(pre_tool_use, self._pre_tool_event(coder_path))

        turn = self._load_state()["turn"]
        self.assertEqual("coder", turn["tool_call_actors"][str(coder_path)])
        self.assertEqual("pr27_hook_lifecycle_compat", turn["current_task_id"])
        coder_pass = turn["agents"]["coder_passes"][0]
        self.assertIsInstance(coder_pass["start_seq"], int)
        self.assertEqual("pr27_hook_lifecycle_compat", coder_pass["start_task_id"])
        self.assertEqual(1, coder_pass["start_task_id_count"])
        self.assertTrue(coder_pass["start_snapshot_recorded"])
        self.assertEqual(
            ["M_|hook.py|before"],
            coder_pass["start_snapshot_signature"],
        )
        self.assertEqual([], turn["lifecycle_violations"])

    def test_opaque_spawn_without_strict_encoding_remains_untrusted(self) -> None:
        coordinator_path = Path(self._tempdir.name) / "untrusted-coordinator.jsonl"
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        event = {
            "hook_event_name": "PreToolUse",
            "tool_name": "collaborationspawn_agent",
            "tool_input": {
                "task_name": "ordinary_coder_name",
                "message": VALID_OPAQUE_MESSAGE,
            },
            "raw": {"transcript_path": str(coordinator_path)},
        }

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, event)

        turn = self._load_state()["turn"]
        details = turn["events"][-1]["details"]
        self.assertEqual("opaque_encrypted", details["message_kind"])
        self.assertTrue(details["task_name_present"])
        self.assertEqual([], turn["collaboration_spawn_evidence"])

    def test_encoded_spawn_rejects_arbitrary_plaintext_and_malformed_opaque_values(self) -> None:
        task_name = "coder__strict_task__nonce"
        cases = (
            ("hello", "invalid_plaintext"),
            ("please implement this task", "invalid_plaintext"),
            ("gAAAAABopaqueEncryptedPayload", "invalid_plaintext"),
            ("", "missing"),
            (None, "missing"),
        )
        for message, expected_kind in cases:
            with self.subTest(message=message):
                event = {
                    "tool_name": "collaborationspawn_agent",
                    "tool_input": {"task_name": task_name, "message": message},
                }
                self.assertIsNone(
                    orchestrator_state.extract_collaboration_spawn_identity(event)
                )
                self.assertEqual(
                    expected_kind,
                    orchestrator_state.collaboration_spawn_diagnostics(event)["message_kind"],
                )

    def test_encoded_spawn_requires_exactly_one_matching_plaintext_task_id(self) -> None:
        task_name = "coder__strict_task__nonce"
        invalid_messages = (
            "Codex-Orchestrator-Internal-Subagent: coder\nImplement it.",
            (
                "Codex-Orchestrator-Internal-Subagent: coder\n"
                "Task ID: strict_task\nTask ID: strict_task"
            ),
            (
                "Codex-Orchestrator-Internal-Subagent: coder\n"
                "Task ID: strict_task\nTask ID: other_task"
            ),
            (
                "Codex-Orchestrator-Internal-Subagent: coder\n"
                "Task ID: other_task"
            ),
        )
        for message in invalid_messages:
            with self.subTest(message=message):
                event = {
                    "tool_name": "collaborationspawn_agent",
                    "tool_input": {"task_name": task_name, "message": message},
                }
                self.assertIsNone(
                    orchestrator_state.extract_collaboration_spawn_identity(event)
                )

        valid_event = {
            "tool_name": "collaborationspawn_agent",
            "tool_input": {
                "task_name": task_name,
                "message": VALID_OPAQUE_MESSAGE,
            },
        }
        self.assertEqual(
            ("coder", "strict_task", 1, task_name),
            orchestrator_state.extract_collaboration_spawn_identity(valid_event),
        )

    def test_encoded_task_name_rejects_ambiguous_or_conflicting_identity(self) -> None:
        conflicting_event = {
            "tool_name": "collaborationspawn_agent",
            "tool_input": {
                "task_name": "coder__strict_task",
                "message": (
                    "Codex-Orchestrator-Internal-Subagent: reviewer\n"
                    "Task ID: strict_task"
                ),
            },
        }
        unrelated_sentinel_event = {
            "tool_name": "collaborationspawn_agent",
            "tool_input": {
                "task_name": "ordinary_name",
                "message": VALID_OPAQUE_MESSAGE,
                "private_value": (
                    "Codex-Orchestrator-Internal-Subagent: coder\n"
                    "Task ID: MUST_NOT_BE_TRUSTED"
                ),
            },
        }

        self.assertIsNone(
            orchestrator_state.extract_collaboration_spawn_identity(
                conflicting_event,
            )
        )
        self.assertIsNone(
            orchestrator_state.extract_collaboration_spawn_identity(
                unrelated_sentinel_event,
            )
        )
        self.assertEqual(
            ("reviewer", "pr27_hook_lifecycle_compat", 1),
            orchestrator_state.extract_encoded_task_name_identity(
                "reviewer__pr27_hook_lifecycle_compat__r2",
            ),
        )
        self.assertEqual(
            ("coder", "two", 1),
            orchestrator_state.extract_encoded_task_name_identity(
                "coder__two__separators",
            ),
        )
        for invalid_name in (
            "coder__UPPERCASE",
            "coder__trailing_",
            "coder__contains-hyphen",
            "coder__task__",
            "coder__task__BAD",
            "coder__task__bad-hyphen",
            "coder__task__nonce__extra",
            "unknown__strict_task",
        ):
            with self.subTest(task_name=invalid_name):
                self.assertIsNone(
                    orchestrator_state.extract_encoded_task_name_identity(
                        invalid_name,
                    )
                )

    def test_spawn_diagnostics_distinguish_plaintext_and_missing_messages(self) -> None:
        coordinator_path = Path(self._tempdir.name) / "diagnostic-kinds.jsonl"
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        plaintext_event = self._spawn_tool_event(
            coordinator_path,
            "coder",
            "DIAGNOSTIC-KIND-101",
            "diagnostic_kind_coder",
        )
        missing_event = {
            "hook_event_name": "PreToolUse",
            "tool_name": "collaborationspawn_agent",
            "tool_input": {"task_name": "missing_message_coder"},
            "raw": {"transcript_path": str(coordinator_path)},
        }

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, plaintext_event)
            self._run_hook(pre_tool_use, missing_event)

        events = self._load_state()["turn"]["events"]
        plaintext_details, missing_details = events[-2]["details"], events[-1]["details"]
        self.assertEqual("plaintext_sentinel", plaintext_details["message_kind"])
        self.assertTrue(plaintext_details["task_name_present"])
        self.assertEqual("missing", missing_details["message_kind"])
        self.assertTrue(missing_details["task_name_present"])

    def test_nested_functions_exec_spawn_spoof_is_not_trusted(self) -> None:
        event = {
            "tool_name": "functions.exec",
            "tool_input": {
                "name": "collaboration__spawn_agent",
                "input": {
                    "task_name": "nested_coder",
                    "payload": {
                        "message": (
                            "Codex-Orchestrator-Internal-Subagent: coder\n"
                            "Task ID: NESTED-ONE\n"
                            "Task ID: NESTED-TWO"
                        )
                    },
                },
            },
        }

        identity = orchestrator_state.extract_collaboration_spawn_identity(event)

        self.assertIsNone(identity)
        self.assertEqual({}, orchestrator_state.collaboration_spawn_diagnostics(event))

    def test_pre_tool_diagnostics_store_names_but_not_spawn_values(self) -> None:
        coordinator_path = Path(self._tempdir.name) / "diagnostic-coordinator.jsonl"
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        event = self._spawn_tool_event(
            coordinator_path,
            "coder",
            "DIAGNOSTIC-101",
            "diagnostic_coder",
        )
        event["tool_input"]["private_value"] = "MUST_NOT_BE_PERSISTED"

        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(pre_tool_use, event)

        details = self._load_state()["turn"]["events"][-1]["details"]
        self.assertEqual("collaboration.spawn_agent", details["tool_name"])
        self.assertEqual(
            ["fork_turns", "message", "private_value", "task_name"],
            details["tool_input_keys"],
        )
        self.assertNotIn("MUST_NOT_BE_PERSISTED", json.dumps(details))

    def test_captured_spawn_stop_only_coder_remains_conservatively_blocked(self) -> None:
        coordinator_path = self._write_coordinator_transcript()
        coder_path = self._write_spawned_subagent_transcript(
            "coder__captured_stop_only",
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        with patch.object(pre_tool_use, "git_changed_file_signatures", return_value=[]):
            self._run_hook(
                pre_tool_use,
                self._spawn_tool_event(
                    coordinator_path,
                    "coder",
                    "captured_stop_only",
                    "coder__captured_stop_only",
                ),
            )
        with patch.object(
            subagent_stop,
            "git_changed_file_signatures",
            return_value=["M_|app.py|after"],
        ):
            self._run_hook(
                subagent_stop,
                self._transcript_only_stop_event(coder_path, "Coder work complete."),
            )

        state = self._load_state()
        coder_pass = state["turn"]["agents"]["coder_passes"][0]
        self.assertIsNone(coder_pass["start_seq"])
        self.assertFalse(coder_pass["start_snapshot_recorded"])
        missing = stop._missing_requirements(state, ["M_|app.py|after"])
        self.assertIn(
            "task captured_stop_only verification must run after its final coder pass",
            missing,
        )
        self.assertIn(
            "task captured_stop_only needs a fresh non-blocking reviewer after verification",
            missing,
        )

    def test_verification_matching_only_checks_segments(self) -> None:
        self.assertTrue(orchestrator_state.command_match_verification("flutter test ."))
        self.assertTrue(orchestrator_state.command_match_verification("cd apps/mobile && flutter test"))
        self.assertTrue(orchestrator_state.command_match_verification("cd apps/mobile && flutter analyze ."))
        self.assertTrue(orchestrator_state.command_match_verification("flutter gen-l10n"))
        self.assertTrue(orchestrator_state.command_match_verification("python -m pytest -q"))
        self.assertTrue(orchestrator_state.command_match_verification("python3 -m unittest"))
        self.assertTrue(orchestrator_state.command_match_verification("python3 -m compile my_module.py"))
        self.assertTrue(orchestrator_state.command_match_verification("python3 -m py_compile file.py"))
        self.assertTrue(orchestrator_state.command_match_verification("dart test ."))
        self.assertFalse(orchestrator_state.command_match_verification("gh pr create --body 'please run flutter test'"))
        self.assertFalse(orchestrator_state.command_match_verification("echo 'python3 -m pytest'"))
        self.assertFalse(orchestrator_state.command_match_verification("flutter create test"))
        self.assertFalse(orchestrator_state.command_match_verification("flutter --version test"))
        self.assertFalse(orchestrator_state.command_match_verification("dart pub test"))

    def test_string_tool_response_preserves_failure_exit_codes(self) -> None:
        events = (
            ({"tool_response": "Process exited with code 1"}, 1),
            ({"tool_response": "exit_code: 23"}, 23),
            ({"tool_response": "exec_command failed for `flutter test`"}, 1),
        )

        for event, expected in events:
            with self.subTest(tool_response=event["tool_response"]):
                self.assertEqual(expected, orchestrator_state.parse_tool_exit_code(event))

    def test_tool_exit_code_preserves_structured_responses_and_successful_stdout(self) -> None:
        self.assertEqual(
            7,
            orchestrator_state.parse_tool_exit_code({"tool_response": {"exit_code": 7}}),
        )
        self.assertEqual(
            0,
            orchestrator_state.parse_tool_exit_code(
                {"tool_response": "Completed 7 checks successfully."}
            ),
        )

    def test_standard_severity_sections_with_findings_are_blocking(self) -> None:
        reviews = (
            "Critical Issues\n- App crashes on launch.\n\nOverall Assessment: APPROVE",
            "Major Issues (🟠)\n- User data can be lost.\n\nOverall Assessment: APPROVE",
            "High Risk\n- Authentication can be bypassed.\n\nOverall Assessment: APPROVE",
        )

        for review in reviews:
            with self.subTest(review=review):
                self.assertTrue(subagent_stop.looks_blocking(review))

    def test_explicitly_empty_severity_sections_remain_non_blocking(self) -> None:
        reviews = (
            "Critical Issues\nNone\n\nOverall Assessment: APPROVE",
            "Major Issues (🟠)\n- No issues\n\nOverall Assessment: APPROVE",
            "High Risk\nNo findings\n\nOverall Assessment: APPROVE",
        )

        for review in reviews:
            with self.subTest(review=review):
                self.assertFalse(subagent_stop.looks_blocking(review))

    def test_load_state_legacy_turn_is_recursively_hydrated_with_defaults_and_preserved_values(self) -> None:
        legacy_state = {
            "active": True,
            "turn": {
                "turn_id": "legacy-turn-001",
                "triggered": True,
                "event_seq": 12,
                "files_changed": ["scripts/run.sh", "lib/main.dart"],
                "legacy_turn_marker": "legacy-legacy",
                "agents": {
                    "coder_started": True,
                    "legacy_agent_value": "legacy-flag",
                },
                "verification": {
                    "run": True,
                },
            },
        }
        self.state_file.write_text(json.dumps(legacy_state), encoding="utf-8")

        state = self._load_state()
        turn = state["turn"]

        self.assertTrue(state["active"])
        self.assertEqual("legacy-turn-001", turn["turn_id"])
        self.assertTrue(turn["triggered"])
        self.assertEqual(12, turn["event_seq"])
        self.assertEqual("legacy-legacy", turn["legacy_turn_marker"])
        self.assertEqual([], turn["files_changed_signature_at_start"])
        self.assertEqual(["lib/main.dart", "scripts/run.sh"], turn["files_changed_at_start"])
        self.assertEqual(["lib/main.dart", "scripts/run.sh"], turn["files_changed_current"])
        self.assertEqual([], turn["files_changed_signature_current"])
        self.assertTrue(turn["agents"]["coder_started"])
        self.assertEqual("legacy-flag", turn["agents"]["legacy_agent_value"])
        self.assertEqual([], turn["agents"]["coder_passes"])
        self.assertTrue(turn["verification"]["run"])
        self.assertEqual([], turn["verification"]["snapshot_signature"])
        self.assertFalse(turn["verification"]["snapshot"])
        self.assertEqual({}, turn["task_ledgers"])
        self.assertEqual({"coder": {}, "reviewer": {}}, turn["agent_identity_usage"])

    def test_stop_gate_ignores_unknown_main_agent_file_edit_without_coordinator_actor(self) -> None:
        state = self._build_stop_gate_state({"tool_name": "Bash", "actor": ""})
        missing = stop._missing_requirements(state, ["100|app.py|A"])
        self.assertNotIn(
            "main agent performed file-edit tool actions while a coder pass was open",
            missing,
        )

    def test_stop_gate_blocks_when_main_agent_file_edit_has_coordinator_actor(self) -> None:
        state = self._build_stop_gate_state({"tool_name": "Bash", "actor": "coordinator"})
        state["turn"]["agents"]["main_agent_file_edit_detected"] = False
        missing = stop._missing_requirements(state, ["100|app.py|A"])
        self.assertIn(
            "main agent performed file-edit tool actions while a coder pass was open",
            missing,
        )

    def test_strict_two_chunks_require_distinct_agents_and_commits(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        turn["task_ledgers"] = {
            "chunk_one": self._strict_ledger(
                "chunk_one", coder_identity="coder-1", reviewer_identity="reviewer-1",
                commit_hash="hash-1",
            ),
            "chunk_two": self._strict_ledger(
                "chunk_two", coder_identity="coder-2", reviewer_identity="reviewer-2",
                commit_hash="hash-2", offset=10,
            ),
        }
        self.assertEqual([], stop._missing_task_ledger_requirements(turn))

    def test_strict_normal_sequential_two_commit_history_succeeds(self) -> None:
        repo, base_hash = self._new_git_history_repo()
        (repo / "history.txt").write_text("base\nchunk one\n", encoding="utf-8")
        self._git(repo, "add", "history.txt")
        self._git(repo, "commit", "-q", "-m", "chunk one")
        first_hash = self._git(repo, "rev-parse", "HEAD")
        (repo / "history.txt").write_text(
            "base\nchunk one\nchunk two\n", encoding="utf-8"
        )
        self._git(repo, "add", "history.txt")
        self._git(repo, "commit", "-q", "-m", "chunk two")
        second_hash = self._git(repo, "rev-parse", "HEAD")

        turn = orchestrator_state.default_state()["turn"]
        first = self._strict_ledger(
            "chunk_one", coder_identity="coder-1", reviewer_identity="reviewer-1",
            commit_hash=first_hash, baseline_head=base_hash,
        )
        second = self._strict_ledger(
            "chunk_two", coder_identity="coder-2", reviewer_identity="reviewer-2",
            commit_hash=second_hash, baseline_head=first_hash, offset=10,
        )
        turn["task_ledgers"] = {"chunk_one": first, "chunk_two": second}
        with patch.object(orchestrator_state, "ROOT", repo):
            self.assertEqual([], stop._missing_task_ledger_requirements(turn))

    def test_strict_second_task_commit_amend_is_rejected(self) -> None:
        repo, base_hash = self._new_git_history_repo()
        (repo / "history.txt").write_text("base\nchunk one\n", encoding="utf-8")
        self._git(repo, "add", "history.txt")
        self._git(repo, "commit", "-q", "-m", "chunk one")
        first_hash = self._git(repo, "rev-parse", "HEAD")
        (repo / "history.txt").write_text(
            "base\nchunk one\nchunk two\n", encoding="utf-8"
        )
        self._git(repo, "add", "history.txt")
        self._git(repo, "commit", "-q", "--amend", "-m", "chunk two amended")
        amended_hash = self._git(repo, "rev-parse", "HEAD")

        turn = orchestrator_state.default_state()["turn"]
        first = self._strict_ledger(
            "chunk_one", coder_identity="coder-1", reviewer_identity="reviewer-1",
            commit_hash=first_hash, baseline_head=base_hash,
        )
        second = self._strict_ledger(
            "chunk_two", coder_identity="coder-2", reviewer_identity="reviewer-2",
            commit_hash=amended_hash, baseline_head=first_hash, offset=10,
        )
        # The hook records Git's actual first parent after the amend, which is
        # the pre-chunk base rather than the recorded pre-commit HEAD.
        second["commits"][0]["first_parent"] = base_hash
        turn["task_ledgers"] = {"chunk_one": first, "chunk_two": second}
        with patch.object(orchestrator_state, "ROOT", repo):
            missing = stop._missing_task_ledger_requirements(turn)
        self.assertTrue(any("normal first-parent child" in item for item in missing))
        self.assertTrue(any("chunk_one commit is no longer an ancestor" in item for item in missing))

    def test_strict_aggregate_commit_cannot_close_two_chunks(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        turn["task_ledgers"] = {
            "chunk_one": self._strict_ledger(
                "chunk_one", coder_identity="coder-1", reviewer_identity="reviewer-1",
                commit_hash="same-hash",
            ),
            "chunk_two": self._strict_ledger(
                "chunk_two", coder_identity="coder-2", reviewer_identity="reviewer-2",
                commit_hash="same-hash", offset=10,
            ),
        }
        missing = stop._missing_task_ledger_requirements(turn)
        self.assertTrue(any("cannot share aggregate commit" in item for item in missing))

    def test_strict_second_chunk_before_first_commit_is_flagged(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        first_path = self._write_spawned_subagent_transcript(
            "coder__chunk_one__a", thread_id="coder-thread-1"
        )
        second_path = self._write_spawned_subagent_transcript(
            "coder__chunk_two__b", thread_id="coder-thread-2"
        )
        first = orchestrator_state.register_strict_agent_start(
            turn, "coder", first_path, 1, []
        )
        self.assertIsNotNone(first)
        turn["task_ledgers"]["chunk_one"]["changed"] = True
        orchestrator_state.register_strict_agent_start(turn, "coder", second_path, 2, [])
        self.assertTrue(
            any("started before changed task chunk_one" in item["message"] for item in turn["lifecycle_violations"])
        )

    def test_strict_overlapping_coders_are_rejected_at_closure_after_late_change_discovery(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        first = self._strict_ledger(
            "chunk_one", coder_identity="coder-1", reviewer_identity="reviewer-1",
            commit_hash="hash-1",
        )
        second = self._strict_ledger(
            "chunk_two", coder_identity="coder-2", reviewer_identity="reviewer-2",
            commit_hash="hash-2", offset=2,
        )
        # chunk_two starts at seq 3 while chunk_one's approved commit is seq 5.
        turn["task_ledgers"] = {"chunk_one": first, "chunk_two": second}
        missing = stop._missing_task_ledger_requirements(turn)
        self.assertTrue(any(
            "task chunk_two started before changed task chunk_one received" in item
            for item in missing
        ))

    def test_strict_coder_session_reuse_is_rejected(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        path = self._write_spawned_subagent_transcript(
            "coder__chunk_one__a", thread_id="same-coder-thread"
        )
        orchestrator_state.register_strict_agent_start(turn, "coder", path, 1, [])
        orchestrator_state.register_strict_agent_start(turn, "coder", path, 2, [])
        self.assertTrue(any("coder agent/session reused" in item["message"] for item in turn["lifecycle_violations"]))

    def test_strict_coder_cannot_be_relabelled_for_another_chunk(self) -> None:
        self._set_unstarted_active_turn_state()
        path = self._write_spawned_subagent_transcript(
            "coder__chunk_one__a", thread_id="coder-thread"
        )
        self._run_hook(
            subagent_start,
            {
                "agent_type": "coder",
                "prompt": (
                    "Codex-Orchestrator-Internal-Subagent: coder\n"
                    "Task ID: chunk_two\n"
                ),
                "agent_transcript_path": str(path),
            },
        )
        violations = self._load_state()["turn"]["lifecycle_violations"]
        self.assertTrue(any("does not exactly match encoded" in item["message"] for item in violations))

    def test_strict_encoded_coder_requires_task_id_line(self) -> None:
        self._set_unstarted_active_turn_state()
        path = self._write_spawned_subagent_transcript(
            "coder__chunk_one__missing", thread_id="missing-task-id"
        )
        self._run_hook(subagent_start, {
            "agent_type": "coder",
            "prompt": "Codex-Orchestrator-Internal-Subagent: coder\nImplement the chunk.",
            "agent_transcript_path": str(path),
        })
        violations = self._load_state()["turn"]["lifecycle_violations"]
        self.assertTrue(any("exactly one Task ID line" in item["message"] for item in violations))

    def test_new_non_strict_coder_start_is_rejected_and_cannot_close_legacy_flow(self) -> None:
        self._set_unstarted_active_turn_state()
        before = self._load_state()["turn"]
        path = self._write_spawned_subagent_transcript(
            "ordinary_coder_name", thread_id="non-strict-coder-thread"
        )
        with patch.object(subagent_start, "git_changed_file_signatures", return_value=[]):
            self._run_hook(subagent_start, {
                "agent_type": "coder",
                "prompt": (
                    "Codex-Orchestrator-Internal-Subagent: coder\n"
                    "Task ID: strict_task"
                ),
                "agent_transcript_path": str(path),
            })

        state = self._load_state()
        violation = (
            "new coder session must use strict name "
            "coder__<canonical_task_id>[__<nonce>] and matching Task ID evidence"
        )
        self.assertIn(
            violation,
            [item["message"] for item in state["turn"]["lifecycle_violations"]],
        )
        self.assertEqual({}, state["turn"]["task_ledgers"])
        self.assertEqual(before["agents"], state["turn"]["agents"])
        self.assertEqual(before["current_task_id"], state["turn"]["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], state["turn"]["agent_identity_usage"])
        self.assertIn(violation, stop._missing_requirements(state, []))

    def test_new_non_strict_reviewer_start_is_rejected(self) -> None:
        self._set_unstarted_active_turn_state()
        before = self._load_state()["turn"]
        path = self._write_spawned_subagent_transcript(
            "ordinary_reviewer_name", thread_id="non-strict-reviewer-thread"
        )
        self._run_hook(subagent_start, {
            "agent_type": "reviewer",
            "prompt": (
                "Codex-Orchestrator-Internal-Subagent: reviewer\n"
                "Task ID: strict_task"
            ),
            "agent_transcript_path": str(path),
        })
        violations = self._load_state()["turn"]["lifecycle_violations"]
        self.assertTrue(any(
            "new reviewer session must use strict name" in item["message"]
            for item in violations
        ))
        turn = self._load_state()["turn"]
        self.assertEqual(before["agents"], turn["agents"])
        self.assertEqual(before["current_task_id"], turn["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], turn["agent_identity_usage"])

    def test_strict_encoded_coder_rejects_empty_nonopaque_start_prompt(self) -> None:
        self._set_unstarted_active_turn_state()
        before = self._load_state()["turn"]
        path = self._write_spawned_subagent_transcript(
            "coder__chunk_one__empty", thread_id="empty-prompt-task-id"
        )
        self._run_hook(subagent_start, {
            "agent_type": "coder",
            "prompt": "",
            "agent_transcript_path": str(path),
        })
        violations = self._load_state()["turn"]["lifecycle_violations"]
        self.assertTrue(any("exactly one Task ID line" in item["message"] for item in violations))
        turn = self._load_state()["turn"]
        self.assertEqual(before["agents"], turn["agents"])
        self.assertEqual(before["current_task_id"], turn["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], turn["agent_identity_usage"])

    def test_new_non_strict_coder_stop_blocks_without_mutating_legacy_lifecycle(self) -> None:
        self._set_unstarted_active_turn_state()
        before = self._load_state()["turn"]
        path = self._write_spawned_subagent_transcript(
            "ordinary_coder_name", thread_id="non-strict-stop-thread"
        )

        with patch.object(subagent_stop, "git_changed_file_signatures", return_value=[]):
            self._run_hook(subagent_stop, {
                "hook_event_name": "SubagentStop",
                "agent_type": "coder",
                "last_assistant_message": "Task ID: strict_task\nCompleted.",
                "agent_transcript_path": str(path),
            })

        state = self._load_state()
        turn = state["turn"]
        self.assertEqual(before["agents"], turn["agents"])
        self.assertEqual(before["current_task_id"], turn["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], turn["agent_identity_usage"])
        self.assertTrue(any(
            "new coder session must use strict name" in item["message"]
            for item in turn["lifecycle_violations"]
        ))
        self.assertTrue(stop._missing_requirements(state, []))

    def test_invalid_reviewer_stop_cannot_record_approval_or_remediation(self) -> None:
        self._set_unstarted_active_turn_state()
        before = self._load_state()["turn"]
        path = self._write_spawned_subagent_transcript(
            "ordinary_reviewer_name", thread_id="non-strict-reviewer-stop-thread"
        )

        with patch.object(subagent_stop, "git_changed_file_signatures", return_value=[]):
            self._run_hook(subagent_stop, {
                "hook_event_name": "SubagentStop",
                "agent_type": "reviewer",
                "last_assistant_message": (
                    "Blocking issue remains.\n\n"
                    "Overall Assessment: REQUEST_CHANGES"
                ),
                "agent_transcript_path": str(path),
            })

        state = self._load_state()
        turn = state["turn"]
        self.assertEqual(before["agents"], turn["agents"])
        self.assertEqual(before["current_task_id"], turn["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], turn["agent_identity_usage"])
        self.assertTrue(any(
            "new reviewer session must use strict name" in item["message"]
            for item in turn["lifecycle_violations"]
        ))
        self.assertTrue(stop._missing_requirements(state, []))

    def test_strict_coder_stop_with_invalid_task_id_blocks_without_legacy_mutation(self) -> None:
        coordinator_path, path = self._write_correlated_role_transcripts(
            "coder", "wrong_task", "coder__strict_task__bad_stop",
        )
        self._set_unstarted_active_turn_state({str(coordinator_path): "coordinator"})
        before = self._load_state()["turn"]

        with patch.object(subagent_stop, "git_changed_file_signatures", return_value=[]):
            self._run_hook(subagent_stop, {
                "hook_event_name": "SubagentStop",
                "agent_type": "coder",
                "last_assistant_message": "Completed.",
                "agent_transcript_path": str(path),
            })

        state = self._load_state()
        turn = state["turn"]
        self.assertEqual(before["agents"], turn["agents"])
        self.assertEqual(before["current_task_id"], turn["current_task_id"])
        self.assertEqual(before["agent_identity_usage"], turn["agent_identity_usage"])
        self.assertTrue(any(
            "does not exactly match encoded" in item["message"]
            for item in turn["lifecycle_violations"]
        ))
        self.assertTrue(stop._missing_requirements(state, []))

    def test_strict_encoded_coder_rejects_duplicate_task_id_lines(self) -> None:
        self._set_unstarted_active_turn_state()
        path = self._write_spawned_subagent_transcript(
            "coder__chunk_one__duplicate", thread_id="duplicate-task-id"
        )
        self._run_hook(subagent_start, {
            "agent_type": "coder",
            "prompt": (
                "Codex-Orchestrator-Internal-Subagent: coder\n"
                "Task ID: chunk_one\nTask ID: chunk_one\n"
            ),
            "agent_transcript_path": str(path),
        })
        violations = self._load_state()["turn"]["lifecycle_violations"]
        self.assertTrue(any("exactly one Task ID line" in item["message"] for item in violations))

    def test_strict_encoded_coder_rejects_conflicting_task_id_lines(self) -> None:
        self._set_unstarted_active_turn_state()
        path = self._write_spawned_subagent_transcript(
            "coder__chunk_one__conflict", thread_id="conflicting-task-id"
        )
        self._run_hook(subagent_start, {
            "agent_type": "coder",
            "prompt": (
                "Codex-Orchestrator-Internal-Subagent: coder\n"
                "Task ID: chunk_one\nTask ID: chunk_two\n"
            ),
            "agent_transcript_path": str(path),
        })
        violations = self._load_state()["turn"]["lifecycle_violations"]
        self.assertTrue(any("exactly one Task ID line" in item["message"] for item in violations))

    def test_strict_identity_rejects_noncanonical_task_name(self) -> None:
        path = self._write_spawned_subagent_transcript(
            "coder__Chunk-One__a", thread_id="bad-task-thread"
        )
        self.assertIsNone(orchestrator_state.strict_agent_session_identity(path, "coder"))

    def test_strict_reviewer_session_reuse_is_rejected(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        path = self._write_spawned_subagent_transcript(
            "reviewer__chunk_one__a", thread_id="same-reviewer-thread"
        )
        orchestrator_state.register_strict_agent_start(turn, "reviewer", path, 1, [])
        orchestrator_state.register_strict_agent_start(turn, "reviewer", path, 2, [])
        self.assertTrue(any("reviewer agent/session reused" in item["message"] for item in turn["lifecycle_violations"]))

    def test_strict_remediation_requires_new_coder_and_reviewer(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        ledger = self._strict_ledger(
            "repair_chunk", coder_identity="initial-coder", reviewer_identity="initial-reviewer",
            commit_hash="repair-hash",
        )
        ledger["coder_passes"][0]["stop_seq"] = 2
        ledger["reviewer_passes"] = [
            {"seq": 4, "agent_identity": "blocking-reviewer", "blocking": True},
            {"seq": 9, "agent_identity": "fresh-reviewer", "blocking": False},
        ]
        ledger["blocking_review_seq"] = 4
        ledger["coder_passes"].append(
            {
                "start_seq": 5, "stop_seq": 6,
                "agent_identity": "remediation-coder",
                "stop_snapshot_signature": ["100|repair_chunk.py|work"],
            }
        )
        ledger["verifications"] = [{
            "seq": 7,
            "snapshot_signature": ["100|repair_chunk.py|work"],
        }]
        ledger["reviewer_passes"][1]["snapshot_signature"] = [
            "100|repair_chunk.py|work"
        ]
        ledger["commits"] = [{
            "seq": 10, "hash": "repair-hash",
            "head_before": "base-repair_chunk",
            "first_parent": "base-repair_chunk",
            "snapshot_signature": ["100|repair_chunk.py|work"],
            "post_snapshot_signature": [],
        }]
        turn["task_ledgers"] = {"repair_chunk": ledger}
        self.assertEqual([], stop._missing_task_ledger_requirements(turn))
        ledger["coder_passes"][1]["agent_identity"] = "initial-coder"
        self.assertTrue(any("reused a coder" in item for item in stop._missing_task_ledger_requirements(turn)))

    def test_strict_encoded_name_without_correlated_opaque_evidence_is_rejected(self) -> None:
        path = self._write_spawned_subagent_transcript(
            "coder__opaque_chunk__nonce", thread_id="encrypted-thread",
            extra_records=[{"payload": {"type": "encrypted_content", "blob": "opaque"}}],
        )
        identity = orchestrator_state.strict_agent_session_identity(path, "coder")
        self.assertIsNotNone(identity)
        self.assertEqual("opaque_chunk", identity["task_id"])
        self.assertEqual("coder__opaque_chunk__nonce", identity["agent_name"])
        turn = orchestrator_state.default_state()["turn"]
        self.assertFalse(orchestrator_state.validate_strict_prompt_identity(turn, identity, ""))
        self.assertTrue(any(
            "exactly one Task ID line" in item["message"]
            for item in turn["lifecycle_violations"]
        ))

    def test_strict_empty_or_unrelated_commit_cannot_close_chunk(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        empty = self._strict_ledger(
            "empty_chunk", coder_identity="coder-empty", reviewer_identity="reviewer-empty",
            commit_hash="empty-hash",
        )
        empty["commits"][0]["snapshot_signature"] = []
        empty["commits"][0]["post_snapshot_signature"] = [
            "100|empty_chunk.py|work"
        ]
        turn["task_ledgers"] = {"empty_chunk": empty}
        self.assertTrue(any(
            "empty commit snapshot" in item
            for item in stop._missing_task_ledger_requirements(turn)
        ))

        unrelated = self._strict_ledger(
            "unrelated_chunk", coder_identity="coder-other", reviewer_identity="reviewer-other",
            commit_hash="unrelated-hash",
        )
        unrelated["commits"][0]["snapshot_signature"] = ["100|other.py|work"]
        turn["task_ledgers"] = {"unrelated_chunk": unrelated}
        self.assertTrue(any(
            "commit snapshot does not match verified coder output" in item
            for item in stop._missing_task_ledger_requirements(turn)
        ))

    def test_strict_commit_must_advance_task_baseline_head(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        ledger = self._strict_ledger(
            "baseline_chunk", coder_identity="coder-base", reviewer_identity="reviewer-base",
            commit_hash="new-hash",
        )
        ledger["commits"][0]["head_before"] = "unrelated-head"
        turn["task_ledgers"] = {"baseline_chunk": ledger}
        self.assertTrue(any(
            "did not advance its recorded baseline HEAD" in item
            for item in stop._missing_task_ledger_requirements(turn)
        ))

    def test_strict_unchanged_task_does_not_require_commit(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        turn["task_ledgers"] = {
            "audit_chunk": self._strict_ledger(
                "audit_chunk", coder_identity="coder-a", reviewer_identity="reviewer-a",
                commit_hash=None, changed=False,
            )
        }
        self.assertEqual([], stop._missing_task_ledger_requirements(turn))

    def test_strict_single_chunk_happy_path(self) -> None:
        turn = orchestrator_state.default_state()["turn"]
        turn["task_ledgers"] = {
            "single_chunk": self._strict_ledger(
                "single_chunk", coder_identity="coder-a", reviewer_identity="reviewer-a",
                commit_hash="hash-a",
            )
        }
        self.assertEqual([], stop._missing_task_ledger_requirements(turn))

    def test_closure_hook_feedback_does_not_start_a_new_turn(self) -> None:
        state = orchestrator_state.default_state()
        state["active"] = True
        state["turn"]["triggered"] = True
        state["turn"]["turn_id"] = "existing-turn"
        orchestrator_state.save_state(state, with_lock=False)
        self._run_hook(
            user_prompt_submit,
            {
                "prompt": (
                    '<hook_prompt hook_run_id="stop:5:test">'
                    "Orchestration closure gate failed: coder subagent not started; "
                    "reviewer has not completed a non-blocking pass</hook_prompt>"
                )
            },
        )
        loaded = self._load_state()
        self.assertTrue(loaded["active"])
        self.assertEqual("existing-turn", loaded["turn"]["turn_id"])

    def test_partial_task_ledger_state_is_hydrated(self) -> None:
        legacy_state = {
            "active": True,
            "turn": {
                "task_ledgers": {
                    "legacy_chunk": {"changed": True, "coder_passes": None}
                }
            },
        }
        self.state_file.write_text(json.dumps(legacy_state), encoding="utf-8")
        ledger = self._load_state()["turn"]["task_ledgers"]["legacy_chunk"]
        self.assertEqual([], ledger["coder_passes"])
        self.assertEqual([], ledger["reviewer_passes"])
        self.assertEqual([], ledger["verifications"])
        self.assertEqual([], ledger["commits"])


if __name__ == "__main__":
    unittest.main()
