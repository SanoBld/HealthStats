package com.healthstats.app.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring

// Material 3 motion in one place: easing curves, springs, durations.
object Motion {
    // Easing
    val Emphasized = CubicBezierEasing(0.2f, 0f, 0f, 1f)
    val EmphasizedDecelerate = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
    val EmphasizedAccelerate = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)

    // Durations (ms)
    const val Short = 150
    const val Medium = 300
    const val Long = 450

    // Springs. "Spatial" = position, size, shape (small overshoot).
    // "Effects" = color, opacity (no overshoot).
    fun <T> spatialFast() = spring<T>(dampingRatio = 0.8f, stiffness = 1400f)
    fun <T> spatialDefault() = spring<T>(dampingRatio = 0.8f, stiffness = 380f)
    fun <T> spatialSlow() = spring<T>(dampingRatio = 0.8f, stiffness = 200f)
    fun <T> effectsFast() = spring<T>(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = 3800f)
    fun <T> effectsDefault() = spring<T>(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = 1600f)
}
