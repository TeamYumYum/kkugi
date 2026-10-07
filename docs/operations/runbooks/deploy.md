# Runbook — 배포

| 항목 | 값 |
|---|---|
| 상태 | 초안 (가정: docker compose 단일 호스트). 배포 환경이 정해지면 C가 명령을 실제 환경으로 바꾼다 |
| 적용 상황 | `main`의 검증된 커밋(보통 `demo/*`·`final` 태그)을 서버에 올릴 때 |
| 소요 | 15~30분 (가정) |
| 관련 | [infra/README.md](../../../infra/README.md), [개발 흐름 7장](../../development-workflow.md), [Git 컨벤션 4장](../../git-convention.md), [스키마 규칙 7장](../../design/schema-rules.md), [롤백](./rollback.md) |

## 사전 조건

- 배포할 커밋이 `main`에 있고 루트 README의 검증 명령이 모두 통과했다(개발 흐름 7장 2단계).
- 서버에 Docker·docker compose·Node(web 빌드용, 가정)가 있고 저장소가 clone돼 있다.
- `infra/.env`가 채워져 있다. 필수 변수가 비면 compose가 바로 멈춘다. 값은 Secret 규칙 3장의 보관 위치에서 가져온다.
- 이번 배포에 마이그레이션이 있으면 **하위 호환 여부**를 MR 본문에서 확인했다. 비호환이면 롤백 Runbook B 절차를 먼저 읽는다.
- 팀 채널에 배포 예고를 올렸다. 데모 직전이면 [데모 Runbook](./demo.md)의 D-1 항목을 먼저 끝낸다.

## 권한

- 서버 SSH(C). `infra/.env` 읽기(C, 필요 시 D).
- 태그 Push는 팀장(Git 컨벤션 4장).

## 절차

1. **커밋 확정**. 서버에서 저장소를 최신화하고 배포할 커밋을 적어 둔다.

   ```bash
   git fetch --tags origin
   git switch --detach <태그 또는 커밋>
   git rev-parse HEAD
   ```

2. **DB 백업**. 롤백의 전제다. 파일명에 커밋과 시각을 넣는다.

   ```bash
   docker compose -f infra/docker-compose.yml --env-file infra/.env exec -T mysql \
     sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction "$MYSQL_DATABASE"' \
     > backup/nyamnyam-$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M).sql
   ```

   `backup/`은 저장소 밖 또는 `.gitignore` 대상이어야 한다. 백업 파일은 커밋하지 않는다.

3. **웹 빌드**. nginx가 서빙할 `web/dist`를 만든다.

   ```bash
   npm --prefix web ci && npm --prefix web run build
   ```

4. **설정 검사**.

   ```bash
   docker compose -f infra/docker-compose.yml --env-file infra/.env config --quiet
   ```

5. **기동**. 이미지를 다시 빌드해 올린다.

   ```bash
   docker compose -f infra/docker-compose.yml --env-file infra/.env up -d --build
   docker compose -f infra/docker-compose.yml --env-file infra/.env ps
   ```

6. **마이그레이션 확인**. backend 기동 로그에서 마이그레이션 적용 줄과 오류 유무를 본다. 적용 실패는 기동 실패이므로 backend 컨테이너가 재시작을 반복한다.

   ```bash
   docker compose -f infra/docker-compose.yml --env-file infra/.env logs --tail=200 backend
   ```

7. **health**. nginx 밖으로 노출되지 않은 서비스는 컨테이너 안에서 확인한다.

   ```bash
   docker compose -f infra/docker-compose.yml --env-file infra/.env exec backend curl -fsS localhost:8080/actuator/health
   docker compose -f infra/docker-compose.yml --env-file infra/.env exec ai curl -fsS localhost:8000/ai/health
   curl -fsS http://<호스트>/            # 웹 셸
   ```

   MLflow UI는 `127.0.0.1:5000`에서 연다(서버에서 터널링).

8. **스모크**. 데모 계정으로 핵심 여정을 한 번 돈다. MVP 단계에 맞춰 늘린다.
   - MVP-1: 로그인 → 홈 → 사진 식사 기록 1건 → 홈에 XP·칼로리 반영
   - MVP-2: 위 + 루틴 → 워치에 내려감 → 세션 완료 → 폰 완료 화면
   - MVP-3: 위 + 웹 대시보드 로그인 → 관리자 검수 화면 → 모델 버전 조회

9. **기록**. 팀 채널에 커밋·태그, 시각, 실행자, DB 변경 유무, 스모크 결과를 남긴다.

## 중단 조건

다음 중 하나면 멈추고 [롤백](./rollback.md)으로 간다.

- 4단계 설정 검사 실패
- 6단계 마이그레이션 오류 또는 backend 재시작 반복
- 7단계 health 중 하나라도 실패가 2분 이상 지속
- 8단계 스모크에서 핵심 여정이 끊김

## 완료 확인

| 항목 | 기대 |
|---|---|
| `docker compose ps` | 6개 서비스 모두 `running`(healthy) |
| backend health | `{"status":"UP"}` |
| ai health | 상태와 Claude 모드, Vision 모델 로드 여부가 보인다. 모델이 없어도 기동은 정상 |
| 웹 | 셸이 열리고 API 호출이 2xx |
| 스모크 | 단계별 여정 통과 |
| 채널 기록 | 커밋·태그·시각·결과 |

## 미결

| 항목 | 결정자 |
|---|---|
| 서버·도메인·TLS. nginx 443 설정 | C |
| CI가 이미지를 빌드해 배포할지, 서버에서 `--build`할지 | C |
| `web/dist`를 서버에서 빌드할지 CI 산출물로 받을지 | C·F |
| 백업 보관 위치와 보존 기간 | C |
