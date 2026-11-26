package com.healthstats.app.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb

/**
 * Simple color scheme built from one accent color (used when Material You is off or not available).
 * Same hue everywhere: accents are colorful, surfaces are lightly tinted.
 */
fun seedScheme(seed: Int, dark: Boolean): ColorScheme {
    val hsv = FloatArray(3)
    android.graphics.Color.colorToHSV(seed, hsv)
    val h = hsv[0]
    val gray = hsv[1] < 0.03f          // gray seed = pure gray theme
    val sat = if (gray) 0f else hsv[1].coerceIn(0.35f, 0.9f)
    fun c(hue: Float, s: Float, l: Float) = Color.hsl(hue, if (gray) 0f else s.coerceIn(0f, 1f), l)
    val tint = 0.10f
    return if (dark) darkColorScheme(
        primary = c(h, sat, 0.78f), onPrimary = c(h, sat, 0.15f),
        primaryContainer = c(h, sat, 0.28f), onPrimaryContainer = c(h, sat, 0.90f),
        secondary = c(h, sat * 0.35f, 0.76f), onSecondary = c(h, sat * 0.35f, 0.18f),
        secondaryContainer = c(h, sat * 0.35f, 0.27f), onSecondaryContainer = c(h, sat * 0.35f, 0.90f),
        tertiary = c(h + 60f, 0.45f, 0.78f), onTertiary = c(h + 60f, 0.45f, 0.17f),
        tertiaryContainer = c(h + 60f, 0.35f, 0.28f), onTertiaryContainer = c(h + 60f, 0.45f, 0.90f),
        background = c(h, tint, 0.07f), onBackground = c(h, tint, 0.90f),
        surface = c(h, tint, 0.07f), onSurface = c(h, tint, 0.90f),
        surfaceVariant = c(h, tint, 0.25f), onSurfaceVariant = c(h, tint, 0.76f),
        surfaceDim = c(h, tint, 0.06f), surfaceBright = c(h, tint, 0.24f),
        surfaceContainerLowest = c(h, tint, 0.04f), surfaceContainerLow = c(h, tint, 0.10f),
        surfaceContainer = c(h, tint, 0.12f), surfaceContainerHigh = c(h, tint, 0.16f),
        surfaceContainerHighest = c(h, tint, 0.20f),
        outline = c(h, tint, 0.55f), outlineVariant = c(h, tint, 0.30f),
        error = Color(0xFFFFB4AB), onError = Color(0xFF690005),
    ) else lightColorScheme(
        primary = c(h, sat, 0.42f), onPrimary = Color.White,
        primaryContainer = c(h, sat, 0.88f), onPrimaryContainer = c(h, sat, 0.12f),
        secondary = c(h, sat * 0.35f, 0.40f), onSecondary = Color.White,
        secondaryContainer = c(h, sat * 0.35f, 0.88f), onSecondaryContainer = c(h, sat * 0.35f, 0.12f),
        tertiary = c(h + 60f, 0.40f, 0.40f), onTertiary = Color.White,
        tertiaryContainer = c(h + 60f, 0.45f, 0.88f), onTertiaryContainer = c(h + 60f, 0.45f, 0.12f),
        background = c(h, tint, 0.98f), onBackground = c(h, tint, 0.10f),
        surface = c(h, tint, 0.98f), onSurface = c(h, tint, 0.10f),
        surfaceVariant = c(h, tint, 0.90f), onSurfaceVariant = c(h, tint, 0.30f),
        surfaceDim = c(h, tint, 0.86f), surfaceBright = c(h, tint, 0.98f),
        surfaceContainerLowest = Color.White, surfaceContainerLow = c(h, tint, 0.96f),
        surfaceContainer = c(h, tint, 0.94f), surfaceContainerHigh = c(h, tint, 0.92f),
        surfaceContainerHighest = c(h, tint, 0.90f),
        outline = c(h, tint, 0.45f), outlineVariant = c(h, tint, 0.80f),
        error = Color(0xFFBA1A1A), onError = Color.White,
    )
}

/** Accent colors offered in onboarding and settings. */
val AccentChoices: List<Int> = listOf(
    0xFFFF2020, 0xFFFF6D00, 0xFFFFB300, 0xFF2E9E5B, 0xFF00A6A6,
    0xFF1E6CF0, 0xFF7C4DFF, 0xFFE91E8C, 0xFF607D8B,
).map { it.toInt() }

@Suppress("unused")
private fun Color.argb() = toArgb()
