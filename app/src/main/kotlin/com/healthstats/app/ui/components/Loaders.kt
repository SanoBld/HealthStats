package com.healthstats.app.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.animateFloat
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.sin

/** A rounded square that turns into a circle while it spins. */
@Composable
fun MorphLoader(modifier: Modifier = Modifier, size: Dp = 48.dp, color: Color = MaterialTheme.colorScheme.primary) {
    val t = rememberInfiniteTransition(label = "morph")
    val p by t.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "corner",
    )
    val rot by t.animateFloat(
        initialValue = 0f, targetValue = 180f,
        animationSpec = infiniteRepeatable(tween(1800, easing = LinearEasing)),
        label = "rotation",
    )
    val percent = (18 + 32 * p).toInt()
    Box(
        modifier
            .size(size)
            .graphicsLayer { rotationZ = rot }
            .clip(RoundedCornerShape(percent = percent))
            .background(color)
    )
}

/** A moving wave line, used as a thin progress bar. */
@Composable
fun WaveLoader(
    modifier: Modifier = Modifier.fillMaxWidth().height(20.dp),
    color: Color = MaterialTheme.colorScheme.primary,
) {
    val t = rememberInfiniteTransition(label = "wave")
    val phase by t.animateFloat(
        initialValue = 0f, targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(1400, easing = LinearEasing)),
        label = "phase",
    )
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val amp = h * 0.3f
        val path = Path()
        path.moveTo(0f, h / 2)
        var x = 0f
        while (x <= w) {
            path.lineTo(x, h / 2 + amp * sin(x / w * 8f * PI.toFloat() + phase))
            x += 4f
        }
        drawPath(path, color, style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round))
    }
}

/** Centered loader with an optional text under it. */
@Composable
fun LoadingBlock(text: String?, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        MorphLoader()
        if (text != null) {
            Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** Grey pulsing box shown where content is coming. */
@Composable
fun SkeletonBox(modifier: Modifier = Modifier) {
    val t = rememberInfiniteTransition(label = "skeleton")
    val a by t.animateFloat(
        initialValue = 0.35f, targetValue = 0.9f,
        animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse),
        label = "alpha",
    )
    Box(
        modifier.background(
            MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = a),
            MaterialTheme.shapes.medium,
        )
    )
}
