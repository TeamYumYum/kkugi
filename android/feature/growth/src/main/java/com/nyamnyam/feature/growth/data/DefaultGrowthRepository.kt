package com.nyamnyam.feature.growth.data

import javax.inject.Inject

/**
 * [GrowthRepository] 구현. 데이터 소스는 생성자로 받는다(Hilt). feature 모듈은 Room을 쓰지 않는다
 * (규칙 feature-no-room, ADR-03: 로컬 저장은 :core의 Workout 테이블만).
 */
class DefaultGrowthRepository
    @Inject
    constructor() : GrowthRepository {
        override suspend fun load(): List<String> = emptyList()
    }
