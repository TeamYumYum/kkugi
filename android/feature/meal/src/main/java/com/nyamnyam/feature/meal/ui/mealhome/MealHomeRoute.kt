package com.nyamnyam.feature.meal.ui.mealhome

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * ViewModel 상태를 생명주기에 맞춰 수집해 [MealHomeScreen]에 넘긴다.
 * ViewModel은 Hilt가 만든다(hiltViewModel, ADR-06). :app의 내비게이션 그래프가 이 Route를 등록한다(ADR-05).
 */
@Composable
fun MealHomeRoute(
    modifier: Modifier = Modifier,
    viewModel: MealHomeViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    MealHomeScreen(
        uiState = uiState,
        onRefresh = viewModel::onRefresh,
        modifier = modifier,
    )
}
