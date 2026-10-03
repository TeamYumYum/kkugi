# contracts

서버 API 계약 산출물을 두는 곳이다([ADR-09](../docs/adr/0009-openapi-contract-generation.md)).
여기의 JSON은 **빌드 산출물**이라 손으로 편집하지 않는다. 아직 생성된 파일은 없다.

## 파일

| 파일 | 원천 | 소비자 |
| --- | --- | --- |
| `openapi.json` | Spring `springdoc-openapi`의 `/v3/api-docs` | 웹 `web/src/generated/api.ts`(openapi-typescript), Android `:core` generated(openapi-generator kotlin) |
| `ai-openapi.json` | FastAPI 내장 OpenAPI | Spring `infrastructure/ai/generated/`(openapi-generator java, 선택) |

## 생성 흐름

```
backend (springdoc) ──▶ contracts/openapi.json ──┬─▶ web: openapi-typescript → src/generated/
                                                 └─▶ android: openapi-generator → :core generated/
```

1. 백엔드가 컨트롤러·DTO에 springdoc 어노테이션(`@Schema`·`@Operation`)으로 nullable·enum을 정확히 적는다.
2. CI가 백엔드를 띄워 `/v3/api-docs`를 받아 `contracts/openapi.json`으로 저장하고 PR에 포함한다(재생성).
   로컬에서는 `cd backend && ./gradlew bootRun` 뒤 `GET http://localhost:8080/v3/api-docs`로 같은 내용을 확인할 수 있다.
3. 웹·Android는 생성된 타입·클라이언트만 쓴다. 수동 DTO를 만들지 않는다.

- 생성 파일은 충돌을 줄이려고 **PR 마지막 커밋에서 재생성**한다.
- `contracts/` 변경은 계약 변경이다. 소비 표면 담당(웹 F, 폰 A)이 리뷰하고, `ai-openapi.json` 변경은 E가 리뷰한다.
- 생성 도구(springdoc Gradle 플러그인 또는 CI 스크립트)와 CI 작업 위치는 아직 정하지 않았다(인프라·CI 담당 C와 D가 정한다).
