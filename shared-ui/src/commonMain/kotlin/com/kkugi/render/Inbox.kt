package com.kkugi.render

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.kkugi.render.resources.*
import org.jetbrains.compose.resources.Font
import org.jetbrains.compose.resources.painterResource

data class InboxRow(val key: String, val title: String, val body: String, val read: Boolean,
                    val type: String, val section: String, val time: String)
data class InboxState(val rows: List<InboxRow>, val loading: Boolean, val error: String,
                      val page: Int, val hasNext: Boolean, val failedPage: Int = 0)
class InboxModel {
    var state by mutableStateOf(InboxState(emptyList(), true, "", 0, false))
        private set
    fun update(value: InboxState) { state = value }
}
interface InboxActions {
    fun back()
    fun select(key: String)
    fun load(page: Int)
}

private val ink = Color(0xff1f2328)
private val muted = Color(0xff868e96)
private val gutter = 21.6.dp
private val gap = 14.4.dp

private val backArrow = ImageVector.Builder("Back", 24.dp, 24.dp, 24f, 24f).apply {
    path(stroke = SolidColor(Color.Black), strokeLineWidth = 2f,
        strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round) {
        moveTo(15f, 5f)
        lineTo(8f, 12f)
        lineTo(15f, 19f)
    }
}.build()

@Composable
private fun Caption(value: String, size: Int = 13, bold: Boolean = false, color: Color = ink, center: Boolean = false,
                    weight: FontWeight = if (bold) FontWeight.Bold else FontWeight.Normal) {
    val em = size * 1.2f
    Text(value, style = TextStyle(fontFamily = FontFamily(Font(Res.font.noto_sans_kr_variable, weight)),
        fontWeight = weight, color = color, fontSize = em.sp, letterSpacing = (-0.01).em, lineHeight = 1.45.em,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None)),
        textAlign = if (center) TextAlign.Center else TextAlign.Start)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SharedInbox(model: InboxModel, actions: InboxActions) {
    val state = model.state
    Column(Modifier.fillMaxSize().background(Color(0xfff5f7fa)).padding(horizontal = gutter)) {
        Box(Modifier.fillMaxWidth().padding(top = 7.2.dp).heightIn(min = 38.4.dp)) {
            Box(Modifier.align(Alignment.CenterStart).semantics { contentDescription = "뒤로" }
                .clickable(role = Role.Button, onClick = actions::back).size(26.4.dp), contentAlignment = Alignment.Center) {
                Image(rememberVectorPainter(backArrow), null, Modifier.fillMaxSize(), colorFilter = ColorFilter.tint(ink))
            }
            Box(Modifier.align(Alignment.Center).semantics { heading() }) { Caption("알림", 15, bold = true) }
        }
        PullToRefreshBox(isRefreshing = state.loading && state.rows.isEmpty(), onRefresh = { actions.load(0) }) {
            LazyColumn(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(gap)) {
                if (state.loading && state.rows.isEmpty()) item { CircularProgressIndicator() }
                if (state.error.isNotEmpty() && state.failedPage == 0) item {
                    Caption(state.error)
                    Box(Modifier.clickable(role = Role.Button) { actions.load(0) }) { Caption("다시 시도") }
                }
                if (!state.loading && state.error.isEmpty() && state.rows.isEmpty()) item {
                    Column(Modifier.fillMaxWidth().padding(gutter), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(gap)) {
                        Image(painterResource(Res.drawable.kkugi_g_character_f_idle), null, Modifier.size(48.dp))
                        Caption("아직 받은 알림이 없어요", 18, bold = true, center = true)
                        Caption("끼니 추천이나 주간 리포트가 오면 여기에 모여요.", color = muted, center = true)
                    }
                }
                for ((section, rows) in state.rows.groupBy { it.section }) {
                    item(key = "section-$section") {
                        Box(Modifier.padding(top = 9.6.dp).semantics { heading() }) {
                            Caption(section, 12, color = muted, weight = FontWeight.SemiBold)
                        }
                    }
                    item(key = "rows-$section") {
                        val shape = RoundedCornerShape(19.2.dp)
                        Column(Modifier.fillMaxWidth().dropShadow(shape) {
                            radius = ((3.6.dp.toPx() / 2f - 0.5f) / 0.57735f).coerceAtLeast(0f)
                            offset = Offset(0f, 1.2.dp.toPx())
                            color = ink.copy(alpha = 0.05f)
                        }.clip(shape).background(Color.White).padding(16.8.dp),
                            verticalArrangement = Arrangement.spacedBy(9.6.dp)) {
                            rows.forEach { row -> NotificationItem(row) { actions.select(row.key) } }
                        }
                    }
                }
                if (state.hasNext && state.rows.isNotEmpty()) item(key = "pagination") {
                    if (state.error.isEmpty()) {
                        if (!state.loading) LaunchedEffect(state.page) { actions.load(state.page + 1) }
                        Caption("알림을 더 불러오는 중이에요", color = muted)
                    } else if (state.failedPage > 0) {
                        Box(Modifier.clickable(role = Role.Button) { actions.load(state.failedPage) }) {
                            Caption("알림 더 불러오기")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationItem(row: InboxRow, open: () -> Unit) {
    val label = listOf(row.title, row.body, row.time, if (row.read) "" else "안 읽음")
        .filter(String::isNotBlank).joinToString(", ")
    Row(Modifier.fillMaxWidth().heightIn(min = 57.6.dp)
        .clickable(role = Role.Button, onClickLabel = "열기", onClick = open)
        .semantics(mergeDescendants = true) { contentDescription = label },
        horizontalArrangement = Arrangement.spacedBy(gap)) {
        val (symbol, color) = notificationIcon(row.type)
        Box(Modifier.size(40.8.dp).background(Color(0xfff5f7fa), RoundedCornerShape(14.4.dp)),
            contentAlignment = Alignment.Center) {
            Image(rememberVectorPainter(symbol), null, Modifier.size(21.6.dp), colorFilter = ColorFilter.tint(color))
        }
        Column(Modifier.weight(1f)) {
            Caption(row.title, 12, weight = FontWeight.SemiBold)
            Caption("${row.body} · ${row.time}", 11, color = muted)
        }
        if (!row.read) Spacer(Modifier.padding(top = 4.8.dp).size(9.6.dp).clip(CircleShape).background(Color(0xffff7e9d)))
    }
}

private fun notificationIcon(type: String) = when (type) {
    "LAST_MEAL" -> bowl to Color(0xffa9d3fb)
    "WEEKLY_REPORT" -> chart to Color(0xff2e6db4)
    "BADGE" -> medal to Color(0xffff7e9d)
    else -> bell to muted
}

private fun ImageVector.Builder.stroke(lines: androidx.compose.ui.graphics.vector.PathBuilder.() -> Unit) =
    path(stroke = SolidColor(Color.Black), strokeLineWidth = 2f,
        strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round, pathBuilder = lines)

private fun icon(name: String, lines: androidx.compose.ui.graphics.vector.PathBuilder.() -> Unit) =
    ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply { stroke(lines) }.build()

private val bowl = ImageVector.Builder("Meal", 24.dp, 24.dp, 24f, 24f).apply {
    stroke {
        moveTo(3f, 11f)
        horizontalLineTo(21f)
        arcToRelative(9f, 9f, 0f, false, true, -18f, 0f)
        close()
    }
    for (x in listOf(9f, 14f)) {
        stroke {
            moveTo(x, 7f)
            curveTo(x, 5f, x + 2f, 5f, x + 2f, 3f)
        }
    }
}.build()
private val chart = icon("Report") {
    moveTo(5f, 20f)
    verticalLineTo(11f)
    moveTo(12f, 20f)
    verticalLineTo(5f)
    moveTo(19f, 20f)
    verticalLineTo(14f)
}
private val medal = icon("Badge") {
    moveTo(8f, 14f)
    lineTo(6f, 22f)
    lineTo(12f, 19f)
    lineTo(18f, 22f)
    lineTo(16f, 14f)
    moveTo(19f, 9f)
    arcToRelative(7f, 7f, 0f, true, true, -14f, 0f)
    arcToRelative(7f, 7f, 0f, true, true, 14f, 0f)
}
private val bell = icon("Notification") {
    moveTo(5f, 17f)
    quadTo(7f, 14f, 7f, 9f)
    arcToRelative(5f, 5f, 0f, false, true, 10f, 0f)
    quadTo(17f, 14f, 19f, 17f)
    close()
    moveTo(10f, 20f)
    quadTo(12f, 22f, 14f, 20f)
}
