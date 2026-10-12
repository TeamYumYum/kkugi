# 물리 스키마 규칙과 마이그레이션 정책

| 항목 | 값 |
|---|---|
| 상태 | 초안 (제안). D(Spring 홈) 확정 전 |
| 소유 | D |
| 범위 | MySQL 8.4 업무 DB. 쓰기는 Spring만(ADR-0011). 폰·워치 Room은 B가 별도로 정한다 |
| 관련 | [논리 ERD](./erd.md), [기획서 9장](../renewal/plan.md), [ADR-0007](../adr/0007-backend-feature-package.md), [ADR-0012](../adr/0012-vertical-ownership.md), [Git 컨벤션](../git-convention.md), `backend/src/main/resources/application.yml` |

`(가정)`은 D가 확정하기 전의 초안값이다. 식별자 타입처럼 전 테이블에 걸치는 규약은 ADR로도 남긴다(ADR README "무엇을 ADR로 남기나").

## 1. 명명

| 대상 | 규칙 | 예 |
|---|---|---|
| 테이블 | snake_case 단수. 도메인 접두사는 ADR에 이미 쓴 이름(`meal_prediction`, `member_device`)을 따르고, 그 밖에는 충돌할 때만 붙인다 | `meal`, `workout_session`, `daily_goal` |
| 컬럼 | snake_case | `target_kcal`, `eaten_at` |
| 기본 키 | `id` | |
| 참조 | `{참조 테이블}_id`. 도메인 밖 참조도 같은 이름 | `member_id`, `routine_id` |
| 불리언 | `is_` 접두사. 상태는 불리언 대신 `status` 문자열 | `is_changed`, `status` |
| 시각 | `_at` 접미사 | `created_at`, `uploaded_at` |
| 날짜 | `_date` 또는 `_on` 접미사 | `goal_date`, `started_on` |
| 단위가 있는 수치 | 단위를 이름에 넣는다 | `weight_kg`, `height_cm`, `total_kcal`, `rest_seconds` |
| 인덱스 | `idx_{테이블}_{컬럼들}` | `idx_meal_member_id_eaten_at` |
| 유일 제약 | `uk_{테이블}_{컬럼들}` | `uk_daily_goal_member_id_goal_date` |
| 외래 키 | `fk_{테이블}_{참조 테이블}` | `fk_meal_item_meal` |
| 열거 값 | 대문자 SNAKE_CASE 문자열. MySQL `ENUM` 타입은 쓰지 않는다 (가정) | `PHOTO`, `VOLUME_UP` |

## 2. 타입

| 뜻 | 물리 타입 (가정) | 비고 |
|---|---|---|
| 식별자 | `BIGINT UNSIGNED AUTO_INCREMENT` | 미결. UUID와 비교해 D가 1주차에 정하고 ADR로 남긴다 |
| 클라이언트 생성 키 | `CHAR(36)` | `workout_session.client_uuid`만. 서버 PK와 별도 |
| 시각 | `DATETIME(6)` | JVM·MySQL 세션·`serverTimezone` 모두 Asia/Seoul(`application.yml`). UTC 저장으로 바꿀지 미결 |
| 날짜 | `DATE` | Asia/Seoul 기준 날짜 |
| 열거 | `VARCHAR(30)` | Java enum 이름 그대로 |
| 짧은 문자열 | `VARCHAR(50)` 이름류, `VARCHAR(255)` 경로·토큰 | 길이는 용도별 상한을 정해 적는다 |
| 긴 문자열 | `TEXT` | 사유·코멘트 |
| 구조화 데이터 | `JSON` | 모델 출력 원본, 리포트 본문. 조회 조건으로 쓰지 않는다 |
| 영양·무게 | `DECIMAL(8,2)` | kcal, g, kg. 부동소수점을 쓰지 않는다 |
| 횟수·점수 | `INT` | reps, xp, streak |
| 불리언 | `TINYINT(1)` | JPA `boolean` |
| 문자 집합 | `utf8mb4`, `utf8mb4_0900_ai_ci` | 이모지·한글 |

## 3. 공통 컬럼

- 모든 테이블에 `created_at DATETIME(6) NOT NULL`. 갱신되는 테이블에 `updated_at DATETIME(6) NOT NULL`. JPA Auditing의 `BaseEntity`로 채운다 (가정: `global/entity/BaseEntity`).
- 로그·이력 테이블(`xp_log`, `weight_record`, `meal_prediction`)은 `updated_at`을 두지 않는다.
- soft delete가 필요한 테이블에만 `deleted_at DATETIME(6) NULL`. 요구사항이 요구하지 않으면 두지 않는다. 현재 대상은 `meal`뿐이다.

## 4. 제약과 인덱스

- 컬럼은 `NOT NULL` 기본. null 허용은 뜻이 있을 때만(`onboarded_at`이 null = 온보딩 전).
- 멱등 키는 유일 제약으로 강제한다. 애플리케이션 검사만으로 두지 않는다.
  - `uk_social_account_provider_provider_user_id`
  - `uk_member_device_member_id_install_id`
  - `uk_workout_session_client_uuid`
  - `uk_daily_goal_member_id_goal_date`
  - `uk_weekly_report_member_id_week_start`
  - `uk_xp_log_source_type_source_id`
  - `uk_member_badge_member_id_badge_id`
  - `uk_meal_correction_prediction_id`
  - `uk_correction_review_correction_id`
- 조회 패턴에 맞는 인덱스를 함께 만든다. 최소: `(member_id, eaten_at)`, `(member_id, started_at)`, `(member_id, recorded_at)`, `(member_id, goal_date)`.
- 외래 키는 5장 규칙을 따른다.

## 5. 도메인 경계와 외래 키 (가정)

- **도메인 안** 관계는 DB 외래 키를 선언한다(`meal_item → meal`, `workout_set → workout_session`).
- **도메인 밖** 참조(`member_id`, `correction_id`)는 외래 키를 선언하지 않고 ID 값만 둔다. 이유: 도메인별 마이그레이션이 서로를 기다리지 않고, 테이블 소유가 패키지 소유와 일치하며, 타 도메인 테이블을 알지 않아도 된다. 무결성은 애플리케이션과 이벤트 멱등 처리로 지킨다.
- `ON DELETE CASCADE`는 쓰지 않는다. 삭제는 소프트 또는 서비스가 순서대로 한다.

## 6. JPA

- `spring.jpa.hibernate.ddl-auto=none`(`application.yml`). Hibernate가 스키마를 만들거나 고치지 않는다.
- CI에 `validate` 단계를 둬 entity와 마이그레이션 결과가 어긋나면 빌드가 실패하게 한다 (가정, C·D).
- entity는 테이블 하나에 하나. 도메인 밖 ID는 `Long memberId`처럼 값으로만 둔다(ERD 1장).
- `@Enumerated(EnumType.STRING)`만 쓴다. ORDINAL 금지.
- 테스트는 H2 MySQL 호환 모드(`src/test/resources/application.yml`)에서 돈다. MySQL 전용 문법(`JSON` 함수 등)은 쿼리에 쓰지 않거나 테스트에서 분리한다.

## 7. 마이그레이션 정책

| 항목 | 규칙 |
|---|---|
| 도구 | 미결. 추천 **Flyway**(기획서 9장). D가 1주차에 정한다. 아래는 Flyway 기준 (가정) |
| 위치 | `backend/src/main/resources/db/migration/` |
| 파일 이름 | `V{yyyyMMddHHmm}__{domain}_{description}.sql`. 예 `V202610071030__meal_create_meal_tables.sql`. 번호 대신 시각을 쓰는 이유: 6명이 병렬 브랜치에서 마이그레이션을 만들어도 번호가 충돌하지 않는다 |
| 한 파일 | 한 도메인, 한 목적. 여러 도메인 테이블을 한 파일에 섞지 않는다 |
| 적용 시점 | backend 기동 시 자동 적용. 적용 실패는 기동 실패다 |
| 수정 금지 | `main`에 병합된 마이그레이션은 고치지 않는다. 바꾸려면 새 파일을 만든다. 로컬에서만 적용한 파일은 고쳐도 되지만 DB를 다시 만든다 |
| 하위 호환 | 데모 사이에 롤백할 수 있도록 **확장 → 전환 → 수축** 순서로 나눈다. 컬럼 삭제·이름 변경·NOT NULL 추가는 코드가 새 컬럼으로 옮겨간 다음 MR에서 한다 |
| 롤백 | Undo 마이그레이션을 쓰지 않는다. 앞으로 고치는 마이그레이션(forward fix)이 원칙이고, DB 백업 복원은 마지막 수단이다([롤백 Runbook](../operations/runbooks/rollback.md)) |
| 데이터 이관 | 스키마 변경과 데이터 변경(UPDATE)을 같은 파일에 섞지 않는다. 데이터 변경은 `R__` 또는 별도 `V` 파일로 두고 멱등하게 쓴다 |
| 초기 데이터 | `exercise`, `food`, `badge` 같은 기준 데이터는 마이그레이션이 아니라 별도 적재 스크립트로 넣는다 (가정, 위치 미결) |
| 브랜치 | 1 Story = 1 Branch에 폰·백엔드·마이그레이션을 함께 둔다(ADR-0012). 마이그레이션만 따로 선행하지 않는다. 단, 여러 스토리가 동시에 기다리는 테이블은 선행 작업으로 분리할 수 있다(루트 `AGENTS.md` 3장) |
| 리뷰 | 마이그레이션 파일이 있는 MR은 backend 엄격 판정이고 D 승인이 필요하다. ERD가 같은 MR에서 갱신돼야 한다 |

## 8. 변경 절차

1. [ERD](./erd.md) 해당 절을 고친다. 도메인 밖 ID나 이벤트 페이로드가 바뀌면 상대 도메인 소유자를 리뷰어로 넣는다.
2. 마이그레이션 파일을 만들고 로컬 MySQL(compose)에서 깨끗한 DB와 기존 DB 양쪽에 적용해 본다.
3. entity를 맞춘다. 테스트(H2)와 `./gradlew build`가 통과해야 한다.
4. MR 본문에 "DB 변경" 영향과 롤백 방법(하위 호환 여부)을 적는다(Git 컨벤션 4장).

## 9. 미결

| 항목 | 결정자 | 기한 |
|---|---|---|
| 마이그레이션 도구(Flyway / Liquibase) | D | 1주차 |
| 식별자 타입. ADR로 기록 | D | 1주차 |
| 시각 저장 기준(Asia/Seoul 유지 / UTC 저장) | D | 1주차 |
| 도메인 간 외래 키 미선언 원칙 | D | 1주차 |
| CI `validate` 단계 | C·D | CI 구성 시 |
| 기준 데이터(운동·음식·뱃지) 적재 방식 | A·B·C | 2주차 |
