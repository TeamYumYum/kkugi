package com.nyamnyam.core.database

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * 운동 세션 테이블 자리표시. ADR-03: 폰 Room은 Workout(세션·세트·업로드 상태)만 가진다. 다른 도메인 테이블을 더하지 않는다.
 * 업로드 재시도가 멱등하도록 클라이언트가 만든 UUID를 기본 키로 쓴다. 세트 테이블과 컬럼은 ERD 확정 뒤 Workout 담당(B)이 채운다.
 */
@Entity(tableName = "workout_session")
data class WorkoutSessionEntity(
    @PrimaryKey val clientId: String,
    val startedAtEpochMillis: Long,
    val uploadState: String,
)
