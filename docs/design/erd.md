# 논리 ERD

| 항목 | 값 |
|---|---|
| 상태 | 초안 (제안). 1주차 "ERD" 마일스톤의 출발점. D와 각 도메인 소유자 확정 전 |
| 범위 | MySQL 업무 DB(Spring만 쓰기). 폰·워치 Room은 11장에서 범위만 적는다 |
| 관련 | [기획서 3.1·5.2](../renewal/plan.md), [이벤트 목록](../renewal/events.md), [스키마 규칙](./schema-rules.md), [ADR-0003](../adr/0003-phone-offline-workout-only.md), [ADR-0007](../adr/0007-backend-feature-package.md), [ADR-0008](../adr/0008-domain-events.md), [ADR-0011](../adr/0011-mlflow-and-ai-ml-split.md), [ADR-0013](../adr/0013-rest-fcm-sse.md) |

논리 모델이므로 타입은 뜻만 적는다. 물리 타입·길이·인덱스 이름은 [스키마 규칙](./schema-rules.md)을 따른다.
`(가정)`은 작성자가 채운 초안이다. 테이블 이름 중 `meal_prediction`·`meal_correction`·`correction_review`(ADR-0011)와
`member_device`(ADR-0013)는 이미 ADR에 적힌 이름이다.

## 1. 도메인 간 참조 규칙

- 테이블은 소유 도메인의 패키지 `domain/{x}/entity/`에만 매핑한다. 다른 도메인의 entity·repository를 쓰지 않는다(ADR-0007·0008).
- 도메인 경계를 넘는 참조는 **ID 값만** 둔다(`member_id`처럼). JPA 연관관계를 걸지 않고, DB 외래 키도 선언하지 않는다 (가정, 스키마 규칙 5장).
- 다른 도메인의 상세가 필요하면 그 도메인의 공개 조회 서비스를 부른다. 조인하지 않는다.
- 이벤트로 넘어온 ID(`mealId`, `sessionId`)는 멱등 키로 저장한다(`xp_log.source_id` 등).

```mermaid
erDiagram
    MEMBER ||--o{ MEAL : "member_id"
    MEMBER ||--o{ WORKOUT_SESSION : "member_id"
    MEMBER ||--o| PROGRAM : "member_id"
    MEMBER ||--o| GROWTH_STATUS : "member_id"
    MEAL ||--o| MEAL_PREDICTION : "owns"
    MEAL_PREDICTION ||--o| MEAL_CORRECTION : "pair"
    MEAL_CORRECTION ||--o| CORRECTION_REVIEW : "correction_id"
```

위 그림은 도메인 사이의 ID 참조만 보여준다. 도메인 안의 관계는 아래 절에 있다.

## 2. Member

소유 C. 계정·온보딩·프로필·기기.

```mermaid
erDiagram
    member ||--o{ social_account : "has"
    member ||--o| member_profile : "has"
    member ||--o{ member_device : "has"

    member {
        bigint id PK
        varchar nickname
        varchar status "ACTIVE, DEACTIVATED"
        varchar role "USER, ADMIN (가정)"
        datetime onboarded_at "null이면 온보딩 전"
        datetime deactivated_at
        datetime created_at
        datetime updated_at
    }
    social_account {
        bigint id PK
        bigint member_id FK
        varchar provider "KAKAO, GOOGLE, EMAIL_DEV (가정)"
        varchar provider_user_id
        varchar email "provider가 주면 저장 (가정)"
        datetime created_at
    }
    member_profile {
        bigint member_id PK "member 1:1"
        varchar gender "(가정)"
        date birth_date "(가정)"
        decimal height_cm
        decimal weight_kg "온보딩 시점 값. 추세는 Coaching weight_record"
        varchar activity_level "(가정, 미결)"
        varchar health_goal "LOSE, MAINTAIN, GAIN (가정)"
        datetime updated_at
    }
    member_device {
        bigint id PK
        bigint member_id FK
        varchar install_id "앱 설치 식별자 (가정)"
        varchar fcm_token
        varchar platform "ANDROID, WEB"
        datetime updated_at
    }
```

- `social_account(provider, provider_user_id)` 유일. 한 회원에 provider당 하나.
- `member_device(member_id, install_id)` 유일. 같은 기기의 토큰은 덮어쓴다(REQ-MEMBER-12).
- 인증 토큰·블랙리스트는 Redis에 둔다 (가정). 테이블 없음.

## 3. Meal

소유 A. 식사 기록과 예측·수정 쌍.

```mermaid
erDiagram
    meal ||--|{ meal_item : "has"
    food ||--o{ meal_item : "food_id"
    meal ||--o| meal_prediction : "photo only"
    meal_prediction ||--o| meal_correction : "pair"

    food {
        bigint id PK
        varchar name
        varchar serving_unit "g 기본 (가정)"
        decimal kcal_per_100g
        decimal carb_g_per_100g
        decimal protein_g_per_100g
        decimal fat_g_per_100g
        varchar source "출처 (미결)"
        datetime created_at
    }
    meal {
        bigint id PK
        bigint member_id "Member ID 참조"
        varchar meal_type "BREAKFAST, LUNCH, DINNER, SNACK (가정)"
        datetime eaten_at
        varchar input_method "PHOTO, SEARCH"
        varchar photo_path "SEARCH면 null"
        decimal total_kcal "항목 합, 비정규화 (가정)"
        decimal carb_g
        decimal protein_g
        decimal fat_g
        datetime deleted_at "soft delete (가정)"
        datetime created_at
        datetime updated_at
    }
    meal_item {
        bigint id PK
        bigint meal_id FK
        bigint food_id FK "Food DB에 없으면 null"
        varchar food_name "표시용 스냅샷"
        decimal quantity
        varchar unit
        decimal kcal
        decimal carb_g
        decimal protein_g
        decimal fat_g
        int sort_order
    }
    meal_prediction {
        bigint id PK
        bigint meal_id FK
        varchar model_name
        varchar model_version "MLflow 버전 또는 외부 API 식별자"
        json raw_output "모델 출력 원본"
        varchar top1_food_name
        decimal top1_quantity
        decimal confidence
        int latency_ms
        datetime created_at
    }
    meal_correction {
        bigint id PK
        bigint prediction_id FK "유일"
        bigint meal_id FK
        varchar corrected_food_name
        decimal corrected_quantity
        boolean is_changed "예측과 다르면 true"
        datetime created_at
    }
```

- `meal_prediction`·`meal_correction`은 식사가 삭제돼도 남는다(REQ-NF-09). 삭제는 `meal.deleted_at`.
- `meal_correction.prediction_id` 유일. 예측 하나에 확정값 하나.
- `ml/datasets`는 이 세 테이블을 읽기만 한다(ADR-0011). 검수 결과는 Admin의 `correction_review`.

## 4. Workout

소유 B. MVP-2이지만 1주차 ERD에 포함한다. 서버 테이블이며 Room 스키마는 11장.

```mermaid
erDiagram
    routine ||--|{ routine_exercise : "has"
    exercise ||--o{ routine_exercise : "exercise_id"
    routine ||--o{ workout_session : "routine_id nullable"
    workout_session ||--|{ workout_set : "has"
    exercise ||--o{ workout_set : "exercise_id"
    exercise ||--o{ personal_record : "exercise_id"
    workout_session ||--o{ personal_record : "achieved in"
    workout_session ||--o{ adjustment : "from_session_id"

    exercise {
        bigint id PK
        varchar name
        varchar muscle_group "(가정)"
        varchar equipment "(가정)"
    }
    routine {
        bigint id PK
        bigint member_id "Member ID 참조"
        varchar name "예: Push Day"
        date scheduled_date "워치에 내려줄 날짜"
        varchar source "AI, MANUAL"
        varchar status "PLANNED, DONE, SKIPPED (가정)"
        datetime created_at
        datetime updated_at
    }
    routine_exercise {
        bigint id PK
        bigint routine_id FK
        bigint exercise_id FK
        int sort_order
        int target_sets
        int target_reps
        decimal target_weight_kg
        int rest_seconds "(가정)"
    }
    workout_session {
        bigint id PK
        uuid client_uuid "기기 생성, 유일. 업로드 멱등 키"
        bigint member_id "Member ID 참조"
        bigint routine_id FK "자유 운동이면 null"
        varchar owner_device "WATCH, PHONE"
        datetime started_at
        datetime ended_at
        int avg_heart_rate
        int max_heart_rate
        decimal burned_kcal
        decimal total_volume_kg
        datetime uploaded_at "서버 수신 시각"
    }
    workout_set {
        bigint id PK
        bigint session_id FK
        bigint exercise_id FK
        int set_no
        decimal weight_kg
        int reps
        datetime completed_at
    }
    personal_record {
        bigint id PK
        bigint member_id "Member ID 참조"
        bigint exercise_id FK
        decimal weight_kg
        int reps
        bigint session_id FK
        datetime achieved_at
    }
    adjustment {
        bigint id PK
        bigint member_id "Member ID 참조"
        bigint exercise_id FK
        varchar decision "UP, HOLD, DOWN, VOLUME_UP, DELOAD"
        bigint from_session_id FK
        decimal next_weight_kg
        datetime created_at
    }
```

- `workout_session.client_uuid` 유일. 같은 UUID가 다시 오면 새로 만들지 않고 기존 세션을 돌려준다(ADR-0003).
- 세션은 항상 폰이 업로드한다. 워치 전용 테이블은 없다(ADR-0002).
- `adjustment`는 Coaching이 FastAPI에서 받은 결정을 Workout이 저장한 것이다. 전달 경로는 미결(요구사항 Coaching REQ-COACH-07).

## 5. Coaching

소유 D. 계획·목표·체중·리포트.

```mermaid
erDiagram
    program ||--o{ daily_goal : "derives"

    program {
        bigint id PK
        bigint member_id "Member ID 참조, 활성 1개"
        decimal target_kcal
        decimal carb_ratio "(가정)"
        decimal protein_ratio "(가정)"
        decimal fat_ratio "(가정)"
        varchar source "AI, FORMULA"
        date started_on
        date ended_on "재조정으로 닫히면 기록"
        datetime created_at
    }
    daily_goal {
        bigint id PK
        bigint member_id "Member ID 참조"
        date goal_date
        decimal target_kcal
        boolean achieved
        datetime achieved_at
    }
    weight_record {
        bigint id PK
        bigint member_id "Member ID 참조"
        decimal weight_kg
        varchar source "MANUAL, HEALTH_CONNECT"
        datetime recorded_at
    }
    weekly_report {
        bigint id PK
        bigint member_id "Member ID 참조"
        date week_start
        json content "요약 수치와 코멘트"
        datetime created_at
    }
    meal_recommendation {
        bigint id PK
        bigint member_id "Member ID 참조"
        date for_date
        decimal remaining_kcal
        json content
        datetime created_at
    }
```

- `daily_goal(member_id, goal_date)` 유일. `DailyGoalAchieved`를 하루 1회만 발행하는 근거.
- `weekly_report(member_id, week_start)` 유일.
- 운동 소모 kcal는 저장하지 않고 조회 시점에 Workout 공개 조회 또는 이벤트 수신 값으로 계산한다 (가정, 미결).
- RAG 채팅 이력 테이블은 RAG 스토리에서 결정한다.

## 6. Growth

소유 C. 상태 1행 + 적립 로그 + 뱃지.

```mermaid
erDiagram
    growth_status ||--o{ xp_log : "member_id"
    badge ||--o{ member_badge : "badge_id"
    growth_status ||--o{ member_badge : "member_id"
    growth_status ||--o{ daily_mission : "member_id"

    growth_status {
        bigint member_id PK "Member ID, 1:1"
        int xp
        int level
        int nyam_stage
        int streak_days
        int longest_streak
        date last_achieved_date
        datetime updated_at
    }
    xp_log {
        bigint id PK
        bigint member_id
        varchar source_type "MEAL, WORKOUT, MISSION, PR"
        bigint source_id "mealId, sessionId 등"
        int amount
        datetime created_at
    }
    badge {
        bigint id PK
        varchar code "STREAK_7, FIRST_PR 등"
        varchar name
        varchar description
    }
    member_badge {
        bigint id PK
        bigint member_id
        bigint badge_id FK
        datetime earned_at
    }
    daily_mission {
        bigint id PK
        bigint member_id
        date mission_date
        varchar type "(가정)"
        int target
        int progress
        datetime completed_at
    }
```

- `xp_log(source_type, source_id)` 유일. 이벤트 중복 수신을 걸러내는 멱등 키(REQ-NF-12).
- `member_badge(member_id, badge_id)` 유일.
- 레벨 경계·외형 단계 매핑은 테이블이 아니라 설정에 둔다 (가정, REQ-GROWTH-04·05).

## 7. Admin · ML

소유 E(검수 데이터)·F(관리자 UI). Spring 테이블은 검수 하나다. 데이터셋 버전·모델 버전·지표는 MLflow에 있다(ADR-0011).

```mermaid
erDiagram
    correction_review {
        bigint id PK
        bigint correction_id "Meal meal_correction ID 참조, 유일"
        bigint reviewer_id "Member ID 참조, ADMIN"
        varchar decision "APPROVED, REJECTED"
        varchar reason
        datetime reviewed_at
    }
```

- `correction_review.correction_id` 유일. 수정 하나에 검수 결과 하나. 재검수는 행을 갱신한다 (가정).
- `ml/datasets`는 `APPROVED`인 correction만 읽어 데이터셋을 만든다.

## 8. 이벤트와 테이블의 대응

| 이벤트 | 발행 측 쓰기 | 구독 측 쓰기 |
|---|---|---|
| `MemberOnboarded` | `member.onboarded_at`, `member_profile` | `program`, `daily_goal` / `growth_status` |
| `MealRecorded` | `meal`, `meal_item`, (`meal_prediction`, `meal_correction`) | `daily_goal.achieved` 평가 / `xp_log`, `growth_status` |
| `MealCorrected` | 위와 같음 | 없음(검수는 관리자가 `correction_review`에) |
| `WorkoutSessionCompleted` | `workout_session`, `workout_set`, `personal_record` | `adjustment`(경로 미결) / `xp_log`, `member_badge` |
| `WeightRecorded` | `weight_record` | `program`(재조정 시 새 행) |
| `DailyGoalAchieved` | `daily_goal.achieved_at` | `growth_status.streak_days`, `member_badge` |

## 9. 미결

| 항목 | 결정자 | 기한 |
|---|---|---|
| 식별자 타입(BIGINT 자동 증가 vs UUID). 전 테이블 규약이라 ADR 대상 | D | 1주차 |
| 도메인 간 DB 외래 키 선언 여부 | D | 1주차 |
| 신체 정보 항목(활동량 포함 여부) | C·D | 2주차 |
| 운동 소모 kcal 저장 위치 | D·B | MVP-2 이전 |
| `adjustment` 저장 주체와 전달 경로 | D·B | MVP-2 이전 |
| Food DB 출처와 적재 | A·E | 2주차 |

## 10. 변경 절차

1. 이 문서를 먼저 고친다(해당 도메인 절). 다른 도메인이 참조하는 ID·이벤트가 바뀌면 상대 소유자를 리뷰어로 넣는다.
2. 같은 MR에서 마이그레이션 파일과 entity를 바꾼다([스키마 규칙 7장](./schema-rules.md)).
3. backend 영역 엄격 판정(트리거 1)이다. D 승인 후 병합한다.

## 11. 폰·워치 Room (범위만)

- Room은 `:core`의 Workout 테이블만 가진다(ADR-0003). 세션·세트·업로드 상태(`pending_upload`)를 두고 `client_uuid`를 서버와 공유한다.
- 워치 Room은 세션·세트를 로컬에 먼저 쓰고 폰 연결 시 Data Layer로 넘긴다(ADR-0002).
- 스키마 내보내기와 마이그레이션 테스트 방식은 첫 Workout 테이블 확정 때 B가 정한다(android/README "결정 필요").
