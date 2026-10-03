# 기술 결정 기록 (ADR)

**아키텍처와 핵심 기술 선택**처럼 한 번 정하면 프로젝트 전체에 영향을 주는 결정만 **결정 1건당 문서 1개**로 기록합니다. 결정의 배경·대안·감수한 것이 남아 있어야 나중에 "왜 이렇게 했지?"에 답할 수 있고, 바꿀 때 무엇을 다시 검토해야 하는지 알 수 있습니다.

## 무엇을 ADR로 남기나

- 아키텍처·서비스 경계 결정
- 핵심 기술·프레임워크·저장소 선택
- 전 테이블·전 API에 걸치는 기술 규약(식별자 타입, 인증 방식 등)

**ADR 대상이 아닌 것**은 각 기준 문서에 기록합니다. 데이터 모델 세부는 ERD, API 규약 세부는 API 명세, 제품 정책은 요구사항 정의서, 값·임계치는 설정값입니다.

## 상태

| 상태 | 의미 |
|---|---|
| 제안 | 회의 안건. 본문의 결정은 `(가정)` 초안값 |
| 채택 | 팀이 결정. 구현·문서의 기준 |
| 대체 | 새 ADR로 바뀜. `관련`에 대체한 ADR 번호를 적고 본문은 수정하지 않음 |
| 폐기 | 전제가 사라져 무효 |

## 규칙

- 파일명은 `NNNN-kebab-case.md`, 번호는 순차 증가하며 재사용하지 않습니다. 새 ADR은 [`0000-template.md`](./0000-template.md)를 복사해 작성합니다.
- **채택된 ADR의 결정 내용은 수정하지 않습니다.** 바꾸려면 새 ADR을 쓰고 이전 ADR을 `대체`로 표시합니다. 오타·링크 수정은 예외입니다.
- `맥락`·`고려한 대안`은 결정 당시의 사실을 남기는 기록이므로 이후 상황이 바뀌어도 갱신하지 않습니다. 가리키는 대상이 바뀐 참조 링크만 정정합니다.
- 제안 → 채택으로 바뀌면 상태·결정일·결정자를 채우고 본문의 `(가정)`을 제거합니다.
- ADR 추가·상태 변경도 Jira 업무 항목과 MR을 거칩니다.

## 목록

0001~0013은 리뉴얼 기획 단계(2026-10-03)에 한 번에 결정했다. 배경은 [기획서](../renewal/plan.md).
본문·규칙 파일(`harness.json`, 영역 `AGENTS.md`, 컨벤션 테스트 주석)에서 `ADR-08`처럼 두 자리로 쓴 것은 `ADR-0008`을 뜻한다.

| ADR | 결정 | 상태 |
|---|---|---|
| [ADR-0001](0001-native-android-wear.md) | 모바일은 네이티브 Android(Kotlin + Compose) + Wear OS — Flutter 아님 | 채택 |
| [ADR-0002](0002-watch-companion-offline-first.md) | 워치는 오프라인 우선 보조 앱(Companion) — 서버·인증을 모른다 | 채택 |
| [ADR-0003](0003-phone-offline-workout-only.md) | 폰 오프라인 범위는 운동 기록만 | 채택 |
| [ADR-0004](0004-android-two-layers.md) | Android 계층은 ui · data 2계층 + 조건부 UseCase | 채택 |
| [ADR-0005](0005-android-feature-modules.md) | Android 모듈은 :app · :wear · :core · :feature:{도메인}×5 | 채택 |
| [ADR-0006](0006-di-hilt.md) | DI는 Hilt | 채택 |
| [ADR-0007](0007-backend-feature-package.md) | 백엔드 패키지는 feelm식 기능 우선 + ArchUnit 규칙 3개 | 채택 |
| [ADR-0008](0008-domain-events.md) | 도메인 간 통신은 도메인 이벤트 — 조회만 공개 서비스 호출 ([이벤트 목록](../renewal/events.md)) | 채택 |
| [ADR-0009](0009-openapi-contract-generation.md) | API 계약은 OpenAPI 한 벌에서 웹·Android 클라이언트 타입을 생성한다 | 채택 |
| [ADR-0010](0010-web-react-vite.md) | 웹은 React + Vite, feelm 폴더 구조 그대로 — Next.js·Vue 아님 | 채택 |
| [ADR-0011](0011-mlflow-and-ai-ml-split.md) | 추론(ai/)과 학습(ml/)을 분리하고, ML 아티팩트는 MLflow에 | 채택 |
| [ADR-0012](0012-vertical-ownership.md) | 개인 수직 소유 4 + 횡단 2, Workout만 페어 — 리뷰어는 상대 표면 홈 담당 | 채택 |
| [ADR-0013](0013-rest-fcm-sse.md) | 서버 통신은 REST + FCM, RAG 채팅만 SSE — WebSocket 없음 | 채택 |

## 가드레일 규칙 파일로 옮긴 문장

ADR에서 기계적으로 검사할 수 있게 뽑은 문장. 괄호는 출처 ADR, 화살표는 현재 강제 위치.

- ViewModel은 Repository 인터페이스만 의존한다. DataSource·Retrofit·Room DAO를 직접 import하지 않는다. (0004) → Konsist `viewmodel-repository-only`
- UseCase는 2개 이상 ViewModel이 공유할 때만 만든다. (0004) → Konsist `usecase-shared-by-two-viewmodels`
- `:feature:*`는 `:core`만 의존한다. feature 간 import 금지. (0005) → Gradle 의존 선언 + `:app` 조립
- `:core`의 Room은 Workout 테이블만 가진다. feature는 Room을 쓰지 않는다. (0003) → Konsist `feature-no-room`
- 워치는 서버·인증을 모른다. (0002) → Konsist `wear-no-network`
- `:app`은 네비게이션·DI 루트·조립만 한다. (0005) → Konsist `app-no-data-layer`
- `..service..`는 `..dto.response..`를 import하지 않는다. (0007) → ArchUnit 계층 규칙
- 타 도메인 `..repository..`·`..entity..`에 의존하지 않는다. (0007, 0008) → ArchUnit `no-cross-domain-persistence`
- `ApplicationEventPublisher`는 `..service..`에서만 사용한다. (0007, 0008) → ArchUnit `event-publisher-in-service-only`
- 이벤트 핸들러는 멱등하며 `@TransactionalEventListener(AFTER_COMMIT)`를 쓴다. (0008) → backend 트리거 6 (사람)
- 웹·Android는 `generated/` 타입만 쓴다. 수동 DTO 금지. 생성 파일은 PR 마지막 커밋에서 재생성. (0009) → web·core 트리거 (사람)
- 모든 Claude 호출은 `claude_service.py` 경유. (0011, v1 계승) → ai/README (사람)
- 1 Story = 1 Branch = 1 PR. `develop` 없음. (0012) → Git 컨벤션
- PR 리뷰어 = 상대 표면 홈 담당. 공통·계약 변경은 해당 홈 담당 승인. (0012) → Git 컨벤션 4장
- SSE 중계 코드는 RAG 스토리 안에서만 작성한다. (0013) → 사람
