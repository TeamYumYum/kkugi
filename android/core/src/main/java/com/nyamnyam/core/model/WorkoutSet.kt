package com.nyamnyam.core.model

/**
 * 폰·워치가 공유하는 순수 Kotlin 모델 자리표시(ADR-04: 모델은 :core). 필드는 ERD·API 계약 v1 확정 뒤 채운다.
 * 서버 DTO는 손으로 쓰지 않는다(ADR-09: contracts/openapi.json에서 생성). 이 모델은 화면·워치가 쓰는 앱 내부 표현이다.
 */
data class WorkoutSet(
    val weightKg: Double,
    val reps: Int,
)
