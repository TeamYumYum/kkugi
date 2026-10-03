package com.nyamnyam.feature.meal.di

import com.nyamnyam.feature.meal.data.DefaultMealRepository
import com.nyamnyam.feature.meal.data.MealRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * feature가 자기 Repository 바인딩을 제공한다(ADR-06). 테스트에서 바꿔치기하려면 @TestInstallIn으로 이 모듈을 대체한다.
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class MealRepositoryModule {
    @Binds
    abstract fun bindMealRepository(repository: DefaultMealRepository): MealRepository
}
