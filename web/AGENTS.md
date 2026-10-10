# web AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `web/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트(ai-dev-harness)가 생성한 것을 팀이 수정한 것입니다. 키트로 다시 생성하지 않습니다.

## 1. 기준 문서

- [API 공통 규약](../docs/api/conventions.md): 4장 응답과 페이징, 5장 오류 코드, 6장 인증(가정), 11장 클라이언트 규칙을 봅니다.
- [요구사항 명세](../docs/requirements/README.md): [공통](../docs/requirements/common.md)과 관리자 웹의 [Admin / ML 플랫폼](../docs/requirements/admin-ml.md)을 봅니다. 대시보드 화면은 각 도메인 파일을 봅니다.
- [contracts/README.md](../contracts/README.md)와 [src/generated/README.md](src/generated/README.md): 생성 타입의 원천과 재생성 절차입니다(ADR-0009).
- [ADR-0010](../docs/adr/0010-web-react-vite.md)은 폴더 구조와 화면 상한을, [ADR-0013](../docs/adr/0013-rest-fcm-sse.md)은 SSE의 범위를 정합니다.
- 실행 방법, 구조, 환경 변수는 [web/README.md](README.md)에 있습니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 Node 22와 `npm --prefix web ci`입니다.

- 작업 중 빠른 확인: `npm --prefix web run test:run`과 `npm --prefix web run lint`를 실행합니다.
- 작업 완료 전 필수(`harness.json`의 `verify`): 아래 네 명령을 모두 실행합니다. `build`에는 `tsc -b` 타입체크가 포함됩니다.
  - `npm --prefix web run lint`
  - `npm --prefix web run format:check`
  - `npm --prefix web run test:run`
  - `npm --prefix web run build`
- CI 전용: 없습니다. CI가 아직 없으므로 위 명령을 모두 로컬에서 실행합니다.

형식은 완료 검증 전에 `npm --prefix web run format`으로 맞춥니다. 검증 명령 자체는 파일을 수정하지 않습니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. 공용 컴포넌트(`src/components/`)를 생성하거나 변경하는 경우입니다. 여러 화면이 함께 쓰기 때문입니다.
2. 라우팅(`routes/router.tsx`, `routes/paths.ts`)을 변경하는 경우입니다.
3. 인증 가드(로그인이 필요한 라우트 보호)를 추가, 변경, 제거하는 경우입니다.
4. 새 라이브러리(의존성)를 추가하거나 `package.json`, lock 파일, `vite.config.*`, `eslint.config.*`를 변경하는 경우입니다.
5. `generated/`를 손으로 수정하거나 수동 DTO를 추가하는 경우입니다. ADR-09에 따라 생성 타입만 쓰고, MR 마지막 커밋에서 재생성합니다.
6. `harness.json`에서 이 영역의 layers, allow, disabled_rules를 변경하는 경우입니다. 컨벤션 규칙을 바꾸거나 끄는 변경이기 때문입니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. 접근성(역할, 이름, 대체 텍스트, 키보드 조작)을 확인하고, 화면 경계(`mocks/`와 다른 화면의 하위 컴포넌트를 import하지 않는지, 계층 허용 방향을 지키는지)를 확인하며, API 호출이 `src/api/`의 도메인 함수와 공통 클라이언트를 거치는지, 테스트가 역할 기반 질의(`getByRole`)로 사용자 관점을 검증하는지 확인합니다. [사람]

## 5. 영역 규칙

- 렌더링은 Vite와 react-router를 쓰는 SPA입니다. 사용자 대시보드는 `AppLayout` 아래에, 관리자 화면은 `/admin/*` 경로에서 `routes/RequireRole`과 `AdminLayout` 아래에 둡니다(README). 역할 가드가 쓰는 `hooks/useCurrentRole`은 1주차 스텁입니다.
- 데이터 페칭에서 화면은 `src/api/`의 도메인 함수를 호출하고, 도메인 함수는 `src/api/client.ts`의 `request<T>()`만 사용합니다. 응답이 2xx가 아니면 `ApiError(status, body)`가 던져지며, 호출한 쪽은 `body.error.code`로 분기합니다(API 규약 11장).
- 요청과 응답의 타입은 `src/generated/`의 생성 타입만 사용합니다. 계층 방향과 `mocks/` import 금지는 `eslint.harness.js`가 검사합니다(`harness.json` web 영역의 `layers`와 `allow`).
- `VITE_` 접두사 변수는 번들에 포함되므로 Secret을 넣지 않습니다(README 환경 변수 절).
- 상태 관리 원칙은 `TODO(확인 필요: 서버 상태와 전역 상태 라이브러리의 사용 여부와 범위를 웹 홈 담당 F가 정합니다)`입니다.
