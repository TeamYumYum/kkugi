# backend

냠냠코치 Spring Boot 백엔드. 1주차 셸(실행·빌드·테스트가 도는 골격과 공통 기반 초안)만 있다.
작업 규칙은 [AGENTS.md](./AGENTS.md), 구조 결정은 [ADR-07](../docs/adr/0007-backend-feature-package.md)을 본다.

## 버전

| 항목 | 버전 |
| --- | --- |
| Java(toolchain) | 21 |
| Gradle(wrapper) | 8.14.3 |
| Spring Boot | 4.0.8 (`io.spring.dependency-management` 1.1.7) |
| springdoc-openapi | 3.0.3 (Boot 4.0.x 기준 라인) |
| Spotless / google-java-format | 7.2.1 / 1.28.0 AOSP |
| ArchUnit(archunit-junit5) | 1.4.1 |

버전은 키트 spring-java 프로필 리허설에서 빌드가 검증된 값이다. 바꾸면 `build.gradle` 변경이라 엄격 판정이다.

## 실행과 검증

저장소 루트에서 실행한다.

```bash
cd backend && ./gradlew build          # 영역 검증 명령(spotlessCheck·test 포함). MySQL·Redis 없이 돈다
cd backend && ./gradlew spotlessApply  # 형식 맞추기(google-java-format AOSP)
cd backend && ./gradlew bootRun        # 로컬 실행. MySQL·Redis가 떠 있어야 한다
```

- 테스트는 `src/test/resources/application.yml`(H2 메모리 DB, MySQL 호환 모드)이 main 설정을 가린다.
- 기동 후 관리 포트의 `GET :8081/actuator/health`, `GET /v3/api-docs`, `/swagger-ui/index.html`로 상태와 문서를 확인한다.

## 환경 변수

`src/main/resources/application.yml`이 읽는다. 값은 커밋하지 않는다([Secret 규칙](../docs/secret-environment-variables.md)).
`.env.example`은 아직 만들지 않았다(위치 결정 필요: 규칙 문서는 서비스 디렉터리, 1주차 계획은 `infra/`).

| 이름 | 필수 | Secret | 기본값 | 용도 |
| --- | --- | --- | --- | --- |
| `DB_HOST` | 선택 | 아니오 | `localhost` | MySQL 호스트 |
| `DB_PORT` | 선택 | 아니오 | `3306` | MySQL 포트 |
| `DB_NAME` | 선택 | 아니오 | `nyamnyam` | 스키마 이름 |
| `DB_USERNAME` | 필수 | 예 | (없음) | MySQL 계정 |
| `DB_PASSWORD` | 필수 | 예 | (없음) | MySQL 비밀번호 |
| `REDIS_HOST` | 선택 | 아니오 | `localhost` | Redis 호스트 |
| `REDIS_PORT` | 선택 | 아니오 | `6379` | Redis 포트 |
| `REDIS_PASSWORD` | 선택 | 예 | (없음) | Redis 비밀번호 |
| `SERVER_PORT` | 선택 | 아니오 | `8080` | HTTP 포트 |
| `APP_ENV` | 선택 | 아니오 | `local` | 지표 태그·로그 필드 `env` |
| `APP_VERSION` | 선택 | 아니오 | `dev` | 지표 태그·로그 필드 `version` |

인증(JWT·OAuth 키), FastAPI 주소, FCM, MLflow 주소는 해당 기능을 붙이는 작업에서 추가한다.

## 관측

설정은 `src/main/resources/observability.yml`에 있고, main과 테스트의 `application.yml`이 함께 import한다.
테스트(`global/config/ObservabilityConfigTest`)가 이 파일을 그대로 검증한다.

- **지표**: actuator는 관리 포트 `8081`에만 있고 `health`·`prometheus`만 연다. nginx는 `8080`의 `/api/`만 프록시하므로 외부에서 닿지 않는다.
  공통 태그는 `service`·`env`·`version`이다. `http.server.requests`는 히스토그램 버킷을 낸다(p95·p99).
- **로그**: 콘솔에 Logstash 형식 JSON을 한 줄씩 낸다. `service`·`env`·`version` 필드가 붙고, OTel Java Agent가 붙어 있으면 `trace_id`·`span_id`도 나온다.
- **추적**: 앱 코드에는 추적 의존성이 없다. 로컬 관측 overlay가 OTel Java Agent를 붙인다([infra/README.md](../infra/README.md)).
- 사용자 ID·trace_id처럼 값이 많은 것은 지표 태그로 쓰지 않는다. 바인딩 값, 토큰, 요청 본문을 로그 메시지에 넣지 않는다.

## 패키지 구조

기본 패키지 `com.nyamnyam.backend`. 빈 디렉터리는 git이 추적하지 않으므로, 아직 코드가 없는 패키지는 아래 표로만 둔다.

| 패키지 | 상태 | 내용 |
| --- | --- | --- |
| `NyamnyamApplication` | 있음 | 진입점 |
| `global/response` | 있음(초안) | `ApiResponse<T>` — `success`·`data`·`error{code,message}`, `ok(T)`·`error(ErrorCode)` |
| `global/error` | 있음(초안) | `ErrorCode`(공통 코드), `BusinessException`, `GlobalExceptionHandler` |
| `global/security` | 있음(초안) | `SecurityConfig` — stateless, CSRF·폼 로그인 끔. **1주차는 모든 요청 허용**(TODO: 인증 방식 확정 후 `authenticated()`) |
| `global/config` | 있음 | `OpenApiConfig`(springdoc 문서 정보). 관측 설정은 `observability.yml`(위 "관측" 절) |
| `global/event` | 예정 | 도메인 이벤트 공통 인프라(ADR-08: `@Async`, 실패 로그·재시도) — D |
| `global/properties` | 예정 | `@ConfigurationProperties` 묶음 |
| `domain/{member,meal,workout,coaching,growth,admin}` | 예정 | 기능 우선 패키지 `controller`·`dto/request`·`dto/response`·`entity`·`event`·`repository`·`service`(ADR-07) |
| `infrastructure/ai` | 예정 | FastAPI 클라이언트(ADR-07·09). 다른 도메인은 이 패키지의 서비스 인터페이스만 호출 |
| `infrastructure/fcm` | 예정 | FCM 발송(ADR-13) |
| `infrastructure/oauth` | 예정 | 카카오·구글 로그인 연동 |
| `infrastructure/mlflow` | 예정 | MLflow REST 프록시(ADR-11) |

`global/`·`infrastructure/`·`SecurityConfig` 변경은 공통 코드 변경(엄격, D 승인)이다.
초안 표시가 있는 공통 계약(`ApiResponse`·`ErrorCode`·`GlobalExceptionHandler`·`SecurityConfig`)은 D가 확정한다.

## 컨벤션 테스트

`src/test/java/com/nyamnyam/backend/architecture/`의 ArchUnit 테스트 두 개는 하네스가 생성·관리한다(손으로 고치지 않는다).
`harness.json` backend 영역의 `layers`·`allow`가 계층 규칙이다. 특히 service는 `dto.response`를 쓰지 못하고(ADR-07 규칙 1),
controller는 엔티티 타입을 직접 쓰지 못한다(service가 돌려준 엔티티를 `XResponse.from(...)`에 바로 넘긴다).

## 도메인 스캐폴드

```bash
python <키트>/bin/harness.py scaffold backend domain MealRecord --target .
cd backend && ./gradlew spotlessApply && ./gradlew build
```

저장소의 `.harness/templates/spring-java/domain/`이 키트 기본 템플릿을 덮어쓴다.

| 덮어쓴 파일 | 키트 기본과 다른 점 |
| --- | --- |
| `Controller.java` | `ResponseEntity<ApiResponse<…>>` 반환, 엔티티 → 응답 DTO 변환, `@Valid` |
| `ControllerTest.java` | `$.success`·`$.data.*`·`$.error.code`로 포장된 응답을 검증, 없는 리소스 404 |
| `Service.java` | 응답 DTO 대신 엔티티 반환(계층 규칙), 없는 리소스는 `BusinessException(ErrorCode.NOT_FOUND)` |
| `ServiceTest.java` | 엔티티 반환·`BusinessException` 기대값 |

이름 길이에 따라 줄바꿈이 달라지므로 생성 뒤 `spotlessApply`를 실행한다. 보안 설정 허용 경로와 DB 마이그레이션은
스캐폴드가 고치지 않는다(출력되는 조각을 보고 직접 붙인다).

## API 계약

springdoc이 `/v3/api-docs`로 내보내는 문서가 `contracts/openapi.json`의 원천이다(ADR-09). 생성 방식은
[contracts/README.md](../contracts/README.md)를 본다.
