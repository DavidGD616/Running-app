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
from typing import Any, Callable, Dict, List

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
    re.compile(r"\bdart\s+test\b"),
]

AGENT_CODER = {"coder", "implementation", "worker"}
AGENT_REVIEWER = {"reviewer"}
AGENT_RESEARCHER = {"researcher"}
AGENT_EXPLORER = {"explorer"}
AGENT_SCRIBE = {"scribe"}


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _normalize_files(items: List[str]) -> List[str]:
    return sorted(set(filter(None, (item.strip() for item in items))))


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
                "command": "",
            },
            "events": [],
        },
    }


def _load_state_no_lock() -> Dict[str, Any]:
    if not STATE_FILE.exists():
        return default_state()

    try:
        data = json.loads(STATE_FILE.read_text())
        if isinstance(data, dict):
            # Ensure expected keys exist after upgrades.
            state = default_state()
            state.update(data)
            state["turn"] = {**state["turn"], **data.get("turn", {})}
            state["turn"]["agents"] = {**state["turn"]["agents"], **data.get("turn", {}).get("agents", {})}
            state["turn"]["verification"] = {
                **state["turn"]["verification"],
                **data.get("turn", {}).get("verification", {}),
            }
            state["turn"]["commit"] = {**state["turn"]["commit"], **data.get("turn", {}).get("commit", {})}
            state["turn"]["pending_commit"] = {**state["turn"]["pending_commit"], **data.get("turn", {}).get("pending_commit", {})}
            if "files_changed_at_start" not in data.get("turn", {}):
                legacy_files = data.get("turn", {}).get("files_changed", [])
                if isinstance(legacy_files, list):
                    state["turn"]["files_changed_at_start"] = _normalize_files(legacy_files)
                    state["turn"]["files_changed_current"] = _normalize_files(legacy_files)
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


TASK_ID_PATTERN = re.compile(
    r"(?im)\b(?:task\s*id|current\s+task|chunk\s+id)\s*:\s*([A-Za-z0-9][A-Za-z0-9._-]*)\b",
    re.IGNORECASE,
)


def extract_task_id(text: str) -> str | None:
    match = TASK_ID_PATTERN.search(text or "")
    if not match:
        return None
    return match.group(1).strip()


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
    lowered = command.lower()
    return any(pattern.search(lowered) for pattern in VERIFICATION_PATTERNS)


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

        return shlex.split(stripped)
    except (ValueError, TypeError):
        return stripped.split()


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
    return re.search(r"\bgit\s+commit\b", command.lower()) is not None


def parse_tool_exit_code(event: Dict[str, Any]) -> int:
    tool_response = event.get("tool_response") if isinstance(event, dict) else None
    if not isinstance(tool_response, dict):
        return 0
    for key in ("exit_code", "code", "status"):
        value = tool_response.get(key)
        if value is None:
            continue
        try:
            return int(value)
        except (TypeError, ValueError):
            continue
    if tool_response.get("ok") is True:
        return 0
    return 0


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
