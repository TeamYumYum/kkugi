# ai AGENTS.md

이 문서는 루트 `AGENTS.md`를 전제로, `ai/`에서 작업하는 AI 코딩 도구가 따를 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계, 플랜과 리뷰 절차, 기록 규칙, `[hook]`·`[ci]`·`[사람]` 표시의 뜻은 루트 7장에 있으므로 여기서 반복하지 않습니다.
이 파일은 키트 생성본이 아니라 팀이 작성한 것입니다. `ai/`는 `harness.json`의 영역이 아니므로 종료 검증 hook이 검증 명령을 대신 실행하지 않습니다. 검증 명령은 직접 실행합니다.

## 1. 기준 문서

- [API 공통 규약 12장](../docs/api/conventions.md): Spring과 FastAPI 사이의 내부 호출 규칙입니다. 경로는 `/ai/**`이고, 타임아웃은 가정값이며, 오류 본문을 밖으로 내보내지 않고, 업무 DB에 쓰지 않습니다.
- [요구사항 명세](../docs/requirements/README.md): [Meal](../docs/requirements/meal.md)(Vision 인식과 폴백), [Coaching](../docs/requirements/coaching.md), [Admin / ML](../docs/requirements/admin-ml.md)을 봅니다.
- [contracts/README.md](../contracts/README.md): `ai-openapi.json`의 원천은 FastAPI의 `GET /openapi.json`입니다(ADR-0009).
- [ADR-0011](../docs/adr/0011-mlflow-and-ai-ml-split.md)은 추론(`ai/`)과 학습(`ml/`)의 분리와 MLflow 사용을, [ADR-0013](../docs/adr/0013-rest-fcm-sse.md)은 SSE를 RAG 채팅에만 쓴다는 원칙을 정합니다.
- 구조, 현재 상태, 실행 방법, 환경 변수는 [ai/README.md](README.md)와 [`.env.example`](.env.example)에 있습니다. Secret 취급은 [Secret 규칙](../docs/secret-environment-variables.md)을 따릅니다.

계약과 다르게 구현해야 하는 상황이면 임의로 진행하지 않고, 합의한 뒤에 기준 문서를 먼저 고칩니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 Python 3.12 이상(Dockerfile 기준)과, 가상 환경에서 실행한 `pip install -r ai/requirements.txt`입니다.

- 작업 중 빠른 확인: `python -m pytest ai/tests -q`를 실행합니다.
- 작업 완료 전 필수(루트 README의 검증 표): `python -m pytest ai/tests -q`를 실행합니다. compose로 띄우는 부분을 바꿨으면 `docker compose -f infra/docker-compose.yml --env-file infra/.env config --quiet`도 실행합니다.
- CI 전용: 없습니다. CI가 아직 없고, `ai-openapi.json`을 내보내는 단계도 아직 없습니다(contracts/README).

린터와 타입체크는 아직 없습니다. `TODO(확인 필요: Ruff, mypy 등의 도입 여부입니다. 새 의존성이므로 팀 합의 후 추가합니다)`

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. `app/schemas/`를 변경하는 경우입니다. Spring과 FastAPI 사이의 계약 변경이므로 E의 리뷰가 필수입니다(ADR-0009·0011, `harness.json`의 `judge`).
2. `app/services/claude_service.py`를 변경하는 경우입니다. Claude 호출의 유일한 입구이며, 모델, 프롬프트, 비용 로그가 바뀝니다.
3. `app/model_loader.py`나 `VISION_MODEL_*` 변수를 변경하는 경우입니다. 레지스트리 폴백 규칙에 영향을 줍니다(ADR-0011).
4. `requirements.txt`, `Dockerfile`, `.env.example`을 변경하는 경우입니다. 의존성, 이미지, 환경 변수 계약이 바뀝니다.
5. 새 라우터를 추가하거나 기존 501 스텁을 구현하는 경우입니다. 계약 문서와 `contracts/ai-openapi.json`의 갱신이 따릅니다.
6. 업무 DB나 파일 시스템에 쓰는 코드를 추가하는 경우입니다. FastAPI는 업무 DB에 쓰지 않으므로(ADR-0011), 쓰기가 필요하면 Spring으로 옮깁니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 7장)에 다음을 덧붙입니다. `schemas`와 Spring `infrastructure/ai` 클라이언트가 서로 대응하는지(계약 정합성), 실패 경로가 맞는지(모델이 없으면 503, 레지스트리 장애 시 로컬 캐시로 폴백, Claude 오류를 그대로 밖으로 내보내지 않음), Secret을 지키는지(`GMS_API_KEY`에 기본값이 없고 로그에 출력하지 않음), mock 모드에서 테스트가 실제 호출 없이 도는지 확인합니다. [사람]

## 5. 영역 규칙

- 모든 Claude 호출은 `claude_service.call_claude` 하나를 거칩니다. 다른 모듈에서 HTTP 클라이언트로 직접 호출하지 않습니다(ADR-0011, v1 계승).
- `CLAUDE_MOCK`은 비어 있거나 `true`인 것이 기본이며, 이때는 크레딧을 쓰지 않습니다. 테스트는 mock 모드로 실행합니다. 실제 호출은 `false`로 설정하고 `GMS_API_KEY`와 `GMS_BASE_URL`을 주어야 하며, 둘이 없으면 명확한 오류와 함께 중단합니다(`config.py`, Secret 규칙 2장).
- 모델 이름은 `CLAUDE_MODEL` 환경 변수로 정합니다(기본값 `claude-haiku-4-5-20251001`). 코드에 하드코딩하지 않습니다.
- Vision 모델은 MLflow 레지스트리의 `Production`(`VISION_MODEL_NAME`, `VISION_MODEL_STAGE`), 로컬 캐시, 모델 없음의 순서로 폴백하며, 어느 경우에도 기동은 멈추지 않습니다. 학습과 평가 코드, torch 같은 학습 의존성은 `ml/`에 두고 이 이미지에 넣지 않습니다.
- 필요한 데이터는 요청 본문으로 받습니다. 업무 DB를 읽거나 쓰지 않습니다(API 규약 12장).
- 프롬프트나 모델을 변경할 때의 eval 실행 의무와 eval과 단위 테스트의 분리는 `TODO(확인 필요: ml/evaluation/에는 README만 있고 코드가 없습니다. E가 Vision 베이스 모델을 결정한 뒤 정합니다)`입니다.
- 지연시간과 비용 기준은 `TODO(확인 필요: vision 10초, plan 30초, chat 120초는 API 규약 12장의 가정값입니다. E와 D가 확정합니다)`입니다.
- 사진과 신체 정보의 처리 규칙(보관 기간, 로그 제외, Claude로 보내는 범위)은 `TODO(확인 필요: E가 정하고 요구사항 공통에 반영합니다)`입니다.
