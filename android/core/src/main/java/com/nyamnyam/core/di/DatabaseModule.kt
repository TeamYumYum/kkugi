package com.nyamnyam.core.di

import android.content.Context
import androidx.room.Room
import com.nyamnyam.core.database.NyamDatabase
import com.nyamnyam.core.database.WorkoutSessionDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * :core가 Room을 제공한다(ADR-03·ADR-06).
 */
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideNyamDatabase(
        @ApplicationContext context: Context,
    ): NyamDatabase = Room.databaseBuilder(context, NyamDatabase::class.java, NyamDatabase.DATABASE_NAME).build()

    @Provides
    fun provideWorkoutSessionDao(database: NyamDatabase): WorkoutSessionDao = database.workoutSessionDao()
}
