package com.healthstats.app.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.healthstats.app.ui.theme.spatialSpring
import kotlin.math.abs

/** Bars with a selectable bar. Tap or drag to select. */
@Composable
fun BarChart(
    values: List<Float>,
    labels: List<String>,
    color: Color,
    selected: Int?,
    onSelect: (Int?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val progress = remember(values) { Animatable(0f) }
    LaunchedEffect(values) { progress.animateTo(1f, spatialSpring()) }
    val track = MaterialTheme.colorScheme.surfaceContainerHighest
    val select by rememberUpdatedState(onSelect)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(
            Modifier
                .fillMaxWidth()
                .height(180.dp)
                .pointerInput(values.size) {
                    detectTapGestures { off ->
                        if (values.isNotEmpty()) select((off.x / size.width * values.size).toInt().coerceIn(0, values.size - 1))
                    }
                }
                .pointerInput(values.size) {
                    detectDragGestures { change, _ ->
                        change.consume()
                        if (values.isNotEmpty()) select((change.position.x / size.width * values.size).toInt().coerceIn(0, values.size - 1))
                    }
                }
        ) {
            if (values.isEmpty()) return@Canvas
            val max = (values.maxOrNull() ?: 0f).coerceAtLeast(0.0001f)
            val slot = size.width / values.size
            val gap = (slot * 0.18f).coerceAtMost(8.dp.toPx())
            val barW = (slot - gap).coerceAtLeast(1f)
            values.forEachIndexed { i, v ->
                val x = i * slot + gap / 2
                drawRoundRect(track, Offset(x, 0f), Size(barW, size.height), CornerRadius(barW / 2.5f))
                val h = (v / max) * size.height * progress.value
                if (h > 0.5f) {
                    val c = if (selected == null || selected == i) color else color.copy(alpha = 0.35f)
                    drawRoundRect(c, Offset(x, size.height - h), Size(barW, h), CornerRadius(barW / 2.5f))
                }
            }
        }
        if (labels.isNotEmpty()) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(labels.first(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(labels.last(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}


/**
 * Line chart. [xs] are positions 0..1 (increasing), [ys] the values.
 * Drag or tap to move the cursor ([cursor] is 0..1). Double tap clears it.
 */
@Composable
fun LineChart(
    xs: List<Float>,
    ys: List<Float>,
    color: Color,
    cursor: Float?,
    onCursor: (Float?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val update by rememberUpdatedState(onCursor)
    Canvas(
        modifier
            .fillMaxWidth()
            .height(150.dp)
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = { off -> update((off.x / size.width).coerceIn(0f, 1f)) },
                    onDoubleTap = { update(null) },
                )
            }
            .pointerInput(Unit) {
                detectDragGestures { change, _ ->
                    change.consume()
                    update((change.position.x / size.width).coerceIn(0f, 1f))
                }
            }
    ) {
        if (xs.size < 2 || xs.size != ys.size) return@Canvas
        val minY = ys.min()
        val maxY = ys.max()
        val range = (maxY - minY).coerceAtLeast(1f)
        val top = range * 0.08f
        fun px(x: Float) = x * size.width
        fun py(y: Float) = size.height - ((y - (minY - top)) / (range + 2 * top)) * size.height

        val line = Path()
        xs.indices.forEach { i -> if (i == 0) line.moveTo(px(xs[i]), py(ys[i])) else line.lineTo(px(xs[i]), py(ys[i])) }
        val fill = Path().apply {
            addPath(line)
            lineTo(px(xs.last()), size.height)
            lineTo(px(xs.first()), size.height)
            close()
        }
        drawPath(fill, Brush.verticalGradient(listOf(color.copy(alpha = 0.30f), Color.Transparent)))
        drawPath(line, color, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))

        if (cursor != null) {
            val x = px(cursor)
            drawLine(color.copy(alpha = 0.6f), Offset(x, 0f), Offset(x, size.height), strokeWidth = 2.dp.toPx())
            val idx = xs.indices.minByOrNull { abs(xs[it] - cursor) } ?: 0
            drawCircle(Color.White, 7.dp.toPx(), Offset(px(xs[idx]), py(ys[idx])))
            drawCircle(color, 5.dp.toPx(), Offset(px(xs[idx]), py(ys[idx])))
        }
    }
}

/** Value of a line chart at the cursor (nearest sample), or null. */
fun valueAt(xs: List<Float>, ys: List<Float>, cursor: Float?): Float? {
    if (cursor == null || xs.isEmpty() || xs.size != ys.size) return null
    val idx = xs.indices.minByOrNull { abs(xs[it] - cursor) } ?: return null
    return ys[idx]
}
