# ADR-08: 도메인 간 통신은 도메인 이벤트 — 조회만 공개 서비스 호출

**Date:** 2026-10-03

## Context

`운동 세션 완료` 하나가 세 도메인을 건드린다: Workout(세션 저장) → Coaching(루틴 조정·칼로리 밸런스) → Growth(XP·Streak·PR 뱃지).
도메인을 4명이 개인 수직으로 소유하므로, Workout 소유자(B)가 Growth 서비스를 직접 호출하면 B가 C의 코드를 알아야 하고 두 브랜치가 엉킨다.
모놀리스 하나(Spring)라 네트워크 메시징은 필요 없다.

## Decision

- **상태 변경의 전파는 도메인 이벤트**로 한다. Spring `ApplicationEventPublisher` + `@TransactionalEventListener(AFTER_COMMIT)`.
  - 발행 도메인은 이벤트 record만 정의한다(`domain/workout/event/WorkoutSessionCompleted`). 누가 듣는지 모른다.
  - 구독 도메인이 자기 패키지에 핸들러를 둔다(`domain/growth/event/WorkoutEventHandler`).
  - 핸들러는 **멱등**해야 한다(이벤트 ID 또는 비즈니스 키로 중복 무시).
- **단순 조회**(회원의 목표 칼로리, 오늘 세션 존재 여부 등)는 타 도메인의 **public service 메서드** 호출을 허용한다. 반환 타입은 그 도메인의 entity가 아니라 **읽기 전용 DTO/record**.
- **타 도메인 Repository 직접 접근 금지.** ArchUnit으로 강제(ADR-07 규칙 2).

MVP 이벤트 목록(초안):

| 이벤트 | 발행 | 구독 |
|---|---|---|
| `MemberOnboarded` | Member | Coaching(Program 생성), Growth(초기 Nyam) |
| `MealRecorded` | Meal | Coaching(오늘 칼로리·마지막 끼니 조건), Growth(XP·Streak) |
| `MealCorrected` | Meal | Admin/ML(수정 데이터 적재) |
| `WorkoutSessionCompleted` | Workout | Coaching(adjust 호출·칼로리 밸런스), Growth(XP·Streak·PR 뱃지) |
| `WeightRecorded` | Coaching | Coaching 내부(추세 재조정) |
| `DailyGoalAchieved` | Coaching | Growth(Streak) |

## Rationale

- **발행자는 구독자를 모른다.** B는 이벤트 record 하나만 정의하고 끝. C·D가 각자 브랜치에서 핸들러를 추가한다. 스토리가 도메인 경계에서 끊긴다.
- `AFTER_COMMIT`이면 세션 저장이 롤백됐을 때 XP가 올라가는 일이 없다. 핸들러 실패가 원 트랜잭션을 깨지 않는다(v1 ADR "no-transactional-on-external-calls"와 같은 교훈).
- 조회까지 이벤트로 하면(요청-응답을 이벤트로 흉내) 코드가 비틀린다. 동기 조회는 직접 호출이 맞다 — 단 Repository가 아니라 service를 통해, entity가 아니라 DTO를 받는다.

## Alternatives Considered

- **전부 직접 서비스 호출**: 단순·디버깅 쉬움. 도메인 결합 ↑, 브랜치 충돌 ↑, 수직 소유 이점 감소. 기각.
- **전부 이벤트(조회 포함)**: 순수하지만 동기 조회를 이벤트로 흉내 내면 비틀림. 기각.
- **Kafka/RabbitMQ**: 모놀리스 하나에 브로커 추가는 과함. 후속에 서비스 분리 시 이벤트 record를 그대로 메시지로 승격 가능. 기각(지금은).

## Consequences

- 핸들러가 외부 호출(FastAPI adjust, FCM)을 하므로 **`@Async`** 로 돌리고 실패는 로그 + 재시도 테이블(또는 단순 재시도)로 처리. 1주차 D가 공통 이벤트 인프라(`global/event/`)를 만든다.
- 디버깅: 이벤트 흐름이 코드에서 보이지 않으므로 **이벤트 목록 표를 `docs/renewal/events.md`로 유지**하고 PR에서 갱신(규칙 파일).
- 테스트: 발행 도메인은 "이벤트가 발행됐는가"만, 구독 도메인은 "이벤트를 받으면 상태가 바뀌는가"만 테스트. 통합은 E2E로.
