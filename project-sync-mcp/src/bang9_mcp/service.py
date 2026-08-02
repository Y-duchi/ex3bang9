from __future__ import annotations

import csv
import json
import os
import re
import subprocess
import tempfile
from collections.abc import Iterable
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any


PACKAGE_ROOT = Path(__file__).resolve().parents[2]
PRIVATE_DATA_DIR = PACKAGE_ROOT / "data"
EXAMPLE_DATA_DIR = PACKAGE_ROOT / "examples"

# Existing users keep their ignored local records. A fresh public clone starts
# with anonymized examples, so real team names and meeting notes are never
# required for the MCP server to run.
DEFAULT_DATA_DIR = (
    PRIVATE_DATA_DIR
    if (PRIVATE_DATA_DIR / "wbs.csv").exists()
    else EXAMPLE_DATA_DIR
)
WBS_FIELDS = [
    "id",
    "category",
    "task",
    "owner",
    "status",
    "start_date",
    "due_date",
    "progress",
    "blocker",
    "last_updated",
    "priority",
    "source_ref",
]
MEETING_FIELDS = [
    "meeting_id",
    "meeting_date",
    "title",
    "summary",
    "decision_count",
    "action_count",
    "source_path",
    "created_at",
    "recorded_by",
]
ACTION_FIELDS = [
    "action_id",
    "meeting_id",
    "task",
    "owner",
    "due_date",
    "category",
    "priority",
    "status",
    "wbs_task_id",
    "note",
]
VALID_STATUSES = {"예정", "진행중", "완료", "보류"}
STATUS_ALIASES = {
    "todo": "예정",
    "planned": "예정",
    "예정": "예정",
    "doing": "진행중",
    "in_progress": "진행중",
    "진행": "진행중",
    "진행중": "진행중",
    "done": "완료",
    "complete": "완료",
    "completed": "완료",
    "완료": "완료",
    "blocked": "보류",
    "on_hold": "보류",
    "보류": "보류",
}


def _configured_path(env_name: str, default: Path) -> Path:
    raw = os.getenv(env_name)
    return Path(raw).expanduser().resolve() if raw else default


def wbs_path() -> Path:
    return _configured_path("BANG9_WBS_PATH", DEFAULT_DATA_DIR / "wbs.csv")


def personal_wbs_path() -> Path:
    return _configured_path(
        "BANG9_PERSONAL_WBS_PATH",
        DEFAULT_DATA_DIR / "wbs_personal_snapshots.csv",
    )


def meeting_index_path() -> Path:
    return _configured_path("BANG9_MEETING_INDEX_PATH", DEFAULT_DATA_DIR / "meetings.csv")


def action_items_path() -> Path:
    return _configured_path("BANG9_ACTION_ITEMS_PATH", DEFAULT_DATA_DIR / "action_items.csv")


def live_meetings_dir() -> Path:
    return _configured_path("BANG9_LIVE_MEETINGS_DIR", DEFAULT_DATA_DIR / "live-meetings")


def operating_workbook_path() -> Path:
    return _configured_path(
        "BANG9_OPERATING_WORKBOOK_PATH",
        PACKAGE_ROOT / "outputs" / "bang9-ax" / "방꾸석_운영_WBS.xlsx",
    )


def meetings_dir() -> Path:
    return _configured_path("BANG9_MEETINGS_DIR", DEFAULT_DATA_DIR / "meetings")


def document_dirs() -> list[Path]:
    configured = os.getenv("BANG9_DOCUMENTS_DIR")
    if configured:
        return [Path(item).expanduser().resolve() for item in configured.split(os.pathsep) if item]
    # Backward-compatible single-folder configuration used by the first prototype.
    if os.getenv("BANG9_MEETINGS_DIR"):
        return [meetings_dir()]
    roots = [DEFAULT_DATA_DIR / "documents", live_meetings_dir()]
    if os.getenv("BANG9_INCLUDE_PRIVATE_DOCUMENTS", "").casefold() in {"1", "true", "yes"}:
        roots.append(DEFAULT_DATA_DIR / "private-documents")
    return roots


def audit_path() -> Path:
    return _configured_path("BANG9_AUDIT_PATH", DEFAULT_DATA_DIR / "audit.jsonl")


def _read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"문서를 찾을 수 없습니다: {path}")
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return [dict(row) for row in csv.DictReader(stream)]


def load_wbs() -> list[dict[str, str]]:
    return _read_csv(wbs_path())


def load_personal_wbs() -> list[dict[str, str]]:
    path = personal_wbs_path()
    return _read_csv(path) if path.exists() else []


def load_meeting_index() -> list[dict[str, str]]:
    path = meeting_index_path()
    return _read_csv(path) if path.exists() else []


def load_action_items() -> list[dict[str, str]]:
    path = action_items_path()
    return _read_csv(path) if path.exists() else []


def _document_type(path: Path, root: Path) -> str:
    label = "/".join((root.name, *path.relative_to(root).parts)).casefold()
    if "회의" in label or "meeting" in label:
        return "meeting"
    if "보고서" in label or "report" in label:
        return "report"
    if "근거" in label or "evidence" in label:
        return "evidence"
    if "조사" in label or "research" in label:
        return "research"
    return "document"


def load_documents() -> list[dict[str, str]]:
    documents: list[dict[str, str]] = []
    for root in document_dirs():
        if not root.exists():
            continue
        for path in sorted(root.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in {".md", ".txt"}:
                continue
            relative = path.relative_to(root)
            documents.append(
                {
                    "name": path.name,
                    "source": str(Path(root.name) / relative),
                    "source_type": _document_type(path, root),
                    "path": str(path),
                    "content": path.read_text(encoding="utf-8-sig"),
                }
            )
    return documents


def load_meetings() -> list[dict[str, str]]:
    """Backward-compatible meeting-only view for existing clients."""
    return [item for item in load_documents() if item["source_type"] == "meeting"]


def list_documents() -> dict[str, Any]:
    documents = load_documents()
    return {
        "wbs": {
            "path": str(wbs_path()),
            "task_count": len(load_wbs()),
        },
        "personal_wbs": {
            "path": str(personal_wbs_path()),
            "snapshot_count": len(load_personal_wbs()),
        },
        "operating_workbook": {
            "path": str(operating_workbook_path()),
            "exists": operating_workbook_path().exists(),
        },
        "meeting_index": {
            "path": str(meeting_index_path()),
            "meeting_count": len(load_meeting_index()),
            "action_count": len(load_action_items()),
        },
        "documents": [
            {
                "name": item["name"],
                "source": item["source"],
                "source_type": item["source_type"],
                "path": item["path"],
            }
            for item in documents
        ],
        "document_count": len(documents),
        "counts_by_type": {
            kind: sum(item["source_type"] == kind for item in documents)
            for kind in sorted({item["source_type"] for item in documents})
        },
    }


def _parse_date(raw: str | None) -> date | None:
    if not raw or not raw.strip():
        return None
    try:
        return date.fromisoformat(raw.strip())
    except ValueError:
        return None


def _reference_date(raw: str | None) -> date:
    if not raw:
        return date.today()
    try:
        return date.fromisoformat(raw)
    except ValueError as exc:
        raise ValueError("reference_date는 YYYY-MM-DD 형식이어야 합니다.") from exc


def _progress(task: dict[str, str]) -> int:
    try:
        value = int(task.get("progress", "0"))
    except (TypeError, ValueError):
        return 0
    return min(100, max(0, value))


def analyze_schedule(
    reference_date: str | None = None,
    stale_days: int = 7,
) -> dict[str, Any]:
    if stale_days < 1 or stale_days > 90:
        raise ValueError("stale_days는 1~90 사이여야 합니다.")

    today = _reference_date(reference_date)
    tasks = load_wbs()
    completed = [task for task in tasks if task.get("status") == "완료"]
    overdue: list[dict[str, Any]] = []
    stale: list[dict[str, Any]] = []
    blocked: list[dict[str, Any]] = []
    missing_fields: list[dict[str, Any]] = []

    for task in tasks:
        task_id = task.get("id", "")
        status = task.get("status", "")
        due = _parse_date(task.get("due_date"))
        updated = _parse_date(task.get("last_updated"))
        missing = [field for field in ("task", "owner", "status", "due_date") if not task.get(field, "").strip()]

        if status != "완료" and due and due < today:
            overdue.append(
                {
                    "id": task_id,
                    "task": task.get("task", ""),
                    "owner": task.get("owner", ""),
                    "due_date": due.isoformat(),
                    "days_overdue": (today - due).days,
                }
            )
        if status == "진행중" and updated and (today - updated).days >= stale_days:
            stale.append(
                {
                    "id": task_id,
                    "task": task.get("task", ""),
                    "owner": task.get("owner", ""),
                    "last_updated": updated.isoformat(),
                    "days_without_update": (today - updated).days,
                }
            )
        if task.get("blocker", "").strip() or status == "보류":
            blocked.append(
                {
                    "id": task_id,
                    "task": task.get("task", ""),
                    "owner": task.get("owner", ""),
                    "blocker": task.get("blocker", "") or "보류 상태",
                }
            )
        if missing:
            missing_fields.append({"id": task_id, "missing": missing})

    total = len(tasks)
    return {
        "reference_date": today.isoformat(),
        "summary": {
            "total": total,
            "completed": len(completed),
            "in_progress": sum(task.get("status") == "진행중" for task in tasks),
            "completion_rate": round(len(completed) / total * 100, 1) if total else 0.0,
            "average_progress": round(sum(_progress(task) for task in tasks) / total, 1) if total else 0.0,
        },
        "overdue": overdue,
        "stale": stale,
        "blocked": blocked,
        "missing_required_fields": missing_fields,
    }


def _searchable_records() -> Iterable[dict[str, str]]:
    for task in load_wbs():
        yield {
            "source_type": "wbs",
            "source": f"WBS:{task.get('id', '')}",
            "title": task.get("task", ""),
            "content": " | ".join(
                f"{field}: {task.get(field, '')}" for field in WBS_FIELDS if task.get(field)
            ),
        }
    for document in load_documents():
        yield {
            "source_type": document["source_type"],
            "source": document["source"],
            "title": document["name"],
            "content": document["content"],
        }


def _normalized_key(value: str) -> str:
    return re.sub(r"[^0-9a-z가-힣]+", "", value.casefold())


def analyze_wbs_consistency() -> dict[str, Any]:
    """Compare the final master WBS with independently maintained personal sheets."""
    master = load_wbs()
    personal = load_personal_wbs()
    if not personal:
        return {
            "available": False,
            "summary": {"master_tasks": len(master), "personal_snapshots": 0},
            "progress_conflicts": [],
            "unmatched_personal": [],
            "missing_from_personal": [],
        }

    index: dict[tuple[str, str], list[dict[str, str]]] = {}
    personal_owners = {row.get("owner", "") for row in personal if row.get("owner")}
    for task in master:
        for owner in (part.strip() for part in task.get("owner", "").split(",")):
            if owner:
                index.setdefault((owner, _normalized_key(task.get("task", ""))), []).append(task)

    matched: set[tuple[str, str]] = set()
    progress_conflicts: list[dict[str, Any]] = []
    unmatched_personal: list[dict[str, str]] = []
    used_master_ids: set[tuple[str, str]] = set()

    for snapshot in personal:
        owner = snapshot.get("owner", "")
        key = (owner, _normalized_key(snapshot.get("task", "")))
        candidates = [
            task
            for task in index.get(key, [])
            if (owner, task.get("id", "")) not in used_master_ids
        ]
        if not candidates:
            unmatched_personal.append(
                {
                    "sheet": snapshot.get("sheet", ""),
                    "task": snapshot.get("task", ""),
                    "owner": owner,
                    "progress": snapshot.get("progress", ""),
                    "source_ref": snapshot.get("source_ref", ""),
                }
            )
            continue

        personal_category = _normalized_key(snapshot.get("category", ""))
        if personal_category:
            category_matches = [
                task
                for task in candidates
                if personal_category in _normalized_key(task.get("category", ""))
            ]
            if category_matches:
                candidates = category_matches
        task = candidates[0]
        used_master_ids.add((owner, task.get("id", "")))
        matched.add((owner, task.get("id", "")))

        master_progress = _progress(task)
        snapshot_progress = _progress(snapshot)
        if master_progress != snapshot_progress:
            progress_conflicts.append(
                {
                    "task_id": task.get("id", ""),
                    "task": task.get("task", ""),
                    "owner": owner,
                    "master_progress": master_progress,
                    "personal_progress": snapshot_progress,
                    "difference": master_progress - snapshot_progress,
                    "master_source": task.get("source_ref", ""),
                    "personal_source": snapshot.get("source_ref", ""),
                }
            )

    missing_from_personal: list[dict[str, str]] = []
    for task in master:
        for owner in (part.strip() for part in task.get("owner", "").split(",")):
            if owner in personal_owners and (owner, task.get("id", "")) not in matched:
                missing_from_personal.append(
                    {
                        "task_id": task.get("id", ""),
                        "task": task.get("task", ""),
                        "owner": owner,
                        "source_ref": task.get("source_ref", ""),
                    }
                )

    return {
        "available": True,
        "summary": {
            "master_tasks": len(master),
            "personal_snapshots": len(personal),
            "matched_snapshots": len(personal) - len(unmatched_personal),
            "progress_conflicts": len(progress_conflicts),
            "unmatched_personal": len(unmatched_personal),
            "missing_from_personal": len(missing_from_personal),
        },
        "progress_conflicts": progress_conflicts,
        "unmatched_personal": unmatched_personal,
        "missing_from_personal": missing_from_personal,
        "interpretation": (
            "본표는 최종 100% 상태인데 일부 개인 시트는 이전 진행률을 유지한다. "
            "이는 당시 수동·분산 관리에서 발생한 동기화 비용의 실자료 근거다."
        ),
    }


def search_knowledge(query: str, limit: int = 5) -> dict[str, Any]:
    if not query or not query.strip():
        raise ValueError("query는 비어 있을 수 없습니다.")
    if limit < 1 or limit > 20:
        raise ValueError("limit은 1~20 사이여야 합니다.")

    terms = [term.casefold() for term in re.findall(r"[\w가-힣]+", query) if len(term) > 1]
    if not terms:
        terms = [query.strip().casefold()]

    ranked: list[tuple[int, dict[str, str]]] = []
    for record in _searchable_records():
        haystack = f"{record['title']}\n{record['content']}".casefold()
        score = sum(haystack.count(term) for term in terms)
        if score:
            ranked.append((score, record))

    ranked.sort(key=lambda item: (-item[0], item[1]["source"]))
    results = [
        {
            "score": score,
            "source_type": record["source_type"],
            "source": record["source"],
            "title": record["title"],
            "excerpt": _excerpt(record["content"], terms),
        }
        for score, record in ranked[:limit]
    ]
    return {"query": query, "count": len(results), "results": results}


def _excerpt(content: str, terms: list[str], size: int = 240) -> str:
    compact = re.sub(r"\s+", " ", content).strip()
    lowered = compact.casefold()
    positions = [lowered.find(term) for term in terms if lowered.find(term) >= 0]
    start = max(0, min(positions) - 60) if positions else 0
    excerpt = compact[start : start + size]
    if start:
        excerpt = f"…{excerpt}"
    if start + size < len(compact):
        excerpt = f"{excerpt}…"
    return excerpt


def build_weekly_report(reference_date: str | None = None) -> str:
    today = _reference_date(reference_date)
    review = analyze_schedule(today.isoformat())
    tasks = load_wbs()
    upcoming_limit = today + timedelta(days=7)
    upcoming = [
        task
        for task in tasks
        if task.get("status") != "완료"
        and (due := _parse_date(task.get("due_date"))) is not None
        and today <= due <= upcoming_limit
    ]

    summary = review["summary"]
    lines = [
        f"# 방꾸석 프로젝트 주간 동기화 ({today.isoformat()})",
        "",
        "## 현황",
        f"- 전체 {summary['total']}개 / 완료 {summary['completed']}개 / 진행 중 {summary['in_progress']}개",
        f"- 완료율 {summary['completion_rate']}% / 평균 진행률 {summary['average_progress']}%",
        "",
        "## 우선 확인",
    ]

    risks = [
        *(f"- [지연 {item['days_overdue']}일] {item['id']} {item['task']} — {item['owner']}" for item in review["overdue"]),
        *(f"- [블로커] {item['id']} {item['task']} — {item['blocker']}" for item in review["blocked"]),
        *(f"- [업데이트 필요] {item['id']} {item['task']} — {item['days_without_update']}일 미갱신" for item in review["stale"]),
    ]
    lines.extend(risks or ["- 확인이 필요한 일정 위험이 없습니다."])
    lines.extend(["", "## 7일 내 마감"])
    lines.extend(
        (
            f"- {task['due_date']} | {task['id']} {task['task']} | "
            f"{task['owner']} | {task['progress']}%"
        )
        for task in sorted(upcoming, key=lambda item: item.get("due_date", ""))
    )
    if not upcoming:
        lines.append("- 예정된 마감 작업이 없습니다.")
    return "\n".join(lines)


def _write_csv_atomic(
    path: Path,
    rows: list[dict[str, str]],
    fieldnames: list[str],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        newline="",
        dir=path.parent,
        delete=False,
    ) as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
        temporary_path = Path(stream.name)
    temporary_path.replace(path)


def _append_audit(event: dict[str, Any]) -> None:
    payload = {
        "timestamp": datetime.now().astimezone().isoformat(timespec="seconds"),
        **event,
    }
    log_path = audit_path()
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(payload, ensure_ascii=False) + "\n")


def sync_operating_workbook() -> dict[str, Any]:
    """Regenerate the human-facing Excel workbook from canonical CSV/JSONL data."""
    node = Path(
        os.getenv(
            "BANG9_NODE_PATH",
            "/Users/yeoduchi/.cache/codex-runtimes/codex-primary-runtime/"
            "dependencies/node/bin/node",
        )
    )
    script = PACKAGE_ROOT / "scripts" / "sync_workbook.mjs"
    output = operating_workbook_path()
    if not node.exists():
        raise RuntimeError(f"Excel 동기화용 Node.js를 찾을 수 없습니다: {node}")
    if not script.exists():
        raise RuntimeError(f"Excel 동기화 스크립트를 찾을 수 없습니다: {script}")

    output.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            str(node),
            str(script),
            str(wbs_path()),
            str(meeting_index_path()),
            str(action_items_path()),
            str(audit_path()),
            str(output),
        ],
        cwd=PACKAGE_ROOT,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    if result.returncode != 0:
        message = (result.stderr or result.stdout or "알 수 없는 오류").strip()
        raise RuntimeError(f"운영 Excel 동기화 실패: {message[-1200:]}")
    return {
        "synced": True,
        "path": str(output),
        "message": result.stdout.strip(),
    }


def _next_identifier(rows: list[dict[str, str]], field: str, prefix: str) -> str:
    numbers = []
    for row in rows:
        match = re.fullmatch(rf"{re.escape(prefix)}-(\d+)", row.get(field, ""))
        if match:
            numbers.append(int(match.group(1)))
    return f"{prefix}-{max(numbers, default=0) + 1:03d}"


def _validate_iso_date(value: str, field: str, allow_blank: bool = False) -> str:
    cleaned = value.strip()
    if not cleaned and allow_blank:
        return ""
    try:
        return date.fromisoformat(cleaned).isoformat()
    except ValueError as exc:
        raise ValueError(f"{field}는 YYYY-MM-DD 형식이어야 합니다.") from exc


def _new_task_row(
    tasks: list[dict[str, str]],
    *,
    task: str,
    category: str,
    owner: str,
    start_date: str,
    due_date: str,
    priority: int,
    progress: int = 0,
    status: str | None = None,
    blocker: str = "",
    source_ref: str = "MCP 생성",
) -> dict[str, str]:
    if not task.strip() or not owner.strip() or not category.strip():
        raise ValueError("task, category, owner는 비어 있을 수 없습니다.")
    if priority < 1 or priority > 5:
        raise ValueError("priority는 1~5 사이여야 합니다.")
    if progress < 0 or progress > 100:
        raise ValueError("progress는 0~100 사이여야 합니다.")
    start = _validate_iso_date(start_date, "start_date")
    due = _validate_iso_date(due_date, "due_date")
    if date.fromisoformat(due) < date.fromisoformat(start):
        raise ValueError("due_date는 start_date보다 빠를 수 없습니다.")
    normalized_status = _normalize_status(status) if status else _infer_status(progress, "")
    if normalized_status == "완료" and progress < 100:
        raise ValueError("완료 상태의 progress는 100이어야 합니다.")
    if progress == 100:
        normalized_status = "완료"
    return {
        "id": _next_identifier(tasks, "id", "B9"),
        "category": category.strip(),
        "task": task.strip(),
        "owner": owner.strip(),
        "status": normalized_status,
        "start_date": start,
        "due_date": due,
        "progress": str(progress),
        "blocker": blocker.strip(),
        "last_updated": date.today().isoformat(),
        "priority": str(priority),
        "source_ref": source_ref.strip() or "MCP 생성",
    }


def list_remaining_tasks(
    reference_date: str | None = None,
    owner: str | None = None,
    category: str | None = None,
) -> dict[str, Any]:
    today = _reference_date(reference_date)
    tasks = [task for task in load_wbs() if task.get("status") != "완료"]
    if owner:
        tasks = [task for task in tasks if owner.casefold() in task.get("owner", "").casefold()]
    if category:
        tasks = [task for task in tasks if category.casefold() in task.get("category", "").casefold()]

    results: list[dict[str, Any]] = []
    for task in tasks:
        due = _parse_date(task.get("due_date"))
        results.append(
            {
                **task,
                "days_until_due": (due - today).days if due else None,
                "overdue": bool(due and due < today),
            }
        )
    results.sort(key=lambda item: (item.get("due_date") or "9999-12-31", item.get("priority") or "9"))
    return {
        "reference_date": today.isoformat(),
        "filters": {"owner": owner, "category": category},
        "summary": {
            "remaining": len(results),
            "overdue": sum(item["overdue"] for item in results),
            "without_due_date": sum(not item.get("due_date") for item in results),
        },
        "tasks": results,
    }


def add_task(
    *,
    task: str,
    category: str,
    owner: str,
    start_date: str,
    due_date: str,
    priority: int,
    progress: int = 0,
    status: str | None = None,
    blocker: str = "",
    requested_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    tasks = load_wbs()
    candidate = _new_task_row(
        tasks,
        task=task,
        category=category,
        owner=owner,
        start_date=start_date,
        due_date=due_date,
        priority=priority,
        progress=progress,
        status=status,
        blocker=blocker,
    )
    if not confirmed:
        return {
            "created": False,
            "requires_confirmation": True,
            "preview": candidate,
            "message": "내용을 확인한 뒤 confirmed=true로 다시 호출하세요.",
        }

    tasks.append(candidate)
    _write_csv_atomic(wbs_path(), tasks, WBS_FIELDS)
    _append_audit(
        {
            "action": "task_created",
            "entity_type": "task",
            "entity_id": candidate["id"],
            "task_id": candidate["id"],
            "updated_by": requested_by,
            "before": None,
            "after": candidate,
        }
    )
    workbook = sync_operating_workbook()
    return {"created": True, "task": candidate, "workbook": workbook}


def add_tasks_bulk(
    *,
    task_specs: list[dict[str, Any]],
    requested_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    """Validate and create multiple WBS tasks with one atomic write and workbook sync."""
    if not task_specs:
        raise ValueError("task_specs는 하나 이상이어야 합니다.")
    if len(task_specs) > 100:
        raise ValueError("한 번에 추가할 수 있는 작업은 최대 100개입니다.")

    tasks = load_wbs()
    original_count = len(tasks)
    candidates: list[dict[str, str]] = []
    for index, spec in enumerate(task_specs, start=1):
        try:
            candidate = _new_task_row(
                tasks,
                task=str(spec["task"]),
                category=str(spec["category"]),
                owner=str(spec["owner"]),
                start_date=str(spec["start_date"]),
                due_date=str(spec["due_date"]),
                priority=int(spec["priority"]),
                progress=int(spec.get("progress", 0)),
                status=spec.get("status"),
                blocker=str(spec.get("blocker", "")),
                source_ref="MCP 일괄 생성",
            )
        except KeyError as exc:
            raise ValueError(f"{index}번째 작업에 필수 필드 {exc.args[0]}가 없습니다.") from exc
        tasks.append(candidate)
        candidates.append(candidate)

    if not confirmed:
        return {
            "created": False,
            "requires_confirmation": True,
            "summary": {
                "current_tasks": original_count,
                "new_tasks": len(candidates),
                "after_confirmation": original_count + len(candidates),
            },
            "preview": candidates,
            "message": "전체 작업 목록을 확인한 뒤 confirmed=true로 다시 호출하세요.",
        }

    _write_csv_atomic(wbs_path(), tasks, WBS_FIELDS)
    _append_audit(
        {
            "action": "tasks_bulk_created",
            "entity_type": "task_batch",
            "entity_id": f"{candidates[0]['id']}..{candidates[-1]['id']}",
            "updated_by": requested_by,
            "before": {"task_count": original_count},
            "after": {
                "task_count": len(tasks),
                "created_task_ids": [item["id"] for item in candidates],
            },
        }
    )
    workbook = sync_operating_workbook()
    return {
        "created": True,
        "count": len(candidates),
        "tasks": candidates,
        "workbook": workbook,
    }


def _replace_owner_value(value: str, mapping: dict[str, str]) -> str:
    if not value.strip():
        return value
    return ", ".join(mapping.get(part.strip(), part.strip()) for part in value.split(","))


def _replace_aliases_in_text(value: str, mapping: dict[str, str]) -> str:
    updated = value
    for alias, actual_name in mapping.items():
        updated = updated.replace(alias, actual_name)
    return updated


def replace_project_owner_aliases(
    *,
    owner_mapping: dict[str, str],
    requested_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    """Replace anonymized owner aliases across structured project data in one operation."""
    mapping = {str(key).strip(): str(value).strip() for key, value in owner_mapping.items()}
    if not mapping or any(not key or not value for key, value in mapping.items()):
        raise ValueError("owner_mapping의 별칭과 실제 이름은 비어 있을 수 없습니다.")

    datasets: list[tuple[str, Path, list[dict[str, str]], list[str]]] = [
        ("wbs", wbs_path(), load_wbs(), WBS_FIELDS),
    ]
    personal = load_personal_wbs()
    if personal:
        datasets.append(("personal_wbs", personal_wbs_path(), personal, list(personal[0].keys())))
    actions = load_action_items()
    if actions:
        datasets.append(("action_items", action_items_path(), actions, ACTION_FIELDS))
    meetings = load_meeting_index()
    if meetings:
        datasets.append(("meetings", meeting_index_path(), meetings, MEETING_FIELDS))

    changes: dict[str, int] = {}
    samples: list[dict[str, str]] = []
    for dataset_name, _, rows, _ in datasets:
        count = 0
        for row in rows:
            for field in ("owner", "sheet", "recorded_by", "source_ref"):
                if field not in row:
                    continue
                before = row.get(field, "")
                after = (
                    _replace_aliases_in_text(before, mapping)
                    if field == "source_ref"
                    else _replace_owner_value(before, mapping)
                )
                if before == after:
                    continue
                row[field] = after
                count += 1
                if len(samples) < 12:
                    samples.append(
                        {
                            "dataset": dataset_name,
                            "id": row.get("id") or row.get("action_id") or row.get("meeting_id") or "",
                            "field": field,
                            "before": before,
                            "after": after,
                        }
                    )
        changes[dataset_name] = count

    preview = {
        "mapping": mapping,
        "changes_by_dataset": changes,
        "total_field_changes": sum(changes.values()),
        "samples": samples,
    }
    if not confirmed:
        return {
            "updated": False,
            "requires_confirmation": True,
            "preview": preview,
            "message": "실명 공개 범위와 변경 건수를 확인한 뒤 confirmed=true로 다시 호출하세요.",
        }

    for _, path, rows, fieldnames in datasets:
        _write_csv_atomic(path, rows, fieldnames)
    _append_audit(
        {
            "action": "owner_aliases_replaced",
            "entity_type": "project_data",
            "entity_id": "owner_mapping",
            "updated_by": requested_by,
            "before": {"aliases": list(mapping.keys())},
            "after": preview,
        }
    )
    workbook = sync_operating_workbook()
    return {"updated": True, **preview, "workbook": workbook}


def update_task(
    task_id: str,
    progress: int,
    status: str | None = None,
    blocker: str | None = None,
    updated_by: str = "mcp-user",
) -> dict[str, Any]:
    if progress < 0 or progress > 100:
        raise ValueError("progress는 0~100 사이여야 합니다.")

    path = wbs_path()
    tasks = load_wbs()
    target = next((task for task in tasks if task.get("id") == task_id), None)
    if target is None:
        raise ValueError(f"존재하지 않는 task_id입니다: {task_id}")

    normalized_status = _normalize_status(status) if status else _infer_status(progress, target.get("status", ""))
    if progress == 100 and normalized_status != "완료":
        normalized_status = "완료"
    if normalized_status == "완료" and progress < 100:
        raise ValueError("완료 상태의 progress는 100이어야 합니다.")

    before = dict(target)
    target["progress"] = str(progress)
    target["status"] = normalized_status
    target["last_updated"] = date.today().isoformat()
    if blocker is not None:
        target["blocker"] = blocker.strip()

    fieldnames = list(dict.fromkeys([*WBS_FIELDS, *(key for task in tasks for key in task)]))
    _write_csv_atomic(path, tasks, fieldnames)

    after = dict(target)
    _append_audit(
        {
            "action": "task_progress_updated",
            "entity_type": "task",
            "entity_id": task_id,
            "updated_by": updated_by,
            "task_id": task_id,
            "before": before,
            "after": after,
        }
    )
    workbook = sync_operating_workbook()

    return {
        "updated": True,
        "task": after,
        "audit_log": str(audit_path()),
        "workbook": workbook,
    }


def update_project_task(
    task_id: str,
    *,
    task: str | None = None,
    category: str | None = None,
    owner: str | None = None,
    start_date: str | None = None,
    due_date: str | None = None,
    priority: int | None = None,
    progress: int | None = None,
    status: str | None = None,
    blocker: str | None = None,
    requested_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    tasks = load_wbs()
    target = next((item for item in tasks if item.get("id") == task_id), None)
    if target is None:
        raise ValueError(f"존재하지 않는 task_id입니다: {task_id}")
    before = dict(target)
    after = dict(target)

    for field, value in (("task", task), ("category", category), ("owner", owner)):
        if value is not None:
            if not value.strip():
                raise ValueError(f"{field}는 비어 있을 수 없습니다.")
            after[field] = value.strip()
    if start_date is not None:
        after["start_date"] = _validate_iso_date(start_date, "start_date")
    if due_date is not None:
        after["due_date"] = _validate_iso_date(due_date, "due_date")
    if after.get("start_date") and after.get("due_date"):
        if date.fromisoformat(after["due_date"]) < date.fromisoformat(after["start_date"]):
            raise ValueError("due_date는 start_date보다 빠를 수 없습니다.")
    if priority is not None:
        if priority < 1 or priority > 5:
            raise ValueError("priority는 1~5 사이여야 합니다.")
        after["priority"] = str(priority)
    next_progress = _progress(after) if progress is None else progress
    if next_progress < 0 or next_progress > 100:
        raise ValueError("progress는 0~100 사이여야 합니다.")
    after["progress"] = str(next_progress)
    next_status = _normalize_status(status) if status else _infer_status(next_progress, after.get("status", ""))
    if next_progress == 100:
        next_status = "완료"
    if next_status == "완료" and next_progress < 100:
        raise ValueError("완료 상태의 progress는 100이어야 합니다.")
    after["status"] = next_status
    if blocker is not None:
        after["blocker"] = blocker.strip()
    after["last_updated"] = date.today().isoformat()

    if not confirmed:
        return {
            "updated": False,
            "requires_confirmation": True,
            "task_id": task_id,
            "before": before,
            "preview": after,
            "message": "변경 내용을 확인한 뒤 confirmed=true로 다시 호출하세요.",
        }

    target.clear()
    target.update(after)
    _write_csv_atomic(wbs_path(), tasks, WBS_FIELDS)
    _append_audit(
        {
            "action": "task_updated",
            "entity_type": "task",
            "entity_id": task_id,
            "task_id": task_id,
            "updated_by": requested_by,
            "before": before,
            "after": after,
        }
    )
    workbook = sync_operating_workbook()
    return {"updated": True, "task": after, "workbook": workbook}


def _safe_slug(value: str) -> str:
    slug = re.sub(r"[^0-9A-Za-z가-힣_-]+", "-", value.strip()).strip("-")
    return slug[:60] or "meeting"


def record_meeting(
    *,
    title: str,
    meeting_date: str,
    raw_notes: str,
    summary: str,
    decisions: list[str] | None = None,
    action_items: list[dict[str, Any]] | None = None,
    create_tasks: bool = True,
    recorded_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    if not title.strip() or not raw_notes.strip() or not summary.strip():
        raise ValueError("title, raw_notes, summary는 비어 있을 수 없습니다.")
    meeting_day = _validate_iso_date(meeting_date, "meeting_date")
    decisions = [item.strip() for item in (decisions or []) if item.strip()]
    action_items = action_items or []
    preview = {
        "meeting_date": meeting_day,
        "title": title.strip(),
        "summary": summary.strip(),
        "decisions": decisions,
        "action_items": action_items,
        "create_tasks": create_tasks,
    }
    if not confirmed:
        return {
            "recorded": False,
            "requires_confirmation": True,
            "preview": preview,
            "message": "정리된 회의록과 생성 예정 작업을 확인한 뒤 confirmed=true로 다시 호출하세요.",
        }

    meetings = load_meeting_index()
    actions = load_action_items()
    tasks = load_wbs()
    meeting_id = _next_identifier(meetings, "meeting_id", "MTG")
    created_at = datetime.now().astimezone().isoformat(timespec="seconds")
    created_tasks: list[dict[str, str]] = []
    normalized_actions: list[dict[str, str]] = []

    for item in action_items:
        task_name = str(item.get("task", "")).strip()
        owner_name = str(item.get("owner", "")).strip()
        if not task_name or not owner_name:
            raise ValueError("각 action_item에는 task와 owner가 필요합니다.")
        due = _validate_iso_date(str(item.get("due_date", "")), "action_item.due_date")
        category_name = str(item.get("category", "회의 액션")).strip() or "회의 액션"
        priority_value = int(item.get("priority", 3))
        wbs_task_id = ""
        if create_tasks and bool(item.get("create_task", True)):
            task_row = _new_task_row(
                tasks,
                task=task_name,
                category=category_name,
                owner=owner_name,
                start_date=meeting_day,
                due_date=due,
                priority=priority_value,
                source_ref=f"회의록 {meeting_id}",
            )
            tasks.append(task_row)
            created_tasks.append(task_row)
            wbs_task_id = task_row["id"]
        normalized_actions.append(
            {
                "action_id": _next_identifier([*actions, *normalized_actions], "action_id", "ACT"),
                "meeting_id": meeting_id,
                "task": task_name,
                "owner": owner_name,
                "due_date": due,
                "category": category_name,
                "priority": str(priority_value),
                "status": "예정",
                "wbs_task_id": wbs_task_id,
                "note": str(item.get("note", "")).strip(),
            }
        )

    folder = live_meetings_dir()
    folder.mkdir(parents=True, exist_ok=True)
    relative_path = Path(f"{meeting_day}-{meeting_id}-{_safe_slug(title)}.md")
    meeting_path = folder / relative_path
    lines = [
        f"# {title.strip()}",
        "",
        f"- 회의 ID: `{meeting_id}`",
        f"- 일자: {meeting_day}",
        f"- 기록자: {recorded_by}",
        "",
        "## 요약",
        "",
        summary.strip(),
        "",
        "## 결정사항",
        "",
        *(f"- {item}" for item in decisions),
        *([] if decisions else ["- 없음"]),
        "",
        "## 액션 아이템",
        "",
        *(
            f"- [{item['status']}] {item['task']} — {item['owner']} / {item['due_date']}"
            + (f" / WBS {item['wbs_task_id']}" if item["wbs_task_id"] else "")
            for item in normalized_actions
        ),
        *([] if normalized_actions else ["- 없음"]),
        "",
        "## 원문 메모",
        "",
        raw_notes.strip(),
        "",
    ]
    meeting_path.write_text("\n".join(lines), encoding="utf-8")

    meeting_row = {
        "meeting_id": meeting_id,
        "meeting_date": meeting_day,
        "title": title.strip(),
        "summary": summary.strip(),
        "decision_count": str(len(decisions)),
        "action_count": str(len(normalized_actions)),
        "source_path": str(meeting_path),
        "created_at": created_at,
        "recorded_by": recorded_by,
    }
    meetings.append(meeting_row)
    actions.extend(normalized_actions)
    _write_csv_atomic(meeting_index_path(), meetings, MEETING_FIELDS)
    _write_csv_atomic(action_items_path(), actions, ACTION_FIELDS)
    if created_tasks:
        _write_csv_atomic(wbs_path(), tasks, WBS_FIELDS)

    _append_audit(
        {
            "action": "meeting_recorded",
            "entity_type": "meeting",
            "entity_id": meeting_id,
            "updated_by": recorded_by,
            "before": None,
            "after": {
                **meeting_row,
                "created_task_ids": [item["id"] for item in created_tasks],
            },
        }
    )
    workbook = sync_operating_workbook()
    return {
        "recorded": True,
        "meeting": meeting_row,
        "actions": normalized_actions,
        "created_tasks": created_tasks,
        "workbook": workbook,
    }


def _normalize_status(status: str) -> str:
    normalized = STATUS_ALIASES.get(status.strip().casefold())
    if not normalized or normalized not in VALID_STATUSES:
        raise ValueError(f"status는 {sorted(VALID_STATUSES)} 중 하나여야 합니다.")
    return normalized


def _infer_status(progress: int, current: str) -> str:
    if progress == 100:
        return "완료"
    if progress == 0:
        return "예정" if current != "보류" else current
    return "진행중"
