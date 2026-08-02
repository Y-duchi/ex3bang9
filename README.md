# 방꾸석 (Bang9)

AR 가구 배치, 예산·취향 기반 추천, 새 가구 쇼핑과 중고거래를 연결한 Flutter 캡스톤 프로젝트입니다. 현재 저장소는 포트폴리오 검토와 로컬 데모 재현을 위한 형태로 정리되어 있습니다.

## 주요 기능

- Flutter 기반 쇼핑·중고거래·커뮤니티 사용자 흐름
- Django REST API와 MariaDB 데이터 모델
- FastAPI 기반 가구 추천 API
- iOS ARKit/SceneKit 기반 가구 배치
- WBS·회의록·운영 Excel을 연결하는 승인형 MCP 자동화

## 로컬 포트폴리오 모드

포트폴리오 모드는 Firebase, 소셜 로그인, 실제 이메일 발송과 유료 지도 API를 호출하지 않습니다. 로컬 MariaDB와 API 서버를 사용하고 로그인 화면의 `데모 시작`으로 진입합니다.

자세한 준비와 실기기 실행 방법은 [PORTFOLIO_DEMO.md](PORTFOLIO_DEMO.md)와 [PORTFOLIO_DEVICE_READY.md](PORTFOLIO_DEVICE_READY.md)를 참고하세요.

```bash
cp backend/.env.example backend/.env.local
./scripts/restore_portfolio_db.sh
./scripts/start_portfolio_backend.sh
```

실제 로컬 `.env.local`에는 충분히 긴 임의 비밀번호를 사용해야 합니다. 해당 파일은 Git에서 제외됩니다.

## 비밀정보와 외부 서비스

다음 로컬 파일은 의도적으로 Git에 포함하지 않습니다.

- `backend/.env.local`
- `ios/Flutter/Secrets.xcconfig`
- `android/local.properties`
- Firebase의 `google-services.json`, `GoogleService-Info.plist`

예전 Git 기록에 등장했던 Gmail, Naver, Google Maps, Django 키는 공개 전에 반드시 폐기하고 재발급해야 합니다. 예제 설정의 `DEMO_DISABLED`를 실제 서비스 키로 오해해 사용하면 안 됩니다.

## 비공개 데이터와 자산

팀원 실명 WBS, 회의록, 생성된 Excel, 사용자 업로드 미디어와 출처가 확인되지 않은 3D 모델은 공개 저장소에서 제외합니다. 기존 로컬 파일은 다음 위치에 그대로 둘 수 있습니다.

- `project-sync-mcp/data/`, `project-sync-mcp/outputs/`
- `backend/media/`
- `ios/Runner/models.scnassets/`

공개 클론의 MCP 서버는 `project-sync-mcp/examples/`의 역할 기반 익명 예시를 자동 사용합니다. 미디어와 AR 모델을 다시 배포하려면 각 파일의 사용·재배포 권리를 먼저 확인해야 합니다.

## 검증

```bash
flutter analyze
cd project-sync-mcp && uv run pytest -q
```

## 라이선스

포트폴리오 검토를 위해 소스가 공개되어도 별도의 사용 허가는 부여되지 않습니다. 자세한 내용은 [LICENSE](LICENSE)와 [ASSET_POLICY.md](ASSET_POLICY.md)를 확인하세요.
