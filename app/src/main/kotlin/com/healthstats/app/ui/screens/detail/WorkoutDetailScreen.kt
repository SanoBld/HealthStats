package com.healthstats.app.ui.screens.detail

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.widthIn
import androidx.health.connect.client.contracts.ExerciseRouteRequestContract
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.healthstats.app.R
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.model.TimedValue
import com.healthstats.app.data.model.Workout
import com.healthstats.app.data.model.sourceLabel
import com.healthstats.app.ui.components.AppScreen
import com.healthstats.app.ui.components.BarChart
import com.healthstats.app.ui.components.ExplainedCard
import com.healthstats.app.ui.components.LineChart
import com.healthstats.app.ui.components.RouteMap
import com.healthstats.app.ui.components.SectionTitle
import com.healthstats.app.ui.components.SkeletonBox
import com.healthstats.app.ui.components.SportBadge
import com.healthstats.app.ui.components.StatTile
import com.healthstats.app.ui.components.TileGrid
import com.healthstats.app.ui.components.valueAt
import com.healthstats.app.ui.theme.isDarkFor
import com.healthstats.app.util.derivedSpeed
import com.healthstats.app.util.elevationOf
import com.healthstats.app.util.fmtDate
import com.healthstats.app.util.fmtDistance
import com.healthstats.app.util.fmtDuration
import com.healthstats.app.util.fmtInt
import com.healthstats.app.util.fmtKcal
import com.healthstats.app.util.fmtPace
import com.healthstats.app.util.fmtSpeed
import com.healthstats.app.util.fmtTime
import com.healthstats.app.util.pointAt
import com.healthstats.app.util.routeFractions
import com.healthstats.app.util.splitsOf
import com.healthstats.app.viewmodel.WorkoutViewModel

private val ZoneColors = listOf(Color(0xFF8E8E93), Color(0xFF34C759), Color(0xFFFFCC00), Color(0xFFFF9500), Color(0xFFFF3B30))
private val FootSports = setOf(56, 57, 79, 37)
private val BikeSports = setOf(8, 9)

@Composable
fun WorkoutDetailScreen(id: String, settings: AppSettings, onBack: () -> Unit) {
    val vm: WorkoutViewModel = viewModel(key = "workout_$id", factory = WorkoutViewModel.factory(id))
    val w by vm.workout.collectAsStateWithLifecycle()
    val d by vm.detail.collectAsStateWithLifecycle()
    // 0..1 position along the workout, shared by the map and every chart
    var cursor by remember { mutableStateOf<Float?>(null) }
    var histSel by remember { mutableStateOf<Int?>(null) }
    val consent = rememberLauncherForActivityResult(ExerciseRouteRequestContract()) { route -> vm.onConsentResult(route) }

    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val workout: Workout? = w
    val lineColor = (if (settings.sportColors) workout?.sport?.color else null) ?: MaterialTheme.colorScheme.primary
    val splits = remember(d.route) { splitsOf(d.route) }
    val derived = remember(d.route) { derivedSpeed(d.route) }
    val elevation = remember(d.route) { elevationOf(d.route) }

    val lDur = stringResource(R.string.detail_duration)
    val lDist = stringResource(R.string.detail_distance)
    val lPace = stringResource(R.string.detail_pace)
    val lSpeed = stringResource(R.string.detail_speed)
    val lKcal = stringResource(R.string.detail_kcal)
    val lSteps = stringResource(R.string.detail_steps)
    val lAvg = stringResource(R.string.detail_hr_avg)
    val lMax = stringResource(R.string.detail_hr_max)
    val lMin = stringResource(R.string.detail_hr_min)

    AppScreen(workout?.sport?.name ?: "", onBack = onBack) { inner ->
    LazyColumn(
        Modifier.padding(inner),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottom + 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (workout == null) return@LazyColumn
        val sport = workout.sport
        val foot = workout.type in FootSports

        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                SportBadge(sport, settings.sportColors, size = 76.dp, spin = true)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(workout.title.ifEmpty { sport.name }, style = MaterialTheme.typography.headlineSmall)
                    Text(
                        fmtDate(workout.start) + " · " + fmtTime(workout.start) + "–" + fmtTime(workout.end),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(sourceLabel(workout.source), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        if (workout.altSources.isNotEmpty()) {
            item {
                Text(
                    stringResource(R.string.detail_merged, workout.altSources.joinToString(", ") { sourceLabel(it) }),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // Summary tiles: only the values we have
        val tiles = buildList {
            add(lDur to fmtDuration(workout.durationSec))
            if (workout.distanceM > 0) add(lDist to fmtDistance(workout.distanceM))
            workout.paceMinKm?.let { if (foot) add(lPace to fmtPace(it)) }
            workout.speedKmh?.let { if (!foot) add(lSpeed to fmtSpeed(it)) }
            if (workout.kcal > 0) add(lKcal to fmtKcal(workout.kcal))
            if (workout.steps > 0) add(lSteps to fmtInt(workout.steps))
            if (workout.hrAvg > 0) add(lAvg to "${workout.hrAvg} bpm")
            if (workout.hrMax > 0) add(lMax to "${workout.hrMax} bpm")
            if (workout.hrMin > 0) add(lMin to "${workout.hrMin} bpm")
        }
        item { TileGrid(tiles) }

        // Map: only when there is a route. No pop-up, just a placeholder while it loads.
        if (d.routeLoading) {
            item { SkeletonBox(Modifier.fillMaxWidth().height(280.dp)) }
        } else if (d.route.isNotEmpty()) {
            item {
                val marker = cursor?.let { pointAt(d.route, workout.start, workout.end, it) }
                RouteMap(
                    points = d.route,
                    marker = marker,
                    lineColor = lineColor.toArgb(),
                    dark = isDarkFor(settings.theme),
                    modifier = Modifier.fillMaxWidth().height(280.dp).clip(RoundedCornerShape(32.dp)),
                )
            }
        } else if (d.consentId != null) {
            item {
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    shape = MaterialTheme.shapes.extraLarge,
                ) {
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.detail_route_allow_sub), style = MaterialTheme.typography.bodyMedium)
                        Button(onClick = { d.consentId?.let { consent.launch(it) } }) { Text(stringResource(R.string.detail_route_allow)) }
                    }
                }
            }
        }

        val span = (workout.end - workout.start).coerceAtLeast(1L).toFloat()
        fun xsOf(list: List<TimedValue>) = list.map { ((it.time - workout.start) / span).coerceIn(0f, 1f) }

        // 1) Heart rate over time, linked to the map
        if (d.hr.size >= 2) {
            item {
                val xs = remember(d.hr, workout.id) { xsOf(d.hr) }
                val ys = remember(d.hr) { d.hr.map { it.value.toFloat() } }
                ExplainedCard(
                    title = stringResource(R.string.detail_hr),
                    explanation = stringResource(R.string.detail_hr_expl),
                    value = valueAt(xs, ys, cursor)?.let { "${it.toInt()} bpm" },
                ) { LineChart(xs, ys, Color(0xFFFF3B30), cursor, { cursor = it }) }
            }

            // 2) Time in each zone
            val total = d.zonesSec.sum()
            if (total > 0) {
                item {
                    ExplainedCard(
                        title = stringResource(R.string.detail_zones),
                        explanation = stringResource(R.string.detail_zones_expl),
                        value = "max ${d.maxHr}",
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            d.zonesSec.forEachIndexed { i, sec ->
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Text("Z${i + 1}", Modifier.width(26.dp), style = MaterialTheme.typography.labelLarge)
                                    Box(Modifier.weight(1f).height(14.dp).clip(RoundedCornerShape(7.dp)).background(MaterialTheme.colorScheme.surfaceContainerHighest)) {
                                        Box(
                                            Modifier.fillMaxWidth((sec.toFloat() / total).coerceIn(0.01f, 1f)).height(14.dp)
                                                .clip(RoundedCornerShape(7.dp)).background(ZoneColors[i])
                                        )
                                    }
                                    Text(fmtDuration(sec), Modifier.width(60.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                }
            }

            // 3) Histogram: minutes at each heart rate
            if (d.hrHist.size >= 2) {
                item {
                    val vals = d.hrHist.map { it.second / 60f }
                    val labels = d.hrHist.map { "${it.first}" }
                    val sel = histSel
                    ExplainedCard(
                        title = stringResource(R.string.detail_hist),
                        explanation = stringResource(R.string.detail_hist_expl),
                        value = if (sel != null && sel in vals.indices) "${labels[sel]} bpm · ${fmtDuration(d.hrHist[sel].second)}" else null,
                    ) { BarChart(vals, labels, Color(0xFFFF3B30), histSel, { histSel = it }) }
                }
            }

            // 4) Effort, intensity and drift
            item {
                val level = when {
                    d.effort < 50 -> R.string.effort_light
                    d.effort < 100 -> R.string.effort_moderate
                    d.effort < 200 -> R.string.effort_hard
                    else -> R.string.effort_extreme
                }
                ExplainedCard(
                    title = stringResource(R.string.detail_effort),
                    explanation = stringResource(R.string.detail_effort_expl),
                ) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        StatTile(stringResource(R.string.detail_effort), "${d.effort} · " + stringResource(level), Modifier.weight(1f))
                        StatTile(stringResource(R.string.detail_intensity), "${d.intensityPct} %", Modifier.weight(1f))
                        d.driftPct?.let {
                            StatTile(stringResource(R.string.detail_drift), String.format(java.util.Locale.getDefault(), "%+.1f %%", it), Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        // 5) Speed (from Health Connect, or worked out from the route)
        val speedSeries = if (d.speed.size >= 2) d.speed else derived
        if (speedSeries.size >= 2) {
            item {
                val xs = remember(speedSeries, workout.id) { xsOf(speedSeries) }
                val ys = remember(speedSeries) { speedSeries.map { it.value.toFloat() } }
                ExplainedCard(
                    title = stringResource(R.string.detail_speed_chart),
                    explanation = stringResource(R.string.detail_speed_expl),
                    value = valueAt(xs, ys, cursor)?.let { v -> if (foot && v > 0.5f) fmtPace(60.0 / v) else fmtSpeed(v.toDouble()) },
                ) { LineChart(xs, ys, lineColor, cursor, { cursor = it }) }
            }
        }

        // 6) Elevation profile + climb and descent
        val altIdx = d.route.indices.filter { !d.route[it].alt.isNaN() }
        if (altIdx.size >= 2) {
            item {
                val fr = remember(d.route, workout.id) { routeFractions(d.route, workout.start, workout.end) }
                val xs = remember(fr) { altIdx.map { fr[it] } }
                val ys = remember(d.route) { altIdx.map { d.route[it].alt.toFloat() } }
                ExplainedCard(
                    title = stringResource(R.string.detail_elev),
                    explanation = stringResource(R.string.detail_elev_expl),
                    value = valueAt(xs, ys, cursor)?.let { "${it.toInt()} m" },
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        LineChart(xs, ys, lineColor, cursor, { cursor = it })
                        elevation?.let { (up, down) ->
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                StatTile(stringResource(R.string.detail_gain), "+${up.toInt()} m", Modifier.weight(1f))
                                StatTile(stringResource(R.string.detail_loss), "−${down.toInt()} m", Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }

        // 7) Power (cycling and others that record it)
        if (d.power.size >= 2) {
            item {
                val xs = remember(d.power, workout.id) { xsOf(d.power) }
                val ys = remember(d.power) { d.power.map { it.value.toFloat() } }
                ExplainedCard(
                    title = stringResource(R.string.detail_power),
                    explanation = stringResource(R.string.detail_power_expl),
                    value = valueAt(xs, ys, cursor)?.let { "${it.toInt()} W" },
                ) { LineChart(xs, ys, Color(0xFFFFB800), cursor, { cursor = it }) }
            }
        }

        // 8) Kilometer splits
        if (splits.isNotEmpty() && (foot || workout.type in BikeSports)) {
            item {
                val best = splits.minOf { it.secPerKm }
                val bike = workout.type in BikeSports
                ExplainedCard(
                    title = stringResource(R.string.detail_splits),
                    explanation = stringResource(R.string.detail_speed_expl),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        splits.forEach { s ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text(
                                    if (s.meters >= 999) "${s.km}" else String.format(java.util.Locale.getDefault(), "%.1f", s.km - 1 + s.meters / 1000.0),
                                    Modifier.width(34.dp),
                                    style = MaterialTheme.typography.labelLarge,
                                )
                                Box(Modifier.weight(1f).height(14.dp).clip(RoundedCornerShape(7.dp)).background(MaterialTheme.colorScheme.surfaceContainerHighest)) {
                                    Box(Modifier.fillMaxWidth((best / s.secPerKm).toFloat().coerceIn(0.05f, 1f)).height(14.dp).clip(RoundedCornerShape(7.dp)).background(lineColor))
                                }
                                Text(
                                    if (bike) fmtSpeed(3600.0 / s.secPerKm) else fmtPace(s.secPerKm / 60.0),
                                    Modifier.width(84.dp),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }
        }

        if (workout.notes.isNotEmpty()) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    SectionTitle(stringResource(R.string.detail_notes))
                    Text(workout.notes, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
    }
}
