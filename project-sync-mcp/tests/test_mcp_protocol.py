from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


def test_stdio_server_lists_and_calls_tools() -> None:
    project_root = Path(__file__).resolve().parents[1]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(project_root / "src")

    async def scenario() -> None:
        parameters = StdioServerParameters(
            command=sys.executable,
            args=["-m", "bang9_mcp.server"],
            cwd=project_root,
            env=env,
        )
        async with stdio_client(parameters) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                tools = await session.list_tools()
                names = {tool.name for tool in tools.tools}
                assert {
                    "list_project_documents",
                    "search_project_knowledge",
                    "get_schedule_risks",
                    "get_wbs_consistency_issues",
                    "get_remaining_tasks",
                    "add_project_task",
                    "bulk_add_project_tasks",
                    "bulk_replace_project_owners",
                    "update_project_task",
                    "record_project_meeting",
                    "sync_project_workbook",
                    "generate_weekly_sync_report",
                    "update_task_progress",
                } <= names

                result = await session.call_tool(
                    "search_project_knowledge",
                    arguments={"query": "README 병합"},
                )
                assert not result.isError
                assert result.structuredContent is not None
                assert result.structuredContent["count"] >= 1

                consistency = await session.call_tool(
                    "get_wbs_consistency_issues",
                    arguments={},
                )
                assert not consistency.isError
                assert consistency.structuredContent is not None
                assert consistency.structuredContent["summary"]["progress_conflicts"] == 19

                remaining = await session.call_tool(
                    "get_remaining_tasks",
                    arguments={"reference_date": "2026-08-02"},
                )
                assert not remaining.isError
                assert remaining.structuredContent is not None
                remaining_count = remaining.structuredContent["summary"]["remaining"]
                assert remaining_count == len(remaining.structuredContent["tasks"])

                task_preview = await session.call_tool(
                    "add_project_task",
                    arguments={
                        "task": "프론트엔드 사용자페이지 구현",
                        "category": "프론트엔드",
                        "owner": "여서진",
                        "start_date": "2026-08-03",
                        "due_date": "2026-08-10",
                        "priority": 1,
                    },
                )
                assert not task_preview.isError
                assert task_preview.structuredContent is not None
                assert task_preview.structuredContent["requires_confirmation"] is True

                meeting_preview = await session.call_tool(
                    "record_project_meeting",
                    arguments={
                        "title": "사용자 페이지 구현 점검",
                        "meeting_date": "2026-08-03",
                        "raw_notes": "API 연결 담당자와 마감일을 확정했다.",
                        "summary": "사용자 페이지 API 연결 일정을 확정했다.",
                        "decisions": ["API 연결을 우선 처리한다."],
                        "action_items": [
                            {
                                "task": "사용자 페이지 API 연결",
                                "owner": "여서진",
                                "due_date": "2026-08-07",
                                "category": "프론트엔드",
                                "priority": 1,
                            }
                        ],
                    },
                )
                assert not meeting_preview.isError
                assert meeting_preview.structuredContent is not None
                assert meeting_preview.structuredContent["requires_confirmation"] is True

    asyncio.run(scenario())
