package com.nyamnyam.feature.workout.data

/**
 * ViewModel이 의존하는 유일한 데이터 창구(ADR-04, 규칙 viewmodel-repository-only).
 * 원격(:core의 Retrofit 서비스)·로컬 데이터 소스와 DTO ↔ 모델 매핑은 구현([DefaultWorkoutRepository])에 숨긴다.
 * 반환 타입은 :core의 순수 Kotlin 모델로 바꾼다.
 */
interface WorkoutRepository {
    suspend fun load(): List<String>
}
