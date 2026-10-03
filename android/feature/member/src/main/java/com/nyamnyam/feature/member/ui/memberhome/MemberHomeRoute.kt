package com.nyamnyam.feature.member.ui.memberhome

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * ViewModel 상태를 생명주기에 맞춰 수집해 [MemberHomeScreen]에 넘긴다.
 * ViewModel은 Hilt가 만든다(hiltViewModel, ADR-06). :app의 내비게이션 그래프가 이 Route를 등록한다(ADR-05).
 */
@Composable
fun MemberHomeRoute(
    modifier: Modifier = Modifier,
    viewModel: MemberHomeViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    MemberHomeScreen(
        uiState = uiState,
        onRefresh = viewModel::onRefresh,
        modifier = modifier,
    )
}
