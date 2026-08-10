# Security policy

이 저장소는 포트폴리오용 로컬 데모이며 공개 인터넷 서비스를 운영하지 않습니다.

## 로컬 설정 원칙

- `.env.local`, `Secrets.xcconfig`, `local.properties`와 Firebase 설정 파일을 커밋하지 않습니다.
- 외부 서비스 키는 제공자 콘솔에서 앱 식별자·허용 API·사용량 한도를 제한합니다.
- `DJANGO_DEBUG=false`인 환경에서는 `DJANGO_SECRET_KEY`를 반드시 설정합니다.
- 공개 배포는 HTTPS, 명시적 `ALLOWED_HOSTS`·CORS origin, 별도 DB 계정과 비밀 저장소를 사용해야 합니다.

외부 서비스 자격증명은 저장소 밖에서 관리하며, 노출이 의심되면 제공자 콘솔에서 즉시 교체합니다.
