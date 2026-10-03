package com.nyamnyam.core.datalayer

/**
 * 폰↔워치 Wearable Data Layer 경로 계약 자리표시(ADR-02). 폰과 워치가 같은 상수를 써서 경로가 어긋나지 않게 한다.
 * 데이터 형식(직렬화)과 경로 확정은 Workout 담당(B)이 2주차 말 실기기 스파이크로 검증한 뒤 정한다. 변경은 엄격 판정이다.
 */
object DataLayerPaths {
    /** DataClient: 폰 → 워치, 오늘 루틴(연결이 끊겨도 보관됐다가 전달된다). */
    const val ROUTINE_TODAY: String = "/routine/today"

    /** DataClient: 워치 → 폰, 끝난 세션(세트·휴식·심박 요약). 서버 업로드는 폰이 한다. */
    const val SESSION_PREFIX: String = "/session/"

    /** MessageClient: 즉시 이벤트(시작·종료). 세션 소유권은 먼저 시작한 기기가 갖는다. */
    const val MESSAGE_WORKOUT_START: String = "/workout/start"
    const val MESSAGE_WORKOUT_END: String = "/workout/end"
}
