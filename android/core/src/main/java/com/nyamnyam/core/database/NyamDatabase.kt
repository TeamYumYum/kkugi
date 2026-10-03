package com.nyamnyam.core.database

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * 폰·워치가 각자 기기에 두는 로컬 DB(ADR-02·ADR-03). 테이블은 Workout만 둔다.
 * 스키마 내보내기(마이그레이션 검증용)는 첫 실제 테이블을 확정할 때 켠다.
 */
@Database(entities = [WorkoutSessionEntity::class], version = 1, exportSchema = false)
abstract class NyamDatabase : RoomDatabase() {
    abstract fun workoutSessionDao(): WorkoutSessionDao

    companion object {
        const val DATABASE_NAME: String = "nyamnyam.db"
    }
}
