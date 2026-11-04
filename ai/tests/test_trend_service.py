from datetime import date, timedelta

import pytest

from app.services.trend_service import calc_calorie_adjustment, calc_weight_trend

D0 = date(2026, 10, 1)


def _daily(*weights: float) -> list[tuple[date, float]]:
    return [(D0 + timedelta(days=i), w) for i, w in enumerate(weights)]


def test_기록이_2개_미만이면_None():
    assert calc_weight_trend([]) is None
    assert calc_weight_trend(_daily(70.0)) is None


def test_날짜가_모두_같으면_None():
    assert calc_weight_trend([(D0, 70.0), (D0, 71.0)]) is None


def test_하루_0_1kg씩_줄면_주당_마이너스_0_7kg():
    assert calc_weight_trend(_daily(70.0, 69.9, 69.8, 69.7, 69.6)) == -0.7


def test_순서가_섞여도_같은_추세():
    records = _daily(70.0, 70.2, 70.4, 70.6)
    assert calc_weight_trend(list(reversed(records))) == calc_weight_trend(records) == 1.4


def test_불규칙한_간격도_날짜_차이로_계산한다():
    records = [(D0, 70.0), (D0 + timedelta(days=7), 69.5), (D0 + timedelta(days=14), 69.0)]
    assert calc_weight_trend(records) == -0.5


def test_추세가_없으면_유지():
    assert calc_calorie_adjustment(2000, "LOSE", None) == (2000, "체중 데이터 부족으로 유지")


@pytest.mark.parametrize(
    ("goal", "trend", "expected_kcal"),
    [
        ("LOSE", -1.5, 2100),  # 너무 빨리 빠짐 → 증량
        ("LOSE", -0.1, 1900),  # 덜 빠짐 → 감량
        ("LOSE", -0.5, 2000),  # 적정
        ("GAIN", 0.8, 1900),  # 너무 빨리 찜 → 감량
        ("GAIN", 0.0, 2100),  # 덜 찜 → 증량
        ("GAIN", 0.3, 2000),  # 적정
        ("MAINTAIN", 0.6, 1900),
        ("MAINTAIN", -0.6, 2100),
        ("MAINTAIN", 0.2, 2000),
    ],
)
def test_목표별_재조정(goal, trend, expected_kcal):
    new_kcal, reason = calc_calorie_adjustment(2000, goal, trend)
    assert new_kcal == expected_kcal
    assert f"{trend:+.2f}kg/주" in reason


@pytest.mark.parametrize(("gender", "floor"), [("FEMALE", 1200), ("MALE", 1500)])
def test_재조정은_하한_아래로_내려가지_않는다(gender, floor):
    new_kcal, _ = calc_calorie_adjustment(floor, "LOSE", 0.0, gender)
    assert new_kcal == floor


def test_잘못된_값은_거부한다():
    with pytest.raises(ValueError):
        calc_calorie_adjustment(2000, "DIET", -0.5)
    with pytest.raises(ValueError):
        calc_calorie_adjustment(2000, "LOSE", -0.5, "M")
