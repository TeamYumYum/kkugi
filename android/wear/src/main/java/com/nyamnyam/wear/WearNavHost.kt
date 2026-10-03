package com.nyamnyam.wear

import androidx.compose.runtime.Composable
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.nyamnyam.wear.ui.workouthome.WorkoutHomeRoute

/**
 * 워치 앱 최상위 구조(Wear Compose Material 3 AppScaffold + SwipeDismissableNavHost).
 * 새 화면은 `harness scaffold android/wear wear-screen <Name>`이 출력하는 조각을 아래 `nyamnyam:destinations` 표식 위에 붙인다.
 * Streak·오늘 칼로리 Tile(ADR-02)은 후속 작업이다.
 */
@Composable
fun WearNavHost() {
    AppScaffold {
        SwipeDismissableNavHost(
            navController = rememberSwipeDismissableNavController(),
            startDestination = "workout-home",
        ) {
            composable(route = "workout-home") {
                WorkoutHomeRoute()
            }
            // nyamnyam:destinations
        }
    }
}
