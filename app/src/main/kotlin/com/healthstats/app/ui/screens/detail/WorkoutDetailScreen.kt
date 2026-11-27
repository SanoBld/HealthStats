package com.healthstats.app.ui.screens.detail

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
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
import androidx.health.connect.client.contracts.ExerciseRouteRequestContract
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.healthstats.app.R
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.model.Workout
import com.healthstats.app.data.model.sourceLabel
import com.healthstats.app.ui.components.LineChart
import com.healthstats.app.ui.components.RouteMap
import com.healthstats.app.ui.components.SectionTitle
import com.healthstats.app.ui.components.SkeletonBox
import com.healthstats.app.ui.components.SportBadge
import com.healthstats.app.ui.components.StatTile
import com.healthstats.app.ui.components.valueAt
import com.healthstats.app.ui.theme.isDarkFor
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
import com.healthstats.app.viewmodel.WorkoutViewModel

private val ZoneColors = listOf(Color(0xFF8E8E93), Color(0xFF34C759), Color(0xFFFFCC00), Color(0xFFFF9500), Color(0xFFFF3B30))

@Composable
fun WorkoutDetailScreen(id: String, settings: AppSettings, onBack: () -> Unit) {
    val vm: WorkoutViewModel = viewModel(key = "workout_$id", factory = WorkoutViewModel.factory(id))
    val w by vm.workout.collectAsStateWithLifecycle()
    val d by vm.detail.collectAsStateWithLifecycle()
    var cursor by remember { mutableStateOf<Float?>(null) }
    val consent = rememberLauncherForActivityResult(ExerciseRouteRequestContract()) { route -> vm.onConsentResult(route) }

    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val l_duration = stringResource(R.string.detail_duration)
    val l_distance = stringResource(R.string.detail_distance)
    val l_pace = stringResource(R.string.detail_pace)
    val l_speed = stringResource(R.string.detail_speed)
    val l_kcal = stringResource(R.string.detail_kcal)
    val l_steps = stringResource(R.string.detail_steps)
    val l_hr_avg = stringResource(R.string.detail_hr_avg)
    val l_hr_max = stringResource(R.string.detail_hr_max)
    val l_hr_min = stringResource(R.string.detail_hr_min)
    val workout: Workout? = w
    val lineColor = (if (settings.sportColors) workout?.sport?.color else null) ?: MaterialTheme.colorScheme.primary

    LazyColumn(
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = top + 8.dp, bottom = bottom + 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.back)) }
        }
        if (workout == null) return@LazyColumn
        val sport = workout.sport

        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                SportBadge(sport, settings.sportColors, size = 64.dp)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(workout.title.ifEmpty { sport.name }, style = MaterialTheme.typography.headlineSmall)
                    Text(
                        fmtDate(workout.start) + " · " + fmtTime(workout.start) + "–" + fmtTime(workout.end),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        sourceLabel(workout.source),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
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

        // Stat tiles: only the values we have
        val tiles = buildList {
            add(l_duration to fmtDuration(workout.durationSec))
            if (workout.distanceM > 0) add(l_distance to fmtDistance(workout.distanceM))
            workout.paceMinKm?.let { if (workout.type in setOf(56, 57, 79, 37)) add(l_pace to fmtPace(it)) }
            workout.speedKmh?.let { if (workout.type !in setOf(56, 57, 79, 37)) add(l_speed to fmtSpeed(it)) }
            if (workout.kcal > 0) add(l_kcal to fmtKcal(workout.kcal))
            if (workout.steps > 0) add(l_steps to fmtInt(workout.steps))
            if (workout.hrAvg > 0) add(l_hr_avg to "${workout.hrAvg} bpm")
            if (workout.hrMax > 0) add(l_hr_max to "${workout.hrMax} bpm")
            if (workout.hrMin > 0) add(l_hr_min to "${workout.hrMin} bpm")
        }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                tiles.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { (label, value) -> StatTile(label, value, Modifier.weight(1f)) }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
        }

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
                    modifier = Modifier.fillMaxWidth().height(280.dp).clip(RoundedCornerShape(28.dp)),
                )
            }
        } else if (d.consentId != null) {
            item {
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    shape = MaterialTheme.shapes.large,
                ) {
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.detail_route_allow_sub), style = MaterialTheme.typography.bodyMedium)
                        Button(onClick = { d.consentId?.let { consent.launch(it) } }) {
                            Text(stringResource(R.string.detail_route_allow))
                        }
                    }
                }
            }
        }

        // Heart rate chart, linked to the map marker
        if (d.hr.size >= 2) {
            item {
                val span = (workout.end - workout.start).coerceAtLeast(1L).toFloat()
                val xs = remember(d.hr, workout.id) { d.hr.map { ((it.time - workout.start) / span).coerceIn(0f, 1f) } }
                val ys = remember(d.hr) { d.hr.map { it.value.toFloat() } }
                ChartCard(
                    title = stringResource(R.string.detail_hr),
                    value = valueAt(xs, ys, cursor)?.let { "${it.toInt()} bpm" },
                ) { LineChart(xs, ys, Color(0xFFFF3B30), cursor, { cursor = it }) }
            }
        }

        // Altitude chart (from the route)
        val altIdx = d.route.indices.filter { !d.route[it].alt.isNaN() }
        if (altIdx.size >= 2) {
            item {
                val fr = remember(d.route, workout.id) { routeFractions(d.route, workout.start, workout.end) }
                val xs = remember(fr) { altIdx.map { fr[it] } }
                val ys = remember(d.route) { altIdx.map { d.route[it].alt.toFloat() } }
                ChartCard(
                    title = stringResource(R.string.detail_alt),
                    value = valueAt(xs, ys, cursor)?.let { "${it.toInt()} m" },
                ) { LineChart(xs, ys, lineColor, cursor, { cursor = it }) }
            }
        }

        // Time in each heart rate zone
        val total = d.zonesSec.sum()
        if (total > 0) {
            item {
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    shape = MaterialTheme.shapes.large,
                ) {
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(R.string.detail_zones) + " (max ${d.maxHr})", style = MaterialTheme.typography.titleMedium)
                        d.zonesSec.forEachIndexed { i, sec ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("Z${i + 1}", Modifier.padding(end = 2.dp), style = MaterialTheme.typography.labelLarge)
                                Box(
                                    Modifier.weight(1f).height(12.dp).clip(RoundedCornerShape(6.dp))
                                        .background(MaterialTheme.colorScheme.surfaceContainerHighest)
                                ) {
                                    Box(
                                        Modifier.fillMaxWidth((sec.toFloat() / total).coerceIn(0f, 1f)).height(12.dp)
                                            .clip(RoundedCornerShape(6.dp)).background(ZoneColors[i])
                                    )
                                }
                                Text(fmtDuration(sec), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
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

@Composable
private fun ChartCard(title: String, value: String?, chart: @Composable () -> Unit) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = MaterialTheme.shapes.large,
    ) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                if (value != null) Text(value, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
            }
            chart()
        }
    }
}
