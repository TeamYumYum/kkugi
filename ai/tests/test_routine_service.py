import pytest

from app.services.routine_service import (
    Adjustment,
    AdjustmentAction,
    SessionResult,
    calculate_adjustment,
)


def _sessions(*completed: int, target: int = 4) -> list[SessionResult]:
    return [SessionResult(target_sets=target, completed_sets=c) for c in completed]


def test_세션없으면_HOLD():
    assert calculate_adjustment(4, 8, 60.0, []) == Adjustment(AdjustmentAction.HOLD, 60.0, 4, 8)


def test_마지막_세션_전성공이면_UP_30kg이상은_5kg():
    assert calculate_adjustment(4, 8, 60.0, _sessions(4)) == Adjustment(
        AdjustmentAction.UP, 65.0, 4, 8
    )


def test_마지막_세션_전성공이면_UP_30kg미만은_2_5kg():
    assert calculate_adjustment(3, 10, 20.0, _sessions(3, target=3)).weight_kg == 22.5


def test_마지막_세션_일부성공이면_HOLD():
    assert calculate_adjustment(4, 8, 60.0, _sessions(2)).action == AdjustmentAction.HOLD


def test_2회_연속_실패면_DOWN():
    assert calculate_adjustment(4, 8, 60.0, _sessions(1, 1)) == Adjustment(
        AdjustmentAction.DOWN, 54.0, 4, 8
    )


def test_3회_연속_성공이면_VOLUME_UP():
    assert calculate_adjustment(4, 8, 60.0, _sessions(4, 4, 4)) == Adjustment(
        AdjustmentAction.VOLUME_UP, 65.0, 5, 8
    )


def test_연속_성공이_중간에_끊기면_UP():
    # 성공·실패·성공·성공 → 최근 연속 성공은 2회
    assert calculate_adjustment(4, 8, 60.0, _sessions(4, 1, 4, 4)).action == AdjustmentAction.UP


def test_4주_지속_감퇴면_DELOAD():
    assert calculate_adjustment(4, 8, 60.0, _sessions(4, 3, 2, 1)) == Adjustment(
        AdjustmentAction.DELOAD, 36.0, 3, 8
    )


def test_DELOAD는_세트를_1미만으로_내리지_않는다():
    result = calculate_adjustment(1, 8, 60.0, _sessions(1, 1, 1, 0, target=1))
    assert result.action == AdjustmentAction.DELOAD
    assert result.sets == 1


def test_목표_초과_완료도_성공으로_본다():
    assert calculate_adjustment(4, 8, 60.0, _sessions(5)).action == AdjustmentAction.UP


@pytest.mark.parametrize(("target", "completed"), [(0, 0), (-1, 0), (4, -1)])
def test_잘못된_세션_값은_거부한다(target, completed):
    with pytest.raises(ValueError):
        SessionResult(target_sets=target, completed_sets=completed)
