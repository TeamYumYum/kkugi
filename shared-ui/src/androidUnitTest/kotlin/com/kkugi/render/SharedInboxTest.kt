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
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36], qualifiers = "ko-rKR-w400dp-h880dp-xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SharedInboxTest {
    @get:Rule val compose = createComposeRule()

    @Test fun emptyToPopulatedKeepsNavigationAndReadActions() {
        val context = androidx.test.core.app.ApplicationProvider.getApplicationContext<android.content.Context>()
        val authority = context.packageName + ".resources.AndroidContextProvider"
        requireNotNull(context.contentResolver.acquireContentProviderClient(authority)).close()
        val model = InboxModel()
        model.update(InboxState(emptyList(), false, "", 0, false))
        val events = mutableListOf<String>()
        val actions = object : InboxActions {
            override fun back() { events.add("back") }
            override fun select(key: String) { events.add(key) }
            override fun load(page: Int) { events.add("page:$page") }
        }
        lateinit var host: View
        var rect = Rect.Zero
        compose.setContent {
            host = LocalView.current
            Box(Modifier.size((1178f/3).dp, 759.dp).onGloballyPositioned { rect = it.boundsInRoot() }) {
                SharedInbox(model, actions)
            }
        }
        compose.onNodeWithText("아직 받은 알림이 없어요").assertExists()
        compose.runOnIdle {
            assertEquals(1178, rect.width.toInt())
            assertEquals(2277, rect.height.toInt())
            val image = Bitmap.createBitmap(1178, 2277, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(image)
            canvas.translate(-rect.left, -rect.top)
            host.draw(canvas)
            val output = File("build/reports/shared-ui/inbox-empty.png")
            requireNotNull(output.parentFile).mkdirs()
            output.outputStream().use { check(image.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        }
        compose.runOnIdle { model.update(InboxState(listOf(InboxRow("42","알림 제목","알림 본문",false,"BADGE","오늘","오후 1:30")),false,"",0,true)) }
        compose.onNodeWithText("알림 제목").performClick()
        compose.onNodeWithText("다음").performClick()
        compose.onNodeWithContentDescription("뒤로").performClick()
        assertEquals(listOf("42","page:1","back"),events)
    }
}
