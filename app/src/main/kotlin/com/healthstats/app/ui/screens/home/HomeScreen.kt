package com.healthstats.app.ui.screens.home

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoGraph
import androidx.compose.material.icons.outlined.Dashboard
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.rounded.AutoGraph
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.health.SyncError
import com.healthstats.app.data.health.SyncStage
import com.healthstats.app.ui.components.M3LoadingIndicator
import com.healthstats.app.ui.components.WavyProgress
import com.healthstats.app.ui.components.rememberHaptics
import com.healthstats.app.viewmodel.AppViewModel
import java.text.DateFormat
import java.util.Date

/** Bottom tabs. The home tab can never be hidden. */
private enum class Tab(val key: String, val label: Int, val off: ImageVector, val on: ImageVector) {
    Dash("dash", R.string.nav_dashboard, Icons.Outlined.Dashboard, Icons.Rounded.Dashboard),
    Activities("activities", R.string.nav_activities, Icons.Outlined.FitnessCenter, Icons.Rounded.FitnessCenter),
    Map("map", R.string.nav_map, Icons.Outlined.Map, Icons.Rounded.Map),
    Search("search", R.string.nav_search, Icons.Outlined.Search, Icons.Rounded.Search),
    Charts("charts", R.string.nav_charts, Icons.Outlined.AutoGraph, Icons.Rounded.AutoGraph),
}

@Composable
fun HomeScreen(vm: AppViewModel) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    val health by vm.health.collectAsStateWithLifecycle()
    val s = settings ?: return
    val haptic = rememberHaptics(s.haptics)

    val tabs = Tab.entries.filter { it == Tab.Dash || it.key !in s.hiddenTabs }
    var selectedKey by rememberSaveable { mutableStateOf(Tab.Dash.key) }
    val current = tabs.firstOrNull { it.key == selectedKey } ?: tabs.first()

    // Back button: go to the home tab first, then leave the app
    BackHandler(enabled = current != tabs.first()) { selectedKey = tabs.first().key }
    // Back from Health Connect settings etc.: re-check permissions, refresh if the data is old
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { vm.onResume() }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar {
                for (t in tabs) {
                    val sel = t == current
                    NavigationBarItem(
                        selected = sel,
                        onClick = { if (!sel) { haptic(); selectedKey = t.key } },
                        icon = { Icon(if (sel) t.on else t.off, contentDescription = null) },
                        label = { Text(stringResource(t.label)) },
                        alwaysShowLabel = s.navLabels,
                    )
                }
            }
        },
    ) { pad ->
        // Fade through: the old tab fades out fast, the new one fades in
        AnimatedContent(
            targetState = current,
            transitionSpec = { fadeIn(tween(220, delayMillis = 90)) togetherWith fadeOut(tween(90)) },
            label = "tabs",
            modifier = Modifier.padding(pad),
        ) { tab ->
            // TEMPORARY: real tab screens come in the next steps
            TabStatus(stringResource(tab.label), health) { vm.sync() }
        }
    }
}

/** Temporary tab content: shows what the data layer loaded, so the sync can be checked on the phone. */
@Composable
private fun TabStatus(title: String, h: HealthState, onSync: () -> Unit) {
    Column(
        Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(title, style = MaterialTheme.typography.headlineLarge)
        Text(stringResource(R.string.status_activities, h.workouts.size), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.status_days, h.days.size), style = MaterialTheme.typography.titleMedium)
        Text(
            if (h.lastSync == 0L) stringResource(R.string.status_never)
            else stringResource(R.string.status_last_sync, DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT).format(Date(h.lastSync))),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (h.loading) {
            val p = h.progress
            Text(
                when (p.stage) {
                    SyncStage.ComputingStats -> stringResource(R.string.sync_stats, p.done, p.total)
                    SyncStage.Totals -> stringResource(R.string.sync_totals)
                    SyncStage.History -> stringResource(R.string.sync_history, p.year)
                    else -> stringResource(R.string.sync_reading)
                },
            )
            WavyProgress(progress = p.fraction, Modifier.fillMaxWidth())
        }
        h.error?.let { e ->
            Text(
                when (e.kind) {
                    SyncError.Kind.Timeout -> stringResource(R.string.err_timeout)
                    SyncError.Kind.PartialStats -> stringResource(R.string.err_stats, e.detail ?: "")
                    SyncError.Kind.Other -> stringResource(R.string.err_other, e.detail ?: "")
                },
                color = MaterialTheme.colorScheme.error,
            )
        }
        Button(onClick = onSync, enabled = !h.loading && h.permitted) { Text(stringResource(R.string.sync_now)) }
        Spacer(Modifier.height(8.dp))
        Text(stringResource(R.string.status_note), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Box(Modifier.fillMaxWidth().padding(top = 16.dp)) { if (h.loading) M3LoadingIndicator() }
    }
}
