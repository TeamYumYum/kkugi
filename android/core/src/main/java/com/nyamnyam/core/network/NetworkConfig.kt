package com.nyamnyam.core.network

/**
 * 네트워크 설정 자리표시. 서버 주소·직렬화 변환기·인증 인터셉터는 API 계약 v1과 함께 정한다.
 * ADR-09: 서버 DTO는 contracts/openapi.json에서 openapi-generator(kotlin)로 이 패키지 아래 generated/에 생성한다.
 * 손으로 DTO를 쓰지 않는다. 생성 설정은 1주차 A가 정한다(DTO만 생성하고 Retrofit 인터페이스는 손으로 쓰는 절충 허용).
 */
object NetworkConfig {
    // 예약 도메인(.invalid)이라 실제로 연결되지 않는다. 빌드 변형별 주소는 API 계약 v1과 함께 정한다
    const val BASE_URL: String = "https://api.nyamnyam.invalid/"
}
