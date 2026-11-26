package com.healthstats.app.ui.navigation

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.IntOffset
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.healthstats.app.ui.screens.home.HomeScreen
import com.healthstats.app.ui.screens.onboarding.OnboardingScreen
import com.healthstats.app.viewmodel.AppViewModel

// Page transition: small slide up + fade, with a soft spring (Material 3 style)
private val slide = spring<IntOffset>(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow, visibilityThreshold = IntOffset.VisibilityThreshold)

@Composable
fun AppNavHost(vm: AppViewModel, startOnboarded: Boolean) {
    val nav = rememberNavController()
    // The start screen is chosen once: later changes of "onboarded" must not restart the navigation
    val start = if (startOnboarded) Routes.Home else Routes.Onboarding

    NavHost(
        navController = nav,
        startDestination = start,
        enterTransition = { slideInVertically(slide) { it / 14 } + fadeIn(tween(260, delayMillis = 60)) },
        exitTransition = { fadeOut(tween(120)) },
        popEnterTransition = { fadeIn(tween(220)) },
        popExitTransition = { slideOutVertically(slide) { it / 14 } + fadeOut(tween(180)) },
    ) {
        composable(Routes.Onboarding) {
            OnboardingScreen(vm) {
                nav.navigate(Routes.Home) { popUpTo(Routes.Onboarding) { inclusive = true } }
            }
        }
        composable(Routes.Home) { HomeScreen(vm) }
    }
}
