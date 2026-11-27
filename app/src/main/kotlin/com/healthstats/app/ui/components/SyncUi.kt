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
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthstats.app.R
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.ui.theme.CookieShape
import com.healthstats.app.ui.theme.spatialSpring

/**
 * The app's only loading logo: a cookie shape that spins and breathes, with a progress ring
 * and the percentage inside. Same look at every size.
 */
@Composable
fun CookieLoader(progress: Float?, modifier: Modifier = Modifier, size: Dp = 96.dp) {
    val t = rememberInfiniteTransition(label = "cookie")
    val rot by t.animateFloat(
        initialValue = 0f, targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(7000, easing = LinearEasing)),
        label = "rotation",
    )
    val depth by t.animateFloat(
        initialValue = 0.03f, targetValue = 0.14f,
        animationSpec = infiniteRepeatable(tween(1200, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "depth",
    )
    val shown by animateFloatAsState(progress ?: 0f, animationSpec = spatialSpring(), label = "progress")
    val ring = MaterialTheme.colorScheme.primary
    val track = MaterialTheme.colorScheme.surfaceContainerHighest
    val pct = (shown.coerceIn(0f, 1f) * 100).toInt()
    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        if (progress != null) {
            Canvas(Modifier.matchParentSize()) {
                val w = (size.value / 14f).coerceIn(2.5f, 8f).dp.toPx()
                val arc = Size(this.size.width - w, this.size.height - w)
                drawArc(track, 0f, 360f, false, Offset(w / 2, w / 2), arc, style = Stroke(w))
                drawArc(ring, -90f, 360f * shown.coerceIn(0f, 1f), false, Offset(w / 2, w / 2), arc, style = Stroke(w, cap = StrokeCap.Round))
            }
        }
        Box(
            Modifier.size(size * 0.76f)
                .graphicsLayer { rotationZ = rot }
                .clip(CookieShape(lobes = 9, depth = depth))
                .background(MaterialTheme.colorScheme.primaryContainer)
        )
        if (progress != null) {
            Text(
                if (size >= 80.dp) "$pct %" else "$pct",
                style = if (size >= 80.dp) MaterialTheme.typography.headlineSmall else MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }
    }
}

/** Loader that fills the page, used only when the page has nothing to show yet. */
@Composable
fun FullLoader(progress: Float?, text: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
            CookieLoader(progress, size = 140.dp)
            Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** Top bar action: small loader while syncing, refresh button otherwise. Hidden when the page shows [FullLoader]. */
@Composable
fun RowScope.SyncAction(health: HealthState, hidden: Boolean, onSync: () -> Unit) {
    if (hidden) return
    if (health.syncing) {
        CookieLoader(health.progress, size = 44.dp, modifier = Modifier.padding(end = 8.dp))
    } else if (health.permitted) {
        IconButton(onClick = onSync) { Icon(Icons.Rounded.Refresh, stringResource(R.string.sync_now)) }
    }
}

/** What the sync is doing right now. */
@Composable
fun syncText(h: HealthState): String = when (h.loadingStage) {
    1 -> stringResource(R.string.sync_reading)
    2 -> stringResource(R.string.sync_daily)
    3 -> stringResource(R.string.sync_body)
    4 -> stringResource(R.string.sync_stats, h.statsDone, h.statsTotal)
    else -> ""
}
