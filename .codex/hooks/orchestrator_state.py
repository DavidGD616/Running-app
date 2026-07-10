from __future__ import annotations

import hashlib
import os
import json
import tempfile
import contextlib
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Dict, Iterable, List

try:
    import fcntl  # type: ignore[attr-defined]
except ImportError:  # pragma: no cover
    fcntl = None


ROOT = Path(__file__).resolve().parents[2]
STATE_DIR = ROOT / ".codex" / ".orchestrator-state"
STATE_FILE = STATE_DIR / "state.json"

TRIGGER_PATTERNS = [
    r"\borchestrator\b",
    r"\borchestration\b",
    r"\bsub[-_ ]?agents?\b",
    r"\bspecialists\b",
    r"\bcoder\b",
    r"\breviewer\b",
    r"\bexplorer\b",
    r"\bresearcher\b",
    r"\bscribe\b",
    r"don't stop until reviewer approves",
]

IMPLEMENT_PATTERNS = [
    r"\bimplement",
    r"\bimplementing",
    r"\bimplementations?",
    r"\bbuild",
    r"\bcreate",
    r"\badd",
    r"\bupdate",
    r"\bmodify",
    r"\bchange",
    r"\bfix",
    r"\bedit",
    r"\bremove",
    r"\bdelete",
    r"\brefactor",
    r"\bwired?",
    r"\badjust",
    r"\bcreate",
]

PLAN_ONLY_PATTERNS = [
    r"\bcreate\s+plan\b",
    r"\bcreate\s+(?:a|an)\s+plan\s+for\s+implementation\b",
    r"\bcreate\s+an?\s+implementation\s+plan\b",
    r"\bcreate\s+implementation\s+plan\b",
    r"\bmake\s+a?\s+plan\b",
    r"\bmake\s+(?:a|an)\s+plan\s+for\s+implementation\b",
    r"\bplan\s+the\s+implementation\b",
    r"\bplan\s+implementation(?:\s+steps)?\b",
    r"\bplan\s+out\b",
    r"\bplan-?only\b",
]

NO_COMMIT_PATTERNS = [
    r"do not commit",
    r"don't commit",
    r"no commit",
    r"without commit",
    r"propose.*only",
]

VERIFICATION_PATTERNS = [
    re.compile(r"\bflutter\s+(analyze|test|gen-l10n)\b"),
    re.compile(r"\bpython3?\s+(-m\s+)?(pytest|unittest|compile|py_compile)\b"),
    re.compile(r"\bpython3?\s+-m\s+(?:compile|py_compile)\b"),
    re.compile(r"\bdart\s+test\b"),
]

_VERIFICATION_FLUTTER_COMMANDS = {"analyze", "test", "gen-l10n"}
_VERIFICATION_PYTHON_MODULES = {"pytest", "unittest", "compile", "py_compile"}
_VERIFICATION_DART_COMMANDS = {"test"}

AGENT_CODER = {"coder", "implementation", "worker"}
AGENT_REVIEWER = {"reviewer"}
AGENT_RESEARCHER = {"researcher"}
AGENT_EXPLORER = {"explorer"}
AGENT_SCRIBE = {"scribe"}


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _normalize_files(items: List[str]) -> List[str]:
    return sorted(set(filter(None, (item.strip() for item in items))))


def _hydrate_with_defaults(defaults: Dict[str, Any], loaded: Any) -> Any:
    if isinstance(defaults, dict):
        loaded_map = loaded if isinstance(loaded, dict) else {}
        merged: Dict[str, Any] = {}
        for key, default_value in defaults.items():
            merged[key] = _hydrate_with_defaults(default_value, loaded_map.get(key))
        for key, loaded_value in loaded_map.items():
            if key not in defaults:
                merged[key] = loaded_value
        return merged

    if isinstance(defaults, list):
        if isinstance(loaded, list):
            return loaded
        return list(defaults)

    if loaded is None:
        return defaults

    return loaded


def default_state() -> Dict[str, Any]:
    return {
        "active": False,
        "last_turn_id": None,
        "last_prompt_text": "",
        "updated_at": now_iso(),
        "turn": {
            "turn_id": None,
            "triggered": False,
            "implementation_oriented": False,
            "files_changed_at_start": [],
            "files_changed_current": [],
            "commit_requested": True,
            "files_changed_signature_at_start": [],
            "files_changed_signature_current": [],
            "event_seq": 0,
            "agents": {
                "coder_started": False,
                "coder_start_seq": None,
                "coder_stopped": False,
                "coder_last_seq": None,
                "coder_last_snapshot_signature": [],
                "coder_last_task_id": None,
                "coder_passes": [],
                "reviewer_stopped": False,
                "reviewer_stops": [],
                "researcher_started": False,
                "explorer_started": False,
                "scribe_started": False,
                "reviewer_last_seq": None,
                "reviewer_last_snapshot_signature": [],
                "reviewer_last_blocking": None,
                "blocking_reviewer_seq": None,
                "blocking_reviewer_snapshot_signature": [],
                "remediation_required_after_seq": None,
                "remediation_required_task_id": None,
                "remediation_coder_start_seq": None,
                "remediation_coder_last_seq": None,
                "remediation_coder_task_id": None,
                "main_agent_file_edit_detected": False,
                "main_agent_file_edit_events": [],
            },
            "current_task_id": None,
            "verification": {
                "run": False,
                "commands": [],
                "last_seq": None,
                "at": None,
                "snapshot": [],
                "snapshot_signature": [],
            },
            "commit": {
                "done": False,
                "commands": [],
                "last_seq": None,
                "at": None,
                "snapshot": [],
                "snapshot_signature": [],
                "snapshot_from_pre_tool": False,
            },
            "pending_commit": {
                "seq": None,
                "snapshot_signature": [],
            },
            "pre_tool_signature": {
                "seq": None,
                "signature": [],
                "coder_pass_open": False,
                "tool_name": "",
                "tool_may_edit_files": False,
                "actor": "",
                "at": None,
                "transcript_path": "",
                "command": "",
            },
            "tool_call_actors": {},
            "collaboration_spawn_evidence": [],
            "events": [],
        },
    }


def _load_state_no_lock() -> Dict[str, Any]:
    if not STATE_FILE.exists():
        return default_state()

    try:
        data = json.loads(STATE_FILE.read_text())
        if isinstance(data, dict):
            default = default_state()
            state = _hydrate_with_defaults(default, data)
            legacy_turn = data.get("turn", {})
            if isinstance(legacy_turn, dict) and "files_changed_at_start" not in legacy_turn:
                legacy_files = data.get("turn", {}).get("files_changed", [])
                if isinstance(legacy_files, list):
                    migrated_files = _normalize_files(legacy_files)
                    state["turn"]["files_changed_at_start"] = migrated_files
                    state["turn"]["files_changed_current"] = migrated_files
            if not isinstance(state["turn"]["files_changed_signature_at_start"], list):
                state["turn"]["files_changed_signature_at_start"] = []
            if not isinstance(state["turn"]["files_changed_signature_current"], list):
                state["turn"]["files_changed_signature_current"] = []
            if not isinstance(state["turn"]["agents"]["reviewer_last_snapshot_signature"], list):
                state["turn"]["agents"]["reviewer_last_snapshot_signature"] = []
            if not isinstance(state["turn"]["agents"].get("coder_last_snapshot_signature"), list):
                state["turn"]["agents"]["coder_last_snapshot_signature"] = []
            if not isinstance(state["turn"]["agents"].get("blocking_reviewer_snapshot_signature"), list):
                state["turn"]["agents"]["blocking_reviewer_snapshot_signature"] = []
            if not isinstance(state["turn"].get("current_task_id"), str):
                state["turn"]["current_task_id"] = None
            if not isinstance(state["turn"]["pending_commit"], dict):
                state["turn"]["pending_commit"] = default_state()["turn"]["pending_commit"]
                state["turn"]["pending_commit"]["seq"] = None
                state["turn"]["pending_commit"]["snapshot_signature"] = []
            if not isinstance(state["turn"].get("files_changed_current"), list):
                state["turn"]["files_changed_current"] = state["turn"]["files_changed_at_start"]
            if not isinstance(state["turn"]["agents"].get("coder_passes"), list):
                state["turn"]["agents"]["coder_passes"] = []
            if not isinstance(state["turn"]["agents"].get("main_agent_file_edit_detected"), bool):
                state["turn"]["agents"]["main_agent_file_edit_detected"] = False
            if not isinstance(state["turn"]["agents"].get("main_agent_file_edit_events"), list):
                state["turn"]["agents"]["main_agent_file_edit_events"] = []
            if not isinstance(state["turn"].get("pre_tool_signature"), dict):
                state["turn"]["pre_tool_signature"] = default_state()["turn"]["pre_tool_signature"]
            pre_tool_signature = state["turn"]["pre_tool_signature"]
            if not isinstance(pre_tool_signature.get("tool_may_edit_files"), bool):
                pre_tool_signature["tool_may_edit_files"] = False
            if not isinstance(pre_tool_signature.get("actor"), str):
                pre_tool_signature["actor"] = ""
            if not isinstance(pre_tool_signature.get("at"), str):
                pre_tool_signature["at"] = None
            if not isinstance(pre_tool_signature.get("transcript_path"), str):
                pre_tool_signature["transcript_path"] = ""
            if not isinstance(state["turn"].get("tool_call_actors"), dict):
                state["turn"]["tool_call_actors"] = {}
            return state
    except (OSError, json.JSONDecodeError):
        return default_state()
    return default_state()


def load_state() -> Dict[str, Any]:
    return _load_state_no_lock()


@contextlib.contextmanager
def _state_file_lock() -> Any:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    lock_path = STATE_DIR / ".state.lock"
    if fcntl is None:
        yield
        return

    lock_fd: int | None = None
    try:
        lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        yield
    finally:
        if lock_fd is not None:
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_UN)
            except OSError:
                pass
            try:
                os.close(lock_fd)
            except OSError:
                pass


def _save_state_no_lock(state: Dict[str, Any]) -> None:
    state["updated_at"] = now_iso()
    serialized_state = json.dumps(state, indent=2, sort_keys=True)
    fd, tmp_path = tempfile.mkstemp(prefix="state.", suffix=".json", dir=STATE_DIR)
    tmp_file = Path(tmp_path)
    os.close(fd)
    try:
        with tmp_file.open("w", encoding="utf-8") as handle:
            handle.write(serialized_state)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, STATE_FILE)
    except Exception:
        try:
            if tmp_file.exists():
                tmp_file.unlink()
        except OSError:
            pass
        raise


def save_state(state: Dict[str, Any], with_lock: bool = True) -> None:
    if with_lock:
        with _state_file_lock():
            _save_state_no_lock(state)
        return
    _save_state_no_lock(state)


def with_state(mutator: Callable[[Dict[str, Any]], None]) -> Dict[str, Any]:
    with _state_file_lock():
        state = _load_state_no_lock()
        mutator(state)
        _save_state_no_lock(state)
    return state


def update_state(mutator: Callable[[Dict[str, Any]], None]) -> Dict[str, Any]:
    return with_state(mutator)


def _collect_strings(data: Any, skip_keys: tuple[str, ...] = ()) -> List[str]:
    if isinstance(data, str):
        return [data]
    if isinstance(data, dict):
        out: List[str] = []
        for key, value in data.items():
            if key in skip_keys:
                continue
            out.extend(_collect_strings(value, skip_keys=skip_keys))
        return out
    if isinstance(data, list):
        out = []
        for item in data:
            out.extend(_collect_strings(item, skip_keys=skip_keys))
        return out
    return []


def _find_first_key_text(data: Any, keys: tuple[str, ...], skip_keys: tuple[str, ...] = ()) -> str:
    if isinstance(data, dict):
        for key in keys:
            value = data.get(key)
            if isinstance(value, str) and value.strip():
                return value
        for key, value in data.items():
            if key in skip_keys:
                continue
            found = _find_first_key_text(value, keys, skip_keys=skip_keys)
            if found:
                return found
        return ""
    if isinstance(data, list):
        for item in data:
            found = _find_first_key_text(item, keys, skip_keys=skip_keys)
            if found:
                return found
        return ""
    return ""


def extract_prompt_text(event: Dict[str, Any]) -> str:
    if not isinstance(event, dict):
        return ""

    prioritized = (
        "last_assistant_message",
        "prompt",
        "message",
        "text",
        "content",
        "summary",
        "result",
        "output",
        "query",
        "user_prompt",
        "input",
        "raw",
    )
    skip_agent_keys: tuple[str, ...] = ("agent_type", "type", "role", "name", "agent", "subagent")
    prioritized_text = _find_first_key_text(
        event,
        prioritized,
        skip_keys=skip_agent_keys,
    )
    if prioritized_text.strip():
        return prioritized_text

    # Fallback to all remaining string values, skipping common label-like keys that
    # can otherwise shadow real content (for example agent_type/name/role).
    for text in _collect_strings(
        event,
        skip_keys=skip_agent_keys,
    ):
        if isinstance(text, str) and text.strip():
            return text

    return ""


def extract_event_transcript_path(event: Dict[str, Any]) -> str:
    if not isinstance(event, dict):
        return ""

    agent_path = event.get("agent_transcript_path")
    if isinstance(agent_path, str) and agent_path.strip():
        return agent_path.strip()

    raw = event.get("raw")
    if isinstance(raw, dict):
        raw_agent_path = raw.get("agent_transcript_path")
        if isinstance(raw_agent_path, str) and raw_agent_path.strip():
            return raw_agent_path.strip()

        raw_path = str(raw.get("transcript_path", "")).strip()
        if raw_path:
            return raw_path

    direct_path = str(event.get("transcript_path", "")).strip()
    return direct_path


def _decode_possible_json(value: Any) -> Any:
    if not isinstance(value, str):
        return value

    stripped = value.strip()
    if not stripped:
        return ""

    if not (
        (stripped.startswith("{") and stripped.endswith("}"))
        or (stripped.startswith("[") and stripped.endswith("]"))
    ):
        return value

    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        return value


def _collect_prompt_texts(value: Any, depth: int = 4) -> list[str]:
    if depth <= 0:
        return []

    normalized = _decode_possible_json(value)
    if isinstance(normalized, str):
        normalized = normalized.strip()
        return [normalized] if normalized else []

    if isinstance(normalized, list):
        out: list[str] = []
        for item in normalized:
            out.extend(_collect_prompt_texts(item, depth - 1))
        return out

    if isinstance(normalized, dict):
        out: list[str] = []
        prioritized = ("message", "prompt", "input", "tool_input", "text", "content", "value", "command", "output")
        for key in prioritized:
            if key in normalized:
                out.extend(_collect_prompt_texts(normalized[key], depth - 1))

        for key, item in normalized.items():
            if key in prioritized:
                continue
            out.extend(_collect_prompt_texts(item, depth - 1))
        return out

    return []


TASK_ID_PATTERN = re.compile(
    r"(?im)\b(?:task\s*id|current\s+task|chunk\s+id)\s*:\s*([A-Za-z0-9][A-Za-z0-9._-]*)\b",
    re.IGNORECASE,
)


SUBAGENT_TASK_ID_PROMPT_LINE_PATTERN = re.compile(
    r"(?im)^\s*(?:[-*]\s*)?task\s*id\s*:\s*([A-Za-z0-9][A-Za-z0-9._-]*)\s*$",
    re.IGNORECASE,
)


def extract_task_ids_from_prompt_lines(text: str) -> list[str]:
    if not isinstance(text, str):
        return []
    ids: list[str] = []
    seen: set[str] = set()
    for value in SUBAGENT_TASK_ID_PROMPT_LINE_PATTERN.findall(text):
        normalized = str(value).strip()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        ids.append(normalized)
    return ids


def extract_task_ids(text: str) -> list[str]:
    if not isinstance(text, str):
        return []
    ids: list[str] = []
    seen: set[str] = set()
    for value in TASK_ID_PATTERN.findall(text):
        normalized = value.strip()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        ids.append(normalized)
    return ids


def extract_task_id(text: str) -> str | None:
    ids = extract_task_ids(text)
    if len(ids) == 1:
        return ids[0]
    return None


def _iter_transcript_records(path: str | Path) -> list[dict[str, Any]]:
    transcript = Path(path)
    if not transcript.exists():
        return []

    records: list[dict[str, Any]] = []
    try:
        with transcript.open("r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(record, dict):
                    records.append(record)
    except OSError:
        return []
    return records


def _normalize_prompt_signature(text: str) -> str:
    return " ".join((text or "").split()).strip().lower()


def _coerce_text_content(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        chunks: list[str] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            item_text = _coerce_text_content(item.get("text") if "text" in item else item.get("content"))
            if item_text:
                chunks.append(item_text)
        return "\n".join(chunks)
    return ""


def _iter_transcript_prompt_candidates(record: dict[str, Any]) -> list[str]:
    payload = record.get("payload") if isinstance(record, dict) else None
    if not isinstance(payload, dict):
        return []

    candidates: list[str] = []

    payload_type = str(payload.get("type", "")).lower()
    if payload_type == "message":
        role = str(payload.get("role", "")).lower()
        if role == "user":
            content = _coerce_text_content(payload.get("content"))
            if content:
                candidates.append(content)

    if payload_type == "user_message":
        message = payload.get("message")
        if isinstance(message, str) and message.strip():
            candidates.append(message)

    if payload_type in {"function_call", "custom_tool_call", "tool_call"}:
        for key in ("input", "arguments", "message", "prompt", "tool_input", "output", "content", "text"):
            for candidate in _collect_prompt_texts(payload.get(key)):
                if isinstance(candidate, str) and candidate.strip():
                    candidates.append(candidate)

    return candidates


def extract_first_internal_subagent_prompt_from_transcript(
    transcript_path: str | Path,
    agent: str | None = None,
) -> str:
    records = _iter_transcript_records(transcript_path)
    seen: set[str] = set()
    fallback: str = ""
    normalized_agent = normalize_agent(agent) if isinstance(agent, str) else ""

    for record in records:
        for candidate in _iter_transcript_prompt_candidates(record):
            normalized = _normalize_prompt_signature(candidate)
            if not normalized or normalized in seen:
                continue
            seen.add(normalized)

            sentinel = _extract_internal_sentinel(candidate)
            if sentinel:
                if normalized_agent:
                    if normalize_agent(sentinel) == normalized_agent:
                        return candidate
                    continue
                return candidate

            if not normalized_agent and not fallback:
                fallback = candidate

    return "" if normalized_agent else fallback


def _task_name_component(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    normalized = value.strip().strip("/")
    if not normalized:
        return ""
    return normalized.rsplit("/", 1)[-1]


def _normalize_task_name(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    normalized = value.strip()
    if not normalized or "/" in normalized or normalized in {".", ".."}:
        return ""
    return normalized


def _normalize_agent_path(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    normalized = value.strip()
    if not normalized.startswith("/"):
        return ""
    components = normalized.split("/")[1:]
    if not components or any(
        not component or component in {".", ".."}
        for component in components
    ):
        return ""
    return "/" + "/".join(components)


def extract_transcript_session_identity(
    transcript_path: str | Path,
) -> Dict[str, Any] | None:
    for record in _iter_transcript_records(transcript_path):
        if str(record.get("type", "")).lower() != "session_meta":
            continue
        payload = record.get("payload")
        if not isinstance(payload, dict):
            return None
        thread_id = payload.get("id")
        if not isinstance(thread_id, str) or not thread_id.strip():
            return None

        source = payload.get("source")
        thread_spawn = None
        if isinstance(source, dict):
            subagent = source.get("subagent")
            if isinstance(subagent, dict):
                candidate = subagent.get("thread_spawn")
                if isinstance(candidate, dict):
                    thread_spawn = candidate

        if thread_spawn is None:
            return {
                "thread_id": thread_id.strip(),
                "parent_thread_id": None,
                "depth": 0,
                "agent_path": "/root",
                "is_subagent": False,
            }

        parent_thread_id = thread_spawn.get("parent_thread_id")
        depth = thread_spawn.get("depth")
        agent_path = _normalize_agent_path(thread_spawn.get("agent_path"))
        agent_path_parts = agent_path.strip("/").split("/") if agent_path else []
        if (
            not isinstance(parent_thread_id, str)
            or not parent_thread_id.strip()
            or not isinstance(depth, int)
            or isinstance(depth, bool)
            or depth < 1
            or not agent_path
            or agent_path_parts[0] != "root"
            or len(agent_path_parts) - 1 != depth
        ):
            return None
        return {
            "thread_id": thread_id.strip(),
            "parent_thread_id": parent_thread_id.strip(),
            "depth": depth,
            "agent_path": agent_path,
            "is_subagent": True,
        }
    return None


def _has_subagent_thread_spawn_metadata(transcript_path: str | Path) -> bool:
    for record in _iter_transcript_records(transcript_path):
        if str(record.get("type", "")).lower() != "session_meta":
            continue
        payload = record.get("payload")
        if not isinstance(payload, dict):
            return False
        source = payload.get("source")
        if not isinstance(source, dict):
            return False
        subagent = source.get("subagent")
        return isinstance(subagent, dict) and "thread_spawn" in subagent
    return False


def _session_boundary_for_identity(
    coordinator_identity: Dict[str, Any],
    task_name: str,
) -> Dict[str, Any] | None:
    normalized_task_name = _normalize_task_name(task_name)
    coordinator_path = _normalize_agent_path(coordinator_identity.get("agent_path"))
    coordinator_thread_id = coordinator_identity.get("thread_id")
    coordinator_depth = coordinator_identity.get("depth")
    if (
        not normalized_task_name
        or not coordinator_path
        or not isinstance(coordinator_thread_id, str)
        or not isinstance(coordinator_depth, int)
        or isinstance(coordinator_depth, bool)
    ):
        return None
    return {
        "coordinator_thread_id": coordinator_thread_id,
        "coordinator_agent_path": coordinator_path,
        "coordinator_depth": coordinator_depth,
        "expected_agent_path": f"{coordinator_path}/{normalized_task_name}",
        "expected_child_depth": coordinator_depth + 1,
    }


def _is_exact_direct_child_session(
    coordinator_identity: Dict[str, Any],
    child_identity: Dict[str, Any],
    task_name: str,
) -> bool:
    boundary = _session_boundary_for_identity(coordinator_identity, task_name)
    if boundary is None:
        return False
    return bool(
        child_identity.get("is_subagent") is True
        and child_identity.get("parent_thread_id")
        == boundary["coordinator_thread_id"]
        and child_identity.get("depth") == boundary["expected_child_depth"]
        and child_identity.get("agent_path") == boundary["expected_agent_path"]
    )


def collaboration_spawn_session_boundary(
    coordinator_transcript_path: str | Path,
    task_name: str,
) -> Dict[str, Any] | None:
    normalized_task_name = _normalize_task_name(task_name)
    coordinator_identity = extract_transcript_session_identity(
        coordinator_transcript_path,
    )
    if not isinstance(coordinator_identity, dict):
        return None
    return _session_boundary_for_identity(coordinator_identity, normalized_task_name)


def _extract_matching_collaboration_spawn_prompt(
    coordinator_transcript_path: str | Path,
    child_identity: Dict[str, Any],
) -> str:
    coordinator_identity = extract_transcript_session_identity(
        coordinator_transcript_path,
    )
    expected_task_name = _task_name_component(child_identity.get("agent_path"))
    if not expected_task_name:
        return ""
    if not isinstance(coordinator_identity, dict) or not _is_exact_direct_child_session(
        coordinator_identity,
        child_identity,
        expected_task_name,
    ):
        return ""

    for record in _iter_transcript_records(coordinator_transcript_path):
        payload = record.get("payload")
        if not isinstance(payload, dict):
            continue
        if str(payload.get("type", "")).lower() not in {
            "function_call",
            "custom_tool_call",
            "tool_call",
        }:
            continue

        tool_name = str(payload.get("name", "")).strip().lower()
        namespace = str(payload.get("namespace", "")).strip().lower()
        is_collaboration_spawn = (
            tool_name == "spawn_agent" and namespace == "collaboration"
        ) or tool_name in {
            "collaboration.spawn_agent",
            "collaboration__spawn_agent",
        }
        if not is_collaboration_spawn:
            continue

        arguments = _decode_possible_json(
            payload.get("arguments", payload.get("input"))
        )
        if not isinstance(arguments, dict):
            continue
        if _normalize_task_name(arguments.get("task_name")) != expected_task_name:
            continue

        message = arguments.get("message")
        if not isinstance(message, str) or not _has_internal_sentinel_at_top(message):
            continue
        return message

    return ""


def extract_internal_subagent_prompt_from_transcript(
    transcript_path: str | Path,
    agent: str | None = None,
    coordinator_transcript_paths: Iterable[str | Path] = (),
) -> str:
    child_identity = extract_transcript_session_identity(
        transcript_path,
    )
    normalized_agent = normalize_agent(agent) if isinstance(agent, str) else ""
    if _has_subagent_thread_spawn_metadata(transcript_path):
        if not isinstance(child_identity, dict):
            return ""
        for coordinator_path in coordinator_transcript_paths:
            correlated_prompt = _extract_matching_collaboration_spawn_prompt(
                coordinator_path,
                child_identity,
            )
            if not correlated_prompt:
                continue
            sentinel = _extract_internal_sentinel(correlated_prompt)
            if normalized_agent and normalize_agent(sentinel or "") != normalized_agent:
                continue
            return correlated_prompt
        # A thread-spawn transcript may include the coordinator's forked history.
        # Without an exact trusted spawn match, scanning it would misattribute an
        # older subagent prompt to the current path.
        return ""

    direct_prompt = extract_first_internal_subagent_prompt_from_transcript(
        transcript_path,
        agent=agent,
    )
    if _extract_internal_sentinel(direct_prompt):
        return direct_prompt
    return ""


def extract_internal_subagent_identity(
    prompt_text: str,
) -> tuple[str | None, str | None, int]:
    if not _has_internal_sentinel_at_top(prompt_text):
        return None, None, 0
    sentinel = _extract_internal_sentinel(prompt_text)
    role = classify_agent({"agent": sentinel or ""})
    if role not in {"coder", "reviewer", "researcher", "explorer", "scribe"}:
        return None, None, 0

    task_ids = extract_task_ids_from_prompt_lines(prompt_text)
    task_id = task_ids[0] if len(task_ids) == 1 else None
    return role, task_id, len(task_ids)


_ENCODED_TASK_NAME_RE = re.compile(
    r"^(coder|reviewer|researcher|explorer|scribe)__"
    r"([a-z0-9]+(?:_[a-z0-9]+)*)"
    r"(?:__([a-z0-9]+(?:_[a-z0-9]+)*))?$"
)


def extract_encoded_task_name_identity(
    value: Any,
) -> tuple[str, str, int] | None:
    task_name = _normalize_task_name(value)
    if not task_name or len(task_name) > 100:
        return None
    match = _ENCODED_TASK_NAME_RE.fullmatch(task_name)
    if not match:
        return None
    return match.group(1), match.group(2), 1


def _iter_nested_event_mappings(
    value: Any,
    depth: int = 5,
) -> Iterable[Dict[str, Any]]:
    if depth <= 0:
        return
    decoded = _decode_possible_json(value)
    if isinstance(decoded, dict):
        yield decoded
        for key in (
            "tool_input",
            "input",
            "arguments",
            "args",
            "payload",
            "data",
            "request",
        ):
            if key in decoded:
                yield from _iter_nested_event_mappings(decoded[key], depth - 1)
    elif isinstance(decoded, list):
        for item in decoded:
            yield from _iter_nested_event_mappings(item, depth - 1)


def extract_completed_agent_paths(value: Any, depth: int = 6) -> set[str]:
    if depth <= 0:
        return set()
    decoded = _decode_possible_json(value)
    if isinstance(decoded, str):
        return set()
    if isinstance(decoded, list):
        completed: set[str] = set()
        for item in decoded:
            completed.update(extract_completed_agent_paths(item, depth - 1))
        return completed
    if not isinstance(decoded, dict):
        return set()

    agents = decoded.get("agents")
    if isinstance(agents, list):
        completed = set()
        for agent in agents[:100]:
            if not isinstance(agent, dict):
                continue
            status = agent.get("agent_status")
            if (
                not isinstance(status, dict)
                or "completed" not in status
                or not isinstance(status.get("completed"), str)
            ):
                continue
            agent_path = _normalize_agent_path(agent.get("agent_name"))
            if agent_path and len(agent_path) <= 512:
                completed.add(agent_path)
        return completed

    completed = set()
    for nested in decoded.values():
        completed.update(extract_completed_agent_paths(nested, depth - 1))
    return completed


def _is_collaboration_spawn_tool(name: Any, namespace: Any = "") -> bool:
    normalized_name = re.sub(
        r"[^a-z0-9]+",
        "_",
        str(name or "").strip().lower(),
    ).strip("_")
    normalized_namespace = re.sub(
        r"[^a-z0-9]+",
        "_",
        str(namespace or "").strip().lower(),
    ).strip("_")
    if normalized_name == "spawn_agent":
        return normalized_namespace in {"", "collaboration"}
    return normalized_name in {
        "collaborationspawn_agent",
        "collaboration_spawn_agent",
        "functionscollaborationspawn_agent",
        "functions_collaboration_spawn_agent",
        "mcpcollaborationspawn_agent",
        "mcp_collaboration_spawn_agent",
    }


def _collaboration_spawn_payload(
    event: Dict[str, Any],
) -> Dict[str, Any] | None:
    mappings = list(_iter_nested_event_mappings(event))
    if not any(
        _is_collaboration_spawn_tool(
            mapping.get("tool_name", mapping.get("tool", mapping.get("name", ""))),
            mapping.get("namespace", ""),
        )
        for mapping in mappings
    ):
        return None
    return next(
        (
            mapping
            for mapping in mappings
            if _normalize_task_name(mapping.get("task_name"))
        ),
        {},
    )


def _collaboration_spawn_message(spawn_payload: Dict[str, Any]) -> Any:
    for mapping in _iter_nested_event_mappings(spawn_payload):
        if "message" in mapping:
            return mapping.get("message")
    return None


def collaboration_spawn_diagnostics(event: Dict[str, Any]) -> Dict[str, Any]:
    if not isinstance(event, dict):
        return {}
    spawn_payload = _collaboration_spawn_payload(event)
    if spawn_payload is None:
        return {}

    message = _collaboration_spawn_message(spawn_payload)
    if isinstance(message, str) and _has_internal_sentinel_at_top(message):
        message_kind = "plaintext_sentinel"
    elif isinstance(message, str) and message:
        message_kind = "opaque_string"
    else:
        message_kind = "missing"
    return {
        "message_kind": message_kind,
        "task_name_present": bool(
            _normalize_task_name(spawn_payload.get("task_name"))
        ),
    }


def extract_collaboration_spawn_identity(
    event: Dict[str, Any],
) -> tuple[str, str | None, int, str] | None:
    if not isinstance(event, dict):
        return None
    spawn_payload = _collaboration_spawn_payload(event)
    if not spawn_payload:
        return None

    task_name = _normalize_task_name(spawn_payload.get("task_name"))
    if not task_name:
        return None
    encoded_identity = extract_encoded_task_name_identity(task_name)
    message = _collaboration_spawn_message(spawn_payload)
    if isinstance(message, str) and _has_internal_sentinel_at_top(message):
        role, task_id, task_id_count = extract_internal_subagent_identity(message)
        if role:
            if encoded_identity and encoded_identity != (
                role,
                task_id,
                task_id_count,
            ):
                return None
            return role, task_id, task_id_count, task_name

    if not encoded_identity:
        return None
    role, task_id, task_id_count = encoded_identity
    return role, task_id, task_id_count, task_name


def _identity_from_collaboration_spawn_evidence(
    transcript_path: str | Path,
    coordinator_transcript_paths: Iterable[str | Path],
    collaboration_spawn_evidence: Iterable[Dict[str, Any]],
) -> tuple[str | None, str | None, int]:
    child_identity = extract_transcript_session_identity(transcript_path)
    if not isinstance(child_identity, dict) or child_identity.get("is_subagent") is not True:
        return None, None, 0
    task_name = _task_name_component(child_identity.get("agent_path"))
    trusted_coordinator_paths = {
        str(path) for path in coordinator_transcript_paths if str(path).strip()
    }
    if not trusted_coordinator_paths:
        return None, None, 0

    records = list(collaboration_spawn_evidence)
    for evidence in reversed(records):
        if not isinstance(evidence, dict):
            continue
        if evidence.get("coordinator_transcript_path") not in trusted_coordinator_paths:
            continue
        if _normalize_task_name(evidence.get("task_name")) != task_name:
            continue
        coordinator_path = str(evidence.get("coordinator_transcript_path", ""))
        coordinator_identity = extract_transcript_session_identity(coordinator_path)
        if not isinstance(coordinator_identity, dict):
            continue
        if not _is_exact_direct_child_session(
            coordinator_identity,
            child_identity,
            task_name,
        ):
            continue
        boundary = collaboration_spawn_session_boundary(coordinator_path, task_name)
        if not isinstance(boundary, dict) or any(
            evidence.get(key) != value
            for key, value in boundary.items()
        ):
            continue
        role = str(evidence.get("role", ""))
        if role not in {"coder", "reviewer", "researcher", "explorer", "scribe"}:
            continue
        task_id_count = evidence.get("task_id_count")
        if not isinstance(task_id_count, int):
            task_id_count = 0
        task_id = evidence.get("task_id")
        if not isinstance(task_id, str) or task_id_count != 1:
            task_id = None
        return role, task_id, task_id_count
    return None, None, 0


def extract_task_id_from_subagent_transcript(
    transcript_path: str | Path,
    agent: str | None = None,
    coordinator_transcript_paths: Iterable[str | Path] = (),
    collaboration_spawn_evidence: Iterable[Dict[str, Any]] = (),
) -> tuple[str | None, int]:
    if not transcript_path:
        return None, 0

    prompt_text = extract_internal_subagent_prompt_from_transcript(
        transcript_path,
        agent=agent,
        coordinator_transcript_paths=coordinator_transcript_paths,
    )
    task_ids = extract_task_ids_from_prompt_lines(prompt_text)
    if not task_ids:
        evidence_role, task_id, task_id_count = _identity_from_collaboration_spawn_evidence(
            transcript_path,
            coordinator_transcript_paths,
            collaboration_spawn_evidence,
        )
        expected_role = classify_agent({"agent": agent or ""}) if agent else None
        if expected_role and evidence_role != expected_role:
            return None, 0
        return task_id, task_id_count

    if len(task_ids) == 1:
        return task_ids[0], 1
    return None, len(task_ids)


def _extract_exit_code_from_exec_output(output: str) -> int | None:
    if not isinstance(output, str):
        return None

    fail_match = re.search(
        r"exit[_ ]code[\"']?\s*[:=]\s*[\"']?(-?\d+)",
        output,
        flags=re.IGNORECASE,
    )
    if fail_match:
        return int(fail_match.group(1))

    if "exec_command failed" in output.lower():
        return 1

    success_match = re.search(r"Process exited with code\s*(-?\d+)", output, flags=re.IGNORECASE)
    if success_match:
        value = success_match.group(1)
        try:
            return int(value)
        except ValueError:
            return None

    if output.startswith("Command:"):
        return 0

    return None


def _extract_command_from_exec_arguments(arguments: Any) -> str:
    if isinstance(arguments, str):
        try:
            parsed = json.loads(arguments)
        except json.JSONDecodeError:
            return ""
    elif isinstance(arguments, dict):
        parsed = arguments
    else:
        return ""

    command = parsed.get("cmd")
    if not isinstance(command, str):
        return ""
    return command


def _extract_command_from_output(output: str) -> str:
    if not isinstance(output, str):
        return ""

    match = re.search(r"^Command:\s*(.+)$", output, flags=re.IGNORECASE | re.MULTILINE)
    if match:
        return match.group(1).strip()

    match = re.search(r"exec_command failed for `([^`]+)`", output, flags=re.IGNORECASE)
    if match:
        return match.group(1).strip()

    return ""


def _extract_call_id_from_output(output: str) -> str:
    if not isinstance(output, str):
        return ""

    match = re.search(r"(call_[A-Za-z0-9_]+)", output)
    return match.group(1) if match else ""


def recover_successful_exec_calls_from_transcript(transcript_path: str | Path) -> list[dict[str, Any]]:
    records = _iter_transcript_records(transcript_path)
    if not records:
        return []

    pending_by_call_id: dict[str, dict[str, Any]] = {}

    recovered: list[dict[str, Any]] = []
    for index, record in enumerate(records, start=1):
        payload = record.get("payload") if isinstance(record, dict) else None
        if not isinstance(payload, dict):
            continue

        event_type = str(payload.get("type", "")).lower()

        if event_type == "function_call" and payload.get("name") == "exec_command":
            command = _extract_command_from_exec_arguments(payload.get("arguments"))
            if not command:
                continue

            call_id = str(payload.get("call_id", "")).strip()
            if not call_id:
                continue

            record_data = {
                "seq": index,
                "call_id": call_id,
                "function_call_id": str(payload.get("id", "")).strip(),
                "command": command,
            }
            pending_by_call_id[call_id] = record_data
            continue

        if event_type != "function_call_output":
            continue

        output = str(payload.get("output", ""))
        if not output:
            continue

        exit_code = _extract_exit_code_from_exec_output(output)
        if exit_code != 0:
            continue

        output_call_id = str(payload.get("call_id", "")).strip()
        if not output_call_id:
            continue

        selected = None
        if output_call_id in pending_by_call_id:
            selected = pending_by_call_id.pop(output_call_id)

        if not selected:
            continue

        command = _extract_command_from_output(output)
        if not command:
            command = str(selected.get("command", "")).strip()
        if not command:
            continue

        recovered.append(
            {
                "seq": int(selected.get("seq", 0)),
                "command": command,
                "exit_code": exit_code,
                "transcript_seq": index,
            }
        )

    return recovered



INTERNAL_SUBAGENT_PROMPT_SENTINEL_MARKER = re.compile(
    r"(?im)^\s*Codex-Orchestrator-Internal-Subagent:\s*([A-Za-z0-9._-]+)\s*$"
)


def _metadata_is_internal(event: Dict[str, Any]) -> bool:
    metadata = event.get("metadata")
    if not isinstance(metadata, dict):
        return False

    keys = (
        metadata.get("agent_type"),
        metadata.get("agent"),
        metadata.get("role"),
        metadata.get("name"),
        metadata.get("subagent"),
        metadata.get("source"),
        metadata.get("intent"),
    )
    for value in keys:
        if not isinstance(value, str):
            continue
        normalized = normalize_agent(value)
        if (
            normalized in AGENT_CODER
            or normalized in AGENT_REVIEWER
            or normalized in AGENT_RESEARCHER
            or normalized in AGENT_EXPLORER
            or normalized in AGENT_SCRIBE
            or "subagent" in normalized
            or "coordinator" in normalized
            or "reviewer" in normalized
            or "coder" in normalized
        ):
            return True

    if metadata.get("is_internal_prompt") is True:
        return True
    return False


def _extract_internal_sentinel(text: str) -> str | None:
    match = INTERNAL_SUBAGENT_PROMPT_SENTINEL_MARKER.search(text or "")
    return match.group(1).strip() if match else None


def infer_internal_subagent_role_from_transcript(
    transcript_path: str | Path,
    coordinator_transcript_paths: Iterable[str | Path] = (),
    collaboration_spawn_evidence: Iterable[Dict[str, Any]] = (),
) -> str | None:
    """Return the canonical role named by a transcript's first internal sentinel."""
    if not transcript_path:
        return None

    prompt_text = extract_internal_subagent_prompt_from_transcript(
        transcript_path,
        coordinator_transcript_paths=coordinator_transcript_paths,
    )
    sentinel = _extract_internal_sentinel(prompt_text)
    if not sentinel:
        role, _, _ = _identity_from_collaboration_spawn_evidence(
            transcript_path,
            coordinator_transcript_paths,
            collaboration_spawn_evidence,
        )
        return role

    role = classify_agent({"agent": sentinel})
    if role not in {"coder", "reviewer", "researcher", "explorer", "scribe"}:
        return None
    return role


def _has_internal_sentinel_at_top(text: str) -> bool:
    for line in (text or "").splitlines():
        if not line.strip():
            continue
        return bool(INTERNAL_SUBAGENT_PROMPT_SENTINEL_MARKER.match(line))
    return False


def is_internal_subagent_prompt(event: Dict[str, Any], text: str) -> bool:
    if not isinstance(event, dict):
        return False
    if _metadata_is_internal(event):
        return True

    if classify_agent(event) in {"coder", "reviewer", "researcher", "explorer", "scribe"}:
        return True

    if not _has_internal_sentinel_at_top(text):
        return False

    return _extract_internal_sentinel(text) is not None


def _contains_any(text: str, patterns: List[str]) -> bool:
    lowered = text.lower()
    return any(re.search(pattern, lowered, flags=re.IGNORECASE) for pattern in patterns)


def is_orchestrator_trigger(text: str) -> bool:
    return _contains_any(text, TRIGGER_PATTERNS)


NON_IMPLEMENT_EXPLICIT_PATTERNS = [
    r"\bdon't implement\b",
    r"\bdont implement\b",
    r"\bdo not implement\b",
]

READ_ONLY_PATTERNS = [
    r"\bjust check\b",
    r"\bcheck only\b",
    r"\bonly inspect\b",
    r"\binspect only\b",
    r"\bjust inspect\b",
    r"\bonly analyze\b",
    r"\bjust analyze\b",
    r"\bdo\s+not\s+edit\b",
    r"\bdo\s+not\s+modify\b",
    r"\bdo\s+not\s+change\b",
    r"\bdo\s+not\s+make\s+changes\b",
    r"\bdon't\s+edit\b",
    r"\bdon't\s+modify\b",
    r"\bread[-\s]*only\b",
    r"\breview\s+only\b",
    r"\banalyze\s+only\b",
    r"\bno\s+edits?\b",
    r"\bno\s+changes?\b",
]

READ_ONLY_NOUN_PATTERNS = [
    r"\b(?:the|a|this|that|latest|current|recent)\s+change(?:s)?\b",
    r"\b(?:the|a|this|that|latest|current|recent)\s+update(?:s)?\b",
    r"\b(?:the|a|this|that|latest|current|recent)\s+diff(?:s)?\b",
    r"\b(?:the|a|this|that|latest|current|recent)\s+patch(?:es)?\b",
    r"\b(?:the|a|this|that|latest|current|recent)\s+code\b",
    r"\bthe\s+plan\s+update\b",
]

REVIEW_REQUEST_PATTERNS = [
    r"\breview\s+this\s+change\b",
    r"\breview\s+the\s+change\b",
    r"\breview\s+this\s+changes\b",
    r"\breview\s+this\s+diff\b",
    r"\breview\s+this\s+patch\b",
    r"\breview\s+this\s+code\b",
    r"\breview\s+my\s+changes\b",
    r"\breview\s+my\s+change\b",
    r"\breview\s+my\s+diff\b",
    r"\breview\s+my\s+patch\b",
    r"\breview\s+my\s+code\b",
    r"\breview\s+this\s+update\b",
    r"\breview\s+the\s+update\s+only\b",
    r"\breview\s+the\s+latest\s+update\b",
    r"\breview\s+current\s+update\b",
    r"\breview\s+the\s+latest\s+changes\b",
    r"\breview\s+the\s+current\s+changes\b",
    r"\breview\s+current\s+changes\b",
    r"\breview\s+latest\s+changes\b",
    r"\breview\s+changes\b",
    r"\breview\s+recent\s+changes\b",
    r"\breview\s+that\s+change\b",
    r"\breview\s+that\s+changes\b",
    r"\breview\s+that\s+diff\b",
    r"\breview\s+that\s+patch\b",
    r"\breview\s+that\s+code\b",
    r"\breview\s+(?:this|that)\s+pull\s+request\b",
    r"\breview\s+(?:this|that)\s+pr\b",
    r"\b(?:orchestrator\s+)?(?:reviewer|explorer|researcher|scribe)\b[^.!?\n]{0,80}\b(?:review|inspect|check|analyz(?:e|ed|ing)|evaluate)\b[^.!?\n]{0,80}\b(?:this|that|the|latest|current|recent)?\s*(?:change|changes|diff|patch|update|code)\b",
]


IMPLEMENT_VERB_TOKENS = {
    "implement",
    "implementing",
    "build",
    "create",
    "add",
    "update",
    "modify",
    "change",
    "fix",
    "edit",
    "remove",
    "delete",
    "refactor",
    "wire",
    "wired",
    "adjust",
}


def _classifier_tokens(text: str) -> List[str]:
    return re.findall(r"[a-z']+", text.lower())


def _is_negated_implementation_token(tokens: List[str], index: int) -> bool:
    if index == 0:
        return False
    prev = tokens[index - 1]
    if prev in {"don't", "dont"}:
        return True
    if prev == "not" and index >= 2 and tokens[index - 2] == "do":
        return True
    return False


def _has_positive_implementation(text: str) -> bool:
    tokens = _classifier_tokens(text)
    return any(
        token in IMPLEMENT_VERB_TOKENS and not _is_negated_implementation_token(tokens, index)
        for index, token in enumerate(tokens)
    )


def _strip_review_request_phrases(text: str) -> str:
    stripped = text
    for pattern in REVIEW_REQUEST_PATTERNS:
        stripped = re.sub(pattern, " ", stripped, flags=re.IGNORECASE)
    return stripped


def _strip_patterns(text: str, patterns: list[str]) -> str:
    stripped = text
    for pattern in patterns:
        stripped = re.sub(pattern, " ", stripped, flags=re.IGNORECASE)
    return stripped


def _strip_non_implementation_intent(text: str) -> str:
    stripped = _strip_review_request_phrases(text)
    stripped = _strip_patterns(stripped, PLAN_ONLY_PATTERNS)
    stripped = _strip_patterns(stripped, READ_ONLY_PATTERNS)
    stripped = _strip_patterns(stripped, READ_ONLY_NOUN_PATTERNS)
    return stripped


def is_implementation_oriented(text: str) -> bool:
    lowered = text.lower()
    implementation_probe = _strip_non_implementation_intent(lowered)
    has_implementation = _has_positive_implementation(implementation_probe)

    if has_implementation:
        return True
    if _contains_any(lowered, PLAN_ONLY_PATTERNS):
        return False
    if _contains_any(lowered, NON_IMPLEMENT_EXPLICIT_PATTERNS):
        return False
    if _contains_any(lowered, REVIEW_REQUEST_PATTERNS):
        return False
    if _contains_any(lowered, READ_ONLY_PATTERNS):
        return False
    return False


def is_commit_requested(text: str) -> bool:
    return not _contains_any(text, NO_COMMIT_PATTERNS)


def normalize_agent(raw: str) -> str:
    return re.sub(r"[^a-z]+", "", raw.lower())


def classify_agent(event: Dict[str, Any]) -> str:
    if not isinstance(event, dict):
        return "other"

    def candidate_values() -> List[Any]:
        values: List[Any] = []
        for key in ("agent_type", "type", "role", "name", "agent", "subagent"):
            values.append(event.get(key))
        metadata = event.get("metadata")
        if isinstance(metadata, dict):
            for key in ("agent_type", "type", "role", "name", "agent"):
                values.append(metadata.get(key))
        return values

    for value in candidate_values():
        if not isinstance(value, str):
            continue
        normalized = normalize_agent(value)
        if normalized in AGENT_CODER:
            return "coder"
        if normalized in AGENT_REVIEWER:
            return "reviewer"
        if normalized in AGENT_RESEARCHER:
            return "researcher"
        if normalized in AGENT_EXPLORER:
            return "explorer"
        if normalized in AGENT_SCRIBE:
            return "scribe"
        if normalized == "worker":
            return "coder"
    return "other"


def hash_turn_id(text: str) -> str:
    normalized = text.strip().lower()
    return hashlib.sha1(normalized.encode("utf-8")).hexdigest()[:12] if normalized else "manual"


def git_changed_files() -> List[str]:
    return sorted(set(record["path"] for record in _iter_git_changed_records() if record.get("path")))


def _sha256_for_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def _is_deleted_status(status: str) -> bool:
    return "D" in status


def _iter_git_changed_records() -> List[dict[str, str]]:
    try:
        output = subprocess.check_output(
            ["git", "-C", str(ROOT), "status", "--short", "--untracked-files=all"],
            text=True,
            stderr=subprocess.STDOUT,
        ).splitlines()
    except (OSError, subprocess.CalledProcessError, subprocess.SubprocessError):
        return []

    ignore_prefixes = (
        ".codex/.orchestrator-state/",
    )
    records: List[dict[str, str]] = []
    for line in output:
        if len(line) < 4:
            continue
        status = (line[:2] or "").replace(" ", "_")
        path = line[3:].strip()
        if not path or any(path.startswith(prefix) for prefix in ignore_prefixes):
            continue
        if " -> " in path:
            _, path = path.rsplit(" -> ", 1)
            path = path.strip()

        target = ROOT.joinpath(path)
        if _is_deleted_status(status):
            fingerprint = "DELETED"
        else:
            try:
                fingerprint = _sha256_for_file(target)
            except OSError:
                fingerprint = "MISSING"

        records.append(
            {
                "path": path,
                "status": status,
                "signature": f"{status}|{path}|{fingerprint}",
            }
        )

    return sorted(records, key=lambda item: str(item["path"]).lower())


def git_changed_file_signatures() -> List[str]:
    return [record["signature"] for record in _iter_git_changed_records()]


def _signature_content_key(signature: str) -> str | None:
    if not isinstance(signature, str):
        return None
    parts = signature.split("|", 2)
    if len(parts) != 3:
        return None
    return f"{parts[1]}|{parts[2]}"


def signatures_match(a: List[str], b: List[str]) -> bool:
    return {sig for sig in (_signature_content_key(entry) for entry in a) if sig is not None} == {
        sig for sig in (_signature_content_key(entry) for entry in b) if sig is not None
    }


def signatures_changed(a: List[str], b: List[str]) -> bool:
    return not signatures_match(a, b)


def signature_paths(signatures: List[str]) -> List[str]:
    return _normalize_files(
        [entry.split("|", 2)[1] for entry in signatures if isinstance(entry, str) and len(entry.split("|", 2)) == 3]
    )


def command_match_verification(command: str) -> bool:
    if not isinstance(command, str):
        return False

    lowered = command.lower()
    for command_parts in _iter_command_segment_parts(lowered):
        if not command_parts:
            continue

        for command_line_parts in _split_command_parts_by_newline(command_parts):
            if not command_line_parts:
                continue

            command_name = command_line_parts[0].lower()
            arguments = [part.lower() for part in command_line_parts[1:]]

            if command_name == "flutter":
                if arguments and arguments[0] in _VERIFICATION_FLUTTER_COMMANDS:
                    return True

            if command_name in {"python", "python3"}:
                for idx, argument in enumerate(arguments):
                    if argument != "-m" or idx + 1 >= len(arguments):
                        continue
                    if arguments[idx + 1] in _VERIFICATION_PYTHON_MODULES:
                        return True

            if command_name in {"dart"}:
                if arguments and arguments[0] in _VERIFICATION_DART_COMMANDS:
                    return True

    return False


_MUTATING_TOOL_NAMES = {
    "apply_patch",
    "applypatch",
}


_MUTATING_BASH_COMMANDS = {
    "chmod",
    "chown",
    "cp",
    "install",
    "ln",
    "mkdir",
    "mv",
    "rm",
    "rmdir",
    "sed",
    "python",
    "python3",
    "tee",
    "touch",
    "perl",
    "git",
    "dart",
    "flutter",
}

_SHELL_WRAPPERS = {
    "bash",
    "sh",
}


_MUTATING_GIT_SUBCOMMANDS = {
    "add",
    "apply",
    "cherry-pick",
    "commit",
    "checkout",
    "mv",
    "restore",
    "rm",
    "revert",
    "reset",
    "switch",
    "tag",
}

_GIT_GLOBAL_OPTIONS_WITH_VALUE = {
    "-c",
    "-C",
    "--config",
    "--config-env",
    "--exec-path",
    "--git-dir",
    "--namespace",
    "--super-prefix",
    "--work-tree",
}


_WRITE_REDIRECTION_PATTERN = re.compile(
    r"(^|[ \t])(?:[0-9]{0,2}>>?(?!&)|&>>?)(?=\s|$)",
    re.IGNORECASE,
)


def _tool_name_is_mutating(tool_name: str) -> bool:
    normalized = (tool_name or "").strip().lower()
    return normalized in _MUTATING_TOOL_NAMES


def _tokenize_command(command: str) -> List[str]:
    stripped = command.strip()
    if not stripped:
        return []
    try:
        import shlex

        lexer = shlex.shlex(stripped, posix=True, punctuation_chars="&|;")
        lexer.whitespace_split = True
        lexer.commenters = ""
        return list(lexer)
    except (ValueError, TypeError):
        return stripped.split()


def _segment_tokens() -> set[str]:
    return {"&&", "||", ";", "|"}


def _iter_command_segments(command: str) -> list[list[str]]:
    tokens = _tokenize_command(command)
    if not tokens:
        return []

    segments: list[list[str]] = []
    current: list[str] = []
    for token in tokens:
        if token in _segment_tokens():
            if current:
                segments.append(current)
                current = []
            continue
        current.append(token)
    if current:
        segments.append(current)
    return segments


def _iter_command_segment_parts(command: str) -> list[list[str]]:
    expanded: list[list[str]] = []
    for segment_parts in _iter_command_segments(command):
        parts = _strip_command_prefix_wrappers(segment_parts)
        if not parts:
            continue

        wrapped = _extract_wrapped_command(parts)
        if wrapped is None:
            expanded.append(parts)
            continue
        if "\n" in wrapped:
            for wrapped_line in wrapped.splitlines():
                wrapped_line = wrapped_line.strip()
                if not wrapped_line:
                    continue
                expanded.extend(_iter_command_segment_parts(wrapped_line))
            continue

        expanded.extend(_iter_command_segment_parts(wrapped))

    return expanded


def _split_command_parts_by_newline(parts: list[str]) -> list[list[str]]:
    if not parts:
        return []

    merged = " ".join(parts)
    if "\n" not in merged:
        return [parts]

    out: list[list[str]] = []
    for line in merged.splitlines():
        line = line.strip()
        if not line:
            continue
        tokens = _tokenize_command(line)
        if tokens:
            out.append(tokens)
    return out


def _strip_command_prefix_wrappers(parts: List[str]) -> List[str]:
    if not parts:
        return []

    trimmed = list(parts)
    while trimmed:
        token = trimmed[0]
        lowered = token.lower()
        if lowered in {"sudo", "command", "env", "time", "nohup"}:
            trimmed = trimmed[1:]
            continue
        if "=" in token and not token.startswith("-") and not token.startswith("'") and not token.startswith('"'):
            trimmed = trimmed[1:]
            continue
        break
    return trimmed


def _extract_wrapped_command(parts: List[str]) -> str | None:
    if not parts:
        return None

    command_name = (parts[0] or "").lower()
    if command_name not in _SHELL_WRAPPERS:
        return None

    args = [part for part in parts[1:] if part]
    for idx, arg in enumerate(args):
        lowered = arg.lower()
        if lowered == "-c" and idx + 1 < len(args):
            return args[idx + 1]
        if lowered.startswith("-") and not lowered.startswith("--") and "c" in lowered[1:] and idx + 1 < len(args):
            # e.g. -lc, -cx, -cfoo
            return args[idx + 1]
    return None


def tool_may_edit_files(tool_name: str, command: str) -> bool:
    if _tool_name_is_mutating(tool_name):
        return True

    command = (command or "").strip()
    if not command:
        return False

    lowered = command.lower()
    if _WRITE_REDIRECTION_PATTERN.search(lowered):
        return True

    segments = re.split(r"\s*(?:&&|\|\||;|\n)\s*", command)
    for segment in segments:
        segment = segment.strip()
        if not segment:
            continue

        for pipeline_chunk in segment.split("|"):
            chunk = pipeline_chunk.strip()
            if not chunk:
                continue
            parts = _tokenize_command(chunk)
            parts = _strip_command_prefix_wrappers(parts)
            if not parts:
                continue
            command_name = parts[0].lower()
            arguments = [part.lower() for part in parts[1:]]

            wrapped = _extract_wrapped_command(parts)
            if wrapped is not None:
                return tool_may_edit_files(tool_name, wrapped)

            if command_name not in _MUTATING_BASH_COMMANDS:
                continue

            if command_name == "sed":
                if any(arg.startswith("-i") for arg in arguments):
                    return True
                continue

            if command_name == "perl":
                if any(arg.startswith("-i") for arg in arguments):
                    return True
                if any(arg == "-0777" for arg in arguments):
                    continue
                return False

            if command_name == "git":
                if arguments and arguments[0] in _MUTATING_GIT_SUBCOMMANDS:
                    return True
                continue

            if command_name in {"dart", "flutter"}:
                if arguments and arguments[0] == "format":
                    return True
                continue

            if command_name in {"cp", "mv", "rm", "rmdir", "mkdir", "touch", "chmod", "chown", "ln", "install", "tee"}:
                return True

            if command_name in {"python", "python3"}:
                return any(argument == "-c" for argument in arguments)

            return True

    return False


def command_is_commit(command: str) -> bool:
    lowered = (command or "").strip().lower()
    if not lowered:
        return False

    for command_parts in _iter_command_segment_parts(lowered):
        if not command_parts:
            continue

        for command_line_parts in _split_command_parts_by_newline(command_parts):
            if not command_line_parts:
                continue

            command_name = command_line_parts[0].lower()
            if command_name != "git":
                continue

            arguments = command_line_parts[1:]
            if not arguments:
                continue

            idx = 0
            while idx < len(arguments):
                argument = arguments[idx]
                if argument == "--":
                    idx += 1
                    break

                if argument.startswith("--"):
                    base, _, value = argument.partition("=")
                    if base in _GIT_GLOBAL_OPTIONS_WITH_VALUE:
                        idx += 1 if value else 2
                        continue
                    idx += 1
                    continue

                if argument in {"-c", "-C"}:
                    idx += 2
                    continue

                if argument.startswith("-c") or argument.startswith("-C"):
                    idx += 1
                    continue

                break

            if idx < len(arguments) and arguments[idx] == "commit":
                return True

    return False


def _coerce_explicit_exit_code(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, str):
        stripped = value.strip()
        if re.fullmatch(r"-?\d+", stripped):
            return int(stripped)
        return _extract_exit_code_from_exec_output(stripped)
    return None


def _extract_tool_response_exit_codes(value: Any) -> list[int]:
    if isinstance(value, str):
        code = _extract_exit_code_from_exec_output(value)
        return [code] if code is not None else []

    if isinstance(value, list):
        codes: list[int] = []
        for item in value:
            codes.extend(_extract_tool_response_exit_codes(item))
        return codes

    if not isinstance(value, dict):
        return []

    codes = []
    for key, item in value.items():
        if str(key).lower() in {"exit_code", "exitcode", "code", "status"}:
            code = _coerce_explicit_exit_code(item)
            if code is not None:
                codes.append(code)
        codes.extend(_extract_tool_response_exit_codes(item))

    if value.get("ok") is False:
        codes.append(1)
    return codes


def parse_tool_exit_code(event: Dict[str, Any]) -> int:
    tool_response = event.get("tool_response") if isinstance(event, dict) else None
    codes = _extract_tool_response_exit_codes(tool_response)
    for code in codes:
        if code != 0:
            return code
    return codes[0] if codes else 0


def new_turn(text: str) -> Dict[str, Any]:
    turn = default_state()["turn"]
    turn["turn_id"] = hash_turn_id(text)
    turn["triggered"] = is_orchestrator_trigger(text)
    turn["implementation_oriented"] = is_implementation_oriented(text)
    turn["commit_requested"] = is_commit_requested(text)
    baseline_signature = git_changed_file_signatures()
    turn["files_changed_at_start"] = git_changed_files()
    turn["files_changed_signature_at_start"] = baseline_signature
    turn["files_changed_signature_current"] = baseline_signature
    turn["files_changed_current"] = turn["files_changed_at_start"]
    return turn


def append_event(state: Dict[str, Any], event_name: str, details: Dict[str, Any] | None = None) -> int:
    state["turn"]["event_seq"] = int(state["turn"].get("event_seq", 0)) + 1
    seq = state["turn"]["event_seq"]
    event = {
        "at": now_iso(),
        "seq": seq,
        "event": event_name,
        "details": details or {},
    }
    state["turn"]["events"].append(event)
    # Keep a short bounded trace.
    state["turn"]["events"] = state["turn"]["events"][-25:]
    return seq


def changed_files_delta(baseline: List[str], current: List[str]) -> List[str]:
    return _normalize_files(list(set(current) ^ set(baseline)))


def changed_signatures_delta(baseline: List[str], current: List[str]) -> List[str]:
    baseline_by_key: dict[str, str] = {}
    for signature in baseline:
        key = _signature_content_key(signature)
        if key is None:
            continue
        baseline_by_key[key] = signature

    current_by_key: dict[str, str] = {}
    for signature in current:
        key = _signature_content_key(signature)
        if key is None:
            continue
        current_by_key[key] = signature

    delta_keys = set(baseline_by_key.keys()) ^ set(current_by_key.keys())
    delta: List[str] = []
    for key in sorted(delta_keys):
        if key in current_by_key:
            delta.append(current_by_key[key])
        elif key in baseline_by_key:
            delta.append(baseline_by_key[key])
    return _normalize_files(delta)
