# ai — FastAPI 추론 서버

Spring이 내부 HTTP(`/ai/**`)로만 호출하는 추론 서버다. 폰·웹은 이 서버를 모른다(plan.md 5.2).
학습·평가 코드는 `ml/`에 있고 이 이미지에 들어가지 않는다([ADR-11](../docs/renewal/adr/2026-10-03-11-mlflow-and-ai-ml-split.md)).
홈 담당은 E. `app/schemas/` 변경은 Spring ↔ FastAPI 계약 변경이라 E 리뷰가 필수다.

## 구조

```
app/
├── main.py            FastAPI 앱, 기동 시 model_loader 실행
├── config.py          환경 변수 읽기(Secret 기본값 없음)
├── model_loader.py    MLflow 레지스트리 "Production" → 로컬 캐시 폴백
├── routers/           health · vision · stubs(meal·routine·plan·chat, 501)
├── services/          claude_service(Claude 단일 진입점) · vision_service
└── schemas/           요청·응답 모델
tests/                 pytest
```

## 현재 상태(1주차 골격)

| 경로 | 동작 |
|---|---|
| `GET /ai/health` | 상태, Claude 모드(mock/live), Vision 모델 로드 여부 |
| `POST /ai/vision` | 모델이 없으면 503, 있으면 501(추론은 2주차) |
| `POST /ai/meal`·`/ai/routine`·`/ai/plan`·`/ai/chat` | 501 — 각 도메인 스토리에서 구현 |

- `claude_service.call_claude`가 Claude 호출의 유일한 입구다. `CLAUDE_MOCK`이 비었거나 `true`면
  고정 문구를 돌려준다. `false`인데 `GMS_API_KEY`·`GMS_BASE_URL`이 없으면 명확한 오류를 낸다.
  비용 로그·Vision 호출·도메인 프롬프트는 v1 `ai/app/services/claude_service.py`에서 이식 예정.
- `model_loader`는 레지스트리에 닿지 못하거나 등록된 버전이 없으면 마지막 로컬 캐시
  (`MODEL_CACHE_DIR/<모델명>/current`)로 기동하고, 캐시도 없으면 모델 없이 기동한다.
  모델 역직렬화는 Vision 베이스 모델이 정해진 뒤 붙인다(plan.md 9장).

## 실행·검증

변수 목록은 [`.env.example`](.env.example). 저장소 루트에서:

```bash
python -m venv .venv            # 저장소 밖이나 ai/.venv(무시됨)
.venv/bin/pip install -r ai/requirements.txt
python -m pytest ai/tests -q    # 검증
cd ai && uvicorn app.main:app --reload --port 8000
```

compose로 함께 띄우는 방법은 [`infra/README.md`](../infra/README.md).
OpenAPI는 `GET /openapi.json`이며 `contracts/ai-openapi.json`으로 내보내는 CI 단계는 아직 없다(ADR-09).
