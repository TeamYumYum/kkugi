# src/generated

openapi-typescript 출력 자리다(ADR-09). **손으로 만들거나 고치지 않는다.**

- 입력: 저장소 루트 `contracts/openapi.json`(Spring springdoc 빌드 산출물, CI가 생성해 PR에 포함)
- 출력: `src/generated/api.ts`
- 생성: `web/`에서 `npm run gen:api`
  (`openapi-typescript ../contracts/openapi.json -o src/generated/api.ts`)

1주차 현재 `contracts/openapi.json`이 아직 없어 `gen:api`는 실패한다. API 계약 v1과 백엔드 springdoc 설정이
들어오면 처음 생성해 커밋한다. 그때까지 웹은 생성 타입 없이 셸만 둔다(수동 DTO 금지).

- 화면·`src/api/`는 `import type { paths, components } from '../generated/api'`처럼 타입만 가져다 쓴다
- 이 디렉터리는 ESLint·Prettier 대상에서 뺐다(`eslint.config.js`, `.prettierignore`)
- 계약 변경 PR은 마지막 커밋에서 다시 생성한다(`web/AGENTS.md` 트리거 5)
