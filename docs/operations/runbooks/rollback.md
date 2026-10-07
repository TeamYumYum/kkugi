# Runbook — 롤백

| 항목 | 값 |
|---|---|
| 상태 | 초안 (가정: docker compose 단일 호스트) |
| 적용 상황 | 배포 Runbook 중단 조건에 걸렸을 때, 데모 중 핵심 여정이 끊기는 결함이 드러났을 때 |
| 원칙 | 코드는 이전 태그로 되돌린다. DB는 **앞으로 고치는 것(forward fix)**이 우선이고 백업 복원은 마지막 수단이다([스키마 규칙 7장](../../design/schema-rules.md)) |
| 관련 | [배포](./deploy.md), [개발 흐름 7장](../../development-workflow.md), [Git 컨벤션 4장](../../git-convention.md) |

## 먼저 판단할 것

| 질문 | 예 | 아니오 |
|---|---|---|
| 이번 배포에 마이그레이션이 있었나 | 다음 질문으로 | **절차 A** |
| 그 마이그레이션은 하위 호환인가(컬럼·테이블 추가만, 삭제·이름 변경·NOT NULL 추가 없음) | **절차 A**. 이전 코드가 새 컬럼을 무시하면 된다 | 다음 질문으로 |
| 배포 후 사용자 쓰기가 있었나 | **절차 C** 검토(데이터 유실 범위 합의) | **절차 B** |

판단과 선택한 절차를 팀 채널에 먼저 적는다. 데모 중이면 발표자는 사전 녹화 영상으로 계속하고(데모 Runbook) 운영자만 롤백한다.

## 권한

- 서버 SSH(C). 백업 파일 접근(C). DB 복원 결정은 D(Spring 홈)와 함께.

## 절차 A — 코드만 되돌린다

1. 이전 태그(직전 `demo/*` 또는 마지막 정상 커밋)로 이동한다.

   ```bash
   git fetch --tags origin
   git switch --detach <이전 태그>
   git rev-parse HEAD
   ```

2. 웹을 다시 빌드하고 compose를 다시 올린다.

   ```bash
   npm --prefix web ci && npm --prefix web run build
   docker compose -f infra/docker-compose.yml --env-file infra/.env up -d --build
   ```

3. 배포 Runbook 7·8단계(health·스모크)를 그대로 수행한다.
4. 하위 호환 마이그레이션으로 생긴 새 컬럼·테이블은 그대로 둔다. 지우지 않는다.

## 절차 B — DB 백업 복원 + 코드 되돌리기

배포 후 쓰기가 없었을 때만. 배포 직전 백업 파일(배포 Runbook 2단계)이 있어야 한다.

1. 쓰기를 막는다. backend를 내린다.

   ```bash
   docker compose -f infra/docker-compose.yml --env-file infra/.env stop backend
   ```

2. 백업을 복원한다. 스키마를 비우고 넣는다(마이그레이션 이력 테이블도 백업 시점으로 돌아간다).

   ```bash
   docker compose -f infra/docker-compose.yml --env-file infra/.env exec -T mysql \
     sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4;"'
   docker compose -f infra/docker-compose.yml --env-file infra/.env exec -T mysql \
     sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < backup/<백업 파일>.sql
   ```

3. 절차 A 1~3단계를 수행한다.
4. 복원한 백업 파일명과 시각을 채널에 적는다.

## 절차 C — 쓰기가 있었던 뒤의 비호환 마이그레이션

백업 복원은 그 사이의 사용자 데이터를 잃는다. 데모 데이터만 있다면 팀 합의 후 절차 B. 실제 사용자 데이터가 있으면
되돌리지 않고 **앞으로 고친다**.

1. 결함을 `fix/` 브랜치에서 고치고 MR → `main` → 새 태그(개발 흐름 7장 5단계. 이미 Push한 태그는 옮기지 않는다).
2. 필요하면 되돌리는 방향의 새 마이그레이션을 추가한다(이전 파일을 고치지 않는다).
3. 배포 Runbook으로 새 태그를 올린다.

## 중단 조건

- 백업 파일이 없거나 열리지 않는다 → 절차 B 포기, 절차 C로.
- 복원 후 backend가 마이그레이션 오류로 기동하지 않는다 → 코드 커밋과 백업 시점이 어긋난 것. 백업 시점의 태그를 확인해 절차 A 1단계를 다시 한다.

## 완료 확인

| 항목 | 기대 |
|---|---|
| health·스모크 | 배포 Runbook과 같음 |
| 채널 기록 | 원인 요약, 선택한 절차, 되돌린 커밋, 데이터 유실 범위(있으면), 후속 Jira 키 |
| Jira | 결함 `fix/` 항목 등록. 동결 이후면 `fix/`만 병합(Git 컨벤션) |

## 미결

| 항목 | 결정자 |
|---|---|
| 점검 페이지(nginx 503) 제공 여부 | C |
| 백업 자동화 주기 | C |
