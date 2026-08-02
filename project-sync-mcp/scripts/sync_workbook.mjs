#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const [wbsPath, meetingsPath, actionsPath, auditPath, outputPath, verifyDir] = process.argv.slice(2);
if (!wbsPath || !meetingsPath || !actionsPath || !auditPath || !outputPath) {
  throw new Error(
    "usage: sync_workbook.mjs <wbs.csv> <meetings.csv> <actions.csv> <audit.jsonl> <output.xlsx> [verify-dir]",
  );
}

const readText = async (filePath, fallback) => {
  try {
    return await fs.readFile(filePath, "utf8");
  } catch (error) {
    if (error?.code === "ENOENT") return fallback;
    throw error;
  }
};

const formatKstTimestamp = (raw) => {
  if (!raw) return "";
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return String(raw);
  return `${new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(parsed)} KST`;
};

const compactAuditValue = (value) => {
  if (value == null) return "";
  const serialized = JSON.stringify(value);
  return serialized.length <= 120 ? serialized : `${serialized.slice(0, 117)}...`;
};

const workbook = Workbook.create();
await workbook.fromCSV(await readText(wbsPath, "id\n"), { sheetName: "WBS" });
await workbook.fromCSV(
  await readText(
    meetingsPath,
    "meeting_id,meeting_date,title,summary,decision_count,action_count,source_path,created_at,recorded_by\n",
  ),
  { sheetName: "회의록" },
);
await workbook.fromCSV(
  await readText(
    actionsPath,
    "action_id,meeting_id,task,owner,due_date,category,priority,status,wbs_task_id,note\n",
  ),
  { sheetName: "액션아이템" },
);

const auditSheet = workbook.worksheets.add("감사로그");
const auditHeaders = [
  "timestamp",
  "action",
  "entity_type",
  "entity_id",
  "updated_by",
  "before",
  "after",
];
const auditText = await readText(auditPath, "");
const auditRows = auditText
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => JSON.parse(line))
  .map((event) => [
    formatKstTimestamp(event.timestamp),
    event.action ?? "",
    event.entity_type ?? "",
    event.entity_id ?? event.task_id ?? "",
    event.updated_by ?? "",
    compactAuditValue(event.before),
    compactAuditValue(event.after),
  ]);
auditSheet.getRangeByIndexes(0, 0, auditRows.length + 1, auditHeaders.length).values = [
  auditHeaders,
  ...auditRows,
];

const dashboard = workbook.worksheets.add("대시보드");
dashboard.mergeCells("A1:F1");
dashboard.getRange("A1:F1").values = [["방꾸석 AX 운영 현황"]];
dashboard.mergeCells("A2:F2");
dashboard.getRange("A2:F2").values = [[
  "MCP로 작업·회의록을 기록하면 WBS, 액션 아이템, 감사 로그가 함께 갱신됩니다.",
]];
dashboard.getRange("A4:B9").values = [
  ["지표", "값"],
  ["전체 작업", null],
  ["완료", null],
  ["진행 중", null],
  ["예정", null],
  ["보류", null],
];
dashboard.getRange("B5:B9").formulas = [
  ["=COUNTA('WBS'!$A$2:$A$1000)"],
  ["=COUNTIF('WBS'!$E$2:$E$1000,\"완료\")"],
  ["=COUNTIF('WBS'!$E$2:$E$1000,\"진행중\")"],
  ["=COUNTIF('WBS'!$E$2:$E$1000,\"예정\")"],
  ["=COUNTIF('WBS'!$E$2:$E$1000,\"보류\")"],
];
dashboard.getRange("D4:E9").values = [
  ["운영 지표", "값"],
  ["평균 진행률", null],
  ["기한 초과", null],
  ["회의", null],
  ["미완료 액션", null],
  [
    "마지막 동기화",
    `${new Intl.DateTimeFormat("sv-SE", {
      timeZone: "Asia/Seoul",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(new Date())} KST`,
  ],
];
dashboard.getRange("E5:E8").formulas = [
  ["=IFERROR(AVERAGE('WBS'!$H$2:$H$1000)/100,0)"],
  ["=COUNTIFS('WBS'!$A$2:$A$1000,\"<>\",'WBS'!$G$2:$G$1000,\"<\"&TODAY(),'WBS'!$E$2:$E$1000,\"<>완료\")"],
  ["=COUNTA('회의록'!$A$2:$A$1000)"],
  ["=COUNTIFS('액션아이템'!$A$2:$A$1000,\"<>\",'액션아이템'!$H$2:$H$1000,\"<>완료\")"],
];
dashboard.getRange("A11:F11").merge();
dashboard.getRange("A11:F11").values = [[
  "쓰기 작업은 미리보기 → 사용자 승인 → 반영 순서로 실행됩니다.",
]];

const headerFill = "#1F4E78";
const headerFont = { bold: true, color: "#FFFFFF" };
const lightBorder = { preset: "inside", style: "thin", color: "#D9E2F3" };

const styleDataSheet = (sheet, widths, tableName) => {
  const used = sheet.getUsedRange();
  const rowCount = Math.max(used?.values?.length ?? 1, 1);
  const colCount = Math.max(used?.values?.[0]?.length ?? widths.length, widths.length);
  const usedRange = sheet.getRangeByIndexes(0, 0, rowCount, colCount);
  usedRange.format = {
    font: { name: "Aptos", size: 10, color: "#1F2937" },
    verticalAlignment: "center",
    borders: lightBorder,
  };
  sheet.getRangeByIndexes(0, 0, 1, colCount).format = {
    fill: headerFill,
    font: headerFont,
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: "#FFFFFF" },
    rowHeight: 30,
  };
  widths.forEach((width, index) => {
    sheet.getRangeByIndexes(0, index, rowCount, 1).format.columnWidthPx = width;
  });
  if (rowCount > 1) {
    usedRange.format.wrapText = true;
    usedRange.format.autofitRows();
    const table = sheet.tables.add(
      sheet.getRangeByIndexes(0, 0, rowCount, colCount),
      true,
      tableName,
    );
    table.style = "TableStyleMedium2";
    table.showFilterButton = true;
  }
  sheet.freezePanes.freezeRows(1);
  sheet.showGridLines = false;
};

const wbsSheet = workbook.worksheets.getItem("WBS");
wbsSheet.getRange("A1:L1").values = [[
  "ID",
  "분류",
  "작업명",
  "담당자",
  "상태",
  "시작일",
  "마감일",
  "진행률",
  "블로커",
  "최종 수정일",
  "우선순위",
  "출처",
]];
styleDataSheet(
  wbsSheet,
  [82, 145, 220, 130, 86, 100, 100, 75, 180, 105, 68, 180],
  "TasksTable",
);
const wbsRowCount = Math.max(wbsSheet.getUsedRange()?.values?.length ?? 1, 2);
if (wbsRowCount > 1) {
  wbsSheet.getRange(`F2:G${wbsRowCount}`).setNumberFormat("yyyy-mm-dd");
  wbsSheet.getRange(`J2:J${wbsRowCount}`).setNumberFormat("yyyy-mm-dd");
  wbsSheet.getRange(`H2:H${wbsRowCount}`).setNumberFormat("0\"%\"");
  wbsSheet.getRange(`E2:E${wbsRowCount}`).dataValidation = {
    rule: { type: "list", values: ["예정", "진행중", "완료", "보류"] },
  };
  wbsSheet.getRange(`K2:K${wbsRowCount}`).dataValidation = {
    rule: { type: "list", values: ["1", "2", "3", "4", "5"] },
  };
  const statusRange = wbsSheet.getRange(`E2:E${wbsRowCount}`);
  statusRange.conditionalFormats.add("containsText", {
    text: "완료",
    format: { fill: "#DCFCE7", font: { color: "#166534", bold: true } },
  });
  statusRange.conditionalFormats.add("containsText", {
    text: "진행중",
    format: { fill: "#DBEAFE", font: { color: "#1D4ED8", bold: true } },
  });
  statusRange.conditionalFormats.add("containsText", {
    text: "보류",
    format: { fill: "#FEE2E2", font: { color: "#B91C1C", bold: true } },
  });
  wbsSheet.getRange(`H2:H${wbsRowCount}`).conditionalFormats.add("dataBar", {
    color: "#3B82F6",
    thresholds: [0, 100],
  });
}

const meetingsSheet = workbook.worksheets.getItem("회의록");
meetingsSheet.getRange("A1:I1").values = [[
  "회의 ID",
  "회의일",
  "제목",
  "요약",
  "결정 수",
  "액션 수",
  "회의록 경로",
  "생성 시각",
  "기록자",
]];
styleDataSheet(
  meetingsSheet,
  [90, 100, 200, 360, 90, 90, 280, 165, 110],
  "MeetingsTable",
);
const meetingsRowCount = Math.max(meetingsSheet.getUsedRange()?.values?.length ?? 1, 1);
if (meetingsRowCount > 1) {
  meetingsSheet.getRange(`B2:B${meetingsRowCount}`).setNumberFormat("yyyy-mm-dd");
  meetingsSheet.getRange(`H2:H${meetingsRowCount}`).setNumberFormat("yyyy-mm-dd hh:mm:ss");
}
const actionsSheet = workbook.worksheets.getItem("액션아이템");
actionsSheet.getRange("A1:J1").values = [[
  "액션 ID",
  "회의 ID",
  "작업",
  "담당자",
  "마감일",
  "분류",
  "우선순위",
  "상태",
  "WBS 작업 ID",
  "메모",
]];
styleDataSheet(
  actionsSheet,
  [90, 90, 260, 120, 100, 130, 70, 86, 90, 220],
  "ActionsTable",
);
const actionsRowCount = Math.max(actionsSheet.getUsedRange()?.values?.length ?? 1, 1);
if (actionsRowCount > 1) {
  actionsSheet.getRange(`E2:E${actionsRowCount}`).setNumberFormat("yyyy-mm-dd");
}
auditSheet.getRange("A1:G1").values = [[
  "시각",
  "작업",
  "대상 유형",
  "대상 ID",
  "변경자",
  "변경 전",
  "변경 후",
]];
styleDataSheet(
  auditSheet,
  [165, 145, 100, 100, 110, 360, 360],
  "AuditTable",
);
const auditRowCount = Math.max(auditSheet.getUsedRange()?.values?.length ?? 1, 1);
if (auditRowCount > 1) {
  auditSheet.getRange(`A2:G${auditRowCount}`).format.rowHeightPx = 60;
}

dashboard.showGridLines = false;
dashboard.getRange("A1:F1").format = {
  fill: "#17365D",
  font: { name: "Aptos Display", size: 20, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "left",
  verticalAlignment: "center",
  rowHeight: 42,
};
dashboard.getRange("A2:F2").format = {
  fill: "#D9EAF7",
  font: { name: "Aptos", size: 10, color: "#334155" },
  wrapText: true,
  rowHeight: 34,
};
for (const rangeName of ["A4:B9", "D4:E9"]) {
  dashboard.getRange(rangeName).format = {
    borders: { preset: "all", style: "thin", color: "#B4C6E7" },
    verticalAlignment: "center",
  };
}
dashboard.getRange("A4:B4").format = { fill: headerFill, font: headerFont };
dashboard.getRange("D4:E4").format = { fill: headerFill, font: headerFont };
dashboard.getRange("B5:B9").format = {
  fill: "#EFF6FF",
  font: { size: 14, bold: true, color: "#1E3A8A" },
  horizontalAlignment: "right",
};
dashboard.getRange("E5:E9").format = {
  fill: "#F8FAFC",
  font: { size: 12, bold: true, color: "#334155" },
  horizontalAlignment: "right",
};
dashboard.getRange("E5").setNumberFormat("0%");
dashboard.getRange("A11:F11").format = {
  fill: "#FFF4CC",
  font: { italic: true, color: "#7C5C00" },
  wrapText: true,
  rowHeight: 30,
};
dashboard.getRange("A1:F11").format.font.name = "Aptos";
dashboard.getRange("A1:A11").format.columnWidthPx = 150;
dashboard.getRange("B1:B11").format.columnWidthPx = 110;
dashboard.getRange("C1:C11").format.columnWidthPx = 34;
dashboard.getRange("D1:D11").format.columnWidthPx = 150;
dashboard.getRange("E1:E11").format.columnWidthPx = 150;
dashboard.getRange("F1:F11").format.columnWidthPx = 50;
dashboard.freezePanes.freezeRows(2);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
const formulaErrorCodes = ["#REF!", "#DIV/0!", "#VALUE!", "#NAME?", "#N/A"];
if (formulaErrorCodes.some((code) => errors.ndjson.includes(code))) {
  throw new Error(`formula errors found: ${errors.ndjson}`);
}

if (verifyDir) {
  const dashboardCheck = await workbook.inspect({
    kind: "table",
    range: "대시보드!A1:F11",
    include: "values,formulas",
    tableMaxRows: 11,
    tableMaxCols: 6,
    maxChars: 5000,
  });
  console.log(dashboardCheck.ndjson);
  await fs.mkdir(verifyDir, { recursive: true });
  for (const sheet of workbook.worksheets.items) {
    const preview = await workbook.render({
      sheetName: sheet.name,
      autoCrop: "all",
      scale: 1.5,
      format: "png",
    });
    const safeName = sheet.name.replace(/[^\p{L}\p{N}._-]+/gu, "_");
    await fs.writeFile(
      path.join(verifyDir, `${safeName}.png`),
      new Uint8Array(await preview.arrayBuffer()),
    );
  }
}

await fs.mkdir(path.dirname(outputPath), { recursive: true });
const temporaryPath = path.join(
  path.dirname(outputPath),
  `.${path.basename(outputPath)}.${process.pid}.tmp.xlsx`,
);
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(temporaryPath);
await fs.rename(temporaryPath, outputPath);
await fs.rm(`${temporaryPath}.inspect.ndjson`, { force: true });
console.log(`synced ${outputPath}`);
