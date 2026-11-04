"""체중 추세와 목표 칼로리 재조정(REQ-COACH-10).

v1 `ai/app/services/trend_service.py`에서 규칙을 이식했다. 바뀐 점:
- numpy 대신 최소제곱 기울기를 직접 계산한다(추론 서버에 새 의존성을 넣지 않는다).
- HealthGoal은 v2 가정값 LOSE·MAINTAIN·GAIN. v1 DIET→LOSE, MUSCLE→GAIN, HEALTH·DISEASE→MAINTAIN.

미결: 추세 산식(v1 선형회귀 vs 요구사항 가정 7일 이동 평균)과 재조정 조건(D·E, MVP-3 이전).
`/ai/plan/weekly-adjust` 계약도 미결이라 순수 함수만 둔다.
"""

from datetime import date
from typing import Literal

HealthGoal = Literal["LOSE", "MAINTAIN", "GAIN"]
Gender = Literal["MALE", "FEMALE"]

ADJUSTMENT_STEP_KCAL = 100.0
MIN_KCAL: dict[str, float] = {"FEMALE": 1200.0, "MALE": 1500.0}


def calc_weight_trend(records: list[tuple[date, float]]) -> float | None:
    """(날짜, 체중kg) 기록의 선형회귀 기울기를 주간 변화량(kg/주)으로 돌려준다.

    양수=증가, 음수=감소. 기록이 2개 미만이거나 날짜가 모두 같으면 None.
    """
    if len(records) < 2:
        return None

    d0 = min(d for d, _ in records)
    xs = [(d - d0).days for d, _ in records]
    ys = [w for _, w in records]
    x_mean = sum(xs) / len(xs)
    y_mean = sum(ys) / len(ys)
    denominator = sum((x - x_mean) ** 2 for x in xs)
    if denominator == 0:
        return None

    slope = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, ys, strict=True)) / denominator
    return round(slope * 7, 3)


def calc_calorie_adjustment(
    current_kcal: float,
    health_goal: HealthGoal,
    weight_trend: float | None,
    gender: Gender = "FEMALE",
) -> tuple[float, str]:
    """체중 추세와 건강 목표로 새 목표 kcal와 사유를 돌려준다.

    gender는 kcal 하한(남성 1500, 여성 1200)에만 쓴다. 기본값 FEMALE은 더 낮은(안전한) 하한.
    """
    if health_goal not in ("LOSE", "MAINTAIN", "GAIN"):
        raise ValueError(f"지원하지 않는 health_goal: {health_goal!r}")
    if gender not in MIN_KCAL:
        raise ValueError(f"지원하지 않는 gender: {gender!r}")

    if weight_trend is None:
        return current_kcal, "체중 데이터 부족으로 유지"

    adjustment = 0.0
    if health_goal == "LOSE":
        if weight_trend < -1.0:
            adjustment = +ADJUSTMENT_STEP_KCAL
            reason = f"체중 감소 속도 과다({weight_trend:+.2f}kg/주) → 칼로리 증량"
        elif weight_trend > -0.25:
            adjustment = -ADJUSTMENT_STEP_KCAL
            reason = f"감소 속도 부족({weight_trend:+.2f}kg/주) → 칼로리 감량"
        else:
            reason = f"적정 감소 속도({weight_trend:+.2f}kg/주) → 유지"
    elif health_goal == "GAIN":
        if weight_trend > 0.5:
            adjustment = -ADJUSTMENT_STEP_KCAL
            reason = f"체중 증가 속도 과다({weight_trend:+.2f}kg/주) → 칼로리 감량"
        elif weight_trend < 0.1:
            adjustment = +ADJUSTMENT_STEP_KCAL
            reason = f"증가 속도 부족({weight_trend:+.2f}kg/주) → 칼로리 증량"
        else:
            reason = f"적정 증가 속도({weight_trend:+.2f}kg/주) → 유지"
    else:  # MAINTAIN
        if abs(weight_trend) > 0.5:
            adjustment = -ADJUSTMENT_STEP_KCAL if weight_trend > 0 else +ADJUSTMENT_STEP_KCAL
            reason = f"체중 변동 과다({weight_trend:+.2f}kg/주) → 칼로리 조정"
        else:
            reason = f"체중 안정({weight_trend:+.2f}kg/주) → 유지"

    new_kcal = max(MIN_KCAL[gender], current_kcal + adjustment)
    return round(new_kcal, 1), reason
