package com.healthstats.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.healthstats.app.R

val AppFont = FontFamily(
    Font(R.font.google_sans_flex_regular, FontWeight.Normal),
    Font(R.font.google_sans_flex_medium, FontWeight.Medium),
    Font(R.font.google_sans_flex_semibold, FontWeight.SemiBold),
    Font(R.font.google_sans_flex_bold, FontWeight.Bold),
)

private val base = Typography()

val AppTypography = Typography(
    displayLarge = base.displayLarge.copy(fontFamily = AppFont, fontWeight = FontWeight.Bold),
    displayMedium = base.displayMedium.copy(fontFamily = AppFont, fontWeight = FontWeight.Bold),
    displaySmall = base.displaySmall.copy(fontFamily = AppFont, fontWeight = FontWeight.Bold),
    headlineLarge = base.headlineLarge.copy(fontFamily = AppFont, fontWeight = FontWeight.SemiBold),
    headlineMedium = base.headlineMedium.copy(fontFamily = AppFont, fontWeight = FontWeight.SemiBold),
    headlineSmall = base.headlineSmall.copy(fontFamily = AppFont, fontWeight = FontWeight.SemiBold),
    titleLarge = base.titleLarge.copy(fontFamily = AppFont, fontWeight = FontWeight.SemiBold),
    titleMedium = base.titleMedium.copy(fontFamily = AppFont, fontWeight = FontWeight.SemiBold),
    titleSmall = base.titleSmall.copy(fontFamily = AppFont, fontWeight = FontWeight.Medium),
    bodyLarge = base.bodyLarge.copy(fontFamily = AppFont),
    bodyMedium = base.bodyMedium.copy(fontFamily = AppFont),
    bodySmall = base.bodySmall.copy(fontFamily = AppFont),
    labelLarge = base.labelLarge.copy(fontFamily = AppFont, fontWeight = FontWeight.Medium),
    labelMedium = base.labelMedium.copy(fontFamily = AppFont, fontWeight = FontWeight.Medium),
    labelSmall = base.labelSmall.copy(fontFamily = AppFont, fontWeight = FontWeight.Medium),
)
