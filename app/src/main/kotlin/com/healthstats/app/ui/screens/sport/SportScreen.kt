package com.healthstats.app.ui.screens.sport

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.model.Workout
import com.healthstats.app.data.model.sportOf
import com.healthstats.app.ui.components.BarChart
import com.healthstats.app.ui.components.EmptyState
import com.healthstats.app.ui.components.ExplainedCard
import com.healthstats.app.ui.components.LargeScreen
import com.healthstats.app.ui.components.LineChart
import com.healthstats.app.ui.components.SportBadge
import com.healthstats.app.ui.components.TileGrid
import com.healthstats.app.ui.components.WorkoutRow
import com.healthstats.app.ui.components.valueAt
import com.healthstats.app.ui.screens.charts.Records
import com.healthstats.app.ui.theme.groupedShape
import com.healthstats.app.util.fmtDate
import com.healthstats.app.util.fmtDistance
import com.healthstats.app.util.fmtDuration
import com.healthstats.app.util.fmtKcal
import com.healthstats.app.util.fmtSpeed
import kotlin.math.roundToInt

private enum class SportMetric(val label: Int, val expl: Int) {
    Hr(R.string.detail_hr_avg, R.string.sport_expl_hr),
    Dist(R.string.detail_distance, R.string.sport_expl_dist),
    Dur(R.string.detail_duration, R.string.sport_expl_dur),
    Speed(R.string.detail_speed, R.string.sport_expl_speed),
    Kcal(R.string.detail_kcal, R.string.sport_expl_kcal),
}

private fun valueOf(w: Workout, m: SportMetric): Double = when (m) {
    SportMetric.Hr -> w.hrAvg.toDouble()
    SportMetric.Dist -> w.distanceM / 1000.0
    SportMetric.Dur -> w.durationSec / 60.0
    SportMetric.Speed -> w.speedKmh ?: 0.0
    SportMetric.Kcal -> w.kcal
}

private fun show(m: SportMetric, v: Double): String = when (m) {
    SportMetric.Hr -> "${v.toInt()} bpm"
    SportMetric.Dist -> fmtDistance(v * 1000)
    SportMetric.Dur -> fmtDuration((v * 60).toLong())
    SportMetric.Speed -> fmtSpeed(v)
    SportMetric.Kcal -> fmtKcal(v)
}

/** Statistics of one sport: trend graph (with explanation), totals, heart rate spread, records, recent sessions. */
@Composable
fun SportScreen(
    type: Int,
    settings: AppSettings,
    health: HealthState,
    onBack: () -> Unit,
    onOpenWorkout: (String) -> Unit,
) {
    val sport = sportOf(type)
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val list = remember(health.workouts, type) { health.workouts.filter { it.type == type }.sortedBy { it.start } }
    var mIdx by rememberSaveable { mutableIntStateOf(0) }
    var cursor by remember { mutableStateOf<Float?>(null) }
    var histSel by remember { mutableStateOf<Int?>(null) }
    val m = SportMetric.entries[mIdx]
    // Last 40 sessions that have a value for this metric
    val pts = remember(list, m) { list.filter { valueOf(it, m) > 0 }.takeLast(40) }

    val lSessions = stringResource(R.string.sport_sessions)
    val lTime = stringResource(R.string.sport_total_time)
    val lDist = stringResource(R.string.detail_distance)
    val lAvg = stringResource(R.string.detail_hr_avg)
    val lMax = stringResource(R.string.detail_hr_max)
    val lKcal = stringResource(R.string.detail_kcal)

    LargeScreen(sport.name, onBack = onBack) { inner ->
        Column(
            Modifier.padding(inner).verticalScroll(rememberScrollState())
                .padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottom + 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            if (list.isEmpty()) {
                EmptyState(Icons.Rounded.BarChart, stringResource(R.string.act_empty))
                return@Column
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                SportBadge(sport, settings.sportColors, size = 84.dp, spin = true)
                Text(
                    stringResource(R.string.act_count, list.size) + " · " + fmtDate(list.first().start) + " → " + fmtDate(list.last().start),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Totals
            val tiles = buildList {
                add(lSessions to list.size.toString())
                add(lTime to fmtDuration(list.sumOf { it.durationSec }))
                val dist = list.sumOf { it.distanceM }
                if (dist > 0) add(lDist to fmtDistance(dist))
                val hrs = list.filter { it.hrAvg > 0 }
                if (hrs.isNotEmpty()) add(lAvg to "${hrs.map { it.hrAvg }.average().roundToInt()} bpm")
                val mx = list.maxOf { it.hrMax }
                if (mx > 0) add(lMax to "$mx bpm")
                val kc = list.sumOf { it.kcal }
                if (kc > 0) add(lKcal to fmtKcal(kc))
            }
            TileGrid(tiles)

            // Trend graph with metric chips
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(SportMetric.entries.toList()) { e ->
                    FilterChip(selected = e == m, onClick = { mIdx = e.ordinal; cursor = null }, label = { Text(stringResource(e.label)) })
                }
            }
            if (pts.size >= 2) {
                val xs = pts.indices.map { it / (pts.size - 1f) }
                val ys = pts.map { valueOf(it, m).toFloat() }
                val sel = cursor?.let { (it * (pts.size - 1)).roundToInt().coerceIn(0, pts.size - 1) }
                ExplainedCard(
                    title = stringResource(R.string.sport_trend),
                    explanation = stringResource(m.expl),
                    value = sel?.let { fmtDate(pts[it].start) + " · " + show(m, valueOf(pts[it], m)) },
                ) {
                    LineChart(xs, ys, if (settings.sportColors) sport.color else MaterialTheme.colorScheme.primary, cursor, { cursor = it })
                }
            } else {
                EmptyState(Icons.Rounded.BarChart, stringResource(R.string.charts_empty))
            }

            // How many sessions at each average heart rate
            val hist = remember(list) {
                val by = list.filter { it.hrAvg > 0 }.groupingBy { it.hrAvg / 10 * 10 }.eachCount()
                if (by.isEmpty()) emptyList() else (by.keys.min()..by.keys.max() step 10).map { it to (by[it] ?: 0) }
            }
            if (hist.size >= 2) {
                val vals = hist.map { it.second.toFloat() }
                val labels = hist.map { "${it.first}" }
                val sel = histSel
                ExplainedCard(
                    title = stringResource(R.string.sport_hist),
                    explanation = stringResource(R.string.sport_hist_expl),
                    value = if (sel != null && sel in hist.indices) "${labels[sel]} bpm · ${hist[sel].second}" else null,
                ) { BarChart(vals, labels, Color(0xFFFF3B30), histSel, { histSel = it }) }
            }

            Records(list, settings.sportColors, onOpenWorkout)

            // Recent sessions
            val recent = list.takeLast(5).reversed()
            Text(stringResource(R.string.sport_recent), style = MaterialTheme.typography.titleMedium)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                recent.forEachIndexed { i, w ->
                    WorkoutRow(w, settings.sportColors, { onOpenWorkout(w.id) }, Modifier.fillMaxWidth(), groupedShape(i, recent.size))
                }
            }
        }
    }
}
