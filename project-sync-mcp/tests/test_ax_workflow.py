from __future__ import annotations

import csv
import shutil
import zipfile
from pathlib import Path

import pytest

from bang9_mcp.service import (
    ACTION_FIELDS,
    MEETING_FIELDS,
    add_task,
    list_remaining_tasks,
    record_meeting,
)


def test_ax_workflow_updates_data_and_operating_workbook(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    project_root = Path(__file__).resolve().parents[1]
    node = Path(
        "/Users/yeoduchi/.cache/codex-runtimes/codex-primary-runtime/"
        "dependencies/node/bin/node"
    )
    if not node.exists() or not (project_root / "node_modules" / "@oai" / "artifact-tool").exists():
        pytest.skip("Codex spreadsheet runtime is not available")

    wbs = tmp_path / "wbs.csv"
    meetings = tmp_path / "meetings.csv"
    actions = tmp_path / "action_items.csv"
    audit = tmp_path / "audit.jsonl"
    workbook = tmp_path / "방꾸석_운영_WBS.xlsx"
    live_meetings = tmp_path / "live-meetings"
    shutil.copyfile(project_root / "examples" / "wbs.csv", wbs)
    initial_task_count = len(list(csv.DictReader(wbs.open(encoding="utf-8"))))
    for path, fields in ((meetings, MEETING_FIELDS), (actions, ACTION_FIELDS)):
        with path.open("w", encoding="utf-8", newline="") as stream:
            csv.DictWriter(stream, fieldnames=fields).writeheader()

    monkeypatch.setenv("BANG9_WBS_PATH", str(wbs))
    monkeypatch.setenv("BANG9_MEETING_INDEX_PATH", str(meetings))
    monkeypatch.setenv("BANG9_ACTION_ITEMS_PATH", str(actions))
    monkeypatch.setenv("BANG9_AUDIT_PATH", str(audit))
    monkeypatch.setenv("BANG9_LIVE_MEETINGS_DIR", str(live_meetings))
    monkeypatch.setenv("BANG9_OPERATING_WORKBOOK_PATH", str(workbook))
    monkeypatch.setenv("BANG9_NODE_PATH", str(node))

    task_arguments = {
        "task": "프론트엔드 사용자페이지 구현",
        "category": "AX 통합 테스트",
        "owner": "통합테스트 담당자",
        "start_date": "2026-08-03",
        "due_date": "2026-08-10",
        "priority": 1,
    }
    preview = add_task(**task_arguments)
    assert preview["requires_confirmation"] is True
    assert len(list(csv.DictReader(wbs.open(encoding="utf-8")))) == initial_task_count

    created = add_task(**task_arguments, confirmed=True)
    created_task_id = created["task"]["id"]
    assert created_task_id == preview["preview"]["id"]
    assert workbook.exists() and workbook.stat().st_size > 10_000

    meeting = record_meeting(
        title="사용자 페이지 구현 점검",
        meeting_date="2026-08-03",
        raw_notes="사용자 페이지 API 연결을 8월 7일까지 완료하기로 했다.",
        summary="사용자 페이지 구현 범위와 API 연결 일정을 확정했다.",
        decisions=["사용자 페이지 API 연결을 우선 처리한다."],
        action_items=[
            {
                "task": "사용자 페이지 API 연결",
                "owner": "통합테스트 담당자",
                "due_date": "2026-08-07",
                "category": "AX 통합 테스트",
                "priority": 1,
            }
        ],
        confirmed=True,
    )
    meeting_task_id = meeting["created_tasks"][0]["id"]
    assert meeting_task_id != created_task_id
    assert Path(meeting["meeting"]["source_path"]).exists()

    remaining = list_remaining_tasks(
        reference_date="2026-08-03",
        owner="통합테스트 담당자",
        category="AX 통합 테스트",
    )
    assert {item["id"] for item in remaining["tasks"]} == {
        created_task_id,
        meeting_task_id,
    }
    assert len(list(csv.DictReader(actions.open(encoding="utf-8")))) == 1
    assert len(audit.read_text(encoding="utf-8").splitlines()) == 2

    with zipfile.ZipFile(workbook) as archive:
        workbook_xml = archive.read("xl/workbook.xml").decode("utf-8")
    for sheet_name in ("대시보드", "WBS", "회의록", "액션아이템", "감사로그"):
        assert sheet_name in workbook_xml
