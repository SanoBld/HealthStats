package com.healthstats.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.healthstats.app.R

// Google Sans Flex, same font as the old app (files are in res/font)
val GoogleSansFlex = FontFamily(
    Font(R.font.google_sans_flex_light, FontWeight.Light),
    Font(R.font.google_sans_flex_regular, FontWeight.Normal),
    Font(R.font.google_sans_flex_medium, FontWeight.Medium),
    Font(R.font.google_sans_flex_semibold, FontWeight.SemiBold),
    Font(R.font.google_sans_flex_bold, FontWeight.Bold),
)

private val base = Typography()

// Same Material 3 sizes, only the font family changes. Titles are a bit bolder.
val AppTypography = Typography(
    displayLarge = base.displayLarge.copy(fontFamily = GoogleSansFlex),
    displayMedium = base.displayMedium.copy(fontFamily = GoogleSansFlex),
    displaySmall = base.displaySmall.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.SemiBold),
    headlineLarge = base.headlineLarge.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.SemiBold),
    headlineMedium = base.headlineMedium.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.SemiBold),
    headlineSmall = base.headlineSmall.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.SemiBold),
    titleLarge = base.titleLarge.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.SemiBold),
    titleMedium = base.titleMedium.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.Medium),
    titleSmall = base.titleSmall.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.Medium),
    bodyLarge = base.bodyLarge.copy(fontFamily = GoogleSansFlex),
    bodyMedium = base.bodyMedium.copy(fontFamily = GoogleSansFlex),
    bodySmall = base.bodySmall.copy(fontFamily = GoogleSansFlex),
    labelLarge = base.labelLarge.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.Medium),
    labelMedium = base.labelMedium.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.Medium),
    labelSmall = base.labelSmall.copy(fontFamily = GoogleSansFlex, fontWeight = FontWeight.Medium, letterSpacing = 0.5.sp),
)
