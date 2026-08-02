# 방꾸석 로컬 포트폴리오 데모

이 구성은 실서비스 계정이나 유료 API 없이 기존 방꾸석 앱을 실기기에서 캡처하기 위한 로컬 실행 환경이다.

## 구성

- Flutter iOS 앱: `PORTFOLIO_DEMO=true`에서 Firebase·카카오·네이버 초기화 생략
- Django API: `0.0.0.0:8000`
- FastAPI 예산 추천 API: `0.0.0.0:8001`
- MariaDB 11.3: Docker의 로컬 볼륨에만 저장
- 실행 복사본: macOS 파일 동기화 지연을 피하기 위해 `~/.cache/bang9-portfolio/app-runtime`에서 빌드
- 데이터: USB의 2025-06-10 MySQL 덤프를 로컬 DB에 복원
- 로그인: `portfolio_demo` 사용자를 자동 준비하고 로그인 화면의 **데모 시작**으로 진입

## 최초 1회 준비

```bash
uv venv --python /opt/homebrew/bin/python3.13 /Users/yeoduchi/.cache/bang9-portfolio/venv
uv pip install --python /Users/yeoduchi/.cache/bang9-portfolio/venv/bin/python -r backend/requirements.txt
./scripts/restore_portfolio_db.sh
./scripts/sync_portfolio_runtime.sh
cd /Users/yeoduchi/.cache/bang9-portfolio/app-runtime && flutter pub get
```

`backend/.env.local`은 Git에서 제외된다. 원본 SQL 덤프에는 개인정보가 있으므로 저장소에 복사하거나 커밋하지 않는다.

## 실행

터미널 1:

```bash
./scripts/start_portfolio_backend.sh
```

아이폰을 연결한 뒤 터미널 2:

```bash
./scripts/run_portfolio_ios.sh
```

앱 로그인 화면에서 **데모 시작**을 누르면 쇼핑 홈으로 이동한다.

## 권장 캡처 동선

1. 로고와 로컬 포트폴리오 모드가 보이는 로그인 화면
2. 쇼핑 홈의 카테고리·인기·최신 가구
3. 예산과 스타일을 입력한 추천 결과
4. OCR 신분 확인 화면
5. AR 가구 배치 화면
6. 중고거래 목록·상세·지도
7. 커뮤니티 목록·상세
8. 사용자 마이페이지

채팅·소셜 로그인·실제 이메일 발송은 포트폴리오 모드에서 비활성화된다. 지도는 별도 키를 넣지 않으면 호출하지 않는 것을 원칙으로 한다.
