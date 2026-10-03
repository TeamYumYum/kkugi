package com.nyamnyam.feature.workout.data

/**
 * ViewModel 단위 테스트에서 생성자로 넘기는 대역(Hilt 없이, ADR-06).
 */
class FakeWorkoutRepository(
    var items: List<String> = emptyList(),
) : WorkoutRepository {
    override suspend fun load(): List<String> = items
}
