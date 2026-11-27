package com.healthstats.app.ui.screens.activities

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.model.SportInfo
import com.healthstats.app.data.model.sourceLabel
import com.healthstats.app.data.model.sportOf
import com.healthstats.app.ui.components.EmptyState
import com.healthstats.app.ui.components.AppScreen
import com.healthstats.app.ui.components.FullLoader
import com.healthstats.app.ui.components.SyncAction
import com.healthstats.app.ui.components.syncText
import com.healthstats.app.ui.components.SportSummaryCard
import com.healthstats.app.ui.components.WorkoutRow
import com.healthstats.app.ui.components.appear
import com.healthstats.app.ui.theme.groupedShape
import com.healthstats.app.util.fmtMonth

private class TypeStat(val type: Int, val count: Int, val sec: Long)

@Composable
fun ActivitiesScreen(settings: AppSettings, health: HealthState, onOpenWorkout: (String) -> Unit, onOpenSport: (Int) -> Unit, onSync: () -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    var sportFilter by rememberSaveable { mutableStateOf(-1) } // -1 = all

    val stats = remember(health.workouts) {
        health.workouts.groupBy { it.type }
            .map { (t, l) -> TypeStat(t, l.size, l.sumOf { it.durationSec }) }
            .sortedByDescending { it.count }
    }
    val filtered = remember(health.workouts, query, sportFilter) {
        val q = query.trim().lowercase()
        health.workouts.filter { w ->
            (sportFilter == -1 || w.type == sportFilter) &&
                (q.isEmpty() || w.title.lowercase().contains(q) || w.sport.name.lowercase().contains(q) ||
                    sourceLabel(w.source).lowercase().contains(q))
        }
    }
    val grouped = remember(filtered) { filtered.groupBy { fmtMonth(it.start) } }
    val allSport = remember { SportInfo("Tout", "All", Icons.Rounded.FitnessCenter, androidx.compose.ui.graphics.Color(0xFF8E8E93)) }

    val full = health.syncing && health.workouts.isEmpty()
    val syncLabel = syncText(health)

    AppScreen(stringResource(R.string.act_title), actions = { SyncAction(health, full, onSync) }) { inner ->
        if (full) {
            FullLoader(health.progress, syncLabel, Modifier.padding(inner))
            return@AppScreen
        }
        LazyColumn(
            Modifier.padding(inner),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            item {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text(stringResource(R.string.act_search)) },
                    leadingIcon = { Icon(Icons.Rounded.Search, null) },
                    singleLine = true,
                    shape = MaterialTheme.shapes.extraLarge,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
                )
            }
            if (stats.size > 1) {
                item {
                    LazyRow(
                        Modifier.padding(bottom = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        item {
                            SportSummaryCard(
                                allSport.let { SportInfo(stringResource(R.string.act_all), stringResource(R.string.act_all), it.icon, it.color) },
                                colored = false,
                                count = health.workouts.size,
                                totalSec = health.workouts.sumOf { it.durationSec },
                                selected = sportFilter == -1,
                                onClick = { sportFilter = -1 },
                                modifier = Modifier.width(150.dp),
                            )
                        }
                        items(stats, key = { it.type }) { s ->
                            SportSummaryCard(
                                sportOf(s.type), settings.sportColors, s.count, s.sec,
                                selected = sportFilter == s.type,
                                onClick = { sportFilter = if (sportFilter == s.type) -1 else s.type },
                                modifier = Modifier.width(150.dp),
                            )
                        }
                    }
                }
            }
            if (sportFilter != -1) {
                item {
                    androidx.compose.material3.FilledTonalButton(
                        onClick = { onOpenSport(sportFilter) },
                        modifier = Modifier.padding(bottom = 12.dp),
                    ) { Text(stringResource(R.string.sport_view)) }
                }
            }
            if (filtered.isEmpty()) {
                item { EmptyState(Icons.Rounded.FitnessCenter, stringResource(R.string.act_empty)) }
            }
            grouped.forEach { (month, list) ->
                stickyHeader(key = "h_$month") {
                    Box(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.background).padding(top = 12.dp, bottom = 8.dp)) {
                        Text(
                            month + " · " + stringResource(R.string.act_count, list.size),
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
                itemsIndexed(list, key = { _, w -> w.id }) { i, w ->
                    WorkoutRow(
                        w, settings.sportColors, { onOpenWorkout(w.id) },
                        Modifier.animateItem(),
                        shape = groupedShape(i, list.size),
                    )
                }
            }
        }
    }
}
