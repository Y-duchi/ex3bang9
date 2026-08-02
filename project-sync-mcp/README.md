# Bang9 Project Sync MCP

방꾸석 캡스톤의 분산된 WBS·개인별 진행표·회의록을 **조회 가능한 자료**에서 **업무가 실제로 갱신되는 AX 워크플로우**로 바꾼 로컬 운영 프로토타입입니다.

사용자는 AI 클라이언트에 자연어로 남은 작업을 묻거나 작업·회의 메모를 전달합니다. AI는 내용을 구조화하고, MCP 서버는 변경안을 먼저 보여 준 뒤 승인된 내용만 WBS·회의록·액션 아이템·감사 로그에 기록합니다. 마지막으로 사람이 확인할 수 있는 운영 Excel을 다시 생성합니다.

```text
자연어 요청/회의 메모
        │
        ▼
AI 클라이언트: 요약·결정·액션·필드 구조화
        │
        ▼
MCP: 미리보기(confirmed=false) → 사용자 승인 → 실행(confirmed=true)
        │
        ├─ WBS 작업 생성·수정
        ├─ 회의록 Markdown 저장
        ├─ 액션 아이템과 WBS 연결
        ├─ JSONL 감사 로그 기록
        └─ 운영 Excel·대시보드 재생성
```

## 왜 만들었는가

당시 최종 WBS 본표와 팀원별 시트를 따로 관리했고, 병합할 내용은 README에 적고 WBS 진행률과 회의 문서를 수동으로 갱신했습니다. 실제 원본을 정규화해 비교한 결과 다음 문제가 확인됐습니다.

- 최종 본표 100개 작업과 개인별 스냅샷 83개가 분리돼 있음
- 본표와 개인표의 진행률 불일치 19건
- 개인표에만 있는 작업 7건
- 본표에만 있는 담당자-작업 조합 19건

이 프로토타입은 팀장이 여러 파일을 열어 현재 상태를 대조하고 다시 기록하는 흐름을 한 대화 안에서 끝내는 것을 목표로 합니다. 위 숫자는 자동 탐지한 데이터 품질 문제이며 시간 절감 성과로 과장하지 않습니다.

## 실제로 가능한 업무

### 1. 남은 작업 조회

> “남은 작업을 마감 임박 순서로 보여줘.”  
> “여서진이 담당한 프론트엔드 작업만 보여줘.”

`get_remaining_tasks`가 완료되지 않은 작업을 담당자·분류로 필터링하고 지연 여부와 남은 일수를 함께 반환합니다.

### 2. 작업 추가·수정

> “작업 일정에 프론트엔드 사용자페이지 구현을 추가해줘. 담당자는 여서진, 8월 3일부터 10일까지, 우선순위 1.”

첫 호출은 변경 미리보기만 반환합니다. 사용자가 승인하면 새 작업 ID를 발급하고 WBS CSV, 감사 로그, 운영 Excel을 함께 갱신합니다. 일정·담당자·우선순위·진행률 수정도 같은 승인 절차를 거칩니다.

### 3. 회의 메모를 실행 항목으로 전환

> “아래 회의 메모를 정리해서 기록하고, 담당자와 마감일이 있는 액션은 WBS에도 넣어줘.”

AI 클라이언트가 원문을 요약·결정사항·액션 아이템으로 구조화합니다. 사용자가 결과를 확인하고 승인하면 다음 항목이 한 번에 반영됩니다.

- 검색 가능한 Markdown 회의록
- 회의 인덱스와 액션 아이템
- 액션과 연결된 신규 WBS 작업
- 누가 무엇을 바꿨는지 남기는 감사 로그
- 대시보드가 포함된 운영 Excel

서버가 회의를 상시 녹음하거나 문서를 몰래 감시하는 구조는 아닙니다. 사용자가 메모나 녹취를 대화에 전달해야 동작합니다.

## MCP 도구

| 도구 | 역할 | 쓰기 승인 |
| --- | --- | --- |
| `list_project_documents` | 연결된 데이터·문서·운영 Excel 확인 | 불필요 |
| `search_project_knowledge` | WBS·회의록·보고서 통합 검색 | 불필요 |
| `get_schedule_risks` | 지연·블로커·미갱신·필수값 누락 탐지 | 불필요 |
| `get_wbs_consistency_issues` | 본표·개인표 진행률 및 작업 불일치 탐지 | 불필요 |
| `get_remaining_tasks` | 미완료 작업과 마감 위험 조회 | 불필요 |
| `add_project_task` | 새 작업 추가 | 필요 |
| `bulk_add_project_tasks` | 테스트 백로그처럼 여러 작업을 한 번에 추가 | 필요 |
| `bulk_replace_project_owners` | 담당자 별칭을 실제 이름으로 일괄 복원 | 필요 |
| `update_project_task` | 일정·담당자·상태 등 수정 | 필요 |
| `update_task_progress` | 진행률·상태·블로커 수정 | 필요 |
| `record_project_meeting` | 회의록·결정·액션 저장 및 WBS 연결 | 필요 |
| `sync_project_workbook` | 현재 데이터로 운영 Excel 재생성 | 즉시 실행 |
| `generate_weekly_sync_report` | 주간 공유문 생성 | 불필요 |

리소스는 `bang9://project/wbs`, `bang9://project/meetings`, `bang9://project/documents`를 제공합니다. `weekly_project_review` 프롬프트는 위험 확인 → 기록 불일치 확인 → 근거 검색 → 액션 정리 → 승인 후 반영 순서를 안내합니다.

## 데이터와 운영 원칙

```text
examples/                           # Git에 포함되는 역할 기반 익명 예시
├── wbs.csv
├── meetings.csv
├── action_items.csv
├── wbs_personal_snapshots.csv
└── documents/

data/                               # 실제 팀 기록, Git 제외
outputs/                            # 생성된 운영 Excel, Git 제외
```

- CSV와 JSONL이 시스템의 기준 데이터이며 Excel은 확인·공유를 위한 산출물입니다. Excel을 직접 고치면 다음 동기화 때 덮어써질 수 있습니다.
- 모든 쓰기 도구는 미리보기와 명시적 승인을 분리합니다.
- CSV는 임시 파일에 쓴 뒤 교체하고, 변경 전·후 값을 감사 로그에 남깁니다.
- USB의 Word·Excel·PDF·PowerPoint 원본과 이력서 파일은 수정하지 않습니다.
- 로컬 `data/wbs.csv`가 있으면 실제 운영 기록을 사용하고, 없으면 `examples/`의 익명 데이터를 자동 사용합니다.
- 팀원 실명과 원문 회의 기록은 공개 저장소에 올리지 않습니다.

## 현재 Codex 연결

현재 로컬 Codex에는 `bang9_project_sync` 이름으로 등록돼 있습니다. 설정을 다시 읽도록 Codex를 재시작한 뒤 다음처럼 요청할 수 있습니다.

- “방꾸석 남은 작업 보여줘.”
- “프론트엔드 사용자페이지 구현 작업 추가안을 만들어줘.”
- “이 회의 메모를 결정사항과 액션으로 정리해서 방꾸석에 기록해줘.”

쓰기 요청은 곧바로 저장하지 않고 변경안을 보여 줍니다. 내용을 확인해 승인하면 실제 파일과 운영 Excel이 갱신됩니다.

## 일반 실행

```bash
cd /path/to/project-sync-mcp
uv sync
uv run bang9-project-sync-mcp
```

stdio 서버이므로 단독 실행 시 출력이 없는 것이 정상입니다. MCP 클라이언트에는 다음과 같이 등록할 수 있습니다.

```json
{
  "mcpServers": {
    "bang9-project-sync": {
      "command": "uv",
      "args": [
        "--directory",
        "/absolute/path/to/project-sync-mcp",
        "run",
        "bang9-project-sync-mcp"
      ]
    }
  }
}
```

운영 Excel 생성기는 현재 Codex가 제공한 Node.js와 `@oai/artifact-tool` 런타임을 사용합니다. `BANG9_NODE_PATH`로 Node 실행 경로를 지정할 수 있습니다. 다른 실행 환경으로 배포할 때는 동일한 인터페이스의 Excel 어댑터를 배포 환경에 맞게 준비해야 합니다.

주요 저장 경로는 환경변수로 교체할 수 있습니다.

```bash
export BANG9_WBS_PATH="/absolute/path/to/wbs.csv"
export BANG9_MEETING_INDEX_PATH="/absolute/path/to/meetings.csv"
export BANG9_ACTION_ITEMS_PATH="/absolute/path/to/action_items.csv"
export BANG9_LIVE_MEETINGS_DIR="/absolute/path/to/live-meetings"
export BANG9_AUDIT_PATH="/absolute/path/to/audit.jsonl"
export BANG9_OPERATING_WORKBOOK_PATH="/absolute/path/to/operating.xlsx"
```

환경변수를 지정하지 않으면 기존 로컬 `data/wbs.csv`를 우선 사용하며, 공개 클론처럼 로컬 데이터가 없을 때는 `examples/wbs.csv`를 사용합니다.

## 검증

```bash
pytest -q
```

검증 범위는 다음과 같습니다.

- 일정 위험·통합 검색·본표/개인표 불일치 분석
- 작업 추가·수정의 미리보기/승인 분리
- 회의록·액션 아이템·WBS 작업 동시 생성
- 실제 운영 Excel 생성과 5개 시트 존재 확인
- 실제 stdio MCP 세션의 13개 도구 검색과 호출

현재 전체 테스트 결과는 `14 passed`입니다.

## 프로덕션 전환 시 남은 항목

현재 결과물은 **실제 파일을 변경하고 감사 가능한 로컬 운영 프로토타입**입니다. 사내 공용 서비스로 배포하려면 다음을 추가해야 합니다.

- 사내 SSO와 역할 기반 권한, 팀별 데이터 분리
- CSV 대신 트랜잭션을 지원하는 데이터베이스와 동시 수정 제어
- Slack·사내 위키·데이터 웨어하우스 커넥터
- 실패 재시도, 백업·복구, 모니터링·알림
- 회의 요약과 액션 추출 품질을 측정하는 eval 데이터셋
- 여러 팀이 재사용할 수 있는 설정·템플릿·배포 파이프라인

즉, 단순 MCP 제작이 아니라 **문제 발견 → 데이터 통합 → 자연어 업무 인터페이스 → 승인형 실행 → 감사·운영 가시성**까지 구현했고, 이후 조직 공용 서비스로 일반화할 경계도 명확히 구분했습니다.

## 기술

- Python 3.11+, MCP Python SDK 1.x, `FastMCP`, stdio 전송
- CSV 원자적 교체, JSONL 감사 로그, Markdown 회의 기록
- 승인형 쓰기 도구와 Pydantic 입력 스키마
- `@oai/artifact-tool` 기반 Excel·대시보드 생성
- 외부 LLM API에 의존하지 않는 결정론적 일정·불일치 분석
