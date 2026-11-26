@file:OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)

package com.healthstats.app.ui.screens.onboarding

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseOutCubic
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.Cake
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.Height
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MonitorWeight
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthPermissions
import com.healthstats.app.data.local.SettingsStore.Keys
import com.healthstats.app.data.local.ThemeMode
import com.healthstats.app.data.model.HcStatus
import com.healthstats.app.ui.components.AppTextField
import com.healthstats.app.ui.components.M3Chip
import com.healthstats.app.ui.components.M3LoadingIndicator
import com.healthstats.app.ui.components.rememberHaptics
import com.healthstats.app.ui.theme.AccentChoices
import com.healthstats.app.util.openHealthConnectSettings
import com.healthstats.app.util.openHealthConnectStore
import com.healthstats.app.viewmodel.AppViewModel
import com.healthstats.app.viewmodel.OnboardingData
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

private const val STEPS = 6

@Composable
fun OnboardingScreen(vm: AppViewModel, onDone: () -> Unit) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    val health by vm.health.collectAsStateWithLifecycle()
    val s = settings ?: return
    val ctx = LocalContext.current
    val haptic = rememberHaptics(s.haptics)

    var step by rememberSaveable { mutableStateOf(0) }
    var name by rememberSaveable { mutableStateOf(s.name) }
    var height by rememberSaveable { mutableStateOf("") }
    var weight by rememberSaveable { mutableStateOf("") }
    var birth by rememberSaveable { mutableStateOf("") } // yyyy-MM-dd
    var sex by rememberSaveable { mutableStateOf("") }
    var stepGoal by rememberSaveable { mutableStateOf(s.stepGoal) }
    var weekly by rememberSaveable { mutableStateOf(s.weeklyGoal) }
    var busy by remember { mutableStateOf(false) }
    var denied by remember { mutableStateOf(false) }
    var showDate by remember { mutableStateOf(false) }

    fun num(t: String) = t.replace(',', '.').toFloatOrNull() ?: 0f
    fun finish() {
        vm.finishOnboarding(OnboardingData(name.trim(), num(height), num(weight), birth, sex, stepGoal, weekly))
        onDone()
    }

    // The permission dialog is only shown on the last step, when the user taps the button
    val launcher = rememberLauncherForActivityResult(HealthPermissions.requestContract()) { granted ->
        busy = false
        vm.onPermissionsResult(granted)
        if (granted.isNotEmpty()) finish() else denied = true
    }

    val canNext = step != 1 || name.isNotBlank()
    val progress by animateFloatAsState((step + 1) / STEPS.toFloat(), tween(350, easing = EaseOutCubic), label = "progress")

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(Modifier.safeDrawingPadding()) {
            Row(Modifier.padding(start = 12.dp, end = 20.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                val backAlpha by animateFloatAsState(if (step > 0) 1f else 0f, tween(200), label = "back")
                IconButton(
                    onClick = { haptic(); step = (step - 1).coerceAtLeast(0) },
                    enabled = step > 0,
                    modifier = Modifier.scale(backAlpha),
                ) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.back)) }
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(6.dp)),
                    trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    drawStopIndicator = {},
                )
            }

            AnimatedContent(
                targetState = step,
                modifier = Modifier.weight(1f),
                transitionSpec = {
                    val fwd = targetState > initialState
                    val dir = if (fwd) 1 else -1
                    (slideInHorizontally(tween(320, easing = EaseOutCubic)) { dir * it / 12 } + fadeIn(tween(320))) togetherWith
                        (slideOutHorizontally(tween(200)) { -dir * it / 12 } + fadeOut(tween(160)))
                },
                label = "step",
            ) { st ->
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp)) {
                    when (st) {
                        0 -> WelcomePage()
                        1 -> {
                            Title(R.string.onb_name_title, R.string.onb_name_sub)
                            AppTextField(name, { name = it }, stringResource(R.string.onb_name_label), Icons.Rounded.Person, Modifier.fillMaxWidth())
                        }
                        2 -> {
                            Title(R.string.onb_about_title, R.string.onb_about_sub)
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                AppTextField(height, { height = it }, stringResource(R.string.onb_height), Icons.Rounded.Height, Modifier.weight(1f), number = true)
                                AppTextField(weight, { weight = it }, stringResource(R.string.onb_weight), Icons.Rounded.MonitorWeight, Modifier.weight(1f), number = true)
                            }
                            Spacer(Modifier.height(16.dp))
                            val birthText = birth.takeIf { it.isNotEmpty() }
                                ?.let { LocalDate.parse(it).format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)) } ?: ""
                            Box {
                                OutlinedTextField(
                                    value = birthText, onValueChange = {}, readOnly = true, singleLine = true,
                                    label = { Text(stringResource(R.string.onb_birth)) },
                                    leadingIcon = { Icon(Icons.Rounded.Cake, null) },
                                    shape = MaterialTheme.shapes.medium,
                                    modifier = Modifier.fillMaxWidth(),
                                )
                                // invisible layer on top: the whole field opens the date picker
                                Box(Modifier.matchParentSize().clickable { showDate = true })
                            }
                            Spacer(Modifier.height(20.dp))
                            Text(stringResource(R.string.onb_sex), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.height(8.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                for ((k, r) in listOf("m" to R.string.sex_m, "f" to R.string.sex_f, "x" to R.string.sex_x))
                                    M3Chip(stringResource(r), sex == k) { haptic(); sex = if (sex == k) "" else k }
                            }
                        }
                        3 -> {
                            Title(R.string.onb_goals_title, R.string.onb_goals_sub)
                            Label(R.string.onb_steps_day)
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                for (v in listOf(5000, 7500, 10000, 12500, 15000)) M3Chip("$v", stepGoal == v) { haptic(); stepGoal = v }
                            }
                            Spacer(Modifier.height(24.dp))
                            Label(R.string.onb_workouts_week)
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                for (v in 1..7) M3Chip("$v", weekly == v) { haptic(); weekly = v }
                            }
                        }
                        4 -> {
                            Title(R.string.onb_style_title, R.string.onb_style_sub)
                            val modes = listOf(ThemeMode.System to R.string.theme_system, ThemeMode.Light to R.string.theme_light, ThemeMode.Dark to R.string.theme_dark)
                            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                                modes.forEachIndexed { i, (m, r) ->
                                    SegmentedButton(
                                        selected = s.themeMode == m,
                                        onClick = { haptic(); vm.setThemeMode(m) },
                                        shape = SegmentedButtonDefaults.itemShape(i, modes.size),
                                    ) { Text(stringResource(r)) }
                                }
                            }
                            Spacer(Modifier.height(12.dp))
                            SwitchRow(stringResource(R.string.onb_dynamic), s.dynamicColor) { haptic(); vm.set(Keys.DYNAMIC, it) }
                            if (!s.dynamicColor) {
                                Spacer(Modifier.height(8.dp))
                                FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                    for (c in AccentChoices) {
                                        val on = s.accent == c
                                        Box(
                                            Modifier.size(44.dp).clip(CircleShape).background(Color(c))
                                                .clickable { haptic(); vm.set(Keys.ACCENT, c) },
                                            contentAlignment = Alignment.Center,
                                        ) { if (on) Icon(Icons.Rounded.Check, null, tint = Color.White) }
                                    }
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                            SwitchRow(stringResource(R.string.onb_advice), s.showAdvice) { haptic(); vm.set(Keys.ADVICE, it) }
                        }
                        else -> {
                            Title(R.string.hc_title, R.string.onb_hc_sub)
                            if (health.status == HcStatus.UpdateRequired) {
                                Text(stringResource(R.string.hc_update), color = MaterialTheme.colorScheme.error)
                                TextButton(onClick = { ctx.openHealthConnectStore() }) { Text(stringResource(R.string.hc_open_store)) }
                            }
                            if (health.status == HcStatus.Unavailable) {
                                Text(stringResource(R.string.hc_unavailable), color = MaterialTheme.colorScheme.error)
                            }
                            if (denied) {
                                Text(stringResource(R.string.hc_denied), color = MaterialTheme.colorScheme.error)
                                TextButton(onClick = { ctx.openHealthConnectSettings() }) { Text(stringResource(R.string.hc_open_settings)) }
                            }
                            Spacer(Modifier.height(12.dp))
                            Button(
                                onClick = {
                                    haptic(); busy = true; denied = false
                                    vm.checkHealthConnect(
                                        onUnavailable = { busy = false },
                                        whenAvailable = { launcher.launch(HealthPermissions.ALL) },
                                    )
                                },
                                enabled = !busy,
                                modifier = Modifier.fillMaxWidth().height(56.dp),
                            ) {
                                if (busy) M3LoadingIndicator(size = 22.dp, color = MaterialTheme.colorScheme.onPrimary)
                                else Icon(Icons.Rounded.Favorite, null)
                                Spacer(Modifier.width(10.dp))
                                Text(stringResource(R.string.hc_allow))
                            }
                            TextButton(onClick = { finish() }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                                Text(stringResource(R.string.hc_later))
                            }
                        }
                    }
                }
            }

            if (step < STEPS - 1) {
                Button(
                    onClick = { haptic(); step += 1 },
                    enabled = canNext,
                    modifier = Modifier.padding(start = 24.dp, end = 24.dp, bottom = 20.dp).fillMaxWidth().height(56.dp),
                ) { Text(stringResource(if (step == 0) R.string.onb_start else R.string.onb_continue)) }
            }
        }
    }

    if (showDate) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = birth.takeIf { it.isNotEmpty() }
                ?.let { LocalDate.parse(it).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() },
        )
        DatePickerDialog(
            onDismissRequest = { showDate = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { birth = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString() }
                    showDate = false
                }) { Text(stringResource(R.string.common_ok)) }
            },
            dismissButton = { TextButton(onClick = { showDate = false }) { Text(stringResource(R.string.common_cancel)) } },
        ) { DatePicker(state = state) }
    }
}

@Composable
private fun Title(big: Int, sub: Int) {
    Text(stringResource(big), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black)
    Spacer(Modifier.height(8.dp))
    Text(stringResource(sub), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Spacer(Modifier.height(28.dp))
}

@Composable
private fun Label(res: Int) {
    Text(stringResource(res), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun SwitchRow(text: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(text, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Switch(checked, onChange)
    }
}

@Composable
private fun WelcomePage() {
    // The logo pops in with a bouncy spring
    val scale = remember { Animatable(0.6f) }
    LaunchedEffect(Unit) { scale.animateTo(1f, spring(dampingRatio = 0.4f, stiffness = 180f)) }
    Spacer(Modifier.height(40.dp))
    Box(
        Modifier.size(104.dp).scale(scale.value).clip(RoundedCornerShape(34.dp)).background(MaterialTheme.colorScheme.primaryContainer),
        contentAlignment = Alignment.Center,
    ) { Icon(Icons.Rounded.Favorite, null, Modifier.size(54.dp), tint = MaterialTheme.colorScheme.primary) }
    Spacer(Modifier.height(32.dp))
    Text("HealthStats", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Black, color = MaterialTheme.colorScheme.primary)
    Spacer(Modifier.height(10.dp))
    Text(stringResource(R.string.onb_tagline), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Spacer(Modifier.height(28.dp))
    for ((icon, text) in listOf(
        Icons.Rounded.FitnessCenter to R.string.onb_f1,
        Icons.Rounded.Bedtime to R.string.onb_f2,
        Icons.Rounded.Lock to R.string.onb_f3,
    )) {
        Row(Modifier.padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(40.dp).clip(CircleShape).background(MaterialTheme.colorScheme.secondaryContainer),
                contentAlignment = Alignment.Center,
            ) { Icon(icon, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSecondaryContainer) }
            Spacer(Modifier.width(14.dp))
            Text(stringResource(text), style = MaterialTheme.typography.bodyLarge)
        }
    }
}
