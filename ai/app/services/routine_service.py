"""점진적 과부하 조정 규칙(REQ-COACH-07, REQ-WORKOUT-26).

운동 하나의 최근 세션 성공률(완료 세트 / 목표 세트)로 다음 목표를 정한다.
결정은 UP · HOLD · DOWN · VOLUME_UP · DELOAD(용어집 "점진적 과부하 조정").

v1 `ai/app/services/routine_service.py`에서 규칙을 그대로 이식했다. `/ai/routine/adjust`
요청·응답 계약은 미결이라 여기서는 계약과 무관한 순수 함수만 둔다.
"""

from dataclasses import dataclass
from enum import StrEnum


class AdjustmentAction(StrEnum):
    UP = "UP"
    HOLD = "HOLD"
    DOWN = "DOWN"
    VOLUME_UP = "VOLUME_UP"
    DELOAD = "DELOAD"


@dataclass(frozen=True)
class SessionResult:
    """한 세션에서 이 운동의 목표 세트와 완료 세트."""

    target_sets: int
    completed_sets: int

    def __post_init__(self) -> None:
        if self.target_sets <= 0:
            raise ValueError("target_sets는 1 이상이어야 한다")
        if self.completed_sets < 0:
            raise ValueError("completed_sets는 0 이상이어야 한다")

    @property
    def success_rate(self) -> float:
        return self.completed_sets / self.target_sets


@dataclass(frozen=True)
class Adjustment:
    action: AdjustmentAction
    weight_kg: float
    sets: int
    reps: int


def calculate_adjustment(
    target_sets: int,
    target_reps: int,
    target_weight_kg: float,
    recent_sessions: list[SessionResult],
) -> Adjustment:
    """이 운동의 최근 세션(오래된 것 → 최근 순)으로 다음 목표를 정한다."""
    if not recent_sessions:
        return Adjustment(AdjustmentAction.HOLD, target_weight_kg, target_sets, target_reps)

    rates = [s.success_rate for s in recent_sessions]

    # DELOAD: 4주 누적 피로 감지 (처음보다 40% 이상 감소 & 마지막 성공률 < 60%)
    if len(rates) >= 4 and rates[-1] < rates[0] * 0.6 and rates[-1] < 0.6:
        return Adjustment(
            AdjustmentAction.DELOAD,
            round(target_weight_kg * 0.6, 1),
            max(1, target_sets - 1),
            target_reps,
        )

    # 최근부터 거슬러 올라가며 연속 성공(100% 이상)·연속 실패(50% 미만)를 센다
    consecutive_success = 0
    consecutive_failure = 0
    for rate in reversed(rates):
        if rate >= 1.0:
            if consecutive_failure > 0:
                break
            consecutive_success += 1
        elif rate < 0.5:
            if consecutive_success > 0:
                break
            consecutive_failure += 1
        else:
            break

    # VOLUME_UP: 3회 연속 성공
    if consecutive_success >= 3:
        return Adjustment(
            AdjustmentAction.VOLUME_UP,
            round(target_weight_kg + 5.0, 1),
            target_sets + 1,
            target_reps,
        )

    # DOWN: 2회 연속 실패
    if consecutive_failure >= 2:
        return Adjustment(
            AdjustmentAction.DOWN, round(target_weight_kg * 0.9, 1), target_sets, target_reps
        )

    # UP: 마지막 세션 전성공
    if rates[-1] >= 1.0:
        increment = 2.5 if target_weight_kg < 30 else 5.0
        return Adjustment(
            AdjustmentAction.UP, round(target_weight_kg + increment, 1), target_sets, target_reps
        )

    return Adjustment(AdjustmentAction.HOLD, target_weight_kg, target_sets, target_reps)
