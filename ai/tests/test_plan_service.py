import pytest

from app.services.plan_service import (
    ActivityLevel,
    Gender,
    HealthGoal,
    NutritionPlan,
    calculate_plan,
)


def _plan(**overrides) -> NutritionPlan:
    params = {
        "gender": Gender.MALE,
        "age": 28,
        "height_cm": 175,
        "weight_kg": 80,
        "health_goal": HealthGoal.LOSE,
        "activity_level": ActivityLevel.MODERATE,
    }
    params.update(overrides)
    return calculate_plan(**params)


def test_v1_문서_예시_입력의_계산값():
    # v1 nutrition-calculation.md의 예시 입력(남성 28세 175cm 80kg 보통 활동 감량).
    # 문서 표는 BMR을 1,741로 잘못 계산했다. 10×80 + 6.25×175 − 5×28 + 5 = 1,758.75
    plan = _plan()
    assert plan.bmr == 1758.8
    assert plan.tdee == 2726.1
    assert plan.target_kcal == 2226.1
    assert plan.protein_g == 160.0
    assert plan.carb_g == 211.5
    assert plan.fat_g == 82.2


def test_여성_BMR은_161을_뺀다():
    male, female = _plan(), _plan(gender=Gender.FEMALE)
    assert round(male.bmr - female.bmr, 1) == 166.0


def test_활동량이_없으면_MODERATE로_계산한다():
    assert _plan(activity_level=None) == _plan(activity_level=ActivityLevel.MODERATE)


@pytest.mark.parametrize(
    ("goal", "delta"),
    [(HealthGoal.LOSE, -500), (HealthGoal.MAINTAIN, 0), (HealthGoal.GAIN, 300)],
)
def test_목표별_kcal_조정(goal, delta):
    plan = _plan(health_goal=goal)
    assert round(plan.target_kcal - plan.tdee, 1) == delta


@pytest.mark.parametrize(("gender", "floor"), [(Gender.FEMALE, 1200), (Gender.MALE, 1500)])
def test_목표_kcal는_하한_아래로_내려가지_않는다(gender, floor):
    plan = _plan(
        gender=gender,
        age=70,
        height_cm=150,
        weight_kg=40,
        activity_level=ActivityLevel.SEDENTARY,
    )
    assert plan.target_kcal == floor


def test_탄단지_kcal_합은_목표_kcal와_같다():
    for goal in HealthGoal:
        plan = _plan(health_goal=goal)
        total = plan.carb_g * 4 + plan.protein_g * 4 + plan.fat_g * 9
        assert total == pytest.approx(plan.target_kcal, abs=2)
        assert sum(plan.macro_kcal_ratios) == pytest.approx(1.0, abs=0.01)
