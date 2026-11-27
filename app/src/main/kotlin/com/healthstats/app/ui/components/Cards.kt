package com.healthstats.app.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Shape
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.healthstats.app.data.model.Workout
import com.healthstats.app.data.model.sourceLabel
import com.healthstats.app.ui.theme.spatialSpring
import com.healthstats.app.util.fmtDate
import com.healthstats.app.util.fmtDistance
import com.healthstats.app.util.fmtDuration
import com.healthstats.app.util.fmtInt
import com.healthstats.app.util.fmtTime

@Composable
fun WorkoutRow(
    w: Workout,
    colored: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    shape: Shape = MaterialTheme.shapes.medium,
) {
    val sport = w.sport
    Card(
        modifier.fillMaxWidth().springClick(shape, onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = shape,
    ) {
        Row(
            Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            SportBadge(sport, colored)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    w.title.ifEmpty { sport.name },
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    fmtDate(w.start) + " · " + fmtTime(w.start) + " · " + sourceLabel(w.source),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                if (w.distanceM > 0) {
                    Text(fmtDistance(w.distanceM), style = MaterialTheme.typography.titleSmall)
                    Text(fmtDuration(w.durationSec), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Text(fmtDuration(w.durationSec), style = MaterialTheme.typography.titleSmall)
                }
                if (w.hasRoute) {
                    Icon(Icons.Rounded.Map, null, Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

/** Ring that fills with the steps of the day. */
@Composable
fun StepsRing(steps: Int, goal: Int, modifier: Modifier = Modifier) {
    val target = if (goal > 0) (steps.toFloat() / goal).coerceIn(0f, 1f) else 0f
    val progress = remember { Animatable(0f) }
    LaunchedEffect(target) { progress.animateTo(target, spatialSpring()) }
    val shownSteps by animateIntAsState(steps, animationSpec = tween(900), label = "steps")
    val track = MaterialTheme.colorScheme.surfaceContainerHighest
    val color = MaterialTheme.colorScheme.primary
    Box(modifier.size(150.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(150.dp)) {
            val stroke = 16.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(track, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
            if (progress.value > 0.001f) {
                drawArc(color, -90f, 360f * progress.value, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(fmtInt(shownSteps), style = MaterialTheme.typography.headlineMedium)
            Text(
                "${(target * 100).toInt()} %",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
fun MetricTile(label: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = MaterialTheme.shapes.medium,
    ) {
        Column(Modifier.padding(14.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
            Text(value, style = MaterialTheme.typography.titleMedium)
        }
    }
}

/** Card for one sport: big cookie icon, name, count and total time. Tap to filter. */
@Composable
fun SportSummaryCard(
    sport: com.healthstats.app.data.model.SportInfo,
    colored: Boolean,
    count: Int,
    totalSec: Long,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = MaterialTheme.shapes.large
    val container = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceContainer
    Card(
        modifier.springClick(shape, onClick),
        colors = CardDefaults.cardColors(containerColor = container),
        shape = shape,
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SportBadge(sport, colored, size = 52.dp)
            Column {
                Text(sport.name, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(
                    "$count · " + fmtDuration(totalSec),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
