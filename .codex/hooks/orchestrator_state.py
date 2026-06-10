from __future__ import annotations

import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


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
    r"\bmake\s+a?\s+plan\b",
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
                "reviewer_stopped": False,
                "reviewer_stops": [],
                "researcher_started": False,
                "explorer_started": False,
                "scribe_started": False,
                "reviewer_last_seq": None,
                "reviewer_last_snapshot_signature": [],
                "reviewer_last_blocking": None,
            },
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
            "events": [],
        },
    }


def load_state() -> Dict[str, Any]:
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
            if not isinstance(state["turn"]["pending_commit"], dict):
                state["turn"]["pending_commit"] = default_state()["turn"]["pending_commit"]
                state["turn"]["pending_commit"]["seq"] = None
                state["turn"]["pending_commit"]["snapshot_signature"] = []
            if not isinstance(state["turn"].get("files_changed_current"), list):
                state["turn"]["files_changed_current"] = state["turn"]["files_changed_at_start"]
            return state
    except (OSError, json.JSONDecodeError):
        return default_state()
    return default_state()


def save_state(state: Dict[str, Any]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state["updated_at"] = now_iso()
    STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True))


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


def _contains_any(text: str, patterns: List[str]) -> bool:
    lowered = text.lower()
    return any(re.search(pattern, lowered, flags=re.IGNORECASE) for pattern in patterns)


def is_orchestrator_trigger(text: str) -> bool:
    return _contains_any(text, TRIGGER_PATTERNS)


READ_ONLY_PATTERNS = [
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


def is_implementation_oriented(text: str) -> bool:
    lowered = text.lower()
    if _contains_any(lowered, READ_ONLY_PATTERNS) or _contains_any(lowered, PLAN_ONLY_PATTERNS):
        return False
    return any(re.search(pattern, lowered, flags=re.IGNORECASE) for pattern in IMPLEMENT_PATTERNS)


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


def signatures_match(a: List[str], b: List[str]) -> bool:
    return sorted(a) == sorted(b)


def signatures_changed(a: List[str], b: List[str]) -> bool:
    return not signatures_match(a, b)


def signature_paths(signatures: List[str]) -> List[str]:
    return _normalize_files(
        [entry.split("|", 2)[1] for entry in signatures if isinstance(entry, str) and len(entry.split("|", 2)) == 3]
    )


def command_match_verification(command: str) -> bool:
    lowered = command.lower()
    return any(pattern.search(lowered) for pattern in VERIFICATION_PATTERNS)


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
    return _normalize_files(list(set(current) ^ set(baseline)))
