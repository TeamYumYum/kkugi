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

## 모니터링 스택(metric·로그·trace)

모니터링 파일을 `-f`로 겹칠 때만 켜진다. 겹치지 않으면 기존 실행 방식은 그대로다. 파일은 역할별로 둘이다.

| 파일 | 띄우는 곳 | 서비스 |
|---|---|---|
| `docker-compose.monitoring-agent.yml` | backend가 있는 호스트 | backend에 OTel Java Agent를 붙이는 설정, `alloy` |
| `docker-compose.monitoring-server.yml` | 모니터링 서버 | `prometheus`, `loki`, `tempo`, `grafana` |

backend 쪽 Alloy가 metric·로그·trace를 모두 모니터링 서버로 보낸다(push). 모니터링 서버는 backend 호스트로 접속하지 않는다.

```text
backend 호스트                                   모니터링 서버
backend :8081 ◀─ 읽기 ─ Alloy ── metric (remote write) ─▶ Prometheus :9090 ─┐
Docker 로그   ◀─ 읽기 ─ Alloy ── 로그 ───────────────────▶ Loki :3100 ───────┼─▶ Grafana :3000
OTel Java Agent ─────▶ Alloy ── trace (OTLP gRPC) ───────▶ Tempo :4317 ─────┘
```

### 경우 1: backend와 같은 호스트

```bash
sh infra/monitoring/otel/download-agent.sh      # OTel Java Agent(버전·SHA-256 고정, jar는 커밋하지 않는다)
docker compose -f infra/docker-compose.yml -f infra/docker-compose.monitoring-agent.yml -f infra/docker-compose.monitoring-server.yml --env-file infra/.env up -d --build
```

- `.env`의 Alloy 주소 세 개(`LOKI_PUSH_URL`·`TEMPO_OTLP_ENDPOINT`·`PROMETHEUS_REMOTE_WRITE_URL`)는 `.env.example`의 경우 1 값(compose 내부 주소)을 그대로 쓰고, `MONITORING_BIND_ADDR`은 비운다. 모든 포트는 `127.0.0.1`에만 열린다.
- 주소 세 개는 필수다. 하나라도 비면 compose가 멈춘다. 경우 2에서 하나를 빠뜨려 옛 주소로 조용히 보내는 일을 막기 위해서다.

### 경우 2: 별도 모니터링 서버

모니터링 서버에서(`.env`에 `GRAFANA_ADMIN_*`, `MONITORING_BIND_ADDR`=모니터링 서버의 사설 IP):

```bash
docker compose -p kkugi-monitoring -f infra/docker-compose.monitoring-server.yml --env-file infra/.env up -d
```

backend 호스트에서(`.env`에 `LOKI_PUSH_URL`·`TEMPO_OTLP_ENDPOINT`·`PROMETHEUS_REMOTE_WRITE_URL`=모니터링 서버 주소):

```bash
sh infra/monitoring/otel/download-agent.sh
docker compose -f infra/docker-compose.yml -f infra/docker-compose.monitoring-agent.yml --env-file infra/.env up -d --build
```

- 보안 그룹은 모니터링 서버의 3100·4317·9090에 backend 호스트에서 오는 연결만 허용한다. backend 호스트에는 들어오는 포트를 열지 않는다.
- 3100과 9090은 수신 전용 포트가 아니다. 같은 포트로 Loki·Prometheus의 조회 API가 인증 없이 열리고, Prometheus는 쓰기도 받는다. 보안 그룹으로 접근을 backend 호스트로만 좁히는 것이 유일한 보호 장치다. Loki의 로그 삭제 API는 꺼 두었다.
- 호스트 사이 전송은 암호화와 인증이 없다. 같은 VPC의 사설 망을 전제로 하며, 다른 망을 지나가면 그 전에 TLS나 인증을 정해야 한다.
- Grafana는 모니터링 서버의 `127.0.0.1:3000`에만 열린다. SSH 터널로 접속한다.

### 경우 1에서 경우 2로 옮기기

1. 모니터링 서버에서 위의 경우 2 명령으로 모니터링 서버 쪽을 띄운다.
2. backend 호스트의 `.env`에서 Alloy 주소 세 개를 모니터링 서버 주소로 바꾼다.
3. backend 호스트에서 경우 2 명령에 `--remove-orphans`를 붙여 다시 띄운다. 같은 compose 프로젝트에 남아 있던 `prometheus`·`loki`·`tempo`·`grafana` 컨테이너가 지워지고, Alloy가 새 주소로 보낸다.

```bash
docker compose -f infra/docker-compose.yml -f infra/docker-compose.monitoring-agent.yml --env-file infra/.env up -d --build --remove-orphans
```

4. backend 호스트에 남은 볼륨 `nyamnyam_prometheus-data`·`nyamnyam_loki-data`·`nyamnyam_tempo-data`·`nyamnyam_grafana-data`는 옛 데이터다. 모니터링 서버로 옮기지 않으며, 보관 기간(최대 14일)이 지나 필요 없어지면 `docker volume rm`으로 지운다.

### 서비스

| 서비스 | 이미지 | 역할 | 호스트 포트 | 보관 |
|---|---|---|---|---|
| `alloy` | `grafana/alloy:v1.20.1` | backend metric 읽기 → remote write, Docker 로그 → Loki, agent trace → `url.query` 제거 → Tempo | `127.0.0.1:12345` | WAL |
| `prometheus` | `prom/prometheus:v3.15.0` | Alloy가 보낸 metric 저장(remote write 수신) | `MONITORING_BIND_ADDR:9090` | 14일 |
| `loki` | `grafana/loki:3.7.8` | 로그. 라벨은 `service`·`env`·`version`·`level`, `trace_id`·`span_id`는 structured metadata | `MONITORING_BIND_ADDR:3100` | 7일 |
| `tempo` | `grafana/tempo:3.1.0` | trace(HTTP·JDBC span) | OTLP `MONITORING_BIND_ADDR:4317`, 조회 `127.0.0.1:3200` | 7일 |
| `grafana` | `grafana/grafana:13.2.3` | 데이터 소스·대시보드 파일 프로비저닝, 로그 ↔ trace 이동 | `127.0.0.1:3000` | 볼륨 |

- 설정 파일은 `monitoring/` 아래에 있다. Grafana에서 고친 데이터 소스·대시보드는 재기동하면 파일 내용으로 돌아간다.
- 대시보드는 두 개다. `JVM (Micrometer)`는 grafana.com 커뮤니티 대시보드 4701 revision 10을 그대로 들여온 것으로, JVM 메모리·GC·스레드를 본다. 앱은 metric의 `application` 태그로 고른다.
  `꾸기 backend`는 직접 만든 것으로, 경로별 요청량, p95·p99 응답 시간, 5xx 비율, HikariCP 연결과 backend 로그(trace_id → Tempo 이동)를 본다.
- 커뮤니티 대시보드를 새로 들여오거나 갱신할 때는 JSON의 `${DS_PROMETHEUS}`를 데이터 소스 이름 `Prometheus`로 바꾸고, `__inputs`·`__requires`를 지우고, `uid`를 고정한다.
- Grafana는 `GRAFANA_ADMIN_USER`·`GRAFANA_ADMIN_PASSWORD`(`.env`)로 로그인한다. 익명 접근은 꺼져 있다.
  이 값은 `grafana-data` 볼륨을 처음 만들 때만 반영된다. 비밀번호를 바꾸거나 폐기하려면 `.env`를 고치고 grafana를 다시 만든 뒤,
  컨테이너 환경 변수로 재설정한다(비밀번호를 명령줄에 쓰지 않아 셸 기록에 남지 않는다). 경우 2에서는 `-f` 대신 `-p kkugi-monitoring -f infra/docker-compose.monitoring-server.yml`을 쓴다.

  ```bash
  docker compose -f infra/docker-compose.yml -f infra/docker-compose.monitoring-agent.yml -f infra/docker-compose.monitoring-server.yml --env-file infra/.env up -d grafana
  docker compose -f infra/docker-compose.yml -f infra/docker-compose.monitoring-agent.yml -f infra/docker-compose.monitoring-server.yml --env-file infra/.env \
    exec grafana sh -c 'grafana cli admin reset-admin-password "$GF_SECURITY_ADMIN_PASSWORD"'
  ```
- 모니터링 파일을 빼고 띄우면 backend는 agent 없이 뜬다. metric·JSON 로그는 backend 설정이라 그대로 나온다.
- 모니터링 서버나 Alloy가 멈춰도 API는 영향을 받지 않는다. 짧은 중단은 복구 후 메워지지만 한계가 있다. 아래 기간은 각 도구의 기본값에서 계산한 것이며, 로컬에서는 154초 중단만 실측했다(metric·로그 손실 0, trace 8% 손실).
  - 로그: Alloy가 보내지 못한 묶음을 약 8분 동안 재시도한 뒤 버린다. Docker 로그 파일은 10MB × 5개에서 순환한다.
  - metric: Alloy WAL은 최대 8시간 보관하지만, Prometheus가 head block보다 오래된 샘플(대략 1-2시간 전)을 거부하므로 그보다 긴 중단은 비는 구간이 생긴다.
  - trace: agent와 Alloy의 메모리 큐가 버티는 만큼만 남고 나머지는 버려진다.
- Alloy가 멈추면 metric이 조용히 끊긴다. 알림을 붙일 때 "backend metric 미수신" 규칙으로 감지한다(후속).
- Alloy는 로그 수집을 위해 Docker 소켓을 마운트한다. `:ro`를 붙여도 Docker API 권한은 줄지 않아 호스트 권한에 준하므로, 서버 배포 전에 로그 파일을 직접 읽는 방식과 비교해 다시 정한다.
- 요청당 JDBC 실행 횟수는 Grafana Explore의 Tempo에서 TraceQL로 센다. 예: `{ span.http.route = "/api/meals" } >> { span.db.system = "mysql" } | count() > 10`

## 아직 없는 것

- backend가 FastAPI 주소를 읽을 변수 이름 — compose는 임시로 `AI_BASE_URL=http://ai:8000`을 넘긴다(결정 필요).
- 배포 환경(서버·도메인·TLS)과 운영 Secret 저장소 — 배포 방식이 정해지면 합의한다.

## CI(결정 필요)

`.gitlab-ci.yml`은 아직 만들지 않았다. SSAFY GitLab 저장소가 생기면 C가 ai-dev-harness CI 템플릿 include와
영역별 검증(harness.json의 `verify` 명령), `ai/` pytest, `contracts/*.json` 생성 단계(ADR-09)를 함께 정한다.
CI 정의는 엄격 트리거이고 GitLab 주소에 의존하므로 별도 이슈로 진행한다.
