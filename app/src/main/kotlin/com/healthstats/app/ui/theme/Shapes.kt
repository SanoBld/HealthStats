package com.healthstats.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Very round shapes, same family everywhere (Material 3 Expressive look). */
val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(12.dp),
    small = RoundedCornerShape(18.dp),
    medium = RoundedCornerShape(26.dp),
    large = RoundedCornerShape(34.dp),
    extraLarge = RoundedCornerShape(44.dp),
)

/** A circle with soft bumps, like the "cookie" shapes of Material 3 Expressive. */
class CookieShape(private val lobes: Int = 8, private val depth: Float = 0.07f) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val cx = size.width / 2
        val cy = size.height / 2
        val r = minOf(cx, cy)
        val path = Path()
        val steps = 120
        for (i in 0..steps) {
            val a = i.toFloat() / steps * 2f * PI.toFloat()
            val rr = r * (1f - depth + depth * cos(lobes * a))
            val x = cx + rr * cos(a)
            val y = cy + rr * sin(a)
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        return Outline.Generic(path)
    }
}

/** Connected list look: big corners at the start and end of a group, small corners between items. */
fun groupedShape(index: Int, count: Int): Shape {
    val big = 30.dp
    val small = 8.dp
    val first = index == 0
    val last = index == count - 1
    return RoundedCornerShape(
        topStart = if (first) big else small,
        topEnd = if (first) big else small,
        bottomStart = if (last) big else small,
        bottomEnd = if (last) big else small,
    )
}
