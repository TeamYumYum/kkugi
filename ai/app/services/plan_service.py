"""Program 목표 칼로리·영양소 산식(REQ-COACH-01·02).

BMR(Mifflin-St Jeor) → TDEE(활동 계수) → 목표별 kcal 조정(안전 하한) → 단백질(g/kg)
→ 남은 kcal를 탄수·지방에 배분. Claude를 쓰지 않는 순수 계산이다.
공식과 근거는 v1 `ai/docs/nutrition-calculation.md`를 따른다.

v1 `/ai/plan/generate`에서 이식했다. `/ai/plan` 요청·응답 계약은 미결이라
여기서는 계약과 무관한 순수 함수만 둔다.
가정: HealthGoal은 LOSE·MAINTAIN·GAIN(용어집), 활동량은 미결이라 없으면 MODERATE.
"""

from dataclasses import dataclass
from enum import StrEnum


class Gender(StrEnum):
    MALE = "MALE"
    FEMALE = "FEMALE"


class HealthGoal(StrEnum):
    LOSE = "LOSE"
    MAINTAIN = "MAINTAIN"
    GAIN = "GAIN"


class ActivityLevel(StrEnum):
    SEDENTARY = "SEDENTARY"
    LIGHT = "LIGHT"
    MODERATE = "MODERATE"
    ACTIVE = "ACTIVE"
    VERY_ACTIVE = "VERY_ACTIVE"


ACTIVITY_MULTIPLIER: dict[ActivityLevel, float] = {
    ActivityLevel.SEDENTARY: 1.2,
    ActivityLevel.LIGHT: 1.375,
    ActivityLevel.MODERATE: 1.55,
    ActivityLevel.ACTIVE: 1.725,
    ActivityLevel.VERY_ACTIVE: 1.9,
}

GOAL_KCAL_ADJUST: dict[HealthGoal, float] = {
    HealthGoal.LOSE: -500,
    HealthGoal.MAINTAIN: 0,
    HealthGoal.GAIN: +300,
}

PROTEIN_PER_KG: dict[HealthGoal, float] = {
    HealthGoal.LOSE: 2.0,
    HealthGoal.MAINTAIN: 1.6,
    HealthGoal.GAIN: 2.2,
}

# 단백질을 뺀 남은 kcal의 탄수:지방 상대 가중치(합이 100일 필요 없음)
CARB_FAT_SPLIT: dict[HealthGoal, tuple[int, int]] = {
    HealthGoal.LOSE: (40, 35),
    HealthGoal.MAINTAIN: (50, 25),
    HealthGoal.GAIN: (55, 20),
}

# 극단적 저칼로리를 막는 목표 kcal 하한
MIN_KCAL: dict[Gender, float] = {
    Gender.FEMALE: 1200,
    Gender.MALE: 1500,
}


@dataclass(frozen=True)
class NutritionPlan:
    bmr: float
    tdee: float
    target_kcal: float
    protein_g: float
    carb_g: float
    fat_g: float

    @property
    def macro_kcal_ratios(self) -> tuple[float, float, float]:
        """(탄수, 단백질, 지방)이 목표 kcal에서 차지하는 비율. Program의 영양 비율용."""
        return (
            round(self.carb_g * 4 / self.target_kcal, 3),
            round(self.protein_g * 4 / self.target_kcal, 3),
            round(self.fat_g * 9 / self.target_kcal, 3),
        )


def calculate_plan(
    *,
    gender: Gender,
    age: int,
    height_cm: float,
    weight_kg: float,
    health_goal: HealthGoal,
    activity_level: ActivityLevel | None = None,
) -> NutritionPlan:
    # ① BMR (Mifflin-St Jeor)
    bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + (5 if gender == Gender.MALE else -161)

    # ② TDEE
    tdee = bmr * ACTIVITY_MULTIPLIER[activity_level or ActivityLevel.MODERATE]

    # ③ 목표 칼로리 (안전 하한)
    target_kcal = max(tdee + GOAL_KCAL_ADJUST[health_goal], MIN_KCAL[gender])

    # ④ 단백질 → ⑤ 남은 kcal를 탄수·지방에 배분
    protein_g = weight_kg * PROTEIN_PER_KG[health_goal]
    remaining_kcal = target_kcal - protein_g * 4
    carb_w, fat_w = CARB_FAT_SPLIT[health_goal]
    carb_g = remaining_kcal * carb_w / (carb_w + fat_w) / 4
    fat_g = remaining_kcal * fat_w / (carb_w + fat_w) / 9

    return NutritionPlan(
        bmr=round(bmr, 1),
        tdee=round(tdee, 1),
        target_kcal=round(target_kcal, 1),
        protein_g=round(protein_g, 1),
        carb_g=round(carb_g, 1),
        fat_g=round(fat_g, 1),
    )
