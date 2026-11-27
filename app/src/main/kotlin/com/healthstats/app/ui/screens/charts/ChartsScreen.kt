package com.healthstats.app.ui.screens.charts

import androidx.compose.foundation.layout.Arrangement
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
        }
    }
    val sums = LinkedHashMap<Long, Double>()
    val firstDates = LinkedHashMap<Long, LocalDate>()
    var d = start
    while (!d.isAfter(today)) {
        val key = when (mode) {
            0 -> d.toEpochDay()
            1 -> ChronoUnit.DAYS.between(start, d) / 7
            else -> d.year * 12L + d.monthValue
        }
        sums[key] = (sums[key] ?: 0.0) + valueOf(d)
        if (key !in firstDates) firstDates[key] = d
        d = d.plusDays(1)
    }
    val dayFmt = DateTimeFormatter.ofPattern("d MMM", loc)
    val monthFmt = DateTimeFormatter.ofPattern("MMM yy", loc)
    return Series(
        sums.values.map { it.toFloat() },
        firstDates.values.map { if (mode == 2) monthFmt.format(it) else dayFmt.format(it) },
        windowDays,
    )
}

private fun format(metric: ChartMetric, v: Float): String = when (metric) {
    ChartMetric.Steps -> fmtInt(v.toInt())
    ChartMetric.Kcal -> fmtInt(v.toInt()) + " kcal"
    ChartMetric.Distance -> String.format(Locale.getDefault(), "%.1f km", v)
    ChartMetric.Workouts -> v.toInt().toString()
}

@Composable
fun ChartsScreen(health: HealthState) {
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

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = top + 12.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(stringResource(R.string.charts_title), style = MaterialTheme.typography.headlineMedium)
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
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(stringResource(R.string.charts_total), format(metric, total), Modifier.weight(1f))
                StatTile(stringResource(R.string.charts_avg), format(metric, avg), Modifier.weight(1f))
                StatTile(stringResource(R.string.charts_best), format(metric, best), Modifier.weight(1f))
            }
        }
    }
}
