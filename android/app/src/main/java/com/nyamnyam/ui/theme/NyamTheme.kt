package com.nyamnyam.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.nyamnyam.core.designsystem.NyamPalette

/**
 * 폰 Material 3 테마 자리표시. 색 값은 :core의 디자인 토큰([NyamPalette])에서 가져온다.
 * 폰 UI 라이브러리(Material 3)는 :app·feature에만 둔다. :core에 두면 :wear APK에 들어간다(ADR-05).
 * 타이포그래피·모양·다크 모드 세부는 디자인 시스템 담당(A)이 채운다.
 */
@Composable
fun NyamTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme =
        if (darkTheme) {
            darkColorScheme(
                primary = Color(NyamPalette.PRIMARY),
                secondary = Color(NyamPalette.SECONDARY),
            )
        } else {
            lightColorScheme(
                primary = Color(NyamPalette.PRIMARY),
                secondary = Color(NyamPalette.SECONDARY),
            )
        }
    MaterialTheme(colorScheme = colorScheme, content = content)
}
