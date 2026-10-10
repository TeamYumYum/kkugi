# backend AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `backend/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것입니다. 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [API 공통 규약](../docs/api/conventions.md): 경로, 응답 포장, 오류, 인증, 멱등, 페이징, SSE, FastAPI 호출, springdoc 작성 규칙입니다. `(가정)` 표시 항목은 D가 확정하기 전입니다.
- [논리 ERD](../docs/design/erd.md)와 [물리 스키마 규칙과 마이그레이션 정책](../docs/design/schema-rules.md)
- [도메인 이벤트 목록](../docs/renewal/events.md): 이벤트 발행과 구독의 기준입니다(ADR-0008).
- [요구사항 명세](../docs/requirements/README.md): 도메인별 파일을 봅니다.
- [contracts/README.md](../contracts/README.md): `openapi.json`의 생성 흐름입니다(ADR-0009).
- [ADR-0007](../docs/adr/0007-backend-feature-package.md)은 패키지 구조와 ArchUnit 규칙을, [ADR-0008](../docs/adr/0008-domain-events.md)은 도메인 이벤트를 정합니다.
- 실행 방법, 환경 변수, 패키지 현황, 스캐폴드는 [backend/README.md](README.md)에 있습니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 21입니다. 첫 실행은 의존성을 내려받으므로 네트워크가 필요합니다. 테스트는 H2로 돌기 때문에 MySQL과 Redis는 필요하지 않습니다.

- 작업 중 빠른 확인: `cd backend && ./gradlew test`를 실행합니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `cd backend && ./gradlew build`를 실행합니다. `spotlessCheck`, `test`, ArchUnit 테스트가 포함됩니다.
- CI 전용: 없습니다. CI가 아직 없으므로 위 명령을 로컬에서 실행합니다.

형식은 완료 검증 전에 `cd backend && ./gradlew spotlessApply`로 맞춥니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. 계약 문서(API, ERD, DB 스키마)를 변경하거나, 계약과 다르게 구현하는 경우입니다.
2. 다른 담당자가 소유한 도메인이나 `global/`, `infrastructure/`, `SecurityConfig` 같은 공통 코드를 변경하는 경우입니다.
3. `@Transactional` 경계를 신설하거나 변경하는 경우, 또는 한 유스케이스에서 둘 이상의 Repository에 쓰는 경우입니다.
4. 인증과 인가 코드, 토큰과 쿠키 처리를 변경하는 경우입니다.
5. 메시지(Kafka 등)를 발행하거나 소비하는 경우, 캐시(Redis 등)의 키나 TTL을 변경하는 경우입니다.
6. 도메인 이벤트를 추가하거나 변경하는 경우입니다(ADR-08). 발행은 service에서만 하고, 핸들러는 멱등해야 하며 `@TransactionalEventListener(AFTER_COMMIT)`을 사용하고, `docs/renewal/events.md`를 갱신합니다.
7. 다른 도메인의 repository나 entity를 직접 쓰는 경우입니다(ADR-08). 조회는 그 도메인의 public service가 돌려주는 읽기 전용 DTO로 합니다.
8. `contracts/openapi.json`에 반영되는 API 계약을 변경하는 경우입니다(ADR-09). 웹 F와 폰 A가 리뷰합니다.
9. `harness.json`에서 이 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. 계약 정합성, 정확성(경계 조건과 실패 경로), 보안(입력 검증과 Secret), 테스트 실효성(플랜 목록과 실제 테스트의 대조), 트랜잭션 경계(Service 메서드 단위, 쓰기 메서드의 `@Transactional`)를 확인합니다. [사람]

## 5. 영역 규칙

- 레이어와 의존 방향은 `harness.json` backend 영역의 `layers`와 `allow`가 정하고 ArchUnit 테스트가 강제합니다. service는 `dto.response`를 쓰지 않고(ADR-0007 규칙 1), controller는 엔티티를 직접 돌려주지 않고 `XResponse.from(entity)`로 변환합니다. 다른 도메인의 `repository`와 `entity`에 의존하지 않으며, `ApplicationEventPublisher`는 service에서만 사용합니다.
- 마이그레이션 도구는 미결이며 Flyway가 추천되어 있습니다. 파일 위치와 이름, 확장 → 전환 → 수축 순서의 하위 호환 규칙, 병합된 파일을 수정하지 않는 규칙은 [스키마 규칙 7장](../docs/design/schema-rules.md)에 있습니다. `ddl-auto: none`이므로 Hibernate는 스키마를 만들지 않습니다.
- 외부 호출(FastAPI)은 `infrastructure/ai`의 서비스 인터페이스로만 합니다. 타임아웃과 오류 변환은 [API 규약 12장](../docs/api/conventions.md)(가정)을, 멱등과 재시도는 7장을, 페이징은 4장을 따릅니다.
- 응답은 `ApiResponse<T>`로 포장하고, 오류는 `BusinessException(ErrorCode)`로 던집니다. 도메인 오류 코드는 같은 enum에 추가합니다(API 규약 5장).
- N+1 방지 기준(fetch join, 배치 크기 등)은 `TODO(확인 필요: Spring 홈 담당 D가 정합니다)`입니다.
- 로깅과 관측 기준(요청 로그 형식, 민감정보 마스킹, actuator 노출 범위)은 `TODO(확인 필요: 현재는 actuator health만 노출합니다. D와 C가 정합니다)`입니다.
