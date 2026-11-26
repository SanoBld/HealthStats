package com.healthstats.app.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.sin

/** Rounded square that turns into a circle while it spins (same idea as the LastStats loader). */
@Composable
fun M3LoadingIndicator(modifier: Modifier = Modifier, size: Dp = 40.dp, color: Color = MaterialTheme.colorScheme.primary) {
    val t = rememberInfiniteTransition(label = "loader")
    val angle by t.animateFloat(
        0f, 360f, infiniteRepeatable(tween(2400, easing = LinearEasing)), label = "angle",
    )
    val round by t.animateFloat(
        0.18f, 0.5f, infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "round",
    )
    val scale by t.animateFloat(
        0.82f, 1f, infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "scale",
    )
    Canvas(modifier.size(size)) {
        val side = this.size.minDimension * scale
        val topLeft = Offset((this.size.width - side) / 2f, (this.size.height - side) / 2f)
        rotate(angle, pivot = center) {
            drawRoundRect(color, topLeft, Size(side, side), CornerRadius(side * round))
        }
    }
}

/**
 * Wavy progress bar. [progress] 0..1, or null when the end is unknown (a wave sweeps back and forth).
 * The wave keeps moving, so the user can see the app is working.
 */
@Composable
fun WavyProgress(
    progress: Float?,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
    trackColor: Color = MaterialTheme.colorScheme.surfaceContainerHighest,
) {
    val t = rememberInfiniteTransition(label = "wave")
    val phase by t.animateFloat(
        0f, (2 * PI).toFloat(), infiniteRepeatable(tween(1400, easing = LinearEasing)), label = "phase",
    )
    val sweep by t.animateFloat(
        0f, 1f, infiniteRepeatable(tween(1800, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "sweep",
    )
    val shown by animateFloatAsState(progress ?: 0f, tween(400), label = "progress")
    Canvas(modifier.fillMaxWidth().height(16.dp)) {
        val stroke = 4.dp.toPx()
        val amp = 3.dp.toPx()
        val wl = 24.dp.toPx()
        val midY = size.height / 2f
        // track
        drawLine(trackColor, Offset(0f, midY), Offset(size.width, midY), stroke, StrokeCap.Round)
        val (from, to) = if (progress == null) {
            val len = size.width * 0.35f
            val s = (size.width - len) * sweep
            s to s + len
        } else 0f to size.width * shown.coerceIn(0f, 1f)
        if (to - from > 1f) {
            val path = Path()
            var x = from
            path.moveTo(x, midY + amp * sin(phase + x / wl * 2 * PI.toFloat()))
            while (x < to) {
                x += 2f
                path.lineTo(minOf(x, to), midY + amp * sin(phase + minOf(x, to) / wl * 2 * PI.toFloat()))
            }
            drawPath(path, color, style = Stroke(stroke, cap = StrokeCap.Round))
        }
    }
}
