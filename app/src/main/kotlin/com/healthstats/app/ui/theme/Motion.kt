package com.healthstats.app.ui.theme

import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.spring

/** Springs for movement (bouncy) and for color/alpha (no bounce). */
fun <T> spatialSpring(): FiniteAnimationSpec<T> = spring(dampingRatio = 0.78f, stiffness = 420f)
fun <T> effectsSpring(): FiniteAnimationSpec<T> = spring(dampingRatio = 1f, stiffness = 1400f)

const val NavMillis = 340
