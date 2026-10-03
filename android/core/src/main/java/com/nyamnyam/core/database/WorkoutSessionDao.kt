package com.nyamnyam.core.database

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert

/**
 * 운동 세션 DAO 자리표시. feature의 Repository 구현만 받는다(규칙 viewmodel-repository-only·feature-no-room).
 */
@Dao
interface WorkoutSessionDao {
    @Upsert
    suspend fun upsert(session: WorkoutSessionEntity)

    @Query("SELECT * FROM workout_session WHERE uploadState = :uploadState")
    suspend fun findByUploadState(uploadState: String): List<WorkoutSessionEntity>
}
