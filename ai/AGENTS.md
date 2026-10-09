# ai AGENTS.md

루트 `AGENTS.md`를 전제로 `ai/`에서 작업하는 AI 코딩 도구의 기준 문서, 검증, 엄격 트리거와 리뷰 관점을 정한다.
판정 단계, 플랜·리뷰 절차, 기록 규칙과 `[hook]`·`[ci]`·`[사람]` 표시는 루트 7장에 있고 여기서 반복하지 않는다.
이 파일은 팀이 작성했다(키트 생성본이 아니다). `ai/`는 `harness.json` 영역이 아니므로 종료 검증 hook이 검증 명령을 대신 돌리지 않는다. 직접 실행한다.

## 1. 기준 문서

- [API 공통 규약 12장](../docs/api/conventions.md) — Spring ↔ FastAPI 내부 호출(경로 `/ai/**`, 타임아웃(가정), 오류 본문 비노출, 업무 DB 쓰기 금지)
- [요구사항 명세](../docs/requirements/README.md) — [Meal](../docs/requirements/meal.md)(Vision 인식·폴백), [Coaching](../docs/requirements/coaching.md), [Admin / ML](../docs/requirements/admin-ml.md)
- [contracts/README.md](../contracts/README.md) — `ai-openapi.json`의 원천은 FastAPI `GET /openapi.json`(ADR-0009)
- [ADR-0011](../docs/adr/0011-mlflow-and-ai-ml-split.md) 추론(`ai/`)·학습(`ml/`) 분리와 MLflow, [ADR-0013](../docs/adr/0013-rest-fcm-sse.md) SSE는 RAG 채팅만
- 구조·현재 상태·실행·환경 변수는 [ai/README.md](README.md), [`.env.example`](.env.example). Secret 취급은 [Secret 규칙](../docs/secret-environment-variables.md)

계약과 다르게 구현해야 하면 임의로 진행하지 않고, 합의한 뒤 기준 문서를 먼저 고친다.

## 2. 검증

저장소 루트에서 실행한다. 전제: Python 3.12 이상(Dockerfile 기준 3.12), 가상 환경에 `pip install -r ai/requirements.txt`.

- 작업 중 빠른 확인: `python -m pytest ai/tests -q`
- 작업 완료 전 필수(루트 README 검증 표): `python -m pytest ai/tests -q`. compose로 띄우는 변경이면 `docker compose -f infra/docker-compose.yml --env-file infra/.env config --quiet`
- CI 전용: 없음. CI는 아직 없고 `ai-openapi.json` 내보내기 단계도 없다(contracts/README)

린터·타입체크는 아직 없다. `TODO(확인 필요: Ruff·mypy 등 도입 여부. 새 의존성이라 팀 합의 후 추가)`

## 3. 엄격 트리거

트리거. diff나 플랜에 하나라도 있으면 해당한다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않는다.

1. `app/schemas/` 변경 — Spring ↔ FastAPI 계약 변경이다. E 리뷰 필수(ADR-0009·0011, `harness.json judge`)
2. `app/services/claude_service.py` 변경 — Claude 호출의 유일한 입구. 모델·프롬프트·비용 로그가 바뀐다
3. `app/model_loader.py`·`VISION_MODEL_*` 변경 — 레지스트리 폴백 규칙(ADR-0011)
4. `requirements.txt`·`Dockerfile`·`.env.example` 변경 — 의존성·이미지·환경 변수 계약
5. 새 라우터 추가, 기존 501 스텁의 구현 — 계약 문서와 `contracts/ai-openapi.json` 갱신이 따른다
6. 업무 DB·파일 시스템에 쓰는 코드 — FastAPI는 업무 DB에 쓰지 않는다(ADR-0011). 쓰기가 필요하면 Spring으로 옮긴다

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 덧붙인다. 계약 정합성(`schemas`와 Spring `infrastructure/ai` 클라이언트의 대응) · 실패 경로(모델 없음 503, 레지스트리 장애 시 로컬 캐시 폴백, Claude 오류를 그대로 밖으로 내보내지 않음) · Secret(`GMS_API_KEY` 기본값·로그 출력 없음) · mock 모드에서 테스트가 실제 호출 없이 도는지. [사람]

## 5. 영역 규칙

- 모든 Claude 호출은 `claude_service.call_claude` 하나를 거친다. 다른 모듈에서 HTTP 클라이언트로 직접 부르지 않는다(ADR-0011, v1 계승).
- `CLAUDE_MOCK`은 비우거나 `true`가 기본이다(크레딧을 쓰지 않는다). 테스트는 mock 모드로 돈다. 실호출은 `false` + `GMS_API_KEY`·`GMS_BASE_URL`이며 둘이 없으면 명확한 오류로 중단한다(`config.py`, Secret 규칙 2장).
- 모델 이름은 `CLAUDE_MODEL` 환경 변수다(기본 `claude-haiku-4-5-20251001`). 코드에 하드코딩하지 않는다.
- Vision 모델은 MLflow 레지스트리 `Production`(`VISION_MODEL_NAME`·`VISION_MODEL_STAGE`) → 로컬 캐시 → 모델 없음 순으로 폴백하며 기동은 멈추지 않는다. 학습·평가 코드와 torch 같은 학습 의존성은 `ml/`에 둔다. 이 이미지에 넣지 않는다.
- 필요한 데이터는 요청 본문으로 받는다. 업무 DB를 읽거나 쓰지 않는다(API 규약 12장).
- 프롬프트·모델 변경 시 eval 실행 의무와 eval·단위 테스트 분리: `TODO(확인 필요: ml/evaluation/은 README만 있고 코드가 없다. E가 Vision 베이스 모델 결정 후 정한다)`
- 지연시간·비용 기준(vision 10초·plan 30초·chat 120초는 API 규약 12장의 가정): `TODO(확인 필요: E·D 확정)`
- 사진·신체 정보 처리 규칙(보관 기간, 로그 제외, Claude로 보내는 범위): `TODO(확인 필요: E가 정하고 요구사항 공통에 반영)`
