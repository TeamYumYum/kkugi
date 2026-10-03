package com.nyamnyam.core.di

import com.nyamnyam.core.network.NetworkConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import retrofit2.Retrofit
import javax.inject.Singleton

/**
 * :core가 네트워크를 제공한다(ADR-06). feature의 Repository 구현만 Retrofit 서비스를 받고, ViewModel은 Repository만 받는다
 * (규칙 viewmodel-repository-only). 워치(:wear)는 이 바인딩을 쓰지 않는다(ADR-02, 규칙 wear-no-network).
 */
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideRetrofit(): Retrofit {
        // 직렬화 변환기(ADR-09: kotlinx-serialization)와 인증 인터셉터는 API 계약 v1과 함께 더한다
        return Retrofit.Builder().baseUrl(NetworkConfig.BASE_URL).build()
    }
}
