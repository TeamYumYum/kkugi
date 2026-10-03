package com.nyamnyam.feature.coaching.data

/**
 * ViewModel 단위 테스트에서 생성자로 넘기는 대역(Hilt 없이, ADR-06).
 */
class FakeCoachingRepository(
    var items: List<String> = emptyList(),
) : CoachingRepository {
    override suspend fun load(): List<String> = items
}
