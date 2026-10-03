# 도메인 이벤트 목록

> [ADR-08](../adr/0008-domain-events.md)의 이벤트 표를 코드와 함께 유지하는 기준 문서다.
> 이벤트를 추가·변경하는 PR은 이 표를 같은 PR에서 갱신한다(backend 영역 트리거 6, 엄격 판정).
> 이벤트 흐름은 코드에서 한눈에 보이지 않으므로, 이 표가 "누가 무엇을 듣는지"의 유일한 지도다.

## 규칙 요약

- 발행은 `domain/{x}/service/`에서만. 이벤트 record는 발행 도메인의 `domain/{x}/event/`에 둔다.
- 구독 핸들러는 구독 도메인의 `domain/{y}/event/`에 두고 `@TransactionalEventListener(phase = AFTER_COMMIT)` + `@Async`.
- 핸들러는 **멱등**해야 한다(이벤트 ID 또는 비즈니스 키로 중복 무시).
- 이벤트 페이로드는 ID와 최소 값만. 구독자가 필요한 상세는 발행 도메인의 public service로 조회한다.
- 상태 변경 전파는 이벤트, 단순 조회는 public service 호출, 타 도메인 Repository 직접 접근 금지(ArchUnit).

## 이벤트

| 이벤트 | 발행 도메인 · 시점 | 페이로드(초안) | 구독 도메인 → 처리 | 상태 |
|---|---|---|---|---|
| `MemberOnboarded` | Member · 온보딩 완료 저장 후 | memberId, healthGoal | Coaching → Program 생성(FastAPI `/ai/plan` 호출) · Growth → 초기 Nyam·XP 0 | 미구현 |
| `MealRecorded` | Meal · 식사 저장 후 | memberId, mealId, recordedAt, kcal | Coaching → 오늘 칼로리 갱신, 마지막 끼니 추천 조건 평가 · Growth → XP, Streak | 미구현 |
| `MealCorrected` | Meal · 사용자가 인식 결과를 수정 저장 후 | memberId, mealId, predictionId | Admin/ML → 예측 vs 수정 쌍 적재(검수 대기) | 미구현 |
| `WorkoutSessionCompleted` | Workout · 세션 업로드 완료 후(폰이 올린 시점) | memberId, sessionId, totalVolumeKg, burnedKcal, prs[] | Coaching → 루틴 조정(FastAPI `/ai/routine/adjust`), 칼로리 밸런스 · Growth → XP, Streak, PR 뱃지 | 미구현 |
| `WeightRecorded` | Coaching · 체중 저장 후(Health Connect 자동 입력 포함) | memberId, weightKg, recordedAt | Coaching 내부 → 추세 재계산, 필요 시 칼로리 재조정(`/ai/plan/weekly-adjust`) | 미구현 |
| `DailyGoalAchieved` | Coaching · DailyGoal 달성 판정 시(배치 또는 기록 직후) | memberId, date | Growth → Streak +1, 마일스톤(3·7·30·100) 뱃지 | 미구현 |

상태 값: `미구현` → `구현` → `폐기`. 폐기한 이벤트는 행을 지우지 않고 상태만 바꾼다(발행·구독 코드가 모두 제거된 뒤).

## 이벤트가 아닌 것 (직접 호출)

| 호출 | 이유 |
|---|---|
| Coaching → Member `getTargetCalories(memberId)` | 동기 조회. 읽기 전용 DTO 반환 |
| Growth → Workout `hasSessionToday(memberId)` | 동기 조회 |
| Spring → FastAPI `/ai/**` | 도메인 이벤트가 아니라 외부 호출. `infrastructure/ai`만 안다 |
| FCM 발송 | 이벤트 핸들러(Coaching)가 조건을 판단해 `infrastructure/fcm` 호출. FCM 자체는 이벤트가 아니다 |
