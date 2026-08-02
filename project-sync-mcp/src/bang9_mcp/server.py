from __future__ import annotations

import json
from typing import Any

from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field

from .service import (
    add_task,
    add_tasks_bulk,
    analyze_schedule,
    analyze_wbs_consistency,
    build_weekly_report,
    list_documents,
    load_documents,
    load_meetings,
    load_wbs,
    list_remaining_tasks,
    record_meeting,
    replace_project_owner_aliases,
    search_knowledge,
    sync_operating_workbook,
    update_project_task as update_task_details,
)


mcp = FastMCP(
    "Bang9 Project Sync",
    instructions=(
        "방꾸석 프로젝트의 WBS, 개인별 진행표, 회의록과 보고서를 검색하고 "
        "일정 위험과 기록 간 불일치를 점검한다. "
        "작업·회의록을 쓸 때는 먼저 confirmed=false로 변경안을 보여주고, "
        "사용자가 승인한 뒤 confirmed=true로 반영한다."
    ),
)


class ActionItemInput(BaseModel):
    task: str = Field(description="실행할 구체적인 작업")
    owner: str = Field(description="담당자")
    due_date: str = Field(description="마감일, YYYY-MM-DD")
    category: str = Field(default="회의 액션", description="WBS 분류")
    priority: int = Field(default=3, ge=1, le=5, description="우선순위 1~5")
    note: str = Field(default="", description="추가 맥락이나 완료 조건")
    create_task: bool = Field(default=True, description="WBS 작업으로 함께 생성할지 여부")


class TaskInput(BaseModel):
    task: str = Field(description="구체적인 작업명")
    category: str = Field(description="WBS 분류")
    owner: str = Field(description="담당자")
    start_date: str = Field(description="시작일, YYYY-MM-DD")
    due_date: str = Field(description="마감일, YYYY-MM-DD")
    priority: int = Field(ge=1, le=5, description="우선순위 1~5")
    progress: int = Field(default=0, ge=0, le=100, description="진행률 0~100")
    status: str | None = Field(default=None, description="예정·진행중·완료·보류")
    blocker: str = Field(default="", description="블로커")


@mcp.tool()
def list_project_documents() -> dict[str, Any]:
    """연결된 WBS, 개인별 진행표, 회의록과 보고서 목록을 조회한다."""
    return list_documents()


@mcp.tool()
def search_project_knowledge(query: str, limit: int = 5) -> dict[str, Any]:
    """WBS, 회의록과 보고서에서 질문과 관련된 프로젝트 기록을 통합 검색한다."""
    return search_knowledge(query=query, limit=limit)


@mcp.tool()
def get_schedule_risks(
    reference_date: str | None = None,
    stale_days: int = 7,
) -> dict[str, Any]:
    """지연 작업, 블로커, 장기 미갱신 작업, 필수값 누락을 찾아 요약한다."""
    return analyze_schedule(reference_date=reference_date, stale_days=stale_days)


@mcp.tool()
def get_wbs_consistency_issues() -> dict[str, Any]:
    """최종 본표와 개인별 WBS 스냅샷의 진행률·작업 불일치를 점검한다."""
    return analyze_wbs_consistency()


@mcp.tool()
def get_remaining_tasks(
    reference_date: str | None = None,
    owner: str | None = None,
    category: str | None = None,
) -> dict[str, Any]:
    """완료되지 않은 작업을 담당자·분류로 필터링하고 마감 위험과 함께 조회한다."""
    return list_remaining_tasks(
        reference_date=reference_date,
        owner=owner,
        category=category,
    )


@mcp.tool()
def add_project_task(
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
    """신규 작업을 제안하거나 승인 후 WBS·운영 Excel에 추가하고 감사 로그를 남긴다."""
    return add_task(
        task=task,
        category=category,
        owner=owner,
        start_date=start_date,
        due_date=due_date,
        priority=priority,
        progress=progress,
        status=status,
        blocker=blocker,
        requested_by=requested_by,
        confirmed=confirmed,
    )


@mcp.tool()
def bulk_add_project_tasks(
    tasks: list[TaskInput],
    requested_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    """여러 작업을 한 번에 미리보기하거나 승인 후 WBS·Excel에 일괄 반영한다."""
    return add_tasks_bulk(
        task_specs=[item.model_dump() for item in tasks],
        requested_by=requested_by,
        confirmed=confirmed,
    )


@mcp.tool()
def bulk_replace_project_owners(
    owner_mapping: dict[str, str],
    requested_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    """담당자 별칭을 실제 이름으로 일괄 변경하고 개인표·Excel까지 동기화한다."""
    return replace_project_owner_aliases(
        owner_mapping=owner_mapping,
        requested_by=requested_by,
        confirmed=confirmed,
    )


@mcp.tool()
def update_project_task(
    task_id: str,
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
    """기존 작업의 일정·담당자·상태를 제안하거나 승인 후 Excel까지 동기화한다."""
    return update_task_details(
        task_id,
        task=task,
        category=category,
        owner=owner,
        start_date=start_date,
        due_date=due_date,
        priority=priority,
        progress=progress,
        status=status,
        blocker=blocker,
        requested_by=requested_by,
        confirmed=confirmed,
    )


@mcp.tool()
def record_project_meeting(
    title: str,
    meeting_date: str,
    raw_notes: str,
    summary: str,
    decisions: list[str] | None = None,
    action_items: list[ActionItemInput] | None = None,
    create_tasks: bool = True,
    recorded_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    """회의 메모를 요약·결정·액션으로 구조화해 저장하고 승인된 액션을 WBS 작업으로 만든다."""
    return record_meeting(
        title=title,
        meeting_date=meeting_date,
        raw_notes=raw_notes,
        summary=summary,
        decisions=decisions,
        action_items=[item.model_dump() for item in (action_items or [])],
        create_tasks=create_tasks,
        recorded_by=recorded_by,
        confirmed=confirmed,
    )


@mcp.tool()
def sync_project_workbook() -> dict[str, Any]:
    """현재 CSV·회의록·감사 로그를 사람이 확인할 수 있는 운영 Excel로 다시 생성한다."""
    return sync_operating_workbook()


@mcp.tool()
def generate_weekly_sync_report(reference_date: str | None = None) -> str:
    """WBS 상태를 바탕으로 공유 가능한 주간 프로젝트 보고서를 생성한다."""
    return build_weekly_report(reference_date=reference_date)


@mcp.tool()
def update_task_progress(
    task_id: str,
    progress: int,
    status: str | None = None,
    blocker: str | None = None,
    updated_by: str = "mcp-user",
    confirmed: bool = False,
) -> dict[str, Any]:
    """진행률 변경안을 보여주거나 승인 후 반영하고 운영 Excel·감사 로그를 갱신한다."""
    return update_task_details(
        task_id,
        status=status,
        progress=progress,
        blocker=blocker,
        requested_by=updated_by,
        confirmed=confirmed,
    )


@mcp.resource("bang9://project/wbs")
def wbs_resource() -> str:
    """현재 WBS 원본을 JSON으로 제공한다."""
    return json.dumps(load_wbs(), ensure_ascii=False, indent=2)


@mcp.resource("bang9://project/meetings")
def meetings_resource() -> str:
    """연결된 회의록 원문을 JSON으로 제공한다."""
    return json.dumps(load_meetings(), ensure_ascii=False, indent=2)


@mcp.resource("bang9://project/documents")
def documents_resource() -> str:
    """연결된 회의록·보고서·근거 문서를 JSON으로 제공한다."""
    return json.dumps(load_documents(), ensure_ascii=False, indent=2)


@mcp.prompt()
def weekly_project_review(reference_date: str = "") -> str:
    """프로젝트 주간 점검을 일관된 순서로 수행하는 프롬프트."""
    date_instruction = f"기준일은 {reference_date}이다." if reference_date else "기준일은 오늘이다."
    return (
        f"{date_instruction}\n"
        "1. get_schedule_risks로 일정 위험을 확인한다.\n"
        "2. get_wbs_consistency_issues로 본표와 개인표의 불일치를 확인한다.\n"
        "3. 필요한 근거는 search_project_knowledge로 회의록·보고서·WBS에서 찾는다.\n"
        "4. 위험도 순으로 현황, 원인, 다음 액션, 담당자를 정리한다.\n"
        "5. 쓰기 도구는 confirmed=false로 미리보기 후 사용자의 승인을 받는다.\n"
        "6. 승인 후에만 confirmed=true로 호출한다."
    )


def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
