from __future__ import annotations

import csv
import json
from pathlib import Path

import pytest

from bang9_mcp.service import (
    ACTION_FIELDS,
    MEETING_FIELDS,
    WBS_FIELDS,
    add_task,
    add_tasks_bulk,
    analyze_schedule,
    analyze_wbs_consistency,
    build_weekly_report,
    list_remaining_tasks,
    record_meeting,
    replace_project_owner_aliases,
    search_knowledge,
    update_task,
    update_project_task,
)


@pytest.fixture()
def project_data(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    wbs = tmp_path / "wbs.csv"
    rows = [
        {
            "id": "T-1",
            "category": "AI",
            "task": "추천 API 예외 처리",
            "owner": "서진",
            "status": "진행중",
            "start_date": "2025-05-01",
            "due_date": "2025-05-10",
            "progress": "60",
            "blocker": "테스트 데이터 부족",
            "last_updated": "2025-05-05",
        },
        {
            "id": "T-2",
            "category": "AR",
            "task": "AR 배치 연동",
            "owner": "팀원",
            "status": "완료",
            "start_date": "2025-05-01",
            "due_date": "2025-05-08",
            "progress": "100",
            "blocker": "",
            "last_updated": "2025-05-08",
        },
    ]
    with wbs.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=WBS_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    meetings = tmp_path / "meetings"
    meetings.mkdir()
    (meetings / "weekly.md").write_text(
        "# 회의록\n추천 API 테스트 데이터를 보강하기로 결정했다.",
        encoding="utf-8",
    )
    monkeypatch.setenv("BANG9_WBS_PATH", str(wbs))
    monkeypatch.setenv("BANG9_MEETINGS_DIR", str(meetings))
    monkeypatch.setenv("BANG9_AUDIT_PATH", str(tmp_path / "audit.jsonl"))
    monkeypatch.setenv("BANG9_MEETING_INDEX_PATH", str(tmp_path / "meetings.csv"))
    monkeypatch.setenv("BANG9_ACTION_ITEMS_PATH", str(tmp_path / "action_items.csv"))
    monkeypatch.setenv("BANG9_LIVE_MEETINGS_DIR", str(tmp_path / "live-meetings"))
    monkeypatch.setenv("BANG9_OPERATING_WORKBOOK_PATH", str(tmp_path / "운영.xlsx"))
    monkeypatch.setattr(
        "bang9_mcp.service.sync_operating_workbook",
        lambda: {"synced": True, "path": str(tmp_path / "운영.xlsx")},
    )

    for path, fields in (
        (tmp_path / "meetings.csv", MEETING_FIELDS),
        (tmp_path / "action_items.csv", ACTION_FIELDS),
    ):
        with path.open("w", encoding="utf-8", newline="") as stream:
            csv.DictWriter(stream, fieldnames=fields).writeheader()

    personal_wbs = tmp_path / "wbs_personal_snapshots.csv"
    with personal_wbs.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "sheet",
                "row",
                "category",
                "task",
                "owner",
                "start_date",
                "due_date",
                "progress",
                "priority",
                "note",
                "source_ref",
            ],
        )
        writer.writeheader()
        writer.writerows(
            [
                {
                    "sheet": "서진",
                    "row": "2",
                    "category": "AI",
                    "task": "추천 API 예외 처리",
                    "owner": "서진",
                    "start_date": "2025-05-01",
                    "due_date": "2025-05-10",
                    "progress": "40",
                    "priority": "1",
                    "note": "",
                    "source_ref": "개인표!2",
                },
                {
                    "sheet": "서진",
                    "row": "3",
                    "category": "AI",
                    "task": "본표에 없는 작업",
                    "owner": "서진",
                    "start_date": "2025-05-01",
                    "due_date": "2025-05-10",
                    "progress": "20",
                    "priority": "2",
                    "note": "",
                    "source_ref": "개인표!3",
                },
            ]
        )
    monkeypatch.setenv("BANG9_PERSONAL_WBS_PATH", str(personal_wbs))
    return tmp_path


def test_analyze_schedule_finds_risks(project_data: Path) -> None:
    result = analyze_schedule(reference_date="2025-05-20", stale_days=7)

    assert result["summary"]["total"] == 2
    assert result["summary"]["completion_rate"] == 50.0
    assert result["overdue"][0]["id"] == "T-1"
    assert result["stale"][0]["days_without_update"] == 15
    assert result["blocked"][0]["blocker"] == "테스트 데이터 부족"


def test_searches_wbs_and_meetings(project_data: Path) -> None:
    result = search_knowledge("추천 API 테스트", limit=5)

    assert result["count"] == 2
    assert {item["source_type"] for item in result["results"]} == {"wbs", "meeting"}


def test_compares_master_and_personal_wbs(project_data: Path) -> None:
    result = analyze_wbs_consistency()

    assert result["available"] is True
    assert result["summary"]["progress_conflicts"] == 1
    assert result["progress_conflicts"][0]["difference"] == 20
    assert result["summary"]["unmatched_personal"] == 1


def test_update_task_writes_audit_log(project_data: Path) -> None:
    result = update_task("T-1", progress=100, updated_by="test-user")

    assert result["task"]["status"] == "완료"
    assert result["task"]["progress"] == "100"
    event = json.loads((project_data / "audit.jsonl").read_text(encoding="utf-8"))
    assert event["task_id"] == "T-1"
    assert event["updated_by"] == "test-user"
    assert event["before"]["progress"] == "60"


def test_add_task_previews_then_writes_wbs(project_data: Path) -> None:
    arguments = {
        "task": "사용자 페이지 구현",
        "category": "프론트엔드",
        "owner": "서진",
        "start_date": "2025-05-20",
        "due_date": "2025-05-27",
        "priority": 1,
        "requested_by": "test-user",
    }
    preview = add_task(**arguments)

    assert preview["requires_confirmation"] is True
    assert len(list(csv.DictReader((project_data / "wbs.csv").open(encoding="utf-8")))) == 2

    result = add_task(**arguments, confirmed=True)
    assert result["created"] is True
    assert result["task"]["id"] == "B9-001"
    assert result["workbook"]["synced"] is True
    assert len(list(csv.DictReader((project_data / "wbs.csv").open(encoding="utf-8")))) == 3


def test_bulk_add_tasks_previews_then_writes_once(project_data: Path) -> None:
    specs = [
        {
            "task": "인증 경계값 테스트",
            "category": "QA/인증",
            "owner": "서진",
            "start_date": "2025-05-20",
            "due_date": "2025-05-21",
            "priority": 1,
        },
        {
            "task": "결제 실패 테스트",
            "category": "QA/결제",
            "owner": "서진",
            "start_date": "2025-05-21",
            "due_date": "2025-05-22",
            "priority": 1,
        },
    ]
    preview = add_tasks_bulk(task_specs=specs)
    assert preview["summary"]["new_tasks"] == 2
    assert preview["preview"][0]["id"] == "B9-001"

    result = add_tasks_bulk(task_specs=specs, confirmed=True)
    assert result["created"] is True
    assert [item["id"] for item in result["tasks"]] == ["B9-001", "B9-002"]
    assert len(list(csv.DictReader((project_data / "wbs.csv").open(encoding="utf-8")))) == 4


def test_bulk_replace_owner_aliases_updates_master_and_personal(project_data: Path) -> None:
    preview = replace_project_owner_aliases(
        owner_mapping={"서진": "여서진", "팀원": "예시 담당자"},
    )
    assert preview["requires_confirmation"] is True
    assert preview["preview"]["changes_by_dataset"]["wbs"] == 2

    result = replace_project_owner_aliases(
        owner_mapping={"서진": "여서진", "팀원": "예시 담당자"},
        confirmed=True,
    )
    assert result["updated"] is True
    wbs_rows = list(csv.DictReader((project_data / "wbs.csv").open(encoding="utf-8")))
    personal_rows = list(
        csv.DictReader((project_data / "wbs_personal_snapshots.csv").open(encoding="utf-8"))
    )
    assert {row["owner"] for row in wbs_rows} == {"여서진", "예시 담당자"}
    assert {row["owner"] for row in personal_rows} == {"여서진"}


def test_update_project_task_previews_then_applies(project_data: Path) -> None:
    preview = update_project_task(
        "T-1",
        due_date="2025-05-30",
        priority=1,
    )
    assert preview["requires_confirmation"] is True
    assert preview["preview"]["due_date"] == "2025-05-30"

    result = update_project_task(
        "T-1",
        due_date="2025-05-30",
        priority=1,
        confirmed=True,
    )
    assert result["updated"] is True
    assert result["task"]["priority"] == "1"


def test_record_meeting_creates_markdown_action_and_wbs_task(project_data: Path) -> None:
    arguments = {
        "title": "프론트엔드 일정 회의",
        "meeting_date": "2025-05-20",
        "raw_notes": "사용자 페이지를 서진이 5월 27일까지 구현한다.",
        "summary": "사용자 페이지 구현 일정과 담당자를 확정했다.",
        "decisions": ["사용자 페이지를 우선 구현한다."],
        "action_items": [
            {
                "task": "사용자 페이지 구현",
                "owner": "서진",
                "due_date": "2025-05-27",
                "category": "프론트엔드",
                "priority": 1,
            }
        ],
        "recorded_by": "test-user",
    }
    preview = record_meeting(**arguments)
    assert preview["requires_confirmation"] is True

    result = record_meeting(**arguments, confirmed=True)
    assert result["recorded"] is True
    assert result["created_tasks"][0]["task"] == "사용자 페이지 구현"
    assert result["actions"][0]["wbs_task_id"] == "B9-001"
    assert Path(result["meeting"]["source_path"]).exists()


def test_lists_remaining_tasks(project_data: Path) -> None:
    result = list_remaining_tasks(reference_date="2025-05-20", owner="서진")

    assert result["summary"]["remaining"] == 1
    assert result["summary"]["overdue"] == 1
    assert result["tasks"][0]["id"] == "T-1"


def test_weekly_report_contains_risk_and_summary(project_data: Path) -> None:
    report = build_weekly_report(reference_date="2025-05-20")

    assert "완료율 50.0%" in report
    assert "지연 10일" in report
    assert "테스트 데이터 부족" in report


def test_rejects_inconsistent_completed_status(project_data: Path) -> None:
    with pytest.raises(ValueError, match="progress는 100"):
        update_task("T-1", progress=80, status="완료")
