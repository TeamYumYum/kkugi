# web

냠냠코치 웹(사용자 대시보드 · 관리자). React 19 + Vite + react-router, feelm 폴더 구조(ADR-10).
1주차 셸이다. 화면·도메인 API는 2주차 이후 웹 담당(F)이 채운다.

## 실행

Node 22. `web/`에서:

```bash
npm ci
cp .env.example .env    # VITE_API_BASE_URL 값을 채운다(비우면 같은 출처)
npm run dev
```

## 검증

저장소 루트에서 실행한다(`harness.json` 영역 검증 명령과 같다).

```bash
npm --prefix web ci
npm --prefix web run lint
npm --prefix web run format:check
npm --prefix web run test:run
npm --prefix web run build
```

## 구조

```
src/
├── api/          공통 클라이언트(client.ts의 request<T>())와 도메인별 함수(meals.ts …)
├── generated/    openapi-typescript 출력(ADR-09) — 손으로 수정 금지, generated/README.md
├── components/   공용 UI(평평하게)
├── pages/        화면. 영역별 폴더 dashboard/ meals/ workouts/ reports/ admin/
├── hooks/ contexts/ layouts/ routes/ mocks/ types/ utils/
└── main.tsx
```

- 라우트: `/` 대시보드 홈(AppLayout), `/admin/*` 관리자(역할 가드 `routes/RequireRole` + AdminLayout)
- 화면 상한: 대시보드 6, 관리자 3(ADR-10)
- 역할 가드는 **1주차 스텁**이다. `hooks/useCurrentRole`이 항상 `ADMIN`을 돌려준다. 인증이 정해지면 그 훅을 바꾼다
- 계층 경계·접근성 규칙은 키트가 생성한 `eslint.harness.js`가 검사한다(손으로 고치지 않는다, `web/AGENTS.md`)

## 스캐폴드

저장소 루트에서:

```bash
python <ai-dev-harness>/bin/harness.py scaffold web screen MealList --var area=meals --target .
python <ai-dev-harness>/bin/harness.py scaffold web api meals --target .
```

`screen`이 출력하는 조각을 `routes/paths.ts`·`routes/router.tsx`에 붙인다.

## API 타입 생성

```bash
npm run gen:api   # ../contracts/openapi.json → src/generated/api.ts
```

`contracts/openapi.json`은 백엔드 springdoc 설정과 API 계약 v1이 들어온 뒤 생긴다. 그 전에는 실패한다.

## 환경 변수

| 이름 | 쓰임 |
| --- | --- |
| `VITE_API_BASE_URL` | API 서버 출처. 비우면 같은 출처의 `/api/v1`로 요청한다 |

`VITE_` 변수는 빌드 결과에 그대로 들어가므로 Secret을 넣지 않는다. `.env`는 커밋하지 않는다.
