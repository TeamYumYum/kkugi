package com.nyamnyam.wear.ui.workouthome

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * ViewModel 상태를 생명주기에 맞춰 수집해 [WorkoutHomeScreen]에 넘긴다.
 * ViewModel은 Hilt가 만든다(hiltViewModel, ADR-06). :wear가 별도 @HiltAndroidApp 루트다.
 */
@Composable
fun WorkoutHomeRoute(
    modifier: Modifier = Modifier,
    viewModel: WorkoutHomeViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    WorkoutHomeScreen(
        uiState = uiState,
        onRefresh = viewModel::onRefresh,
        modifier = modifier,
    )
}
