package com.nyamnyam.feature.meal.data

/**
 * ViewModel 단위 테스트에서 생성자로 넘기는 대역(Hilt 없이, ADR-06).
 */
class FakeMealRepository(
    var items: List<String> = emptyList(),
) : MealRepository {
    override suspend fun load(): List<String> = items
}
