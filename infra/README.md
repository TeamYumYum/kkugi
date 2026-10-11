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

## 관측 스택(지표·로그·추적)

`docker-compose.observability.yml`을 `-f`로 겹칠 때만 켜진다. 기존 실행 방식은 그대로다.

```bash
sh infra/observability/otel/download-agent.sh      # OTel Java Agent(버전·SHA-256 고정, jar는 커밋하지 않는다)
docker compose -f infra/docker-compose.yml -f infra/docker-compose.observability.yml --env-file infra/.env up -d --build
```

| 서비스 | 이미지 | 역할 | 호스트 포트 | 보관 |
|---|---|---|---|---|
| `prometheus` | `prom/prometheus:v3.15.0` | backend 관리 포트 `backend:8081/actuator/prometheus`를 15초마다 수집 | `127.0.0.1:9090` | 14일 |
| `alloy` | `grafana/alloy:v1.20.1` | backend Docker 로그 → Loki, agent 추적(OTLP) → `url.query` 제거 → Tempo | `127.0.0.1:12345` | 없음 |
| `loki` | `grafana/loki:3.7.8` | 로그. 라벨은 `service`·`env`·`version`·`level`, `trace_id`·`span_id`는 structured metadata | `127.0.0.1:3100` | 7일 |
| `tempo` | `grafana/tempo:3.1.0` | 추적(HTTP·JDBC span) | `127.0.0.1:3200` | 7일 |
| `grafana` | `grafana/grafana:13.2.3` | 데이터 소스·대시보드 파일 프로비저닝, 로그 ↔ 추적 이동 | `127.0.0.1:3000` | 볼륨 |

- 설정 파일은 `observability/` 아래에 있다. Grafana에서 고친 데이터 소스·대시보드는 재기동하면 파일 내용으로 돌아간다.
- Grafana는 `GRAFANA_ADMIN_USER`·`GRAFANA_ADMIN_PASSWORD`(`.env`)로 로그인한다. 익명 접근은 꺼져 있다.
  이 값은 `grafana-data` 볼륨을 처음 만들 때만 반영된다. 비밀번호를 바꾸거나 폐기하려면 `.env`를 고치고 grafana를 다시 만든 뒤,
  컨테이너 환경 변수로 재설정한다(비밀번호를 명령줄에 쓰지 않아 셸 기록에 남지 않는다).

  ```bash
  docker compose -f infra/docker-compose.yml -f infra/docker-compose.observability.yml --env-file infra/.env up -d grafana
  docker compose -f infra/docker-compose.yml -f infra/docker-compose.observability.yml --env-file infra/.env \
    exec grafana sh -c 'grafana cli admin reset-admin-password "$GF_SECURITY_ADMIN_PASSWORD"'
  ```
- overlay를 빼고 띄우면 backend는 agent 없이 뜬다. 지표·JSON 로그는 backend 설정이라 그대로 나온다.
- Alloy가 멈춰도 API는 영향을 받지 않는다. 그동안의 로그는 Docker 로그에서 다시 읽고, 추적은 agent 재시도로 버티지 못한 만큼 버려진다.
- Alloy는 로그 수집을 위해 Docker 소켓을 마운트한다. `:ro`를 붙여도 Docker API 권한은 줄지 않아 호스트 권한에 준하므로, 로컬에서만 쓴다(서버 배포 때 다시 정한다).
- 요청당 JDBC 실행 횟수는 Grafana Explore의 Tempo에서 TraceQL로 센다. 예: `{ span.http.route = "/api/meals" } >> { span.db.system = "mysql" } | count() > 10`

## 아직 없는 것

- backend가 FastAPI 주소를 읽을 변수 이름 — compose는 임시로 `AI_BASE_URL=http://ai:8000`을 넘긴다(결정 필요).
- 배포 환경(서버·도메인·TLS)과 운영 Secret 저장소 — 배포 방식이 정해지면 합의한다.

## CI(결정 필요)

`.gitlab-ci.yml`은 아직 만들지 않았다. SSAFY GitLab 저장소가 생기면 C가 ai-dev-harness CI 템플릿 include와
영역별 검증(harness.json의 `verify` 명령), `ai/` pytest, `contracts/*.json` 생성 단계(ADR-09)를 함께 정한다.
CI 정의는 엄격 트리거이고 GitLab 주소에 의존하므로 별도 이슈로 진행한다.
