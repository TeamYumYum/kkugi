# infra — 로컬 통합 실행(docker compose · nginx)

홈 담당은 C. `infra/` 변경은 엄격 검토 대상이다(harness.json judge 트리거).

## 구성

| 서비스 | 이미지·빌드 | 역할 | 호스트 포트 |
|---|---|---|---|
| `nginx` | `nginx:1.28-alpine` | `web/dist` 정적 서빙, `/api/` → backend, `/api/chat/stream` SSE(`proxy_buffering off`, ADR-13) | `80`(공개) |
| `backend` | `../backend` 빌드 | Spring Boot | 없음(nginx 경유) |
| `ai` | `../ai` 빌드 | FastAPI 추론, backend만 호출 | 없음 |
| `mlflow` | `ghcr.io/mlflow/mlflow:v3.16.1` | 실험 추적·모델 레지스트리(SQLite + 아티팩트 볼륨, ADR-11) | `127.0.0.1:5000` |
| `mysql` | `mysql:8.4` | 업무 DB(쓰기는 Spring만) | `127.0.0.1:3306` |
| `redis` | `redis:7.4-alpine` | JWT·캐시 | `127.0.0.1:6379` |

- FastAPI와 MLflow는 nginx로 공개하지 않는다. 관리자 웹의 모델 버전 조회는 Spring이 MLflow REST를 프록시한다(ADR-11).
- `ai`는 MLflow가 없거나 등록 모델이 없어도 기동한다(로컬 캐시 볼륨 `ai-model-cache`로 폴백).

## 실행

저장소 루트에서:

```bash
cp infra/.env.example infra/.env     # 값 채우기 — infra/.env는 커밋하지 않는다
npm --prefix web ci && npm --prefix web run build   # nginx가 서빙할 web/dist
docker compose -f infra/docker-compose.yml --env-file infra/.env up -d --build
docker compose -f infra/docker-compose.yml --env-file infra/.env ps
```

- 필수 변수(`MYSQL_ROOT_PASSWORD`·`DB_NAME`·`DB_USERNAME`·`DB_PASSWORD`·`REDIS_PASSWORD`)가 비어 있으면 compose가 바로 멈춘다.
- 설정 검사만: `docker compose -f infra/docker-compose.yml --env-file infra/.env config --quiet`
- MLflow UI: `http://127.0.0.1:5000`. `ml/` 스크립트는 `MLFLOW_TRACKING_URI=http://127.0.0.1:5000`으로 붙는다.

## 아직 없는 것

- `backend/Dockerfile` — backend 셸 담당이 추가해야 `docker compose up`의 backend 빌드가 된다.
- backend가 FastAPI 주소를 읽을 변수 이름 — compose는 임시로 `AI_BASE_URL=http://ai:8000`을 넘긴다(결정 필요).
- 배포 환경(서버·도메인·TLS)과 운영 Secret 저장소 — 배포 방식이 정해지면 합의한다.

## CI(결정 필요)

`.gitlab-ci.yml`은 아직 만들지 않았다. SSAFY GitLab 저장소가 생기면 C가 ai-dev-harness CI 템플릿 include와
영역별 검증(harness.json의 `verify` 명령), `ai/` pytest, `contracts/*.json` 생성 단계(ADR-09)를 함께 정한다.
CI 정의는 엄격 트리거이고 GitLab 주소에 의존하므로 별도 이슈로 진행한다.
