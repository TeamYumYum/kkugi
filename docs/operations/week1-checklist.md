# 1주차 기반 체크리스트

| 항목 | 값 |
|---|---|
| 목적 | 기획서 8장 "기반 1주 압축" 리스크의 대응책. 1주차 금요일에 각 표면 빌드·배포·로그인 왕복·규칙 파일 적용을 확인한다 |
| 판정 | **필수** 항목이 모두 통과하면 2주차 수직 스토리를 시작한다. 통과하지 못한 필수 항목은 2주차 첫 Jira 항목으로 등록한다. **결정** 항목은 결정 내용이 문서에 적혀 있으면 통과 |
| 담당 | A~F는 기획서 6.1의 홈 담당. 실명 매핑은 미결이므로 매핑이 정해지면 이 표의 글자를 이름으로 바꾼다 |
| 관련 | [기획서 5.3·6.3·8·9장](../renewal/plan.md), [ADR README](../adr/README.md), 루트 [README 검증 명령](../../README.md), 영역 README |

확인 방법은 저장소 루트에서 실행하는 명령이거나 눈으로 확인할 증거다. 통과하면 `[x]`와 확인자·날짜를 적는다.

## A. 저장소와 협업 기반

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | SSAFY GitLab 저장소에 `main`이 올라가 있고 `main` 직접 Push가 막혀 있다 | C | GitLab 보호 브랜치 설정 화면 | 필수 |
| [ ] | Jira 프로젝트(키 `NYAM`)와 보드가 있고 2주차 스토리가 등록돼 있다 | 팀장 | Jira 보드 | 필수 |
| [ ] | MR 템플릿 `Default.md`가 GitLab에서 선택된다 | C | MR 생성 화면 | 필수 |
| [ ] | 팀원 실명 → A~F 매핑이 정해졌다 | 팀장 | 기획서 9장 미결 해소, 6.1 표 갱신 | 결정 |
| [ ] | 전원이 `core.autocrlf=false`이고 `git status`에 개행만 다른 파일이 없다 | 전원 | Git 컨벤션 5장 명령 | 필수 |

## B. 표면별 셸 빌드

깨끗한 clone에서 루트 README의 검증 명령이 통과한다.

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | backend | D | `cd backend && ./gradlew build` | 필수 |
| [ ] | web | F | `npm --prefix web run lint` · `format:check` · `test:run` · `build` | 필수 |
| [ ] | android 폰·core·wear | A·B | `android/gradlew -p android :app:check :core:check :wear:check` | 필수 |
| [ ] | android feature 5개 | A | `android/gradlew -p android :feature:member:check ... :feature:growth:check` | 필수 |
| [ ] | android 컨벤션 | A | `android/gradlew -p android :konsist-test:test` | 필수 |
| [ ] | ai | E | `python -m pytest ai/tests -q` | 필수 |
| [ ] | infra 설정 | C | `docker compose -f infra/docker-compose.yml --env-file infra/.env config --quiet` | 필수 |
| [ ] | 폰 앱이 에뮬레이터 또는 실기기에 설치되고 셸 홈이 뜬다 | A | 스크린샷 | 필수 |
| [ ] | 워치 앱이 에뮬레이터 또는 실기기에 설치되고 `WorkoutHome`이 뜬다 | B | 스크린샷 | 필수 |

## C. 규칙 파일

ADR-0012 결과: "1주차 끝에 규칙 파일이 완성돼 있어야 한다."

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | `harness.json` 영역별 `verify`가 루트 README 표와 같다 | C | 두 파일 대조 | 필수 |
| [ ] | backend ArchUnit 3규칙(ADR-0007)이 테스트에 있고 통과한다 | D | `FixedRulesArchitectureTest`·`LayerRulesArchitectureTest` | 필수 |
| [ ] | android Konsist 고정 규칙(ADR-0002·03·04·05)이 빈 범위가 아니라 실제 파일을 검사한다 | A·B | `:konsist-test:test` 보고서에서 검사 대상 수 | 필수 |
| [ ] | web `eslint.harness.js` 계층·접근성 규칙이 켜져 있다 | F | `npm --prefix web run lint` | 필수 |
| [ ] | 영역 `AGENTS.md` "1. 기준 문서"에 요구사항·ERD·API 규약 링크가 들어갔다 | 각 홈 담당 | 파일 확인 | 필수 |
| [ ] | `.harness/mr-lint`가 MR 본문 형식을 검사한다(CI 전이면 로컬 실행) | C | `python .harness/mr-lint/mr_lint.py` | 결정 |

## D. 설계 문서

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | [논리 ERD](../design/erd.md) 각 도메인 절을 소유자가 검토해 `(가정)`을 줄이고 상태를 바꿨다 | D + A·B·C | 문서 상태 표 | 필수 |
| [ ] | [스키마 규칙](../design/schema-rules.md)의 식별자 타입·시간대·외래 키 원칙이 결정됐다. 식별자 타입은 ADR로 남겼다 | D | ADR 번호 | 결정 |
| [ ] | 마이그레이션 도구가 결정됐고 첫 마이그레이션(빈 스키마 또는 member)이 compose MySQL에 적용된다 | D | backend 기동 로그 | 필수 |
| [ ] | [API 공통 규약](../api/conventions.md) 15장 미결 중 1주차 항목(단복수, 시각 포맷, 404 vs 403)이 결정됐다 | D | 문서 갱신 | 결정 |
| [ ] | [요구사항 명세](../requirements/README.md) MVP-1 범위(Member·Meal·Coaching·Growth·공통)를 소유자가 검토했다 | A·C·D | 문서 상태 표 | 필수 |
| [ ] | [용어집](../glossary.md)을 전원이 훑고 자기 도메인 용어를 고쳤다 | 전원 | MR | 결정 |
| [ ] | [이벤트 목록](../renewal/events.md) 페이로드가 ERD·요구사항과 어긋나지 않는다 | D | 세 문서 대조 | 필수 |

## E. API 계약 v1

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | `contracts/openapi.json` 생성 도구와 CI 위치가 결정됐다(contracts/README "정하지 않았다") | C·D | contracts/README 갱신 | 결정 |
| [ ] | 첫 `contracts/openapi.json`이 커밋됐다(최소 health·member 셸) | D | 파일 존재 | 필수 |
| [ ] | web `npm --prefix web run gen:api`가 성공하고 `src/generated/api.ts`가 생긴다 | F | 명령 | 필수 |
| [ ] | `:core` openapi-generator 설정이 들어갔고 DTO만 생성할지 Retrofit까지 생성할지 결정됐다(ADR-0009) | A | android/README 1주차 항목 | 결정 |
| [ ] | FastAPI `GET /openapi.json`을 `contracts/ai-openapi.json`으로 내보내는 방법이 정해졌다 | E | 파일 또는 CI 단계 | 결정 |
| [ ] | springdoc 어노테이션 규칙(API 규약 13장)이 스캐폴드 템플릿에 반영됐다 | D | `.harness/templates/spring-java` | 결정 |

## F. 인프라와 실행

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | `backend/Dockerfile`이 있어 `docker compose up --build`가 backend를 빌드한다 | D | compose 로그 | 필수 |
| [ ] | backend가 FastAPI 주소를 읽는 변수 이름이 정해졌고 compose의 임시 `AI_BASE_URL`과 맞췄다 | D·C | infra/README 갱신 | 결정 |
| [ ] | `backend/.env.example` 위치가 정해졌고 변수 목록이 README와 같다 | D·C | 파일 | 결정 |
| [ ] | compose 전체(mysql·redis·mlflow·backend·ai·nginx)가 뜨고 health가 통과한다 | C | `docker compose ps`, `GET :8081/actuator/health`(backend 관리 포트, 컨테이너 안에서), `GET /ai/health` | 필수 |
| [ ] | nginx가 `web/dist`를 서빙하고 `/api/`를 backend로 넘긴다 | C | 브라우저에서 웹 셸 + API 호출 | 필수 |
| [ ] | SSE 경로(`/api/chat/stream` vs `/api/v1/...`) 접두사가 정해졌다 | C·D | API 규약 9장 갱신 | 결정 |
| [ ] | MLflow UI가 `127.0.0.1:5000`에서 열리고 `ai`가 레지스트리 없이도 기동한다(ADR-0011) | E | 브라우저, ai 로그 | 필수 |
| [ ] | 배포 환경(서버·도메인·TLS)과 운영 Secret 보관 방식이 정해졌다. 미정이면 결정 기한을 적었다 | C | infra/README "아직 없는 것" 갱신 | 결정 |
| [ ] | `.gitlab-ci.yml` 작성 Jira 항목이 등록됐다(엄격 트리거, 별도 이슈) | C | Jira | 필수 |

## G. 인증과 로그인 왕복

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | 인증 방식(JWT·저장 위치·전달 방식)이 결정됐고 [설계 문서 인증](../design/README.md) 작성 Jira 항목이 있다 | D·C | 문서 | 결정 |
| [ ] | 개발용 이메일 로그인으로 폰 → Spring → 토큰 → 보호 API 200 왕복이 된다 | C·D | 폰 또는 curl 로그 | 필수 |
| [ ] | `SecurityConfig`가 공개 경로 외 `authenticated()`로 바뀌었고 401·403이 ApiResponse 모양이다 | D | curl 응답 | 필수 |
| [ ] | 카카오 개발자 앱 등록·키 발급을 신청했다(심사 지연 대비) | C | 콘솔 스크린샷 | 필수 |
| [ ] | 구글 OAuth 클라이언트 생성 여부가 소셜 로그인 범위 결정에 따라 처리됐다 | C | 결정 기록 | 결정 |

## H. 외부 연동 준비 (기획서 5.3)

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | Firebase 프로젝트를 만들고 FCM 서버 키 보관 위치를 정했다 | D | 콘솔, Secret 규칙 | 필수 |
| [ ] | 워치 Health Services 권한 플로우가 셸에 들어갔다 | B | 워치 화면 | 결정 |
| [ ] | 폰 Health Connect 읽기 권한을 매니페스트에 선언했다 | C | 매니페스트 | 결정 |
| [ ] | Claude 호출이 `CLAUDE_MOCK=true`로 동작하고 GMS 키로 1회 실호출이 성공했다 | E | `GET /ai/health`, 로그 | 필수 |

## I. 미결 결정 (기획서 9장, 1주차 기한)

| | 항목 | 담당 | 기록 위치 | 구분 |
|---|---|---|---|---|
| [ ] | Vision 베이스 모델(자체 fine-tune vs 외부 API + 분류기) | E | 새 ADR 또는 ADR-0011 `관련` | 결정 |
| [ ] | 마이그레이션 도구 | D | 스키마 규칙 7장 | 결정 |
| [ ] | 인증 방식 | D·C | 설계 문서 인증 | 결정 |
| [ ] | `:core` OpenAPI 생성 범위 | A | android/README | 결정 |
| [ ] | MLflow stage vs alias. 채택 ADR은 본문을 고치지 않으므로 새 ADR로 대체하거나 `관련`에 적는다 | E | ADR | 결정 |
| [ ] | 디자인 파운데이션(색·타이포·컴포넌트) | A | `:app` 테마 또는 문서 | 결정 |
| [ ] | 소셜 로그인 범위 | C | 요구사항 Member | 결정 |
| [ ] | 워치 `standalone` 플래그와 단독 설치 허용 여부 | B | android/README | 결정 |
| [ ] | XP 규칙 초안 일정(2주차)이 Jira에 있다 | C | Jira | 결정 |

## J. Android 1주차 (android/README)

| | 항목 | 담당 | 확인 방법 | 구분 |
|---|---|---|---|---|
| [ ] | 모든 모듈 `dependencyLocking`과 `gradle.lockfile` 커밋 | A | 파일 존재, `--write-locks` 명령 | 필수 |
| [ ] | 앱 아이콘, 서명 설정(폰·워치 같은 키), Material 3·Wear 테마 토큰 | A·B | 빌드 산출물 | 결정 |
| [ ] | `DataLayerPaths` 경로·형식 초안과 2주차 말 실기기 스파이크 Jira 항목 | B | 코드, Jira | 필수 |

## 금요일 판정 기록

| 항목 | 값 |
|---|---|
| 판정일 | |
| 통과하지 못한 필수 항목 | |
| 2주차로 넘긴 Jira 항목 | |
| 판정자 | |
