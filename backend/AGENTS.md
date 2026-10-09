# backend AGENTS.md

루트 `AGENTS.md`를 전제로 `backend/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
키트(ai-dev-harness)가 생성한 파일을 팀이 수정했다. 키트로 다시 생성하지 않는다.

## 1. 기준 문서

- [API 공통 규약](../docs/api/conventions.md) — 경로·응답 포장·오류·인증·멱등·페이징·SSE·FastAPI 호출·springdoc 규칙. `(가정)` 항목은 D 확정 전
- [논리 ERD](../docs/design/erd.md) · [물리 스키마 규칙과 마이그레이션 정책](../docs/design/schema-rules.md)
- [도메인 이벤트 목록](../docs/renewal/events.md) — 발행·구독의 기준(ADR-0008)
- [요구사항 명세](../docs/requirements/README.md) — 도메인별 파일
- [contracts/README.md](../contracts/README.md) — `openapi.json` 생성 흐름(ADR-0009)
- [ADR-0007](../docs/adr/0007-backend-feature-package.md) 패키지·ArchUnit 규칙, [ADR-0008](../docs/adr/0008-domain-events.md) 도메인 이벤트
- 실행·환경 변수·패키지 현황·스캐폴드는 [backend/README.md](README.md)

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: JDK 21. 첫 실행은 의존성을 내려받으므로 네트워크가 필요하다. MySQL·Redis는 필요 없다(테스트는 H2).

- 작업 중 빠른 확인: `cd backend && ./gradlew test`
- 작업 완료 전 필수(`harness.json verify`): `cd backend && ./gradlew build` (`spotlessCheck`·`test`·ArchUnit 포함)
- CI 전용: 없음. CI는 아직 없으므로 위 명령을 로컬에서 돌린다

형식은 `cd backend && ./gradlew spotlessApply`로 맞춘다(완료 검증 전에 실행).

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. 계약 문서(API·ERD·DB 스키마)의 변경, 또는 계약과 다른 구현
2. 다른 담당자 소유 도메인, `global/`·`infrastructure/`·`SecurityConfig` 같은 공통 코드의 변경
3. `@Transactional` 경계의 신설·변경, 한 유스케이스에서 둘 이상의 Repository 쓰기
4. 인증·인가 코드, 토큰·쿠키 처리
5. 메시지(Kafka 등) 발행·소비, 캐시(Redis 등) 키·TTL
6. 도메인 이벤트 추가·변경(ADR-08): 발행은 service에서만, 핸들러는 멱등하고 @TransactionalEventListener(AFTER_COMMIT), docs/renewal/events.md 갱신
7. 다른 도메인의 repository·entity를 직접 쓰는 변경(ADR-08: 조회는 그 도메인 public service의 읽기 전용 DTO로)
8. contracts/openapi.json에 반영되는 API 계약 변경(ADR-09: 웹 F·폰 A 리뷰)
9. harness.json 이 영역 설정의 layers·allow·disabled_rules 변경(컨벤션 규칙을 바꾸거나 끈다)

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 계약 정합성 · 정확성(경계 조건, 실패 경로) · 보안(입력 검증, Secret) · 테스트 실효성(플랜 목록과 실제 테스트의 대조) · 트랜잭션 경계(Service 메서드 단위, 쓰기 메서드의 @Transactional). [사람]

## 5. 영역 규칙

- 레이어와 의존 방향은 `harness.json` backend `layers`·`allow`이고 ArchUnit 테스트가 강제한다. service는 `dto.response`를 쓰지 않고(ADR-0007 규칙 1), controller는 엔티티를 직접 돌려주지 않는다(`XResponse.from(entity)`). 타 도메인 `repository`·`entity` 의존 금지, `ApplicationEventPublisher`는 service에서만.
- 마이그레이션: 도구 미결(Flyway 추천). 위치·파일 이름·**확장 → 전환 → 수축** 하위 호환 순서와 "병합된 파일 수정 금지"는 [스키마 규칙 7장](../docs/design/schema-rules.md). `ddl-auto: none`이라 Hibernate가 스키마를 만들지 않는다.
- 외부 호출(FastAPI)은 `infrastructure/ai`의 서비스 인터페이스로만. 타임아웃·오류 변환은 [API 규약 12장](../docs/api/conventions.md)(가정). 멱등·재시도는 7장, 페이징은 4장.
- 응답은 `ApiResponse<T>`, 오류는 `BusinessException(ErrorCode)`. 도메인 코드는 같은 enum에 추가한다(API 규약 5장).
- N+1 방지 기준(fetch join·배치 크기 등): `TODO(확인 필요: Spring 홈 담당 D가 정한다)`
- 로깅·관측 기준(요청 로그 형식, 민감정보 마스킹, actuator 노출 범위): `TODO(확인 필요: 현재 actuator health만 노출. D·C가 정한다)`
