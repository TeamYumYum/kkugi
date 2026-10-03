# ADR-07: 백엔드 패키지는 feelm식 기능 우선 + ArchUnit 규칙 3개

**Date:** 2026-10-03

## Context

레포에 서로 다른 관행이 둘 있다.
- **feelm식**(`S15P21E106-980`): `domain/{x}/{controller, dto/request, dto/response, entity, event, repository, service}` + `global/` + `infrastructure/`. 레이어 방향은 리뷰로 지킴.
- **yumyum v1식**(기존 CLAUDE.md): `domain/{x}/{presentation/dto, application, domain, infrastructure/client}`. Request→Command→Entity→Result→Response 변환으로 레이어 방향을 패키지로 강제.

6인·8주, 도메인 4개를 4명이 개인 수직 소유. 가드레일 키트가 규칙을 기계적으로 검사할 수 있다.

## Decision

**feelm식 패키지**를 쓴다.

```
com.nyamnyam.backend/
├── domain/{member,meal,workout,coaching,growth,admin}/
│   ├── controller/     HTTP 수신·변환·응답 포장만
│   ├── dto/request/    {기능}Request (record)
│   ├── dto/response/   {기능}Response (record, static from(entity))
│   ├── entity/
│   ├── event/          도메인 이벤트 (ADR-08)
│   ├── repository/
│   └── service/        트랜잭션·비즈니스 규칙·이벤트 발행
├── global/             config · security · error · response(ApiResponse) · properties
└── infrastructure/     ai(FastAPI 클라이언트) · fcm · oauth · mlflow
```

레이어 방향은 패키지가 아니라 **ArchUnit 테스트 3개**로 강제한다:
1. `..service..`는 `..dto.response..`를 import하지 않는다. (service는 entity 또는 service 전용 Result를 반환, controller가 Response로 변환)
2. `..domain.{x}..`는 다른 도메인의 `..repository..`에 의존하지 않는다. (ADR-08)
3. `ApplicationEventPublisher`는 `..service..`에서만 사용한다.

v1의 DTO 접미사 규칙(Request/Response, 외부 송수신은 ClientRequest/ClientResponse)은 유지한다. Command/Result 레이어는 두지 않는다.

## Rationale

- **기능 하나 = 폴더 하나에 파일 7개.** v1식은 11개 + 변환 코드 4군데. 변환 코드는 Claude가 만들어 줘도 리뷰 양은 그대로다.
- **초기 스타트업 Spring 코드베이스의 사실상 표준**이다. 새 팀원이 설명 없이 읽는다.
- v1식이 패키지로 강제하던 것(service의 HTTP 무지)은 **규칙 한 줄 + ArchUnit 테스트 1개**로 같은 효과를 낸다. 가드레일 키트가 할 일이 정확히 이것.
- 도메인 폴더가 자기완결적이라 개인 수직 소유(A는 `domain/meal/`만)와 일치.

## Alternatives Considered

- **yumyum v1식**: 기존 CLAUDE.md 규칙 재사용 가능. 변환 보일러플레이트가 6인·8주에서 발목. 2인 팀 시절의 선택. 기각.
- **feelm식 + Command/Result만 추가(중간)**: 변환 2군데. 이점이 ArchUnit 규칙 1과 겹침. 기각.
- **헥사고날(port·adapter)**: 파일 16개+. 8주 CRUD 서비스에서 교체할 인프라가 없음. 기각.

## Consequences

- service가 비대해지면 **유스케이스별 service 분리**를 허용한다(`MealRecordService`, `MealCorrectionService`). 한 service 300줄 넘으면 분리 검토(규칙 파일).
- controller는 `ResponseEntity<ApiResponse<T>>`로 통일(v1 규칙 유지).
- ArchUnit 테스트는 1주차에 D(Spring 홈)가 `backend/src/test/.../ArchitectureTest.java`로 작성하고 CI에 포함.
- `infrastructure/ai`만 FastAPI를 안다. 다른 도메인은 `infrastructure/ai`의 서비스 인터페이스를 호출(v1 원칙 유지).
