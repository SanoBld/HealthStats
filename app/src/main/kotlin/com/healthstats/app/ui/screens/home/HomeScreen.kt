package com.healthstats.app.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.ui.components.EmptyState
import com.healthstats.app.ui.components.ErrorCard
import com.healthstats.app.ui.components.LoadingBlock
import com.healthstats.app.ui.components.MetricTile
import com.healthstats.app.ui.components.MorphLoader
import com.healthstats.app.ui.components.SectionTitle
import com.healthstats.app.ui.components.StepsRing
import com.healthstats.app.ui.components.WaveLoader
import com.healthstats.app.ui.components.WorkoutRow
import com.healthstats.app.util.fmtDateTime
import com.healthstats.app.util.fmtDistance
import com.healthstats.app.util.fmtDuration
import com.healthstats.app.util.fmtInt
import com.healthstats.app.util.fmtKcal
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

@Composable
fun HomeScreen(
    settings: AppSettings,
    health: HealthState,
    onSync: () -> Unit,
    onConnect: () -> Unit,
    onOpenWorkout: (String) -> Unit,
    onOpenActivities: () -> Unit,
) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val today = LocalDate.now()
    val todayStat = health.days.lastOrNull { it.epochDay == today.toEpochDay() }
    val zone = ZoneId.systemDefault()
    val lRhr = stringResource(R.string.home_resting_hr)
    val lWeight = stringResource(R.string.home_weight)
    val lSleep = stringResource(R.string.home_sleep)

    // Workouts of this week (Monday to Sunday)
    val monday = today.with(DayOfWeek.MONDAY)
    val weekDays = remember(health.workouts, monday) {
        health.workouts
            .map { Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate() }
            .filter { !it.isBefore(monday) }
            .toSet()
    }
    val weekCount = remember(health.workouts, monday) {
        health.workouts.count { !Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate().isBefore(monday) }
    }

    LazyColumn(
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = top + 12.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (settings.name.isNotEmpty()) stringResource(R.string.home_hello, settings.name) else stringResource(R.string.home_hello_anon),
                        style = MaterialTheme.typography.headlineMedium,
                    )
                    Text(
                        if (health.lastSync > 0) stringResource(R.string.last_sync, fmtDateTime(health.lastSync)) else stringResource(R.string.never_synced),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (health.loading) {
                    MorphLoader(size = 26.dp)
                } else if (health.permitted) {
                    IconButton(onClick = onSync) { Icon(Icons.Rounded.Refresh, stringResource(R.string.sync_now)) }
                }
            }
        }

        if (health.ready && !health.permitted) {
            item {
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                    shape = MaterialTheme.shapes.large,
                ) {
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.home_no_perm_title), style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onPrimaryContainer)
                        Text(stringResource(R.string.home_no_perm_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onPrimaryContainer)
                        Button(onClick = onConnect) { Text(stringResource(R.string.hc_allow)) }
                    }
                }
            }
        }

        health.error?.let { e ->
            item {
                ErrorCard(
                    if (e.timeout) stringResource(R.string.err_timeout) else stringResource(R.string.err_other, e.detail),
                    onRetry = onSync,
                )
            }
        }

        if (health.loading) {
            item {
                LoadingBlock(
                    stringResource(if (health.loadingStage == 2) R.string.sync_daily else R.string.sync_reading),
                    Modifier.padding(vertical = 12.dp),
                )
            }
        } else if (health.enriching) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    WaveLoader()
                    Text(
                        stringResource(R.string.sync_stats, health.statsDone, health.statsTotal),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        if (health.permitted) {
            item {
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    shape = MaterialTheme.shapes.large,
                ) {
                    Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                        StepsRing(todayStat?.steps ?: 0, settings.stepGoal)
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(stringResource(R.string.home_steps_today), style = MaterialTheme.typography.titleMedium)
                            Text(
                                stringResource(R.string.home_goal, fmtInt(settings.stepGoal)),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            if (todayStat != null && todayStat.distanceM > 0) Text(fmtDistance(todayStat.distanceM), style = MaterialTheme.typography.bodyMedium)
                            if (todayStat != null && todayStat.kcal > 0) Text(fmtKcal(todayStat.kcal), style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }

            item {
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    shape = MaterialTheme.shapes.large,
                ) {
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(stringResource(R.string.home_week), style = MaterialTheme.typography.titleMedium)
                        Text(
                            stringResource(R.string.home_week_goal, weekCount, settings.weeklyGoal),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            for (i in 0..6) {
                                val d = monday.plusDays(i.toLong())
                                val done = d in weekDays
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Box(
                                        Modifier
                                            .size(34.dp)
                                            .clip(CircleShape)
                                            .background(if (done) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        if (done) Icon(Icons.Rounded.FitnessCenter, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onPrimary)
                                    }
                                    Text(
                                        d.dayOfWeek.getDisplayName(TextStyle.NARROW, Locale.getDefault()),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = if (d == today) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            val tiles = buildList {
                health.latest.restingHr?.let { add(lRhr to "${it.toInt()} bpm") }
                health.latest.weightKg?.let { add(lWeight to String.format(Locale.getDefault(), "%.1f kg", it)) }
                health.latest.sleepMinutes?.let { add(lSleep to fmtDuration(it * 60)) }
            }
            if (tiles.isNotEmpty()) {
                item {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        tiles.forEach { (label, value) -> MetricTile(label, value, Modifier.weight(1f)) }
                    }
                }
            }

            val recent = health.workouts.take(3)
            if (recent.isNotEmpty()) {
                item {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        SectionTitle(stringResource(R.string.home_recent), Modifier.weight(1f))
                        TextButton(onClick = onOpenActivities) { Text(stringResource(R.string.home_see_all)) }
                    }
                }
                items(recent, key = { it.id }) { w ->
                    WorkoutRow(w, settings.sportColors, { onOpenWorkout(w.id) }, Modifier)
                }
            } else if (!health.loading && health.ready && health.error == null) {
                item { EmptyState(Icons.Rounded.FitnessCenter, stringResource(R.string.home_no_data)) }
            }
        }
    }
}
