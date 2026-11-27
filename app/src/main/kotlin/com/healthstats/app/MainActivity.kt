package com.healthstats.app

import android.graphics.Color as AColor
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.healthstats.app.ui.navigation.AppNavHost
import com.healthstats.app.ui.theme.HealthStatsTheme
import com.healthstats.app.ui.theme.isDarkFor
import com.healthstats.app.viewmodel.AppViewModel

class MainActivity : ComponentActivity() {

    private val vm: AppViewModel by viewModels { AppViewModel.Factory }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)
        // The splash screen only waits for the settings file (a few ms), never for Health Connect
        splash.setKeepOnScreenCondition { vm.settings.value == null }

        setContent {
            val settings by vm.settings.collectAsStateWithLifecycle()
            val s = settings
            if (s != null) {
                HealthStatsTheme(mode = s.theme, dynamic = s.dynamicColor) {
                    val dark = isDarkFor(s.theme)
                    DisposableEffect(dark) {
                        enableEdgeToEdge(
                            statusBarStyle = SystemBarStyle.auto(AColor.TRANSPARENT, AColor.TRANSPARENT) { dark },
                            navigationBarStyle = SystemBarStyle.auto(AColor.TRANSPARENT, AColor.TRANSPARENT) { dark },
                        )
                        onDispose { }
                    }
                    AppNavHost(vm, s)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        vm.onResume()
    }
}
