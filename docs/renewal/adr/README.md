# 리뉴얼 ADR 목록

> 2026-10-03 순차 결정. 기획서는 `../plan.md`. 결정 1개 = 파일 1개. 가드레일 키트 규칙 파일의 입력.

| # | 결정 | 한 줄 |
|---|---|---|
| [01](2026-10-03-01-native-android-wear.md) | 플랫폼 | 네이티브 Android(Kotlin+Compose) + Wear OS. Flutter 아님 |
| [02](2026-10-03-02-watch-companion-offline-first.md) | 워치 | Companion, 오프라인 우선, 서버·인증 모름, 세션 소유권 단일 |
| [03](2026-10-03-03-phone-offline-workout-only.md) | 폰 오프라인 | 운동 세션만 Room + WorkManager |
| [04](2026-10-03-04-android-two-layers.md) | Android 계층 | ui·data 2계층 + 조건부 UseCase(2개 이상 ViewModel 공유 시) |
| [05](2026-10-03-05-android-feature-modules.md) | Android 모듈 | `:app :wear :core :feature:{member,meal,workout,coaching,growth}`, feature 간 의존 금지 |
| [06](2026-10-03-06-di-hilt.md) | DI | Hilt |
| [07](2026-10-03-07-backend-feature-package.md) | 백엔드 패키지 | feelm식 기능 우선 + ArchUnit 규칙 3개 |
| [08](2026-10-03-08-domain-events.md) | 도메인 간 통신 | 도메인 이벤트 기본, 조회만 public service, Repository 접근 금지 |
| [09](2026-10-03-09-openapi-contract-generation.md) | API 계약 | OpenAPI 한 벌 → 웹 TS + Android Kotlin 생성 |
| [10](2026-10-03-10-web-react-vite.md) | 웹 | React+Vite, feelm 폴더 그대로. Next.js·Vue 아님 |
| [11](2026-10-03-11-mlflow-and-ai-ml-split.md) | AI/ML | `ai/` 추론 · `ml/` 학습 분리, MLflow |
| [12](2026-10-03-12-vertical-ownership.md) | 팀 구조 | 개인 수직 4 + 횡단 2, Workout만 B+F 페어, 리뷰어 = 상대 표면 홈 담당 |
| [13](2026-10-03-13-rest-fcm-sse.md) | 통신 | REST + FCM, RAG만 SSE, WebSocket 없음 |

## 가드레일 규칙 파일로 바로 옮길 수 있는 문장

- ViewModel은 Repository 인터페이스만 의존한다. DataSource·Retrofit·Room DAO를 직접 import하지 않는다. (04)
- UseCase는 2개 이상 ViewModel이 공유할 때만 만든다. PR에 사용처 2곳을 적는다. (04)
- `:feature:*`는 `:core`만 의존한다. feature 간 import 금지. (05)
- `:core`의 Room은 Workout 테이블만 가진다. (03)
- `..service..`는 `..dto.response..`를 import하지 않는다. (07)
- 타 도메인 `..repository..`에 의존하지 않는다. (07, 08)
- `ApplicationEventPublisher`는 `..service..`에서만 사용한다. (07, 08)
- 이벤트 핸들러는 멱등해야 하며 `@TransactionalEventListener(AFTER_COMMIT)`를 쓴다. (08)
- 웹·Android는 `generated/` 타입만 쓴다. 수동 DTO 금지. 생성 파일은 PR 마지막 커밋에서 재생성. (09)
- 모든 Claude 호출은 `claude_service.py` 경유. (11, v1 계승)
- 1 Story = 1 Branch = 1 PR. `feature/{JIRA-ID}-{slug}`. `develop` 없음. (12)
- PR 리뷰어 = 상대 표면 홈 담당. 공통 변경·계약 변경은 해당 홈 담당 승인. (12)
- SSE 중계 코드는 RAG 스토리 안에서만 작성한다. (13)
