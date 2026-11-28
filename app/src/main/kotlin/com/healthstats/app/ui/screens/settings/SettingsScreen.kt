package com.healthstats.app.ui.screens.settings

import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.healthstats.app.BuildConfig
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.local.SettingsStore.Keys
import com.healthstats.app.data.local.ThemeMode
import com.healthstats.app.ui.components.BigPillButton
import com.healthstats.app.ui.components.ConnectedButtonGroup
import com.healthstats.app.ui.components.DateField
import com.healthstats.app.ui.components.AppScreen
import com.healthstats.app.ui.components.SyncAction
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.foundation.layout.size
import com.healthstats.app.data.health.HealthPermissions
import com.healthstats.app.util.fmtInt
import com.healthstats.app.util.openHealthConnect
import com.healthstats.app.util.openLanguageSettings
import com.healthstats.app.viewmodel.AppViewModel
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(start = 8.dp))
        Card(
            Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            shape = MaterialTheme.shapes.extraLarge,
        ) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { content() }
        }
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
fun SettingsScreen(settings: AppSettings, health: HealthState, vm: AppViewModel, onConnect: () -> Unit) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    var name by remember { mutableStateOf(settings.name) }
    var height by remember { mutableStateOf(if (settings.heightCm > 0) settings.heightCm.toString() else "") }
    var stepGoal by remember { mutableFloatStateOf(settings.stepGoal.toFloat()) }
    var weekly by remember { mutableFloatStateOf(settings.weeklyGoal.toFloat()) }
    var intervalsId by remember { mutableStateOf(settings.intervalsId) }
    var intervalsKey by remember { mutableStateOf(settings.intervalsKey) }
    var testState by remember { mutableIntStateOf(0) } // 0 idle, 1 testing, 2 ok, 3 failed
    var confirmClear by remember { mutableStateOf(false) }
    val clearedMsg = stringResource(R.string.set_clear_done)

    AppScreen(stringResource(R.string.set_title), actions = { SyncAction(health, false) { vm.sync() } }) { inner ->
    Column(
        Modifier.padding(inner).imePadding().verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Section(stringResource(R.string.set_profile)) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it.take(30); vm.set(Keys.NAME, name.trim()) },
                label = { Text(stringResource(R.string.set_name)) },
                singleLine = true,
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = height,
                onValueChange = { v -> height = v.filter { it.isDigit() }.take(3); vm.set(Keys.HEIGHT, height.toIntOrNull() ?: 0) },
                label = { Text(stringResource(R.string.set_height)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth(),
            )
            DateField(stringResource(R.string.set_birth), settings.birthDate, { vm.set(Keys.BIRTH, it) })
        }

        Section(stringResource(R.string.set_goals)) {
            Text(stringResource(R.string.set_steps_goal, fmtInt(stepGoal.roundToInt())), style = MaterialTheme.typography.bodyLarge)
            Slider(
                value = stepGoal,
                onValueChange = { stepGoal = it },
                onValueChangeFinished = { vm.set(Keys.STEP_GOAL, stepGoal.roundToInt()) },
                valueRange = 2000f..30000f,
                steps = 55,
            )
            Text(stringResource(R.string.set_week_goal, weekly.roundToInt()), style = MaterialTheme.typography.bodyLarge)
            Slider(
                value = weekly,
                onValueChange = { weekly = it },
                onValueChangeFinished = { vm.set(Keys.WEEKLY_GOAL, weekly.roundToInt()) },
                valueRange = 1f..14f,
                steps = 12,
            )
        }

        Section(stringResource(R.string.set_appearance)) {
            ConnectedButtonGroup(
                listOf(
                    ThemeMode.System to stringResource(R.string.theme_system),
                    ThemeMode.Light to stringResource(R.string.theme_light),
                    ThemeMode.Dark to stringResource(R.string.theme_dark),
                ),
                settings.theme,
                { vm.set(Keys.THEME, it.ordinal) },
            )
            SwitchRow(stringResource(R.string.set_dynamic), settings.dynamicColor) { vm.set(Keys.DYNAMIC, it) }
            SwitchRow(stringResource(R.string.set_sport_colors), settings.sportColors) { vm.set(Keys.SPORT_COLORS, it) }
            Column(Modifier.fillMaxWidth().clickable { openLanguageSettings(ctx) }) {
                Text(stringResource(R.string.set_language), style = MaterialTheme.typography.bodyLarge)
                Text(stringResource(R.string.set_language_sub), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        Section(stringResource(R.string.set_data)) {
            if (health.permitted) {
                BigPillButton(stringResource(R.string.sync_now), { vm.sync() }, enabled = !health.syncing)
            }
            TextButton(onClick = onConnect) { Text(stringResource(R.string.hc_allow)) }
            TextButton(onClick = { openHealthConnect(ctx) }) { Text(stringResource(R.string.set_open_hc)) }
            TextButton(onClick = { confirmClear = true }) { Text(stringResource(R.string.set_clear_cache)) }
        }

        Section(stringResource(R.string.set_diag)) {
            Text(stringResource(R.string.diag_sub), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            val perms = HealthPermissions.NAMED.toMap()
            val m = health.metrics
            val rows = listOf(
                Triple(R.string.dt_exercise, "exercise", health.workouts.size),
                Triple(R.string.dt_steps, "steps", health.days.count { it.steps > 0 }),
                Triple(R.string.dt_heart_rate, "heart_rate", m.hrDays.size),
                Triple(R.string.dt_distance, "distance", health.days.count { it.distanceM > 0 }),
                Triple(R.string.dt_kcal, "kcal", health.days.count { it.kcal > 0 }),
                Triple(R.string.dt_sleep, "sleep", m.sleep.size),
                Triple(R.string.dt_weight, "weight", m.weight.size),
                Triple(R.string.dt_height, "height", -1),
                Triple(R.string.dt_resting, "resting", m.restingHr.size),
                Triple(R.string.dt_hrv, "hrv", m.hrv.size),
                Triple(R.string.dt_spo2, "spo2", m.spo2.size),
                Triple(R.string.dt_vo2, "vo2", m.vo2.size),
                Triple(R.string.dt_speed, "speed", -1),
                Triple(R.string.dt_power, "power", -1),
                Triple(R.string.dt_history, "history", -1),
            )
            rows.forEach { (label, key, count) ->
                val ok = perms[key] in health.granted
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(
                        if (ok) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel, null, Modifier.size(22.dp),
                        tint = if (ok) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    )
                    Text(stringResource(label), Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
                    Text(
                        when {
                            !ok -> stringResource(R.string.diag_denied)
                            count < 0 -> stringResource(R.string.diag_ok)
                            count == 0 -> stringResource(R.string.diag_none)
                            else -> stringResource(R.string.diag_found, count)
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = if (ok) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.error,
                    )
                }
            }
            if (rows.any { perms[it.second] !in health.granted }) {
                BigPillButton(stringResource(R.string.hc_allow), onConnect)
            }
        }

        Section(stringResource(R.string.set_intervals)) {
            Text(stringResource(R.string.set_intervals_sub), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(
                value = intervalsId,
                onValueChange = { intervalsId = it.trim().take(20); testState = 0; vm.set(Keys.INTERVALS_ID, intervalsId) },
                label = { Text(stringResource(R.string.set_intervals_id)) },
                singleLine = true,
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = intervalsKey,
                onValueChange = { intervalsKey = it.trim(); testState = 0; vm.set(Keys.INTERVALS_KEY, intervalsKey) },
                label = { Text(stringResource(R.string.set_intervals_key)) },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = {
                        testState = 1
                        scope.launch { testState = if (vm.testIntervals(intervalsId, intervalsKey)) 2 else 3 }
                    },
                    enabled = intervalsKey.isNotEmpty() && testState != 1,
                ) { Text(stringResource(R.string.set_intervals_test)) }
                when (testState) {
                    1 -> Text("…", style = MaterialTheme.typography.titleMedium)
                    2 -> Text(stringResource(R.string.set_intervals_ok), color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodyMedium)
                    3 -> Text(stringResource(R.string.set_intervals_fail), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }

        Section(stringResource(R.string.set_about)) {
            Text(stringResource(R.string.set_version, BuildConfig.VERSION_NAME), style = MaterialTheme.typography.bodyMedium)
        }
    }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text(stringResource(R.string.set_clear_title)) },
            text = { Text(stringResource(R.string.set_clear_body)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmClear = false
                    vm.clearCache()
                    Toast.makeText(ctx, clearedMsg, Toast.LENGTH_SHORT).show()
                }) { Text(stringResource(R.string.set_clear_cache)) }
            },
            dismissButton = { TextButton(onClick = { confirmClear = false }) { Text(stringResource(R.string.cancel)) } },
        )
    }
}
