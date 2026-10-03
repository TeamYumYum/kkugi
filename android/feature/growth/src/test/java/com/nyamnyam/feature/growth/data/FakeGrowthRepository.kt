package com.nyamnyam.feature.growth.data

/**
 * ViewModel 단위 테스트에서 생성자로 넘기는 대역(Hilt 없이, ADR-06).
 */
class FakeGrowthRepository(
    var items: List<String> = emptyList(),
) : GrowthRepository {
    override suspend fun load(): List<String> = items
}
