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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.ui.unit.Density
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.unit.dp
import java.io.File
import java.security.MessageDigest

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
        val fontScale = mutableFloatStateOf(1f)
        compose.setContent {
            host = LocalView.current
            CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale.floatValue)) {
                Box(Modifier.size((1178f/3).dp, 759.dp).onGloballyPositioned { rect = it.boundsInRoot() }) {
                    SharedInbox(model, actions)
                }
            }
        }
        compose.onNodeWithText("아직 받은 알림이 없어요").assertExists()
        fun capture(name: String, referenceDigest: String) = compose.runOnIdle {
            assertEquals(1178, rect.width.toInt())
            assertEquals(2277, rect.height.toInt())
            val image = Bitmap.createBitmap(1178, 2277, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(image)
            canvas.translate(-rect.left, -rect.top)
            host.draw(canvas)
            val output = File("build/reports/shared-ui/$name.png")
            requireNotNull(output.parentFile).mkdirs()
            output.outputStream().use { check(image.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            val digest = MessageDigest.getInstance("SHA-256")
            val row = IntArray(image.width)
            val bytes = ByteArray(image.width * 4)
            for (y in 0 until image.height) {
                image.getPixels(row, 0, row.size, 0, y, image.width, 1)
                row.forEachIndexed { x, argb ->
                    bytes[4*x] = (argb ushr 16).toByte()
                    bytes[4*x+1] = (argb ushr 8).toByte()
                    bytes[4*x+2] = argb.toByte()
                    bytes[4*x+3] = (argb ushr 24).toByte()
                }
                digest.update(bytes)
            }
            assertEquals("Original Android RGBA at 218f3248: $name", referenceDigest,
                digest.digest().joinToString("") { "%02x".format(it) })
        }
        capture("inbox-empty", "451016baa00e444bb7ee62386023ceb5a71cc6528c7bddd4b8fcae1e08390aa3")
        val rows = listOf(
            InboxRow("2", "제목 2", "본문 2", false, "LAST_MEAL", "오늘", "오후 5:05"),
            InboxRow("1", "제목 1", "본문 1", true, "WEEKLY_REPORT", "이번 주", "월요일")
        )
        compose.runOnIdle { model.update(InboxState(rows, false, "", 0, false)) }
        compose.onNodeWithText("제목 2").assertExists()
        capture("inbox", "451248ac9d7f568a41851351a3ce2ebd9006e416c915ed86533c6cf178d95cae")
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading)).assertCountEquals(3)
        val title = compose.onNodeWithText("알림")
        val initialHeight = title.fetchSemanticsNode().boundsInRoot.height
        compose.runOnIdle { fontScale.floatValue = 1.6f }
        check(title.fetchSemanticsNode().boundsInRoot.height > initialHeight)
        compose.runOnIdle { model.update(InboxState(rows, false, "", 0, true)) }
        compose.onNodeWithText("제목 2").performClick()
        compose.onNodeWithText("다음").performClick()
        compose.onNodeWithContentDescription("뒤로").performClick()
        assertEquals(listOf("2", "page:1", "back"), events)
    }
}
