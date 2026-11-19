package com.kkugi.render

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "ko-rKR-w393dp-h759dp-xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SharedInboxTest {
    @get:Rule val compose = createComposeRule()

    @Test fun emptyToPopulatedKeepsNavigationAndReadActions() {
        val model = InboxModel()
        model.update(InboxState(emptyList(), false, "", 0, false))
        val events = mutableListOf<String>()
        val actions = object : InboxActions {
            override fun back() { events.add("back") }
            override fun select(key: String) { events.add(key) }
            override fun load(page: Int) { events.add("page:$page") }
        }
        compose.setContent { SharedInbox(model, actions) }
        compose.onNodeWithText("아직 받은 알림이 없어요").assertExists()
        compose.runOnIdle { model.update(InboxState(listOf(InboxRow("42","알림 제목","알림 본문",false,"BADGE","오늘","오후 1:30")),false,"",0,true)) }
        compose.onNodeWithText("알림 제목").performClick()
        compose.onNodeWithText("다음").performClick()
        compose.onNodeWithContentDescription("뒤로").performClick()
        assertEquals(listOf("42","page:1","back"),events)
    }
}
