package com.healthstats.app.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.R
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.model.BodyMetrics
import com.healthstats.app.data.model.DayStat
import com.healthstats.app.ui.components.BarChart
import com.healthstats.app.ui.components.ExplainedCard
import com.healthstats.app.ui.components.LineChart
import com.healthstats.app.ui.components.MetricTile
import com.healthstats.app.ui.components.StepsRing
import com.healthstats.app.ui.components.WavyProgress
import com.healthstats.app.ui.components.valueAt
import com.healthstats.app.util.fmtDate
import com.healthstats.app.util.fmtDistance
import com.healthstats.app.util.fmtDuration
import com.healthstats.app.util.fmtInt
import com.healthstats.app.util.fmtKcal
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

@Composable
private fun tileTint(): Color = LocalContentColor.current.copy(alpha = 0.10f)

private val Deep = Color(0xFF5E5CE6)
private val Rem = Color(0xFFBF5AF2)
private val Light = Color(0xFF64D2FF)
private val Awake = Color(0xFFFF9F0A)

/** Steps of today (ring) and of the last 7 days (bars). */
@Composable
fun StepsCard(settings: AppSettings, days: List<DayStat>, today: LocalDate, modifier: Modifier = Modifier) {
    val stat = days.firstOrNull { it.epochDay == today.toEpochDay() }
    val week = remember(days, today) { (6 downTo 0).map { d -> days.firstOrNull { it.epochDay == today.toEpochDay() - d }?.steps ?: 0 } }
    val labels = remember(today) { (6 downTo 0).map { today.minusDays(it.toLong()).dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()) } }
    var sel by remember { mutableStateOf<Int?>(null) }
    ExplainedCard(
        modifier = modifier,
        container = MaterialTheme.colorScheme.primaryContainer,
        title = stringResource(R.string.home_steps_today),
        explanation = stringResource(R.string.home_steps_expl),
        value = sel?.let { labels[it] + " · " + fmtInt(week[it]) },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                StepsRing(stat?.steps ?: 0, settings.stepGoal)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(R.string.home_goal, fmtInt(settings.stepGoal)), style = MaterialTheme.typography.bodySmall, color = LocalContentColor.current.copy(alpha = 0.7f))
                    if (stat != null && stat.distanceM > 0) Text(fmtDistance(stat.distanceM), style = MaterialTheme.typography.titleMedium)
                    if (stat != null && stat.kcal > 0) Text(fmtKcal(stat.kcal), style = MaterialTheme.typography.titleMedium)
                }
            }
            if (week.any { it > 0 }) {
                BarChart(week.map { it.toFloat() }, labels, LocalContentColor.current, sel, { sel = it }, height = 100.dp)
            }
        }
    }
}

/** Workout days of this week + totals. */
@Composable
fun WeekCard(workoutDays: Set<LocalDate>, count: Int, goal: Int, totalSec: Long, distanceM: Double, kcal: Double, today: LocalDate, modifier: Modifier = Modifier) {
    val monday = today.with(DayOfWeek.MONDAY)
    Card(
        modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer, contentColor = MaterialTheme.colorScheme.onTertiaryContainer),
        shape = MaterialTheme.shapes.extraLarge,
    ) {
        Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.home_week), style = MaterialTheme.typography.titleMedium)
                Text(stringResource(R.string.home_week_goal, count, goal), style = MaterialTheme.typography.bodySmall, color = LocalContentColor.current.copy(alpha = 0.7f))
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                for (i in 0..6) {
                    val d = monday.plusDays(i.toLong())
                    val done = d in workoutDays
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(
                            Modifier.size(36.dp).clip(CircleShape)
                                .background(if (done) MaterialTheme.colorScheme.tertiary else LocalContentColor.current.copy(alpha = 0.12f)),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (done) Icon(Icons.Rounded.FitnessCenter, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onTertiary)
                        }
                        Text(
                            d.dayOfWeek.getDisplayName(TextStyle.NARROW, Locale.getDefault()),
                            style = MaterialTheme.typography.labelSmall,
                            color = if (d == today) MaterialTheme.colorScheme.tertiary else LocalContentColor.current.copy(alpha = 0.7f),
                        )
                    }
                }
            }
            WavyProgress(if (goal > 0) count.toFloat() / goal else 0f, color = MaterialTheme.colorScheme.tertiary)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricTile(stringResource(R.string.detail_duration), fmtDuration(totalSec), Modifier.weight(1f), tint = tileTint())
                if (distanceM > 0) MetricTile(stringResource(R.string.detail_distance), fmtDistance(distanceM), Modifier.weight(1f), tint = tileTint())
                else if (kcal > 0) MetricTile(stringResource(R.string.detail_kcal), fmtKcal(kcal), Modifier.weight(1f), tint = tileTint())
            }
        }
    }
}

/** Last night (stages) and the last 7 nights. */
@Composable
fun SleepCard(m: BodyMetrics, modifier: Modifier = Modifier) {
    val nights = remember(m.sleep) { m.sleep.takeLast(7) }
    if (nights.isEmpty()) return
    val zone = ZoneId.systemDefault()
    val fmt = remember { DateTimeFormatter.ofPattern("EEE d", Locale.getDefault()) }
    val labels = nights.map { fmt.format(Instant.ofEpochMilli(it.endMs).atZone(zone)) }
    var sel by remember { mutableStateOf<Int?>(null) }
    val shown = nights[sel ?: nights.lastIndex]
    val stages = listOf(
        Triple(stringResource(R.string.sleep_deep), shown.deepMin, Deep),
        Triple(stringResource(R.string.sleep_rem), shown.remMin, Rem),
        Triple(stringResource(R.string.sleep_light), shown.lightMin, Light),
        Triple(stringResource(R.string.sleep_awake), shown.awakeMin, Awake),
    ).filter { it.second > 0 }
    ExplainedCard(
        modifier = modifier,
        container = MaterialTheme.colorScheme.secondaryContainer,
        title = stringResource(R.string.sleep_title),
        explanation = stringResource(R.string.sleep_expl),
        value = (sel?.let { labels[it] + " · " } ?: "") + fmtDuration(shown.totalMin * 60),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (stages.isNotEmpty()) {
                Row(Modifier.fillMaxWidth().height(18.dp).clip(RoundedCornerShape(9.dp)), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    stages.forEach { (_, min, c) -> Box(Modifier.weight(min.toFloat()).fillMaxHeight().background(c)) }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    stages.forEach { (name, min, c) ->
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Box(Modifier.size(8.dp).clip(CircleShape).background(c))
                                Text(name, style = MaterialTheme.typography.labelSmall, color = LocalContentColor.current.copy(alpha = 0.7f), maxLines = 1)
                            }
                            Text(fmtDuration(min * 60), style = MaterialTheme.typography.titleSmall)
                        }
                    }
                }
            }
            if (nights.size >= 2) {
                BarChart(nights.map { it.totalMin / 60f }, labels, LocalContentColor.current, sel, { sel = it }, height = 110.dp)
            }
        }
    }
}

/** Resting heart rate trend (or daily average) + today's heart rate. */
@Composable
fun HeartCard(m: BodyMetrics, today: LocalDate, modifier: Modifier = Modifier) {
    val rest = remember(m.restingHr) { m.restingHr.takeLast(30) }
    val days = remember(m.hrDays) { m.hrDays.takeLast(30) }
    val useRest = rest.size >= 2
    val ys = remember(rest, days) { if (useRest) rest.map { it.value.toFloat() } else days.map { it.avg.toFloat() } }
    if (ys.size < 2 && m.hrv.isEmpty() && m.hrDays.isEmpty()) return
    val xs = remember(ys) { ys.indices.map { it / (ys.size - 1).coerceAtLeast(1).toFloat() } }
    var cursor by remember { mutableStateOf<Float?>(null) }
    val todayHr = m.hrDays.lastOrNull { it.epochDay == today.toEpochDay() }
    val lAvg = stringResource(R.string.heart_today_avg)
    val lMin = stringResource(R.string.heart_today_min)
    val lMax = stringResource(R.string.heart_today_max)
    val lHrv = stringResource(R.string.hrv_title)
    ExplainedCard(
        modifier = modifier,
        container = MaterialTheme.colorScheme.errorContainer,
        title = stringResource(if (useRest) R.string.home_resting_hr else R.string.heart_avg_title),
        explanation = stringResource(if (useRest) R.string.heart_expl else R.string.heart_avg_expl),
        value = (valueAt(xs, ys, cursor) ?: ys.lastOrNull())?.let { "${it.toInt()} bpm" },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (ys.size >= 2) LineChart(xs, ys, LocalContentColor.current, cursor, { cursor = it }, height = 120.dp)
            val tiles = buildList {
                todayHr?.let {
                    add(lAvg to "${it.avg} bpm")
                    if (it.min > 0) add(lMin to "${it.min}")
                    if (it.max > 0) add(lMax to "${it.max}")
                }
                m.hrv.lastOrNull()?.let { add(lHrv to "${it.value.toInt()} ms") }
            }
            if (tiles.isNotEmpty()) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    tiles.take(4).forEach { (l, v) -> MetricTile(l, v, Modifier.weight(1f), tint = tileTint()) }
                }
            }
        }
    }
}

/** Weight trend + VO2 max and oxygen. */
@Composable
fun BodyCard(m: BodyMetrics, modifier: Modifier = Modifier) {
    val w = remember(m.weight) { m.weight.takeLast(60) }
    val vo2 = m.vo2.lastOrNull()
    val spo2 = m.spo2.lastOrNull()
    if (w.isEmpty() && vo2 == null && spo2 == null) return
    val ys = remember(w) { w.map { it.value.toFloat() } }
    val xs = remember(ys) { ys.indices.map { it / (ys.size - 1).coerceAtLeast(1).toFloat() } }
    var cursor by remember { mutableStateOf<Float?>(null) }
    val sel = cursor?.let { c -> w.getOrNull((c * (w.size - 1)).toInt().coerceIn(0, (w.size - 1).coerceAtLeast(0))) }
    val lWeight = stringResource(R.string.weight_title)
    val lVo2 = stringResource(R.string.vo2_title)
    val lSpo2 = stringResource(R.string.spo2_title)
    ExplainedCard(
        modifier = modifier,
        container = MaterialTheme.colorScheme.surfaceContainerHigh,
        title = stringResource(R.string.body_title),
        explanation = stringResource(R.string.body_expl),
        value = (sel ?: w.lastOrNull())?.let { String.format(Locale.getDefault(), "%.1f kg", it.value) + (if (sel != null) " · " + fmtDate(it.time) else "") },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (ys.size >= 2) LineChart(xs, ys, MaterialTheme.colorScheme.tertiary, cursor, { cursor = it }, height = 120.dp)
            val tiles = buildList {
                if (w.isNotEmpty() && ys.size < 2) add(lWeight to String.format(Locale.getDefault(), "%.1f kg", w.last().value))
                vo2?.let { add(lVo2 to String.format(Locale.getDefault(), "%.1f", it.value)) }
                spo2?.let { add(lSpo2 to String.format(Locale.getDefault(), "%.0f %%", it.value)) }
            }
            if (tiles.isNotEmpty()) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    tiles.forEach { (l, v) -> MetricTile(l, v, Modifier.weight(1f), tint = tileTint()) }
                }
            }
        }
    }
}
