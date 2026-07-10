from __future__ import annotations

import io
import json
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
import user_prompt_submit


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
        path = Path(self._tempdir.name) / f"transcript-{id(records)}.jsonl"
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

    def test_reviewer_task_id_recovered_from_transcript_when_summary_missing(self) -> None:
        transcript_path = self._write_transcript(
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

        event: dict[str, Any] = {
            "prompt": "Reviewer completed",
            "raw": {"transcript_path": str(transcript_path)},
        }
        task_id, count = subagent_stop._extract_reviewer_task_info(event, {})

        self.assertEqual("REV-77", task_id)
        self.assertEqual(1, count)

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


if __name__ == "__main__":
    unittest.main()
