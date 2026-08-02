# 방꾸석 포트폴리오 실기기 실행

현재 데모는 유료 외부 API 없이 로컬 MariaDB, Django API, 추천 FastAPI를 사용한다. 소셜 로그인 대신 `데모 시작` 버튼으로 `portfolio_demo` 계정에 진입한다.

## 아이폰 연결 후

1. 아이폰과 Mac을 같은 Wi-Fi에 연결한다.
2. 아이폰 잠금을 풀고 USB로 연결한 뒤 `이 컴퓨터를 신뢰`한다.
3. iOS 개발자 모드가 꺼져 있으면 아이폰의 `설정 > 개인정보 보호 및 보안 > 개발자 모드`를 켠다.
4. 아래 명령으로 로컬 서비스를 확인하고 앱을 실행한다.

```bash
cd /Users/yeoduchi/Documents/ex3bang9
./scripts/start_portfolio_services.sh
./scripts/run_portfolio_device.sh
```

실행 스크립트가 Mac의 현재 LAN IP와 연결된 iPhone ID를 자동으로 찾고, 디버거 없이 홈 화면에서 실행할 수 있는 iOS profile 앱을 빌드·설치한다.

## 캡처 권장 동선

`데모 시작` → 홈 가구 목록 → 새 가구 상세/장바구니 → 중고거래 목록/상세 → 커뮤니티 → 마이페이지 → AI 가구 추천 결과 순서로 캡처한다. 지도·소셜 로그인처럼 외부 키가 필요한 기능은 포트폴리오 데모에서 제외한다.

무료 Apple 개발 프로비저닝은 유효기간이 짧다. 만료되면 같은 실행 명령을 다시 수행하면 Xcode 자동 서명이 갱신된다.
