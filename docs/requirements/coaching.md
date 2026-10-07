# 요구사항 명세 — Coaching

| 항목 | 값 |
|---|---|
| 상태 | 초안 (제안). 소유자 D 확정 전 |
| 도메인 소유 | D (Coaching) |
| 표면 | 폰 · 웹 |
| MVP | 1: Program·DailyGoal, 오늘 칼로리. 2: 칼로리 밸런스, 루틴 조정 호출. 3: 마지막 끼니 추천, 주간 리포트, 체중 추세, FCM 판단, RAG(후순위) |
| 관련 | [기획서 3.1·5.2·5.3](../renewal/plan.md), [이벤트 목록](../renewal/events.md), [ERD Coaching](../design/erd.md#5-coaching), [ADR-0008](../adr/0008-domain-events.md), [ADR-0013](../adr/0013-rest-fcm-sse.md) |

## 1. 범위

- 포함: Program 생성·조회, DailyGoal, 오늘 칼로리 요약, 칼로리 밸런스, 루틴 조정 호출, 마지막 끼니 추천, 주간 리포트, 체중 기록·추세·재조정, FCM 트리거 판단, RAG 채팅 중계
- 제외: Multi-Agent 코칭·2주 체크인(기획서 7장), FCM 발송 자체(`infrastructure/fcm`), 루틴 데이터 소유(Workout)

## 2. 기능 요구사항

| ID | 요구사항 | 인수 조건 | MVP | 상태 |
|---|---|---|---|---|
| REQ-COACH-01 | 온보딩이 끝나면 Program을 만든다 | `MemberOnboarded`를 받으면 Member 공개 조회로 신체 정보를 얻고 FastAPI `/ai/plan`을 호출해 Program(목표 kcal, 영양 비율, 시작일)을 저장한다. 같은 회원에 Program이 이미 있으면 무시한다(멱등) | 1 | 제안 |
| REQ-COACH-02 | FastAPI가 실패해도 Program은 만들어진다 (가정) | `/ai/plan` 실패·타임아웃이면 기본 산식(가정: Mifflin-St Jeor × 활동 계수, 목표별 ±)으로 만들고 `source=FORMULA`로 표시한다. 홈은 목표 칼로리를 바로 받는다 | 1 | 제안 |
| REQ-COACH-03 | 하루 목표를 제공한다 | 날짜별 DailyGoal(목표 kcal)을 Program에서 파생해 돌려준다. 없으면 조회 시점에 만든다 (가정). (member, goal_date)는 유일하다 | 1 | 제안 |
| REQ-COACH-04 | 오늘 칼로리 요약을 제공한다 | 홈용 API가 목표·섭취·잔여를 돌려준다. 섭취는 Meal 공개 조회로 얻는다. Program이 아직 없으면 목표를 null로 주고 폰이 "계산 중"으로 보여준다 | 1 | 제안 |
| REQ-COACH-05 | 식사 저장이 오늘 칼로리에 반영된다 | `MealRecorded` 이후 요약 조회에 새 kcal가 보인다. 마지막 끼니 추천 조건(REQ-COACH-08)도 이 시점에 평가한다 | 1 | 제안 |
| REQ-COACH-06 | 운동 소모를 칼로리 밸런스에 반영한다 | `WorkoutSessionCompleted.burnedKcal`를 그날 소모로 더해 잔여 = 목표 + 소모 − 섭취로 계산한다. 같은 sessionId는 한 번만 반영한다 | 2 | 제안 |
| REQ-COACH-07 | 세션 완료 후 루틴 조정을 요청한다 | `WorkoutSessionCompleted`를 받으면 FastAPI `/ai/routine/adjust`를 호출해 결정(UP·HOLD·DOWN·VOLUME_UP·DELOAD)을 받는다. 결과를 Workout에 반영하는 경로는 미결(이벤트 목록에 없음) | 2 | 제안 |
| REQ-COACH-08 | 마지막 끼니를 추천한다 | 17시 이후이고 그날 잔여 끼니가 1끼면 잔여 kcal ±20% 안의 식사를 추천한다. 추천은 FastAPI `/ai/meal`로 만들고 하루 1회만 (가정) | 3 | 제안 |
| REQ-COACH-09 | 주간 리포트를 만든다 | 매주 월요일 00:30 Asia/Seoul (가정)에 지난주 식사·운동·체중 요약을 생성한다. 생성 후 FCM 트리거 판단으로 넘긴다 | 3 | 제안 |
| REQ-COACH-10 | 체중을 기록하고 추세를 계산한다 | 수동 입력과 Health Connect 읽기 모두 `WeightRecorded(memberId, weightKg, recordedAt)`를 발행한다. 7일 이동 평균 (가정)으로 추세를 계산하고, 2주 추세가 목표와 어긋나면 `/ai/plan/weekly-adjust`로 목표 kcal를 재조정한다 | 3 | 제안 |
| REQ-COACH-11 | DailyGoal 달성을 판정한다 | 달성 조건(미결, 가정: 섭취가 목표 ±10% 이내)을 만족하면 `DailyGoalAchieved(memberId, date)`를 하루 1회만 발행한다. 판정 시점은 기록 직후와 자정 배치 | 1 | 제안 |
| REQ-COACH-12 | FCM 발송 조건을 판단한다 | Streak 리마인드(가정: 20시까지 기록 없음), 마지막 끼니 추천 생성, 주간 리포트 생성 시 `infrastructure/fcm`에 발송을 요청한다. 페이로드는 종류와 ID만 | 3 | 제안 |
| REQ-COACH-13 | RAG 영양 채팅을 중계한다 | FastAPI `/ai/chat`의 스트림을 SSE로 그대로 넘긴다. RAG 스토리 안에서만 구현한다(ADR-0013) | 3(후순위) | 제안 |

## 3. 정책

- Coaching은 Workout·Meal·Member의 테이블을 읽지 않는다. 이벤트와 공개 조회만 쓴다(ADR-0008).
- FastAPI 호출은 `infrastructure/ai`의 인터페이스로만 한다. 실패는 로그와 재시도 또는 폴백으로 처리하고 사용자 요청을 실패시키지 않는다.
- 추천·리포트 본문은 Claude가 만들고, 수치(목표·섭취·소모)는 Spring이 계산한다. Claude 출력의 숫자를 저장 기준으로 쓰지 않는다 (가정).
- "오늘"은 Asia/Seoul 기준이다(REQ-NF-06).

## 4. 이벤트와 공개 조회

| 구분 | 이름 | 시점·용도 | 페이로드·반환 |
|---|---|---|---|
| 구독 | `MemberOnboarded` | Program 생성 | memberId, healthGoal |
| 구독 | `MealRecorded` | 오늘 칼로리 갱신, 마지막 끼니 조건 평가 | memberId, mealId, recordedAt, kcal |
| 구독 | `WorkoutSessionCompleted` | 루틴 조정 호출, 칼로리 밸런스 | memberId, sessionId, totalVolumeKg, burnedKcal, prs[] |
| 발행 | `WeightRecorded` | 체중 저장 후 | memberId, weightKg, recordedAt |
| 발행 | `DailyGoalAchieved` | 달성 판정 시 | memberId, date |
| 공개 조회 | 목표 칼로리 (`getTargetCalories(memberId)`) | Growth·홈 | 목표 kcal DTO |

## 5. 미결

| 항목 | 결정자 | 기한 |
|---|---|---|
| Program 기본 산식과 FastAPI 실패 폴백 | D·E | 2주차 |
| DailyGoal 달성 조건 | D·C | MVP-1 이전 |
| 루틴 조정 결과를 Workout에 반영하는 경로(새 이벤트 또는 Workout 쓰기 서비스) | D·B | MVP-2 이전 |
| 주간 리포트 생성 시각과 FCM 발송 시각 | D | MVP-3 이전 |
| 체중 추세 산식과 재조정 조건 | D·E | MVP-3 이전 |
