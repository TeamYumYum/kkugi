package com.kkugi.render

import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.em
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.heading
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kkugi.render.resources.*
import org.jetbrains.compose.resources.Font
import org.jetbrains.compose.resources.painterResource

data class InboxRow(val key: String, val title: String, val body: String, val read: Boolean,
                    val type: String, val section: String, val time: String)
data class InboxState(val rows: List<InboxRow>, val loading: Boolean, val error: String, val page: Int, val hasNext: Boolean)
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
private fun Caption(value: String, size: Int = 13, bold: Boolean = false, color: Color = ink, center: Boolean = false) {
    val em = size * 1.2f
    val weight = if (bold) FontWeight.Bold else FontWeight.Normal
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
        PullToRefreshBox(isRefreshing = state.loading, onRefresh = { actions.load(state.page) }) {
        LazyColumn(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(gap)) {
            if (state.loading) item { CircularProgressIndicator() }
            if (state.error.isNotEmpty()) item {
                Caption(state.error)
                Box(Modifier.clickable(role = Role.Button) { actions.load(state.page) }) { Caption("다시 시도") }
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
                item(key = "section-$section") { Caption(section, 18, bold = true) }
                items(rows, key = { it.key }) { row ->
                    val spoken = listOf(row.title, row.body, row.time, if (row.read) "" else "안 읽음")
                        .filter { it.isNotBlank() }.joinToString(", ")
                    Row(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(16.dp))
                        .clickable(role = Role.Button) { actions.select(row.key) }
                        .semantics { contentDescription = spoken }.padding(gap),
                        horizontalArrangement = Arrangement.spacedBy(gap)) {
                        val mark = when (row.type) {
                            "LAST_MEAL" -> "♨"
                            "WEEKLY_REPORT" -> "▥"
                            "BADGE" -> "★"
                            else -> "●"
                        }
                        Caption(mark, 18, color = muted)
                        Column(Modifier.weight(1f)) {
                            Caption(row.title, bold = !row.read)
                            Caption(row.body, color = muted)
                            Caption(row.time, 11, color = muted)
                        }
                        if (!row.read) Spacer(Modifier.size(8.dp).background(Color(0xffff83a1), CircleShape))
                    }
                }
            }
            if (state.page > 0 || state.hasNext) item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Box(Modifier.clickable(enabled = !state.loading && state.page > 0, role = Role.Button) { actions.load(state.page-1) }) { Caption("이전") }
                    Caption((state.page + 1).toString() + "페이지")
                    Box(Modifier.clickable(enabled = !state.loading && state.hasNext, role = Role.Button) { actions.load(state.page+1) }) { Caption("다음") }
                }
            }
        }
        }
    }
}
