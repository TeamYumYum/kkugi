# 요구사항 명세 — Growth

| 항목 | 값 |
|---|---|
| 상태 | 초안 (제안). 소유자 C 확정 전 |
| 도메인 소유 | C (Member + Growth) |
| 표면 | 폰 · 워치 Tile |
| MVP | 1: 초기화, XP·레벨, 외형, Streak. 2: 운동 XP, PR 뱃지. 3: 마일스톤 뱃지, 일일 미션, Tile |
| 관련 | [기획서 3.1·J2·9장](../renewal/plan.md), [이벤트 목록](../renewal/events.md), [ERD Growth](../design/erd.md#6-growth), [ADR-0002](../adr/0002-watch-companion-offline-first.md), [ADR-0008](../adr/0008-domain-events.md) |

## 1. 범위

- 포함: Growth 상태 초기화, XP 적립·레벨, 냠냠이 외형 단계, Streak·마일스톤, 뱃지, 일일 미션, 홈·Tile용 조회
- 제외: 랭킹·친구 비교(커뮤니티, 기획서 7장), XP 상점·소비

## 2. 기능 요구사항

| ID | 요구사항 | 인수 조건 | MVP | 상태 |
|---|---|---|---|---|
| REQ-GROWTH-01 | 온보딩이 끝나면 Growth 상태를 만든다 | `MemberOnboarded`를 받으면 xp 0, level 1, nyam_stage 1, streak 0으로 저장한다. 이미 있으면 무시한다(멱등) | 1 | 제안 |
| REQ-GROWTH-02 | 식사 기록에 XP를 준다 | `MealRecorded`마다 XP(설정값, 가정 20)를 더하고 xp_log에 (MEAL, mealId)로 남긴다. 같은 mealId는 한 번만 적립한다 | 1 | 제안 |
| REQ-GROWTH-03 | 운동 세션 완료에 XP를 준다 | `WorkoutSessionCompleted`마다 기본 XP(가정 100)와 PR당 추가 XP(가정 20)를 더한다. 같은 sessionId는 한 번만 적립한다 | 2 | 제안 |
| REQ-GROWTH-04 | XP 누적으로 레벨이 오른다 | 레벨 경계는 설정 테이블(가정: 레벨 n 필요 XP = 100 × n × (n+1) / 2). 경계를 넘으면 level이 오르고 응답에 레벨업 여부가 있다 | 1 | 제안 |
| REQ-GROWTH-05 | 레벨에 따라 냠냠이 외형이 바뀐다 | 외형 단계 수(미결, 가정 5)와 레벨 구간을 설정으로 둔다. 조회 API가 `nyamStage`를 돌려준다 | 1 | 제안 |
| REQ-GROWTH-06 | DailyGoal 달성으로 Streak이 늘어난다 | `DailyGoalAchieved(date)`를 받으면 전날이 마지막 달성일이면 +1, 아니면 1로 시작한다. 같은 date는 한 번만 반영한다. longest_streak을 함께 갱신한다 | 1 | 제안 |
| REQ-GROWTH-07 | 달성하지 못한 날이 지나면 Streak이 끊긴다 | 자정(Asia/Seoul) 배치 (가정)가 전날 미달성 회원의 streak을 0으로 만든다. 유예일은 없다 (가정) | 1 | 제안 |
| REQ-GROWTH-08 | 마일스톤에 뱃지를 준다 | streak이 3·7·30·100에 도달하면 해당 뱃지를 1회 준다. 이미 가진 뱃지는 다시 주지 않는다 | 3 | 제안 |
| REQ-GROWTH-09 | PR 달성에 뱃지를 준다 | `WorkoutSessionCompleted.prs`가 비어 있지 않으면 첫 PR 뱃지 (가정)를 준다. 운동별 PR 뱃지 세분화는 미결 | 2 | 제안 |
| REQ-GROWTH-10 | 일일 미션을 제공한다 | 매일 미션 1~3개 (가정)를 만들고 식사·운동 이벤트로 진행을 갱신한다. 완료 시 XP를 준다 | 3 | 제안 |
| REQ-GROWTH-11 | 홈과 Tile에 Growth 상태를 제공한다 | 조회 API가 xp, level, 다음 레벨까지 남은 XP, nyamStage, streakDays, 새로 얻은 뱃지를 돌려준다. 워치 Tile 값은 폰이 Data Layer로 내려준다. 워치는 서버를 부르지 않는다 | 1 | 제안 |
| REQ-GROWTH-12 | 식사·세션 삭제 시 XP 처리 | 미결. (가정) 회수하지 않는다. 결정되면 Meal·Workout 명세와 함께 고친다 | 1 | 제안 |

## 3. 정책

- Growth는 이벤트로만 상태가 바뀐다. 다른 도메인이 Growth 서비스를 직접 호출해 XP를 바꾸지 않는다.
- 모든 적립은 xp_log에 남기고 (source_type, source_id) 유일 제약으로 멱등을 보장한다.
- XP·레벨·외형·마일스톤 수치는 코드가 아니라 설정에 둔다. 값 변경은 배포 없이 가능해야 한다 (가정).
- 완료 화면의 보상 연출(기획서 2장 원칙 3)은 폰 UI 책임이고, Growth는 "무엇이 새로 생겼는지"만 돌려준다.

## 4. 이벤트와 공개 조회

| 구분 | 이름 | 시점·용도 | 페이로드·반환 |
|---|---|---|---|
| 구독 | `MemberOnboarded` | 상태 초기화 | memberId, healthGoal |
| 구독 | `MealRecorded` | XP | memberId, mealId, recordedAt, kcal |
| 구독 | `WorkoutSessionCompleted` | XP, PR 뱃지 | memberId, sessionId, totalVolumeKg, burnedKcal, prs[] |
| 구독 | `DailyGoalAchieved` | Streak, 마일스톤 | memberId, date |
| 공개 조회 | 오늘 세션 존재 여부는 Workout이 제공(`hasSessionToday`) | 미션 진행 | boolean |

발행하는 이벤트는 없다. 상세는 [이벤트 목록](../renewal/events.md).

## 5. 미결

| 항목 | 결정자 | 기한 |
|---|---|---|
| XP 규칙 전체(식사·세트·미션별 값, 레벨 경계, 외형 단계 매핑) | C | 2주차 초안(기획서 9장) |
| Streak 끊김 판정 시각과 유예 | C·D | MVP-1 이전 |
| 식사·세션 삭제 시 XP 회수 | C·A·B | MVP-1 이전 |
| PR 뱃지 세분화 | C·B | MVP-2 이전 |
