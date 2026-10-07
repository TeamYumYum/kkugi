# 요구사항 명세 — Meal

| 항목 | 값 |
|---|---|
| 상태 | 초안 (제안). 소유자 A 확정 전 |
| 도메인 소유 | A (Meal) |
| 표면 | 폰 |
| MVP | 1 |
| 관련 | [기획서 3.1·J1](../renewal/plan.md), [이벤트 목록](../renewal/events.md), [ERD Meal](../design/erd.md#3-meal), [API 공통 규약](../api/conventions.md), [ADR-0003](../adr/0003-phone-offline-workout-only.md), [ADR-0011](../adr/0011-mlflow-and-ai-ml-split.md) |

## 1. 범위

- 포함: 사진 촬영·선택 → 인식 → 수정 → 저장, 검색 입력 폴백, 식사 목록·상세·수정·삭제, 하루 영양 합산, 예측·수정 쌍 보존
- 제외: 워치 식사 기록(ADR-0002), 오프라인 사진 보관(ADR-0003 후속 후보), Food DB 관리자 CRUD(기획서 7장), 바코드·영수증 인식

## 2. 기능 요구사항

| ID | 요구사항 | 인수 조건 | MVP | 상태 |
|---|---|---|---|---|
| REQ-MEAL-01 | 홈에서 촬영으로 바로 들어간다 | 홈의 촬영 버튼 1탭으로 카메라가 열린다. 갤러리 선택도 허용한다. 촬영부터 저장까지 기본 경로는 3탭(촬영·확인·저장) | 1 | 제안 |
| REQ-MEAL-02 | 사진을 보내면 인식 결과를 받는다 | 응답에 `predictionId`와 후보 1개 이상(가정: 최대 3개)이 있고, 후보마다 음식명·추정 양·kcal·탄단지·신뢰도가 있다. 인식이 타임아웃(설정값, 가정 10초)을 넘기면 안내와 함께 검색 입력 폴백 버튼을 보여준다 | 1 | 제안 |
| REQ-MEAL-03 | 인식 결과를 수정한다 | 음식명은 Food DB 검색으로 바꾸고 양은 숫자로 바꾼다. 양을 바꾸면 kcal·탄단지가 즉시 다시 계산된다(가정: Food DB 100g당 값 × 양) | 1 | 제안 |
| REQ-MEAL-04 | 저장하면 예측과 확정값을 모두 보존한다 | meal·meal_item이 저장되고, 사진 경로일 때 meal_prediction(모델 출력 원본)과 meal_correction(사용자 확정값, `is_changed`)이 같은 트랜잭션에 기록된다. 수정 없이 저장해도 correction 행을 만들고 `is_changed=false` (가정) | 1 | 제안 |
| REQ-MEAL-05 | 저장 시 이벤트를 발행한다 | 커밋 후 `MealRecorded(memberId, mealId, recordedAt, kcal)`. `is_changed=true`면 `MealCorrected(memberId, mealId, predictionId)`도 발행한다 | 1 | 제안 |
| REQ-MEAL-06 | 검색으로 식사를 기록한다 | 음식 이름 2자 이상 입력하면 Food DB 후보 목록(가정: 20개)을 돌려준다. 선택 후 양을 입력해 저장하면 `input_method=SEARCH`이고 prediction은 없다 | 1 | 제안 |
| REQ-MEAL-07 | 식사 구분과 시각을 정한다 | 기본값은 현재 시각과 시간대별 구분(가정: 05~10 아침, 10~15 점심, 15~21 저녁, 그 외 간식). 사용자가 바꿀 수 있다. 미래 시각은 400 `INVALID_INPUT` | 1 | 제안 |
| REQ-MEAL-08 | 날짜별 식사 목록과 상세를 본다 | 날짜를 주면 그날 식사 목록과 합계(kcal·탄단지)를 돌려준다. 상세에는 사진, 항목, 수정 전 예측이 있다 | 1 | 제안 |
| REQ-MEAL-09 | 저장한 식사를 수정·삭제한다 | 항목·양·구분·시각을 수정할 수 있다. 삭제는 soft delete (가정). 수정·삭제가 Growth XP와 Coaching 합계에 미치는 영향은 미결 | 1 | 제안 |
| REQ-MEAL-10 | 하루 섭취 합계를 다른 도메인에 제공한다 | public service가 (memberId, date)를 받아 kcal·탄단지 합계 DTO를 돌려준다. 삭제된 식사는 제외한다 | 1 | 제안 |
| REQ-MEAL-11 | 오프라인이면 기록할 수 없음을 알린다 | 네트워크가 없을 때 촬영·검색 저장은 안내 메시지로 막는다. 마지막으로 받은 오늘 목록만 캐시로 보여준다 | 1 | 제안 |
| REQ-MEAL-12 | 사진 원본을 보존한다 | 사진은 서버 저장소(미결, 가정: 로컬 볼륨)에 저장하고 meal에 경로를 둔다. 학습 원료이므로 식사 삭제 후에도 보존한다 (가정) | 1 | 제안 |

## 3. AI 추론 의존

- 인식 호출은 Spring `infrastructure/ai`가 FastAPI `POST /ai/vision`을 부른다. 폰은 FastAPI를 모른다(기획서 5.2).
- FastAPI가 503(모델 미로드)·타임아웃·5xx를 돌려주면 Spring은 (가정) `MEAL_RECOGNITION_UNAVAILABLE`로 응답하고 폰은 검색 폴백을 안내한다. 식사 저장 자체는 막지 않는다.
- Vision 베이스 모델이 외부 API로 정해져도 prediction·correction 적재는 동일하다(ADR-0011).
- `ai/schemas` 변경은 E 리뷰가 필수다.

## 4. 정책 값

| 항목 | 값 | 상태 |
|---|---|---|
| 양 단위 | g 기본, 인분 선택 (가정) | 미결 |
| 영양 계산 | Food DB 100g당 값 × 양 (가정) | 미결 |
| 인식 후보 개수 | 최대 3 (가정) | 미결 |
| 인식 타임아웃 | 10초 (가정), 설정값 | 미결 |
| 사진 최대 크기 | 10MB, 초과 시 폰에서 축소 (가정) | 미결 |
| Food DB 출처 | 미결 (식약처 공공데이터 후보) | 미결 |

## 5. 이벤트와 공개 조회

| 구분 | 이름 | 시점·용도 | 페이로드·반환 |
|---|---|---|---|
| 발행 | `MealRecorded` | 식사 저장 커밋 후 | memberId, mealId, recordedAt, kcal |
| 발행 | `MealCorrected` | 인식 결과를 수정해 저장한 뒤 | memberId, mealId, predictionId |
| 공개 조회 | 하루 섭취 합계 (가정: `MealQueryService.getDailyIntake`) | Coaching의 오늘 칼로리·밸런스 | kcal·탄단지 합계 DTO |

구독하는 이벤트는 없다. 상세는 [이벤트 목록](../renewal/events.md).

## 6. 미결

| 항목 | 결정자 | 기한 |
|---|---|---|
| Food DB 출처와 적재 방식 | A·E | 2주차 |
| 사진 저장소(로컬 볼륨 / 객체 스토리지) | A·C | 2주차 |
| 식사 수정·삭제 시 XP·합계 처리 | A·C·D | MVP-1 이전 |
| 인식 후보 개수와 신뢰도 임계 | A·E | 2주차 |
