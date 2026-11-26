package com.healthstats.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.local.ThemeMode

/** Is the app dark right now? (user choice, or the system when set to "System") */
fun resolveDark(mode: ThemeMode, systemDark: Boolean): Boolean = when (mode) {
    ThemeMode.System -> systemDark
    ThemeMode.Light -> false
    ThemeMode.Dark -> true
}

@Composable
fun HealthStatsTheme(settings: AppSettings, content: @Composable () -> Unit) {
    val dark = resolveDark(settings.themeMode, isSystemInDarkTheme())
    val context = LocalContext.current
    val base: ColorScheme =
        if (settings.dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        } else seedScheme(settings.accent, dark)

    // OLED: pure black background in dark mode
    val scheme = if (dark && settings.amoled) {
        base.copy(
            background = Color.Black, surface = Color.Black, surfaceDim = Color.Black,
            surfaceContainerLowest = Color.Black,
            surfaceContainerLow = Color(0xFF080808), surfaceContainer = Color(0xFF0D0D0D),
            surfaceContainerHigh = Color(0xFF141414), surfaceContainerHighest = Color(0xFF1C1C1C),
        )
    } else base

    MaterialTheme(colorScheme = scheme, typography = AppTypography, shapes = AppShapes, content = content)
}
