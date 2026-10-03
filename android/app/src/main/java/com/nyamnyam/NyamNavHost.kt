package com.nyamnyam

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.nyamnyam.feature.coaching.ui.coachinghome.CoachingHomeRoute
import com.nyamnyam.feature.growth.ui.growthhome.GrowthHomeRoute
import com.nyamnyam.feature.meal.ui.mealhome.MealHomeRoute
import com.nyamnyam.feature.member.ui.memberhome.MemberHomeRoute
import com.nyamnyam.feature.workout.ui.workouthome.WorkoutHomeRoute

/**
 * 폰 내비게이션 그래프. ADR-05: 화면 간 이동은 :app이 맡고, feature 사이에는 의존이 없다.
 * 새 화면은 `harness scaffold android/feature screen <Name> --var feature=<feature>`가 출력하는 조각을
 * 아래 `nyamnyam:destinations` 표식 위에 붙인다. 시작 화면(home)은 1주차 셸 확인용 자리표시다.
 */
@Composable
fun NyamNavHost() {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = "home") {
        composable(route = "home") {
            ShellHome(onNavigate = { route -> navController.navigate(route) })
        }
        composable(route = "member-home") {
            MemberHomeRoute()
        }
        composable(route = "meal-home") {
            MealHomeRoute()
        }
        composable(route = "workout-home") {
            WorkoutHomeRoute()
        }
        composable(route = "coaching-home") {
            CoachingHomeRoute()
        }
        composable(route = "growth-home") {
            GrowthHomeRoute()
        }
        // nyamnyam:destinations
    }
}

/**
 * 1주차 셸 확인용 시작 화면. 실제 홈(여러 feature의 공개 Composable 조립, ADR-05)으로 바꾼다.
 */
@Composable
private fun ShellHome(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val routes = listOf("member-home", "meal-home", "workout-home", "coaching-home", "growth-home")
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(text = "냠냠코치")
        routes.forEach { route ->
            Button(onClick = { onNavigate(route) }) {
                Text(text = route)
            }
        }
    }
}
