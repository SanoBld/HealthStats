package com.healthstats.app.ui.screens.charts

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import com.healthstats.app.data.model.sportOf
import com.healthstats.app.ui.components.LargeScreen
import com.healthstats.app.ui.components.SportBadge
import com.healthstats.app.ui.components.springClick
import com.healthstats.app.ui.theme.groupedShape
import com.healthstats.app.util.fmtDate
import com.healthstats.app.util.fmtDistance
import com.healthstats.app.util.fmtDuration
import com.healthstats.app.util.fmtKcal
import com.healthstats.app.util.fmtPace
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.model.ChartMetric
import com.healthstats.app.data.model.DayStat
import com.healthstats.app.data.model.Workout
import com.healthstats.app.ui.components.BarChart
import com.healthstats.app.ui.components.EmptyState
import com.healthstats.app.ui.components.StatTile
import com.healthstats.app.util.fmtInt
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

private class Series(val values: List<Float>, val labels: List<String>, val windowDays: Int)

private fun buildSeries(metric: ChartMetric, periodDays: Int, days: List<DayStat>, workouts: List<Workout>): Series {
    val zone = ZoneId.systemDefault()
    val loc = Locale.getDefault()
    val today = LocalDate.now()
    val byDay = days.associateBy { it.epochDay }
    val workoutsByDay = workouts.groupingBy { Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate().toEpochDay() }.eachCount()
    val hrByDay = workouts.filter { it.hrAvg > 0 }.groupBy { Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate().toEpochDay() }
        .mapValues { (_, l) -> l.map { it.hrAvg }.average() }
    val first = listOfNotNull(days.firstOrNull()?.epochDay, workouts.lastOrNull()?.let { Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate().toEpochDay() }).minOrNull()
    val start = if (periodDays > 0) today.minusDays(periodDays - 1L) else (first?.let { LocalDate.ofEpochDay(it) } ?: today.minusDays(29))
    val windowDays = (ChronoUnit.DAYS.between(start, today) + 1).toInt().coerceAtLeast(1)
    // 0 = day, 1 = week, 2 = month
    val mode = when {
        windowDays <= 31 -> 0
        windowDays <= 100 -> 1
        else -> 2
    }
    fun valueOf(d: LocalDate): Double {
        val e = d.toEpochDay()
        return when (metric) {
            ChartMetric.Steps -> (byDay[e]?.steps ?: 0).toDouble()
            ChartMetric.Kcal -> byDay[e]?.kcal ?: 0.0
            ChartMetric.Distance -> (byDay[e]?.distanceM ?: 0.0) / 1000.0
            ChartMetric.Workouts -> (workoutsByDay[e] ?: 0).toDouble()
            ChartMetric.Heart -> hrByDay[e] ?: 0.0
        }
    }
    val sums = LinkedHashMap<Long, Double>()
    val counts = HashMap<Long, Int>()
    val firstDates = LinkedHashMap<Long, LocalDate>()
    var d = start
    while (!d.isAfter(today)) {
        val key = when (mode) {
            0 -> d.toEpochDay()
            1 -> ChronoUnit.DAYS.between(start, d) / 7
            else -> d.year * 12L + d.monthValue
        }
        val v = valueOf(d)
        sums[key] = (sums[key] ?: 0.0) + v
        if (v > 0) counts[key] = (counts[key] ?: 0) + 1
        if (key !in firstDates) firstDates[key] = d
        d = d.plusDays(1)
    }
    val dayFmt = DateTimeFormatter.ofPattern("d MMM", loc)
    val monthFmt = DateTimeFormatter.ofPattern("MMM yy", loc)
    return Series(
        sums.map { (k, v) -> (if (metric == ChartMetric.Heart) v / (counts[k] ?: 1).coerceAtLeast(1) else v).toFloat() },
        firstDates.values.map { if (mode == 2) monthFmt.format(it) else dayFmt.format(it) },
        windowDays,
    )
}

private fun format(metric: ChartMetric, v: Float): String = when (metric) {
    ChartMetric.Steps -> fmtInt(v.toInt())
    ChartMetric.Kcal -> fmtInt(v.toInt()) + " kcal"
    ChartMetric.Distance -> String.format(Locale.getDefault(), "%.1f km", v)
    ChartMetric.Workouts -> v.toInt().toString()
    ChartMetric.Heart -> "${v.toInt()} bpm"
}

@Composable
fun ChartsScreen(health: HealthState, colored: Boolean, onOpenWorkout: (String) -> Unit, onOpenSport: (Int) -> Unit) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    var metricIdx by rememberSaveable { mutableIntStateOf(0) }
    var period by rememberSaveable { mutableIntStateOf(30) } // 0 = all
    var selected by remember { mutableStateOf<Int?>(null) }
    val metric = ChartMetric.entries[metricIdx]

    LaunchedEffect(metric, period) { selected = null }
    val series = remember(metric, period, health.days, health.workouts) {
        buildSeries(metric, period, health.days, health.workouts)
    }
    val color = when (metric) {
        ChartMetric.Kcal -> MaterialTheme.colorScheme.tertiary
        ChartMetric.Distance -> MaterialTheme.colorScheme.secondary
        else -> MaterialTheme.colorScheme.primary
    }
    val total = series.values.sum()
    val best = series.values.maxOrNull() ?: 0f
    val avg = if (metric == ChartMetric.Workouts) total / (series.windowDays / 7f).coerceAtLeast(1f) else total / series.windowDays
    val periods = listOf(7 to R.string.charts_7d, 30 to R.string.charts_30d, 90 to R.string.charts_90d, 365 to R.string.charts_1y, 0 to R.string.act_all)

    LargeScreen(stringResource(R.string.charts_title)) { inner ->
    Column(
        Modifier.padding(inner).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(ChartMetric.entries.toList()) { m ->
                FilterChip(selected = m == metric, onClick = { metricIdx = m.ordinal }, label = { Text(stringResource(m.label)) })
            }
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(periods) { (days, label) ->
                FilterChip(selected = period == days, onClick = { period = days }, label = { Text(stringResource(label)) })
            }
        }

        if (series.values.isEmpty() || total <= 0f) {
            EmptyState(Icons.Rounded.BarChart, stringResource(R.string.charts_empty))
        } else {
            Card(
                Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                shape = MaterialTheme.shapes.large,
            ) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    val sel = selected
                    Text(
                        if (sel != null && sel in series.values.indices) series.labels[sel] + " · " + format(metric, series.values[sel]) else " ",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    BarChart(series.values, series.labels, color, selected, { selected = it })
                    Text(
                        stringResource(
                            when (metric) {
                                ChartMetric.Steps -> R.string.charts_expl_steps
                                ChartMetric.Kcal -> R.string.charts_expl_kcal
                                ChartMetric.Distance -> R.string.charts_expl_distance
                                ChartMetric.Workouts -> R.string.charts_expl_workouts
                                ChartMetric.Heart -> R.string.charts_expl_hr
                            }
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (metric == ChartMetric.Heart) {
                    val nz = series.values.filter { it > 0 }
                    StatTile(stringResource(R.string.charts_avg), format(metric, nz.average().toFloat()), Modifier.weight(1f))
                } else {
                    StatTile(stringResource(R.string.charts_total), format(metric, total), Modifier.weight(1f))
                    StatTile(stringResource(R.string.charts_avg), format(metric, avg), Modifier.weight(1f))
                }
                StatTile(stringResource(R.string.charts_best), format(metric, best), Modifier.weight(1f))
            }
        }

        val inPeriod = remember(health.workouts, period) {
            if (period == 0) health.workouts else {
                val from = LocalDate.now().minusDays(period - 1L).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                health.workouts.filter { it.start >= from }
            }
        }
        if (inPeriod.isNotEmpty()) {
            SportBreakdown(inPeriod, colored, onOpenSport)
            Records(inPeriod, colored, onOpenWorkout)
        }
    }
    }
}

@Composable
private fun SportBreakdown(workouts: List<Workout>, colored: Boolean, onOpenSport: (Int) -> Unit) {
    val groups = remember(workouts) {
        workouts.groupBy { it.type }.map { (t, l) -> Triple(t, l.size, l.sumOf { it.durationSec }) }.sortedByDescending { it.third }
    }
    val total = groups.sumOf { it.third }.coerceAtLeast(1L)
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = MaterialTheme.shapes.extraLarge,
    ) {
        Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(stringResource(R.string.charts_by_sport), style = MaterialTheme.typography.titleMedium)
            Row(Modifier.fillMaxWidth().height(16.dp).clip(RoundedCornerShape(8.dp)), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                groups.forEachIndexed { i, g ->
                    val c = if (colored) sportOf(g.first).color else MaterialTheme.colorScheme.primary.copy(alpha = (1f - i * 0.15f).coerceAtLeast(0.25f))
                    Box(Modifier.weight(g.third.coerceAtLeast(1L).toFloat()).fillMaxHeight().background(c))
                }
            }
            groups.forEach { (type, count, sec) ->
                Row(
                    Modifier.fillMaxWidth().springClick(MaterialTheme.shapes.medium) { onOpenSport(type) }.padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    SportBadge(sportOf(type), colored, size = 40.dp)
                    Column(Modifier.weight(1f)) {
                        Text(sportOf(type).name, style = MaterialTheme.typography.titleSmall)
                        Text(stringResource(R.string.act_count, count) + " · " + fmtDuration(sec), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text("${(sec * 100 / total)} %", style = MaterialTheme.typography.titleSmall)
                }
            }
        }
    }
}

private class Record(val label: String, val value: String, val w: Workout)

@Composable
internal fun Records(workouts: List<Workout>, colored: Boolean, onOpen: (String) -> Unit) {
    val lDist = stringResource(R.string.rec_distance)
    val lDur = stringResource(R.string.rec_duration)
    val lPace = stringResource(R.string.rec_pace)
    val lKcal = stringResource(R.string.rec_kcal)
    val lHr = stringResource(R.string.rec_hr)
    val items = remember(workouts, lDist) {
        buildList {
            workouts.filter { it.distanceM > 0 }.maxByOrNull { it.distanceM }?.let { add(Record(lDist, fmtDistance(it.distanceM), it)) }
            workouts.maxByOrNull { it.durationSec }?.let { add(Record(lDur, fmtDuration(it.durationSec), it)) }
            workouts.filter { it.type in setOf(56, 57, 79, 37) && it.distanceM >= 1000 }
                .minByOrNull { it.paceMinKm ?: Double.MAX_VALUE }?.let { w -> w.paceMinKm?.let { add(Record(lPace, fmtPace(it), w)) } }
            workouts.filter { it.kcal > 0 }.maxByOrNull { it.kcal }?.let { add(Record(lKcal, fmtKcal(it.kcal), it)) }
            workouts.filter { it.hrMax > 0 }.maxByOrNull { it.hrMax }?.let { add(Record(lHr, "${it.hrMax} bpm", it)) }
        }
    }
    if (items.isEmpty()) return
    Text(stringResource(R.string.charts_records), style = MaterialTheme.typography.titleMedium)
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        items.forEachIndexed { i, r ->
            val shape = groupedShape(i, items.size)
            Card(
                Modifier.fillMaxWidth().springClick(shape) { onOpen(r.w.id) },
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                shape = shape,
            ) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    SportBadge(r.w.sport, colored, size = 44.dp)
                    Column(Modifier.weight(1f)) {
                        Text(r.label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(r.value, style = MaterialTheme.typography.titleMedium)
                    }
                    Text(fmtDate(r.w.start), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}
