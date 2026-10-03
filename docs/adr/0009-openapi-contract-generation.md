# ADR-0009: API 계약은 OpenAPI 한 벌에서 웹·Android 클라이언트 타입을 생성한다

| 항목 | 값 |
|---|---|
| 상태 | 채택 |
| 결정일 | 2026-10-03 |
| 결정자 | 리뉴얼 기획 단계 팀 결정 (E 주도) |
| 관련 | [기획서](../renewal/plan.md) |

## 맥락

소비 표면이 셋이다(Android 폰, 웹, 그리고 Spring → FastAPI 내부). 6명이 각자 브랜치에서 API를 추가·변경한다.
v1은 Spring ↔ FastAPI 연동 7개의 DTO를 "양쪽 동시 수정"으로 관리했고, 불일치는 런타임에 발견됐다.
feelm은 `springdoc` → `openapi-typescript`로 웹 타입을 생성했다.

## 결정

```
Spring (springdoc-openapi)
  └─▶ contracts/openapi.json            (빌드 산출물, git 커밋)
        ├─▶ web/src/generated/api.ts     openapi-typescript
        └─▶ android/core/.../generated/  openapi-generator (kotlin, retrofit2 + kotlinx-serialization)

FastAPI (내장 OpenAPI)
  └─▶ contracts/ai-openapi.json
        └─▶ backend/.../infrastructure/ai/generated/   openapi-generator (java, 선택)
```

- `contracts/*.json`은 **CI가 생성해 PR에 포함**한다. 손으로 편집하지 않는다.
- 웹·Android는 생성된 타입/클라이언트만 쓴다. 수동 DTO 금지(규칙 파일).
- 계약 변경 PR은 소비 표면 담당(웹 F, 폰 A)이 리뷰어에 포함된다.
- Spring → FastAPI 계약(`ai-openapi.json`) 변경은 E 리뷰 필수.

## 근거

- **계약 변경이 컴파일 에러가 된다.** 백엔드가 `MealResponse` 필드명을 바꾸면 웹·Android 빌드가 깨진다. 런타임 발견 → 빌드 발견.
- **별도 API 명세 문서를 유지하지 않아도 된다.** `contracts/openapi.json` diff가 곧 변경 이력.
- feelm 파이프라인을 그대로 가져와 1주차 비용이 낮다.
- Android 측 생성은 선택이었으나, 6명 계약 동기화 장치로서 가치가 설정 반나절보다 크다고 판단.

## 고려한 대안

- **웹만 생성, Android는 수동 DTO**: 설정 간단. Android 계약 불일치는 런타임 발견. 기각.
- **Protobuf/gRPC**: 타입 안전하지만 REST + Spring 생태계와 어긋나고 팀 경험 없음. 기각.
- **스키마 우선(OpenAPI를 손으로 쓰고 서버 코드 생성)**: 계약이 코드보다 먼저 합의되는 장점. Spring 서버 생성기 품질과 팀 습관(코드 우선)에 맞지 않음. 기각.

## 결과

- springdoc 어노테이션(`@Schema`, `@Operation`)이 컨트롤러·DTO에 들어간다. nullable·enum을 정확히 표기해야 생성 타입이 쓸 만하다(규칙 파일).
- 생성된 Kotlin 클라이언트의 모양이 마음에 안 들 수 있다 → `:core`에서 **DTO만 생성**하고 Retrofit 인터페이스는 손으로 쓰는 절충 허용. 1주차 A가 결정.
- `contracts/` 변경이 많은 PR은 충돌하기 쉽다 → 생성 파일은 **PR 마지막 커밋에서 재생성**하는 습관(규칙 파일).
