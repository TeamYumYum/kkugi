# evaluation — 오프라인 평가와 품질 게이트

## 지표

- **top-1 정확도**(게이트 기준)
- 혼동 행렬과 혼동 상위 쌍(관리자 웹·발표용)

평가는 `datasets/`의 고정된 평가 분할로 한다. 결과는 해당 MLflow run의 지표로 남긴다.

## 품질 게이트(ADR-11)

```
새 모델 top-1 ≥ 현재 Production 모델 top-1  →  통과
```

- 같은 평가 분할에서 두 모델을 잰다. Production 모델이 없으면(첫 등록) 통과로 본다.
- 통과하면 `registry/`가 `Staging`으로 등록한다. `Production` 승격은 사람이 승인한다.
- 실패하면 등록하지 않고 지표만 남긴다.

할 일(MVP-3): 평가 스크립트, 게이트 판정 스크립트(종료 코드로 통과·실패).

## 사진 식사 정확도 채점 (`photo_meal/`)

v1 `ai/eval/eval_photo_meal.py`의 채점부를 이식했다. 모델을 호출하지 않고
**정답 라벨 + 예측 JSONL**만으로 음식명·그램·kcal 정확도를 잰다. 그래서 Vision 베이스
모델이 무엇이 되든(Claude Vision, fine-tune 분류기 + 영양 조회 등) 같은 잣대로 비교할 수 있다.
예측을 만드는 실행기와 top-1 게이트 연결은 Vision 베이스 모델이 정해진 뒤 붙인다.

v1에서 옮기지 않은 것: v1 ADR-1(식약처 DB 조회 vs Vision 직접 추정) 비교 arm,
v1 프롬프트 변주 실행, Claude 비용 집계. v1 라우터·식약처 서비스에 묶여 있었다.

### 실행

```bash
cd ml/evaluation
python -m photo_meal.score --dataset photo_meal/data/labels.jsonl \
    --predictions photo_meal/results/preds.jsonl --out photo_meal/results/score.json
python -m pytest tests          # 단위 테스트 (pytest 필요)
```

`photo_meal/data/`와 `photo_meal/results/`는 gitignore된다. 평가셋 사진·라벨은 git에 넣지 않는다.
v1 평가셋(사진 31장)은 v1 저장소 `ai/eval/dataset/`에 있다. 상품 사진이 섞여 있어 출처를 확인하기 전에는 공유 저장소에 올리지 않는다.

### 라벨 (`labels.jsonl`, 사진 1장당 한 줄)

| 필드 | 필수 | 설명 |
| --- | --- | --- |
| `id` | O | 사진 식별자 |
| `image` | O | 라벨 파일 기준 상대 경로 (jpg·png·webp) |
| `meal_type` | O | `BREAKFAST` / `LUNCH` / `DINNER` / `SNACK` |
| `kind` | - | `single` 단품 / `multi` 여러 접시 / `composite` 복합 한식. 기본 `single` |
| `items[].name` | O | 정답 음식명 |
| `items[].grams` | O | 실제 무게. 저울 실측 또는 포장 표기 |
| `items[].kcal` | - | 있으면 kcal·밀도 오차도 잰다 |
| `items[].kcal_source` | kcal 있으면 O | `package` / `scale+db` / `mfds`. DB에서 베낀 정답을 갈라 보려고 적는다 |
| `items[].aliases` | - | 모델이 다르게 부를 수 있는 이름 |
| `total_only` | - | 항목 정답 없이 합계만 아는 사진(칸 나뉜 도시락). 이때 `total_kcal` 필수 |
| `total_kcal`, `total_grams` | - | 사진 합계 정답 |

### 예측 (`preds.jsonl`, 사진 1장당 한 줄)

```json
{"id": "0001", "detected_items": [{"name": "제육덮밥", "estimated_grams": 480, "kcal": 760}], "error": null}
```

예측이 없거나 `error`가 있는 사진은 빈 예측으로 채점한다(미검출로 잡힌다).

### 지표

| 지표 | 뜻 |
| --- | --- |
| 음식명 P·R·F1 | 정답·예측을 정규화한 이름(괄호·공백 제거)으로 1:1 배정. 별칭 일치는 정확, 포함 관계는 부분 일치 |
| 그램 / 항목 kcal MAPE | 배정된 항목의 절대 백분율 오차 |
| 밀도(kcal/g) MAPE | 그램 오차를 소거한 계수 오차. kcal 오차는 그램·계수 오차가 상쇄될 수 있어 따로 본다 |
| 합계 kcal MAPE·편향 | 사용자에게 보이는 총 칼로리. 편향이 +50%를 넘는 사진은 이중 계산 의심 |

`total_only` 사진은 항목 지표(tp·fp·fn)에 넣지 않고 합계 지표에만 쓴다.

### v1 기준선 (2026-09, 사진 31장, `claude-opus-4-5-20251101`)

v1 원시 예측을 이 채점기로 다시 채점해 v1 결과와 같은 값이 나오는 것을 확인했다.

| 지표 | 값 |
| --- | --- |
| 음식명 P / R / F1 | 0.708 / 0.85 / 0.773 |
| 그램 MAPE | 19.04% |
| 항목 kcal MAPE | 20.84% |
| 밀도 MAPE | 22.36% |
| 합계 kcal MAPE | 26.35% |
| 합계 kcal 편향 | +12.47% (이중 계산 의심 2장) |

v1 프롬프트의 핵심은 "요리 전체와 구성 재료를 동시에 나열하지 말 것"이라는 규칙이다.
이 규칙 하나로 F1이 0.377에서 0.773으로, 과검출이 49건에서 7건으로 줄었다.
