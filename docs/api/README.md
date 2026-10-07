# API 명세

엔드포인트의 경로·메서드·요청·응답 모양은 손으로 쓰지 않는다. springdoc이 만드는 `contracts/openapi.json`이 계약이고,
웹·Android 타입은 거기서 생성한다([ADR-0009](../adr/0009-openapi-contract-generation.md), [contracts/README.md](../../contracts/README.md)).
이 폴더에는 **OpenAPI가 표현하지 못하는 것**만 둔다.

## 문서

| 문서 | 내용 | 소유 | 상태 |
|---|---|---|---|
| [공통 규약](./conventions.md) | 경로·명명, 요청·응답 형식, 오류 코드, 인증, 멱등·재시도, 페이징, 버전, SSE·FCM, Spring ↔ FastAPI, springdoc 작성 규칙 | D | 초안 |
| `{domain}.md` | 도메인별 처리 규칙. 상태 전이, 멱등 규칙, 오류 코드 목록, 미정 사항. 필요할 때만 만든다 | 도메인 소유자 | 없음 |

## 규칙

- 공통 규약 변경은 계약 변경이다. backend 엄격 판정이고 D 승인과 소비 표면(웹 F, 폰 A) 리뷰가 필요하다.
- 도메인 문서는 OpenAPI의 `description`으로 충분히 적을 수 있으면 만들지 않는다. 여러 엔드포인트에 걸친 규칙이 생길 때 만든다.
- 엔드포인트 하나의 요청·응답 예시를 여기에 옮겨 적지 않는다. Swagger UI(`/swagger-ui/index.html`)가 보여준다.
- 문서를 추가하면 위 표에 넣는다.
