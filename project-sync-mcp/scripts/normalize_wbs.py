#!/usr/bin/env python3
"""Normalize the extracted Bang9 WBS workbook without modifying the source file.

The input JSON is produced by the spreadsheet inspection step and contains one
entry per worksheet with ``sheet``, ``address`` and ``values`` keys.  Names are
replaced with stable role aliases before data is written to the MCP project.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any


MAIN_FIELDS = [
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
PERSONAL_FIELDS = [
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
]

NAME_ALIASES = {"전원": "전원"}


def owner_alias(name: str) -> str:
    lead_name = os.getenv("BANG9_PROJECT_LEAD_NAME", "").strip()
    if lead_name and name == lead_name:
        return "본인(팀장)"
    if name not in NAME_ALIASES:
        anonymous_count = sum(alias.startswith("팀원 ") for alias in NAME_ALIASES.values())
        NAME_ALIASES[name] = f"팀원 {anonymous_count + 1}"
    return NAME_ALIASES[name]


def cell(row: list[Any], index: int) -> Any:
    return row[index] if index < len(row) else None


def text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def excel_date(value: Any) -> str:
    if value in (None, ""):
        return ""
    if isinstance(value, str) and "-" in value:
        return value
    try:
        return (datetime(1899, 12, 30) + timedelta(days=float(value))).date().isoformat()
    except (TypeError, ValueError):
        return text(value)


def progress_percent(value: Any) -> int:
    if value in (None, ""):
        return 0
    number = float(value)
    if 0 <= number <= 1:
        number *= 100
    return max(0, min(100, round(number)))


def anonymize_owner(raw: Any) -> str:
    owner = text(raw)
    if not owner:
        return ""
    names = [part.strip() for part in owner.split(",")]
    return ", ".join(owner_alias(name) for name in names)


def status_for(progress: int) -> str:
    if progress == 100:
        return "완료"
    if progress == 0:
        return "예정"
    return "진행중"


def sheet_map(payload: list[dict[str, Any]]) -> dict[str, list[list[Any]]]:
    return {item["sheet"]: item["values"] for item in payload}


def normalize_main(rows: list[list[Any]]) -> list[dict[str, str]]:
    normalized: list[dict[str, str]] = []
    area = ""
    group = ""

    for row_number, row in enumerate(rows[1:], start=2):
        first = text(cell(row, 0))
        task = text(cell(row, 1))
        owner_raw = cell(row, 3)
        is_heading = not text(owner_raw) and not text(cell(row, 4)) and not text(cell(row, 7))

        if is_heading:
            if first:
                area = first
                group = task
            elif task:
                group = task
            continue

        if first:
            area = first
            group = ""
        if not task:
            continue

        progress = progress_percent(cell(row, 7))
        category = "/".join(part for part in (area, group) if part)
        normalized.append(
            {
                "id": f"B9-{len(normalized) + 1:03d}",
                "category": category,
                "task": task,
                "owner": anonymize_owner(owner_raw),
                "status": status_for(progress),
                "start_date": excel_date(cell(row, 4)),
                "due_date": excel_date(cell(row, 5)),
                "progress": str(progress),
                "blocker": "",
                # The workbook has no per-row update date. Do not invent one.
                "last_updated": "",
                "priority": text(cell(row, 2)),
                "source_ref": f"원본 WBS#WBS!A{row_number}:H{row_number}",
            }
        )
    return normalized


def personal_layout(rows: list[list[Any]]) -> dict[str, int]:
    layouts = [
        {"task": 0, "priority": 1, "owner": 2, "start": 3, "due": 4, "progress": 6},
        {"task": 1, "priority": 2, "owner": 3, "start": 4, "due": 5, "progress": 7},
    ]

    def score(layout: dict[str, int]) -> int:
        return sum(
            bool(text(cell(row, layout["task"])))
            and bool(text(cell(row, layout["owner"])))
            for row in rows
        )

    return max(layouts, key=score)


def normalize_personal(sheets: dict[str, list[list[Any]]]) -> list[dict[str, str]]:
    normalized: list[dict[str, str]] = []
    for sheet, rows in sheets.items():
        if sheet == "WBS":
            continue
        layout = personal_layout(rows)
        sheet_alias = owner_alias(sheet)
        category = ""
        for row_number, row in enumerate(rows, start=1):
            task = text(cell(row, layout["task"]))
            owner_raw = cell(row, layout["owner"])
            if task in {"작업명", "기능"}:
                continue

            has_owner = bool(text(owner_raw))
            if not has_owner:
                # Personal sheets use owner-less rows as section labels.
                if task:
                    category = task
                continue
            if layout["task"] == 1 and text(cell(row, 0)):
                category = text(cell(row, 0))
            progress = progress_percent(cell(row, layout["progress"]))
            normalized.append(
                {
                    "sheet": sheet_alias,
                    "row": str(row_number),
                    "category": category,
                    "task": task,
                    "owner": anonymize_owner(owner_raw),
                    "start_date": excel_date(cell(row, layout["start"])),
                    "due_date": excel_date(cell(row, layout["due"])),
                    "progress": str(progress),
                    "priority": text(cell(row, layout["priority"])),
                    "note": text(cell(row, 8)),
                    "source_ref": f"원본 WBS#{sheet_alias}!{row_number}",
                }
            )
    return normalized


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def summarize(main: list[dict[str, str]], personal: list[dict[str, str]]) -> dict[str, Any]:
    owners: defaultdict[str, int] = defaultdict(int)
    for row in main:
        for owner in row["owner"].split(", "):
            owners[owner] += 1
    return {
        "main_task_count": len(main),
        "personal_snapshot_count": len(personal),
        "owner_assignment_counts": dict(sorted(owners.items())),
        "self_solo_assignments": sum(row["owner"] == "본인(팀장)" for row in main),
        "self_shared_assignments": sum(
            "본인(팀장)" in row["owner"] and row["owner"] != "본인(팀장)" for row in main
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_json", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    payload = json.loads(args.input_json.read_text(encoding="utf-8"))
    sheets = sheet_map(payload)
    main_rows = normalize_main(sheets["WBS"])
    personal_rows = normalize_personal(sheets)

    write_csv(args.output_dir / "wbs.csv", MAIN_FIELDS, main_rows)
    write_csv(
        args.output_dir / "wbs_personal_snapshots.csv",
        PERSONAL_FIELDS,
        personal_rows,
    )
    print(json.dumps(summarize(main_rows, personal_rows), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
