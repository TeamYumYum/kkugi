# backend AGENTS.md

이 문서는 `backend/`에서 작업할 때 루트 `AGENTS.md`에 더하여 적용하는 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계와 플랜·리뷰 절차는 루트 5장에 있습니다. 이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것이므로,
키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [API 공통 규약](../docs/api/conventions.md): 컨트롤러, DTO, 오류 코드를 작성할 때 2~5장과 13장을, 멱등이나 재시도를 다룰 때 7장을,
  FastAPI를 호출할 때 12장을 읽습니다. `(가정)` 표시 항목은 D가 확정하기 전입니다.
- [논리 ERD](../docs/design/erd.md)와 [스키마 규칙](../docs/design/schema-rules.md): entity를 추가하거나 바꿀 때, 마이그레이션을 작성할 때 읽습니다.
- [도메인 이벤트 목록](../docs/renewal/events.md): 이벤트를 발행하거나 구독하기 전에 읽습니다(ADR-0008).
- [요구사항 명세](../docs/requirements/README.md): 기능을 구현할 때 해당 도메인 파일을 읽습니다.
- [contracts/README.md](../contracts/README.md): API 계약을 바꿀 때 읽습니다(ADR-0009).
- [backend/README.md](README.md): 로컬 실행 환경을 준비하거나 스캐폴드로 도메인을 추가할 때 읽습니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 JDK 21이며, 첫 실행은 의존성을 내려받으므로 네트워크가 필요합니다.

- 작업 중 빠른 확인: `cd backend && ./gradlew test`를 실행합니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): `cd backend && ./gradlew build`를 실행합니다.
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

공통 관점(루트 5장)에 다음을 덧붙입니다. 트랜잭션 경계가 Service 메서드 단위인지, 쓰기 메서드에 `@Transactional`이 있는지
확인합니다. [사람]

## 5. 영역 규칙

- 레이어와 도메인 사이의 의존 규칙은 ArchUnit 테스트가 검사합니다. 규칙 목록과 출처 ADR은 [ADR README의 가드레일 표](../docs/adr/README.md)에 있습니다.
- 마이그레이션 도구는 아직 결정되지 않았습니다. 도구를 임의로 추가하지 않으며, 파일 규칙과 하위 호환 순서는 [스키마 규칙 7장](../docs/design/schema-rules.md)을 따릅니다.
- N+1 방지 기준(fetch join, 배치 크기 등)은 `TODO(확인 필요: Spring 홈 담당 D가 정합니다)`입니다.
- 로깅과 관측 기준(요청 로그 형식, 민감정보 마스킹, actuator 노출 범위)은 `TODO(확인 필요: 현재는 actuator health만 노출합니다. D와 C가 정합니다)`입니다.
