package com.healthstats.app.ui.components

import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material3.Icon

/** Small vibration on taps. Respects the "haptic feedback" setting. */
@Composable
fun rememberHaptics(enabled: Boolean): () -> Unit {
    val view = LocalView.current
    return remember(view, enabled) {
        { if (enabled) view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK) }
    }
}

/** Shrinks a little while pressed, then springs back. */
fun Modifier.pressScale(source: MutableInteractionSource, pressed: Float = 0.96f): Modifier = composed2(source, pressed)

@Composable
private fun pressValue(source: MutableInteractionSource, pressed: Float): Float {
    val down by source.collectIsPressedAsState()
    val v by animateFloatAsState(
        targetValue = if (down) pressed else 1f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMedium),
        label = "press",
    )
    return v
}

private fun Modifier.composed2(source: MutableInteractionSource, pressed: Float): Modifier =
    androidx.compose.ui.composed {
        val s = pressValue(source, pressed)
        graphicsLayer { scaleX = s; scaleY = s }
    }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun M3Chip(label: String, selected: Boolean, onClick: () -> Unit) {
    FilterChip(selected = selected, onClick = onClick, label = { Text(label) })
}

/** Rounded text field used in forms. */
@Composable
fun AppTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    number: Boolean = false,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        leadingIcon = { Icon(icon, contentDescription = null) },
        singleLine = true,
        shape = MaterialTheme.shapes.medium,
        keyboardOptions = KeyboardOptions(
            keyboardType = if (number) KeyboardType.Decimal else KeyboardType.Text,
            capitalization = if (number) KeyboardCapitalization.None else KeyboardCapitalization.Words,
        ),
        modifier = modifier,
    )
}
