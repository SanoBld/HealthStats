package com.healthstats.app.ui.screens.activities

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.FilterChip
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
import com.healthstats.app.data.model.sourceLabel
import com.healthstats.app.data.model.sportOf
import com.healthstats.app.ui.components.EmptyState
import com.healthstats.app.ui.components.LoadingBlock
import com.healthstats.app.ui.components.WorkoutRow
import com.healthstats.app.util.fmtMonth

@Composable
fun ActivitiesScreen(settings: AppSettings, health: HealthState, onOpenWorkout: (String) -> Unit) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    var query by rememberSaveable { mutableStateOf("") }
    var sportFilter by rememberSaveable { mutableStateOf(-1) } // -1 = all

    val types = remember(health.workouts) {
        health.workouts.groupingBy { it.type }.eachCount().entries.sortedByDescending { it.value }.map { it.key }
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

    LazyColumn(
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = top + 12.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.act_title), style = MaterialTheme.typography.headlineMedium)
                Text(
                    stringResource(R.string.act_count, filtered.size),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        item {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                placeholder = { Text(stringResource(R.string.act_search)) },
                leadingIcon = { Icon(Icons.Rounded.Search, null) },
                singleLine = true,
                shape = MaterialTheme.shapes.extraLarge,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        if (types.size > 1) {
            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item {
                        FilterChip(selected = sportFilter == -1, onClick = { sportFilter = -1 }, label = { Text(stringResource(R.string.act_all)) })
                    }
                    items(types, key = { it }) { t ->
                        val sp = sportOf(t)
                        FilterChip(
                            selected = sportFilter == t,
                            onClick = { sportFilter = if (sportFilter == t) -1 else t },
                            label = { Text(sp.name) },
                            leadingIcon = { Icon(sp.icon, null, Modifier.size(18.dp)) },
                        )
                    }
                }
            }
        }
        if (health.loading && health.workouts.isEmpty()) {
            item { LoadingBlock(stringResource(R.string.sync_reading), Modifier.padding(vertical = 32.dp)) }
        } else if (filtered.isEmpty()) {
            item { EmptyState(Icons.Rounded.FitnessCenter, stringResource(R.string.act_empty)) }
        }
        grouped.forEach { (month, list) ->
            stickyHeader(key = "h_$month") {
                Box(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.background).padding(vertical = 8.dp)) {
                    Text(month, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                }
            }
            items(list, key = { it.id }) { w ->
                WorkoutRow(w, settings.sportColors, { onOpenWorkout(w.id) }, Modifier.animateItem())
            }
        }
    }
}
