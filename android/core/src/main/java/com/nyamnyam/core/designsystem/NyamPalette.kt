package com.nyamnyam.core.designsystem

/**
 * 디자인 토큰 자리표시(ARGB). 폰(:app의 Material 3 테마)과 워치(Wear Material 3)가 같은 색을 쓰도록 :core에 둔다.
 * Compose·Material 의존 없이 값만 둔다(ADR-05: :core를 통해 폰 UI 라이브러리가 :wear에 들어가지 않게). 값은 디자인 담당(A)이 정한다.
 */
object NyamPalette {
    const val PRIMARY: Long = 0xFFFF8A3D
    const val SECONDARY: Long = 0xFF4CAF50
}
