# 냠냠코치(NyamNyam) 리뉴얼

> 사용자가 기록하는 앱이 아니라, **냠냠이가 미리 준비해 두고 사용자는 확인만 하는** AI 건강 코치.
> Android 폰과 Wear OS가 주 무대이고, 웹은 대시보드·관리자다.

- 기획서: [docs/renewal/plan.md](docs/renewal/plan.md) — 기능·여정·아키텍처(5장)·팀과 일정(6장)
- 결정 기록: [docs/renewal/adr/](docs/renewal/adr/README.md) — ADR-01~13
- 협업 문서: [docs/README.md](docs/README.md) — 문서 역할, Git 컨벤션, Secret 관리, AI 작업 규칙([AGENTS.md](AGENTS.md))

## 저장소 구조

최상위는 배포·기술 경계, 내부는 도메인 경계다(plan.md 5.4).

| 디렉터리 | 표면 | 내용 | 안내 |
|---|---|---|---|
| `android/` | Android 폰 + Wear OS | `:app` `:wear` `:core` `:feature:{member,meal,workout,coaching,growth}` (ADR-01·05) | [android/README.md](android/README.md) |
| `backend/` | Spring Boot | `domain/{…}/{controller,dto,entity,event,repository,service}` · `global/` · `infrastructure/` (ADR-07·08) | [backend/README.md](backend/README.md) |
| `web/` | React + Vite | 대시보드·관리자, `generated/` API 타입 (ADR-10) | [web/README.md](web/README.md) |
| `ai/` | FastAPI | 추론 전용 — Vision · Claude 코칭, Spring만 호출 (ADR-11) | [ai/README.md](ai/README.md) |
| `ml/` | 학습·평가 | datasets · training · evaluation · registry, MLflow (ADR-11) | [ml/README.md](ml/README.md) |
| `contracts/` | API 계약 | `openapi.json` · `ai-openapi.json` — 빌드 산출물, 손 편집 금지 (ADR-09) | — |
| `infra/` | 실행 환경 | docker compose · nginx · (CI) | [infra/README.md](infra/README.md) |
| `docs/` | 문서 | 기획서 · ADR · 협업 규칙 | [docs/README.md](docs/README.md) |

## 검증 명령

저장소 루트에서 실행한다. 영역 명령은 [harness.json](harness.json)의 `verify`가 기준이다.

| 영역 | 명령 |
|---|---|
| backend | `cd backend && ./gradlew build` |
| web | `npm --prefix web run lint` · `npm --prefix web run format:check` · `npm --prefix web run test:run` · `npm --prefix web run build` |
| android | `android/gradlew -p android :app:check :core:check :wear:check` |
| android feature | `android/gradlew -p android :feature:member:check :feature:meal:check :feature:workout:check :feature:coaching:check :feature:growth:check` |
| android 컨벤션 | `android/gradlew -p android :konsist-test:test` |
| ai | `python -m pytest ai/tests -q` (harness.json 영역 아님, [ai/README.md](ai/README.md)) |
| infra | `docker compose -f infra/docker-compose.yml --env-file infra/.env config --quiet` |

로컬 통합 실행(MySQL·Redis·MLflow·backend·ai·nginx)은 [infra/README.md](infra/README.md)를 본다.
Secret은 커밋하지 않고 각 디렉터리의 `.env.example`에 이름만 둔다([Secret 관리 규칙](docs/secret-environment-variables.md)).
