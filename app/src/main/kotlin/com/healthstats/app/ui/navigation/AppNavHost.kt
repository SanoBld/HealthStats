package com.healthstats.app.ui.navigation

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.healthstats.app.ui.theme.effectsSpring
import com.healthstats.app.ui.theme.spatialSpring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.DirectionsRun
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthPermissions
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.model.HcStatus
import com.healthstats.app.ui.screens.activities.ActivitiesScreen
import com.healthstats.app.ui.screens.charts.ChartsScreen
import com.healthstats.app.ui.screens.detail.WorkoutDetailScreen
import com.healthstats.app.ui.screens.home.HomeScreen
import com.healthstats.app.ui.screens.onboarding.OnboardingScreen
import com.healthstats.app.ui.screens.settings.SettingsScreen
import com.healthstats.app.ui.screens.sport.SportScreen
import com.healthstats.app.ui.components.isWide
import com.healthstats.app.ui.theme.NavMillis
import com.healthstats.app.util.openHealthConnect
import com.healthstats.app.util.openHealthConnectStore
import com.healthstats.app.viewmodel.AppViewModel

private class Tab(val route: String, val label: Int, val icon: ImageVector)

private val Tabs = listOf(
    Tab(Routes.Home, R.string.nav_home, Icons.Rounded.Home),
    Tab(Routes.Activities, R.string.nav_activities, Icons.Rounded.DirectionsRun),
    Tab(Routes.Charts, R.string.nav_charts, Icons.Rounded.BarChart),
    Tab(Routes.Settings, R.string.nav_settings, Icons.Rounded.Settings),
)

private enum class HcDialog { Denied, Update, Unavailable }

@Composable
fun AppNavHost(vm: AppViewModel, settings: AppSettings) {
    val nav = rememberNavController()
    val health by vm.health.collectAsStateWithLifecycle()
    val ctx = LocalContext.current
    var hcDialog by remember { mutableStateOf<HcDialog?>(null) }

    // One permission launcher for the whole app
    val launcher = rememberLauncherForActivityResult(HealthPermissions.contract()) { granted ->
        vm.onPermissions(granted)
        if (HealthPermissions.EXERCISE !in granted) hcDialog = HcDialog.Denied
    }
    val connect: () -> Unit = {
        vm.checkHealthConnect { status ->
            when (status) {
                HcStatus.Available -> launcher.launch(HealthPermissions.ALL)
                HcStatus.UpdateRequired -> hcDialog = HcDialog.Update
                HcStatus.Unavailable -> hcDialog = HcDialog.Unavailable
            }
        }
    }

    val start = remember { if (settings.onboarded) Routes.Home else Routes.Onboarding }
    val entry by nav.currentBackStackEntryAsState()
    val route = entry?.destination?.route
    val showBar = Tabs.any { it.route == route }
    val wide = isWide()

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            if (!wide) AnimatedVisibility(
                visible = showBar,
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
            ) {
                FloatingNavBar(route) { r ->
                    nav.navigate(r) {
                        popUpTo(Routes.Home) { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                }
            }
        },
    ) { inner ->
        Row {
        // Tablets and unfolded phones: side rail instead of the bottom bar
        if (wide && showBar) {
            NavigationRail {
                Tabs.forEach { tab ->
                    NavigationRailItem(
                        selected = route == tab.route,
                        onClick = {
                            nav.navigate(tab.route) {
                                popUpTo(Routes.Home) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, null) },
                        label = { Text(stringResource(tab.label)) },
                    )
                }
            }
        }
        NavHost(
            navController = nav,
            startDestination = start,
            modifier = Modifier.weight(1f).padding(bottom = inner.calculateBottomPadding()),
            enterTransition = {
                if (targetState.destination.route.let { it == Routes.Detail || it == Routes.Sport }) {
                    slideInHorizontally(tween(NavMillis)) { it / 5 } + fadeIn(tween(NavMillis)) + scaleIn(tween(NavMillis), 0.94f)
                } else {
                    fadeIn(tween(NavMillis, delayMillis = 60)) + scaleIn(tween(NavMillis, delayMillis = 60), 0.92f)
                }
            },
            exitTransition = {
                if (targetState.destination.route.let { it == Routes.Detail || it == Routes.Sport }) {
                    fadeOut(tween(NavMillis / 2)) + scaleOut(tween(NavMillis), 0.96f)
                } else {
                    fadeOut(tween(NavMillis / 2))
                }
            },
            popEnterTransition = { fadeIn(tween(NavMillis)) + scaleIn(tween(NavMillis), 0.96f) },
            popExitTransition = {
                if (initialState.destination.route.let { it == Routes.Detail || it == Routes.Sport }) {
                    slideOutHorizontally(tween(NavMillis)) { it / 5 } + fadeOut(tween(NavMillis / 2)) + scaleOut(tween(NavMillis), 0.94f)
                } else {
                    fadeOut(tween(NavMillis / 2))
                }
            },
        ) {
            composable(Routes.Onboarding) {
                OnboardingScreen(
                    permitted = health.permitted,
                    onConnect = connect,
                    onFinish = { name, height, birth ->
                        vm.finishOnboarding(name, height, birth)
                        nav.navigate(Routes.Home) { popUpTo(Routes.Onboarding) { inclusive = true } }
                    },
                )
            }
            composable(Routes.Home) {
                HomeScreen(
                    settings = settings,
                    health = health,
                    onSync = { vm.sync() },
                    onConnect = connect,
                    onOpenWorkout = { nav.navigate(Routes.detail(it)) },
                    onOpenActivities = {
                        nav.navigate(Routes.Activities) {
                            popUpTo(Routes.Home) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
            composable(Routes.Activities) {
                ActivitiesScreen(settings, health, { nav.navigate(Routes.detail(it)) }, { nav.navigate(Routes.sport(it)) }, { vm.sync() })
            }
            composable(Routes.Charts) { ChartsScreen(health, settings.sportColors, { nav.navigate(Routes.detail(it)) }, { nav.navigate(Routes.sport(it)) }, { vm.sync() }) }
            composable(Routes.Settings) { SettingsScreen(settings, health, vm, connect) }
            composable(
                Routes.Sport,
                arguments = listOf(navArgument("type") { type = NavType.IntType }),
            ) { e ->
                SportScreen(
                    type = e.arguments?.getInt("type") ?: 0,
                    settings = settings,
                    health = health,
                    onBack = { nav.popBackStack() },
                    onOpenWorkout = { nav.navigate(Routes.detail(it)) },
                )
            }
            composable(
                Routes.Detail,
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { e ->
                val id = e.arguments?.getString("id")
                if (id != null) WorkoutDetailScreen(id, settings) { nav.popBackStack() }
            }
        }
        }
    }

    hcDialog?.let { d ->
        AlertDialog(
            onDismissRequest = { hcDialog = null },
            text = {
                Text(
                    stringResource(
                        when (d) {
                            HcDialog.Denied -> R.string.hc_denied
                            HcDialog.Update -> R.string.hc_update
                            HcDialog.Unavailable -> R.string.hc_unavailable
                        }
                    )
                )
            },
            confirmButton = {
                when (d) {
                    HcDialog.Denied -> TextButton(onClick = { hcDialog = null; openHealthConnect(ctx) }) { Text(stringResource(R.string.hc_open_settings)) }
                    HcDialog.Update -> TextButton(onClick = { hcDialog = null; openHealthConnectStore(ctx) }) { Text(stringResource(R.string.hc_open_store)) }
                    HcDialog.Unavailable -> TextButton(onClick = { hcDialog = null }) { Text(stringResource(R.string.ok)) }
                }
            },
            dismissButton = {
                if (d != HcDialog.Unavailable) TextButton(onClick = { hcDialog = null }) { Text(stringResource(R.string.close)) }
            },
        )
    }
}

/** Floating pill navigation bar: the selected tab opens into a pill with its name (Material 3 Expressive). */
@Composable
private fun FloatingNavBar(route: String?, onSelect: (String) -> Unit) {
    Box(
        Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
            tonalElevation = 3.dp,
            shadowElevation = 6.dp,
        ) {
            Row(Modifier.padding(6.dp), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                Tabs.forEach { tab ->
                    val on = route == tab.route
                    val bg by animateColorAsState(
                        if (on) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
                        animationSpec = effectsSpring(), label = "navBg",
                    )
                    val fg = if (on) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
                    Row(
                        Modifier
                            .animateContentSize(spatialSpring())
                            .clip(CircleShape)
                            .background(bg)
                            .clickable { onSelect(tab.route) }
                            .padding(horizontal = 18.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(tab.icon, stringResource(tab.label), tint = fg)
                        if (on) {
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(tab.label), style = MaterialTheme.typography.labelLarge, color = fg, maxLines = 1)
                        }
                    }
                }
            }
        }
    }
}
