# web AGENTS.md

루트 `AGENTS.md`를 전제로 `web/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
키트(ai-dev-harness)가 생성한 파일을 팀이 수정했다. 키트로 다시 생성하지 않는다.

## 1. 기준 문서

- [API 공통 규약](../docs/api/conventions.md) — 4장 응답·페이징, 5장 오류 코드, 6장 인증(가정), 11장 클라이언트 규칙
- [요구사항 명세](../docs/requirements/README.md) — [공통](../docs/requirements/common.md), [Admin / ML 플랫폼](../docs/requirements/admin-ml.md)(관리자 웹), 대시보드는 각 도메인 파일
- [contracts/README.md](../contracts/README.md) · [src/generated/README.md](src/generated/README.md) — 생성 타입의 원천과 재생성 절차(ADR-0009)
- [ADR-0010](../docs/adr/0010-web-react-vite.md) 폴더 구조·화면 상한, [ADR-0013](../docs/adr/0013-rest-fcm-sse.md) SSE 범위
- 실행·구조·환경 변수는 [web/README.md](README.md)

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: Node 22, `npm --prefix web ci`.

- 작업 중 빠른 확인: `npm --prefix web run test:run` · `npm --prefix web run lint`
- 작업 완료 전 필수(`harness.json verify`):
  - `npm --prefix web run lint`
  - `npm --prefix web run format:check`
  - `npm --prefix web run test:run`
  - `npm --prefix web run build` (`tsc -b` 타입체크를 포함한다)
- CI 전용: 없음. CI는 아직 없으므로 위 명령을 모두 로컬에서 돌린다

형식은 `npm --prefix web run format` 으로 맞춘다(완료 검증 전에 실행, 검증 명령 자체는 파일을 수정하지 않는다).

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. 공용 컴포넌트(`src/components/`)의 생성·변경(여러 화면이 함께 쓴다)
2. 라우팅(`routes/router.tsx`·`routes/paths.ts`) 변경
3. 인증 가드(로그인이 필요한 라우트 보호)의 추가·변경·제거
4. 새 라이브러리(의존성) 추가, `package.json`·lock·`vite.config.*`·`eslint.config.*` 변경
5. generated/ 손 수정이나 수동 DTO 추가(ADR-09: 생성 타입만, MR 마지막 커밋에서 재생성)
6. harness.json 이 영역 설정의 layers·allow·disabled_rules 변경(컨벤션 규칙을 바꾸거나 끈다)

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 접근성(역할·이름·대체 텍스트, 키보드 조작) · 화면 경계(`mocks/`·다른 화면 하위 컴포넌트 import 금지, 계층 허용 방향) · API 호출은 `src/api/` 도메인 함수와 공통 클라이언트를 거친다 · 테스트는 역할 기반 질의(`getByRole`)로 사용자 관점을 검증한다. [사람]

## 5. 영역 규칙

- 렌더링은 SPA(Vite + react-router). 사용자 대시보드는 `AppLayout`, 관리자는 `/admin/*` + `routes/RequireRole` + `AdminLayout` 아래에 둔다(README). 역할 가드 `hooks/useCurrentRole`은 1주차 스텁이다.
- 데이터 페칭: 화면은 `src/api/` 도메인 함수를 부르고, 도메인 함수는 `src/api/client.ts`의 `request<T>()`만 쓴다. 2xx가 아니면 `ApiError(status, body)`가 던져지며 `body.error.code`로 분기한다(API 규약 11장).
- 요청·응답 타입은 `src/generated/`의 생성 타입만 쓴다. 계층 방향과 `mocks/` 금지는 `eslint.harness.js`가 검사한다(`harness.json` web `layers`·`allow`).
- `VITE_` 변수는 번들에 들어간다. Secret을 넣지 않는다(README 환경 변수).
- 상태 관리 원칙: `TODO(확인 필요: 서버 상태·전역 상태 라이브러리 사용 여부와 범위. 웹 홈 담당 F가 정한다)`
