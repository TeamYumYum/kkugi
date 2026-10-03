# Git 컨벤션

## 1. 운영 원칙

- 브랜치는 `main` 하나와 Jira 업무 항목 단위의 짧은 작업 브랜치만 둔다. `develop`·영역별 장기 통합 브랜치는 만들지 않는다([ADR-0012](./adr/0012-vertical-ownership.md)).
- `main`은 항상 빌드·검증이 통과하고 시연 가능한 상태를 유지한다. 통합 브랜치이자 기본 브랜치다.
- `main`에는 직접 Push하지 않고 Merge Request를 통해서만 병합한다.
- 하나의 Story는 폰·백엔드·마이그레이션을 포함해 **브랜치 하나, MR 하나**로 끝낸다(1 Story = 1 Branch = 1 MR).
- 데모·동결 시점은 `main`의 커밋에 태그로 표시한다(4장).

```text
main  ──────●──────────●──────────●──────────●──▶
            ↑          ↑          ↑          ↑
         feat/*      fix/*     refactor/*   docs/*     (짧은 작업 브랜치, MR로 병합)
                 demo/mvp1   demo/mvp2   demo/mvp3  freeze   (태그)
```

## 2. 브랜치 전략

| 브랜치 | 역할 |
| --- | --- |
| `main` | 통합 브랜치이자 기본 브랜치. 항상 시연 가능한 상태 |
| 작업 브랜치 | 하나의 Jira 업무 항목을 구현하는 단기 브랜치. 최신 `main`에서 만들고 `main`으로 병합 |

브랜치 이름:

```text
<type>/<KEY>-<description>
```

| Type | 용도 |
| --- | --- |
| `feat` | 새로운 기능 |
| `fix` | 버그 수정 |
| `refactor` | 기능 변경 없는 리팩터링 |
| `test` | 테스트 코드 |
| `docs` | 문서 수정 |
| `chore` | 기타 설정 및 작업 |
| `ci` | CI/CD 설정 변경 |

예시:

```text
feat/NYAM-52-meal-photo-correction
fix/NYAM-52-login-error
```

- 작업 추적을 위해 작업 브랜치에는 Jira Issue Key를 반드시 포함한다.
- 한 브랜치에는 하나의 Jira 업무 항목만 포함한다.
- 작업 브랜치는 최신 `main`에서 생성하고 가능한 1~2일 안에 병합한다.
- 기능 동결(7주 말, `freeze` 태그) 이후에는 `fix/`·`docs/` 브랜치만 `main`에 병합한다.

## 3. 커밋 컨벤션

Conventional Commits 형식을 사용한다.

```text
<type>(<scope>): <내용>
```

Scope는 담당자가 아니라 실제 변경 영역(디렉터리)을 기준으로 정한다.

| Scope | 변경 영역 |
| --- | --- |
| `android` | `android/` 폰 앱(`:app`, `:core`, `:feature:*`) |
| `wear` | `android/wear/` 워치 앱 |
| `backend` | `backend/` Spring Boot |
| `web` | `web/` React 대시보드·관리자 |
| `ai` | `ai/` FastAPI 추론 서버 |
| `ml` | `ml/` 학습·평가·레지스트리 |
| `contracts` | `contracts/` OpenAPI 산출물(재생성 커밋) |
| `infra` | `infra/` compose·nginx·CI |
| `docs` | `docs/` 문서, 루트 README·AGENTS |

- 한 Story가 여러 영역을 바꾸면 커밋을 영역별로 나누되 브랜치는 하나로 둔다. 예: `feat(backend): …` → `feat(android): …` → `chore(contracts): …`.
- 여러 영역을 포괄하거나 Scope가 불필요하면 생략할 수 있다.
- 커밋 메시지에는 Jira Issue Key를 필수로 넣지 않는다.
- 제목은 변경 결과가 드러나는 명령형 표현으로 간결하게 작성한다.

## 4. Merge Request 규칙

### 작업 브랜치에서 main으로 병합

제목 형식:

```text
[<KEY>] <type>(<scope>): <내용>
```

본문에는 다음 내용을 포함한다.

- `Closes <KEY>` 형식의 관련 이슈
- 변경이 필요한 배경과 병합 후 해결되는 문제
- 논리 단위로 정리한 변경 내용과 diff만으로 알 수 없는 판단 근거
- 검증 방법과 결과, 검증하지 못한 사항 및 남은 위험
- API 계약, DB Schema, 환경 변수, 의존성, CI/CD 등 공통 영역의 영향 여부
- 대안 중 선택한 결정, 리뷰 순서와 후속 작업 등 리뷰에 필요한 사항

해당 사항이 없는 선택형 절은 삭제해 형식적인 내용을 남기지 않는다. 공통 영역에 영향이
있으면 관련 영역 담당자를 리뷰어로 추가하고, 필요한 사전 합의 또는 적용 순서를 본문에
기록한다.

작업 MR은 다음 원칙을 따른다.

- 하나의 Jira 업무 항목 또는 하나의 명확한 변경 목적만 포함한다.
- 본인이 만든 MR을 본인이 승인하지 않는다.
- **리뷰어는 변경한 표면의 홈 담당이다**(ADR-0012). 폰 코드는 A, Wear는 B, Spring은 D, FastAPI·`ml/`은 E, Web은 F, 인프라·CI는 C. 여러 표면을 바꾼 MR은 해당 홈 담당을 모두 리뷰어로 넣는다.
- 공통 변경(`:core`, `global/`, `components/`, CI)과 계약 변경(`contracts/`, `ai/schemas`)은 해당 홈 담당의 Approve가 있어야 병합한다.
- 최소 한 명의 리뷰와 Approve를 받은 후 병합한다.
- Squash를 활성화하고 병합 후 Source Branch를 삭제한다.
- CI가 구성된 이후에는 Pipeline이 성공한 상태에서만 병합한다.

### MR 크기

MR은 하나의 목적을 유지하고 리뷰 가능한 크기로 작성한다. 대규모 변경은 분리
가능성을 검토하고, 분리하기 어렵다면 본문에 이유와 리뷰 순서를 작성한다. 기능 구현과
무관한 대규모 리팩터링은 같은 MR에 섞지 않는다.

테스트 코드를 제외한 수동 구현 변경량을 400줄 이내로 작성하는 것을 권장한다. 400줄을
초과하면 기능 또는 계층별 분할을 검토하고, 600줄을 초과하면 분할을 원칙으로 한다.
생성 코드(`contracts/`, `generated/`), 의존성 및 lock 파일, 자동 포맷 변경은 수동 구현 변경량에서 제외하지만 전체
리뷰 부담에는 포함한다. 분할하면 미완성 계약이 노출되거나 같은 변경을 반복해야 하는 등
분리가 더 위험한 경우에는 예외를 허용하고, 본문에 합쳐야 하는 이유와 리뷰 순서를 작성한다.

### 데모·동결 태그

통합 브랜치가 따로 없으므로 "릴리스"는 `main`의 특정 커밋에 태그를 다는 것이다.

| 태그 | 시점 | 의미 |
| --- | --- | --- |
| `demo/mvp1` | 3주차 데모 직전 | 폰만으로 로그인 → 사진 식사 → 홈 |
| `demo/mvp2` | 5주차 데모 직전 | 워치 세트 기록 → 완료 화면 → AI 조정 |
| `demo/mvp3` | 7주차 데모 직전 | 웹 대시보드 · FCM · MLOps 1회전 |
| `freeze` | 7주차 말 | 기능 동결. 이후 `fix/`·`docs/`만 병합 |
| `final` | 8주차 발표 | 최종 시연 커밋 |

- 태그는 팀장이 `main`에서 붙이고 Push한다. 태그 커밋은 전체 검증 명령(루트 README)이 통과한 상태여야 한다.
- 데모 직전 급한 수정은 작업 브랜치 → MR → `main` → 태그 이동 순서를 지킨다. 태그 커밋에 직접 커밋하지 않는다.
- `.gitlab/merge_request_templates/Release.md`는 쓰지 않는다(통합 MR이 없다). 데모 범위·DB 변경·롤백 확인은 태그를 붙이기 전 팀 채널에 같은 항목으로 남긴다.

## 5. 개발 환경 규칙

텍스트 파일은 저장소와 워킹트리 모두 LF를 사용한다. 루트 `.gitattributes`가 이를
강제하므로 운영체제와 개인 git 설정에 관계없이 동일하게 동작한다. Windows 배치 파일만
CRLF를 쓰고 바이너리는 변환하지 않는다.

Windows용 git은 설치 시 `core.autocrlf=true`가 들어간다. 내용이 같은데도 수정하지 않은
파일이 `git status`에 다수 나타나면 개행문자 문제를 의심한다.

```bash
git config --global core.autocrlf false
git diff --stat --ignore-cr-at-eol   # 비어 있으면 개행문자만 다른 상태
```

## 6. 규칙 변경

- 이 문서를 Git 협업 규칙의 기준 문서로 사용한다.
- 외부 문서는 핵심 내용을 요약하고 이 문서로 연결한다.
- 규칙 변경도 Jira 업무 항목과 MR을 통해 팀 리뷰를 받은 뒤 반영한다.
