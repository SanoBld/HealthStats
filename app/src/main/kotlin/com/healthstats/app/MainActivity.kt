package com.healthstats.app

import android.content.res.Configuration
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.healthstats.app.ui.navigation.AppNavHost
import com.healthstats.app.ui.theme.HealthStatsTheme
import com.healthstats.app.ui.theme.resolveDark
import com.healthstats.app.viewmodel.AppViewModel
import java.util.Locale

class MainActivity : ComponentActivity() {
    private val vm: AppViewModel by viewModels { AppViewModel.Factory }

    override fun onCreate(savedInstanceState: Bundle?) {
        // The splash screen stays until settings and saved data are loaded (no flash of the wrong screen)
        installSplashScreen().setKeepOnScreenCondition { !vm.ready.value }
        super.onCreate(savedInstanceState)

        setContent {
            val settings by vm.settings.collectAsStateWithLifecycle()
            val s = settings
            if (s != null) {
                val dark = resolveDark(s.themeMode, isSystemInDarkTheme())
                // System bar icons follow the app theme, not only the system theme
                DisposableEffect(dark) {
                    enableEdgeToEdge(
                        statusBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT) { dark },
                        navigationBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT) { dark },
                    )
                    onDispose { }
                }
                // "onboarded" is read once: the start screen must not change while the app runs
                val startOnboarded = remember { s.onboarded }
                LocalizedContent(s.locale) {
                    HealthStatsTheme(s) {
                        TextScale(s.textScale) {
                            Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                                AppNavHost(vm, startOnboarded)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Makes every string use the language chosen in the app (fr / en), whatever the phone language is. */
@Composable
private fun LocalizedContent(lang: String, content: @Composable () -> Unit) {
    val base = LocalContext.current
    val ctx = remember(lang, base) {
        val cfg = Configuration(base.resources.configuration)
        cfg.setLocale(Locale(lang))
        base.createConfigurationContext(cfg)
    }
    CompositionLocalProvider(
        LocalContext provides ctx,
        LocalConfiguration provides ctx.resources.configuration,
        content = content,
    )
}

/** User text size (settings) on top of the system text size. */
@Composable
private fun TextScale(scale: Float, content: @Composable () -> Unit) {
    val d = LocalDensity.current
    CompositionLocalProvider(LocalDensity provides Density(d.density, d.fontScale * scale), content = content)
}
