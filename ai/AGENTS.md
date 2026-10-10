# ai AGENTS.md

이 문서는 `ai/`에서 작업할 때 루트 `AGENTS.md`에 더하여 적용하는 기준 문서, 검증 명령, 엄격 트리거, 리뷰 관점을 정합니다.
판정 단계와 플랜·리뷰 절차는 루트 5장에 있습니다. `ai/`는 `harness.json`의 영역이 아니므로 종료 검증 hook이 검증 명령을
대신 실행하지 않습니다. 검증 명령은 직접 실행합니다.

## 1. 기준 문서

- [API 공통 규약 12장](../docs/api/conventions.md): 라우터나 `schemas`를 추가하거나 바꿀 때 읽습니다. Spring과 FastAPI 사이의 호출 규칙입니다.
- [요구사항 명세](../docs/requirements/README.md): 기능을 구현할 때 [Meal](../docs/requirements/meal.md)(Vision 인식과 폴백),
  [Coaching](../docs/requirements/coaching.md), [Admin / ML](../docs/requirements/admin-ml.md) 중 해당 파일을 읽습니다.
- [ADR-0011](../docs/adr/0011-mlflow-and-ai-ml-split.md): 모델 로딩이나 MLflow 연동을 바꿀 때, 학습 코드를 어디에 둘지 판단할 때 읽습니다.
- [ai/README.md](README.md): 로컬 실행 환경을 준비할 때 읽습니다. Secret은 [Secret 규칙](../docs/secret-environment-variables.md)을 따릅니다.

## 2. 검증

저장소 루트에서 실행합니다. 전제 조건은 Python 3.12 이상과, 가상 환경에서 실행한 `pip install -r ai/requirements.txt`입니다.

- 작업 중 빠른 확인과 작업 완료 전 필수: `python -m pytest ai/tests -q`를 실행합니다. compose 설정을 바꿨으면
  `docker compose -f infra/docker-compose.yml --env-file infra/.env config --quiet`도 실행합니다.
- CI 전용: 없습니다. CI가 아직 없고, `contracts/ai-openapi.json`을 내보내는 단계도 아직 없습니다.

## 3. 엄격 트리거

diff나 플랜에 다음 중 하나라도 있으면 엄격 판정입니다. 테스트 코드와 테스트 리소스만 바꾼 변경은 트리거로 보지 않습니다.

1. `app/schemas/`를 변경하는 경우입니다. Spring과 FastAPI 사이의 계약 변경이므로 E의 리뷰가 필수입니다(ADR-0009·0011).
2. `app/services/claude_service.py`를 변경하는 경우입니다. Claude 호출의 유일한 입구이며, 프롬프트와 비용이 바뀝니다.
3. `app/model_loader.py`를 변경하는 경우입니다. 레지스트리 폴백 규칙에 영향을 줍니다(ADR-0011).
4. `requirements.txt`, `Dockerfile`, `.env.example`을 변경하는 경우입니다. 의존성, 이미지, 환경 변수 계약이 바뀝니다.
5. 새 라우터를 추가하거나 기존 501 스텁을 구현하는 경우입니다. 계약 문서와 `contracts/ai-openapi.json`의 갱신이 따릅니다.
6. 업무 DB나 파일 시스템에 쓰는 코드를 추가하는 경우입니다. FastAPI는 업무 DB에 쓰지 않으므로(ADR-0011), 쓰기가 필요하면 Spring으로 옮깁니다.

## 4. 이 영역에서 특히 볼 관점

공통 관점(루트 5장)에 다음을 덧붙입니다. `schemas`와 Spring `infrastructure/ai` 클라이언트가 서로 대응하는지, Claude 오류와
FastAPI 오류 본문을 그대로 밖으로 내보내지 않는지, 테스트가 실제 Claude 호출 없이 mock 모드로 실행되는지 확인합니다. [사람]

## 5. 영역 규칙

- 모든 Claude 호출은 `claude_service.call_claude` 하나를 거칩니다. 다른 모듈에서 HTTP 클라이언트로 직접 호출하지 않습니다.
- 테스트와 로컬 개발은 `CLAUDE_MOCK`이 비어 있거나 `true`인 mock 모드로 실행하여 크레딧을 쓰지 않습니다.
- 프롬프트나 모델을 변경할 때의 eval 실행 의무는 `TODO(확인 필요: ml/evaluation/에는 아직 코드가 없습니다. E가 Vision 베이스 모델을 결정한 뒤 정합니다)`입니다.
- 지연시간과 비용 기준은 `TODO(확인 필요: API 규약 12장의 타임아웃은 가정값입니다. E와 D가 확정합니다)`입니다.
- 사진과 신체 정보의 처리 규칙(보관 기간, 로그 제외, Claude로 보내는 범위)은 `TODO(확인 필요: E가 정하고 요구사항 공통에 반영합니다)`입니다.
