package com.healthstats.app.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.ui.components.AppScreen
import com.healthstats.app.ui.components.BigPillButton
import com.healthstats.app.ui.components.EmptyState
import com.healthstats.app.ui.components.ErrorCard
import com.healthstats.app.ui.components.FullLoader
import com.healthstats.app.ui.components.SectionTitle
import com.healthstats.app.ui.components.SyncAction
import com.healthstats.app.ui.components.WorkoutRow
import com.healthstats.app.ui.components.appear
import com.healthstats.app.ui.components.syncText
import com.healthstats.app.util.fmtDateTime
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

@Composable
fun HomeScreen(
    settings: AppSettings,
    health: HealthState,
    onSync: () -> Unit,
    onConnect: () -> Unit,
    onOpenWorkout: (String) -> Unit,
    onOpenActivities: () -> Unit,
) {
    val today = LocalDate.now()
    val zone = ZoneId.systemDefault()
    val monday = today.with(DayOfWeek.MONDAY)
    val m = health.metrics
    val hasData = health.workouts.isNotEmpty() || health.days.isNotEmpty() || m.sleep.isNotEmpty() || m.restingHr.isNotEmpty()
    // One loader per page: the big one when there is nothing to show yet, otherwise the small one in the top bar
    val full = health.syncing && !hasData
    val title = if (settings.name.isNotEmpty()) stringResource(R.string.home_hello, settings.name) else stringResource(R.string.home_hello_anon)

    val weekWorkouts = remember(health.workouts, monday) {
        health.workouts.filter { !Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate().isBefore(monday) }
    }
    val weekDays = remember(weekWorkouts) { weekWorkouts.map { Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate() }.toSet() }
    val syncLabel = syncText(health)

    AppScreen(title, actions = { SyncAction(health, full, onSync) }) { inner ->
        if (full) {
            FullLoader(health.progress, syncLabel, Modifier.padding(inner))
            return@AppScreen
        }
        LazyColumn(
            Modifier.padding(inner),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                Text(
                    if (health.syncing) syncLabel
                    else if (health.lastSync > 0) stringResource(R.string.last_sync, fmtDateTime(health.lastSync))
                    else stringResource(R.string.never_synced),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (health.ready && !health.permitted) {
                item {
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                        shape = MaterialTheme.shapes.extraLarge,
                    ) {
                        Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(stringResource(R.string.home_no_perm_title), style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onPrimaryContainer)
                            Text(stringResource(R.string.home_no_perm_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onPrimaryContainer)
                            BigPillButton(stringResource(R.string.hc_allow), onConnect)
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

            if (health.permitted) {
                item { StepsCard(settings, health.days, today, Modifier.appear(0)) }
                item {
                    WeekCard(
                        weekDays, weekWorkouts.size, settings.weeklyGoal,
                        weekWorkouts.sumOf { it.durationSec }, weekWorkouts.sumOf { it.distanceM }, weekWorkouts.sumOf { it.kcal },
                        today, Modifier.appear(1),
                    )
                }
                item { SleepCard(m, Modifier.appear(2)) }
                item { HeartCard(m, today, Modifier.appear(3)) }
                item { BodyCard(m, Modifier.appear(4)) }

                val recent = health.workouts.take(3)
                if (recent.isNotEmpty()) {
                    item {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            SectionTitle(stringResource(R.string.home_recent), Modifier.weight(1f))
                            TextButton(onClick = onOpenActivities) { Text(stringResource(R.string.home_see_all)) }
                        }
                    }
                    items(recent, key = { it.id }) { w ->
                        WorkoutRow(w, settings.sportColors, { onOpenWorkout(w.id) })
                    }
                } else if (!health.syncing && health.ready && health.error == null && !hasData) {
                    item { EmptyState(Icons.Rounded.FitnessCenter, stringResource(R.string.home_no_data)) }
                }
            }
        }
    }
}
