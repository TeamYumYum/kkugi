# API 공통 규약

| 항목 | 값 |
|---|---|
| 상태 | 초안 (제안). D(Spring 홈) 확정 전. `ApiResponse`·`ErrorCode`·`GlobalExceptionHandler`·`SecurityConfig`의 "초안" 표시와 함께 확정한다 |
| 소유 | D |
| 적용 | Spring `/api/v1/**`. Spring ↔ FastAPI 내부 호출은 12장 |
| 관련 | [ADR-0007](../adr/0007-backend-feature-package.md), [ADR-0009](../adr/0009-openapi-contract-generation.md), [ADR-0013](../adr/0013-rest-fcm-sse.md), [contracts/README.md](../../contracts/README.md), `backend/.../global/`, `web/src/api/client.ts`, `.harness/templates/spring-java/domain/Controller.java` |

이미 코드에 있는 것은 그대로 적고, 아직 없는 것은 `(가정)`으로 표시했다. 확정하면 표기를 지우고 코드와 맞춘다.

## 1. 기본

- REST + JSON. 모든 CRUD·조회(ADR-0013).
- 접두사는 `/api/v1`. 컨트롤러 템플릿과 웹 클라이언트(`API_BASE`)가 이미 이 값을 쓴다.
- 서버 → 클라이언트 푸시는 FCM, 스트리밍은 RAG 채팅 SSE 한 곳만. WebSocket 없음.
- 폰·웹은 Spring만 안다. FastAPI(`/ai/**`)는 Spring `infrastructure/ai`만 부른다.
- 문자 인코딩은 UTF-8. `Content-Type: application/json; charset=utf-8`.

## 2. 경로와 명명

| 규칙 | 예 | 상태 |
|---|---|---|
| 리소스는 명사, kebab-case | `/api/v1/meals`, `/api/v1/workout-sessions` | (가정) |
| 복수형 | `/meals`, `/routines` | (가정) 미결. 스캐폴드 템플릿은 스캐폴드 이름을 그대로 kebab-case로 쓰므로(`MealRecord` → `/meal-record`) 복수형으로 하려면 이름을 복수로 넘기거나 생성 후 고친다 |
| 로그인 사용자 자신의 리소스는 `me` | `/members/me`, `/members/me/profile` | (가정) |
| 경로에 다른 회원 ID를 노출하지 않는다. memberId는 토큰에서 얻는다 | `/meals?date=2026-10-04` | (가정) |
| 하위 리소스는 중첩 1단계까지 | `/meals/{mealId}/items` | (가정) |
| 상태를 바꾸는 행위는 하위 POST | `POST /workout-sessions/{id}/complete` | (가정) |
| 경로 변수는 `{id}` 또는 `{리소스Id}` | `{mealId}` | (가정) |
| 쿼리 파라미터는 camelCase | `?date=`, `?from=&to=`, `?page=&size=` | (가정) |

## 3. 요청

- 본문은 JSON, 필드는 camelCase. Java record 필드명이 그대로 나간다.
- 본문 검증은 `@Valid`와 Bean Validation. 검증 실패는 400 `INVALID_INPUT`(5장).
- 날짜는 `yyyy-MM-dd`, 시각은 오프셋이 있는 ISO-8601(`2026-10-04T18:30:00+09:00`) (가정). 서버는 Asia/Seoul로 해석한다.
- 열거 값은 대문자 SNAKE_CASE 문자열. 모르는 값은 400.
- 파일 업로드(식사 사진)는 `multipart/form-data`, 파일 파트 이름은 `image`, 나머지 필드는 `request` JSON 파트 (가정). 최대 크기는 설정값.
- 멱등 키가 필요한 요청은 본문 필드로 받는다(`clientUuid`). 별도 헤더 규약은 두지 않는다 (가정, 7장).

## 4. 응답

모든 응답은 `ApiResponse<T>`로 포장한다(ADR-0007). 코드에 있는 모양:

```json
{ "success": true,  "data": { "...": "..." }, "error": null }
{ "success": false, "data": null, "error": { "code": "NOT_FOUND", "message": "리소스를 찾을 수 없다" } }
```

| 상황 | HTTP | 본문 | 상태 |
|---|---|---|---|
| 조회·수정 성공 | 200 | `data`에 리소스 | 코드 |
| 생성 성공 | 201 + `Location` | `data`에 생성된 리소스 | 템플릿 |
| 삭제·본문 없는 성공 | 200, `data: null` | 204를 쓰지 않는다. 포장을 유지해 생성 타입이 단순해진다 | (가정) |
| 목록 | 200 | `data: { "items": [...], "page": 0, "size": 20, "totalElements": 57 }` | (가정) |
| 실패 | `ErrorCode`의 상태 | `error.code`·`error.message` | 코드 |

- `null` 필드는 생략하지 않고 `null`로 보낸다. 생성 타입에서 optional과 nullable이 구분되도록 `@Schema(nullable = true)`를 적는다 (가정).
- 페이징은 offset 방식. `page` 0부터, `size` 기본 20·최대 100, `sort=field,desc` (가정). 무한 스크롤이 필요한 목록(식사 기록 등)은 날짜 범위 조회로 대신한다.
- 시각은 요청과 같은 ISO-8601 오프셋 형식으로 돌려준다.
- 응답 DTO는 `dto/response/{기능}Response` record이고 `static from(entity)`로 만든다(ADR-0007). service는 response를 모른다.

## 5. 오류

- `error.code`는 `ErrorCode` enum 이름 그대로다. 클라이언트는 `code`로만 분기하고 `message`로 분기하지 않는다.
- 공통 코드(코드에 있음): `INVALID_INPUT` 400, `UNAUTHORIZED` 401, `FORBIDDEN` 403, `NOT_FOUND` 404, `METHOD_NOT_ALLOWED` 405, `CONFLICT` 409, `INTERNAL_ERROR` 500.
- 도메인 코드는 각 담당이 같은 enum에 추가한다. 도메인 전용 예외 클래스는 만들지 않고 `BusinessException(ErrorCode)`를 던진다.
- 도메인 코드 이름은 `{도메인}_{이유}` (가정). 예 `MEMBER_ALREADY_ONBOARDED` 409, `MEMBER_NOT_ONBOARDED` 403, `MEAL_RECOGNITION_UNAVAILABLE` 503. HTTP 상태는 enum에 함께 둔다.
- 검증 실패 메시지는 `필드명: 메시지` 한 건(첫 번째 오류)이다. 전체 필드 오류 목록이 필요해지면 `error.details` 배열을 추가하되 기존 필드는 유지한다 (가정).
- 처리되지 않은 예외는 500과 고정 메시지. 내부 메시지는 로그에만 남는다.
- 다른 회원의 리소스는 존재를 숨기기 위해 403이 아니라 404 (가정, 요구사항 공통 미결).
- 401·403은 보안 필터 단계에서 나므로 `SecurityConfig`의 EntryPoint·AccessDeniedHandler가 같은 `ApiResponse` 모양을 쓴다. 인증 방식 결정 시 함께 구현한다.

## 6. 인증 (가정)

인증 방식은 미결(기획서 9장, D·C 1주차)이다. 아래는 기획서가 추천한 v1 방식 기준 초안이다.

- `Authorization: Bearer <access token>`. access는 짧게(설정값), refresh는 길게(설정값). refresh는 Redis에 두고 로그아웃 시 블랙리스트.
- 공개 경로: `/actuator/health`, `/v3/api-docs/**`, `/swagger-ui/**`(코드), 로그인·토큰 재발급·개발용 이메일 로그인(추가 예정). 나머지 `/api/v1/**`는 인증 필수.
- 웹 클라이언트는 현재 `credentials: 'include'`로 쿠키를 보낼 준비만 돼 있다. 헤더와 쿠키 중 무엇으로 전달할지는 인증 설계와 함께 정한다. 결정되면 `client.ts`와 Android 네트워크 모듈을 같은 MR에서 맞춘다.
- 토큰에는 memberId와 role만 담는다. 신체 정보 같은 개인정보는 넣지 않는다.
- 관리자 API는 `ADMIN` 역할 검사. 실패는 403 `FORBIDDEN`.

## 7. 멱등과 재시도

- 워치·폰 세션 업로드는 기기가 만든 `clientUuid`를 본문에 담는다. 서버는 같은 UUID가 오면 새로 만들지 않고 **기존 리소스를 200으로** 돌려준다(ADR-0003). 409를 쓰지 않는다 (가정).
- 온보딩 완료처럼 "한 번만" 하는 요청은 두 번째부터 409 `CONFLICT` 계열 코드.
- 클라이언트 재시도는 GET과 멱등이 보장된 POST에만, 지수 백오프(가정: 1·2·4초, 최대 3회). 그 밖의 POST는 자동 재시도하지 않는다.
- 이벤트 핸들러의 멱등은 API가 아니라 유일 제약으로 지킨다([스키마 규칙 4장](../design/schema-rules.md)).

## 8. 버전

- `/api/v1` 하나만 둔다. 8주 안에 `v2`를 만들지 않는다 (가정).
- 호환을 깨는 변경은 계약 변경 MR로 서버와 소비 표면을 함께 고친다. 생성 타입이 컴파일 에러로 알려 준다(ADR-0009).
- 필드 추가는 호환 변경이다. 필드 삭제·이름 변경·타입 변경·필수화는 비호환 변경이고 소비 표면 담당 리뷰가 필수다.

## 9. SSE (RAG 채팅만)

- `Content-Type: text/event-stream`. Spring이 FastAPI 스트림을 그대로 중계한다(ADR-0013). 코드는 RAG 스토리 안에서만 작성한다.
- 이벤트 이름 (가정): `token`(본문 조각), `done`(완료, 메시지 ID), `error`(코드). 각 `data`는 JSON.
- 경로: nginx는 `/api/chat/stream`에 `proxy_buffering off`를 걸어 두었다(infra/README). `/api/v1` 접두사와 어긋나므로 실제 경로를 `/api/v1/chat/stream`으로 통일하고 nginx 설정을 맞출지 C·D가 정한다. **확인 필요.**

## 10. FCM 페이로드

- data 메시지만 쓰고 페이로드는 최소: `type`(가정: `STREAK_REMINDER`, `LAST_MEAL`, `WEEKLY_REPORT`)과 관련 `id`. 본문 텍스트를 넣지 않고 클라이언트가 REST로 재조회한다(ADR-0013).
- 발송은 `infrastructure/fcm`, 조건 판단은 Coaching 이벤트 핸들러.

## 11. 클라이언트 규칙

- 웹·Android는 `generated/` 타입만 쓴다. 수동 DTO 금지. 생성 파일은 MR 마지막 커밋에서 재생성한다(ADR-0009).
- 웹 `request<T>()`는 2xx가 아니면 `ApiError(status, body)`를 던진다. 호출 측은 `body.error.code`로 분기한다.
- 오프라인 처리는 운동 세션만(요구사항 REQ-NF-01). 나머지 네트워크 오류는 안내 메시지.

## 12. Spring ↔ FastAPI 내부 호출

- 경로 `/ai/**`. 계약은 FastAPI 내장 OpenAPI → `contracts/ai-openapi.json`. `ai/app/schemas` 변경은 E 리뷰 필수.
- 호출은 `infrastructure/ai`의 서비스 인터페이스로만 한다. 도메인 코드가 HTTP 클라이언트를 직접 쓰지 않는다(ADR-0007).
- 타임아웃 (가정): vision 10초, plan·routine·meal 30초, chat 스트림 120초. 설정값으로 둔다.
- FastAPI의 오류 본문(`detail`)을 그대로 밖으로 내보내지 않는다. 도메인별 폴백 또는 도메인 오류 코드로 바꾼다(요구사항 Meal 3장, Coaching REQ-COACH-02).
- FastAPI는 업무 DB에 쓰지 않는다. 필요한 데이터는 요청 본문으로 넘긴다(ADR-0011).

## 13. springdoc 작성 규칙

생성 타입의 품질은 어노테이션이 정한다(contracts/README).

- 컨트롤러마다 `@Tag(name = "도메인")`. 메서드마다 `@Operation(summary = "한 줄")` (가정).
- 응답 DTO 필드에 `@Schema(description, nullable, requiredMode)`. nullable과 enum을 빠뜨리지 않는다.
- enum 필드는 Java enum 타입으로 선언해 OpenAPI `enum`으로 나가게 한다. 문자열로 두지 않는다.
- 오류 응답은 공통 `ApiResponse<Void>`로 문서화한다. 엔드포인트별 오류 코드 목록은 `@Operation(description)`에 적는다.
- `GET /v3/api-docs`가 곧 계약이다. 로컬에서 `./gradlew bootRun` 뒤 확인한다. CI 재생성 단계는 미정(contracts/README).

## 14. 변경 절차

1. 이 문서를 고친다. 코드에 있는 항목이면 `global/`도 같은 MR에서 고친다(공통 코드, D 승인).
2. backend 엄격 판정(트리거 1·8). 소비 표면 담당(웹 F, 폰 A)을 리뷰어에 넣는다.
3. 생성 타입을 MR 마지막 커밋에서 재생성한다.

## 15. 미결

| 항목 | 결정자 | 기한 |
|---|---|---|
| 리소스 단수·복수형과 스캐폴드 템플릿 처리 | D | 1주차 |
| 인증 방식과 전달 방식(헤더 / 쿠키) | D·C | 1주차 |
| SSE 경로 접두사와 nginx 설정 | C·D | RAG 스토리 전 |
| 페이징 방식(offset / 날짜 범위) | D·F | 2주차 |
| 시각 포맷(오프셋 포함 여부) | D·A | 1주차 |
| 타인 리소스 404 vs 403 | D | 1주차 |
| 멀티파트 파트 이름과 크기 상한 | D·A | 2주차 |
