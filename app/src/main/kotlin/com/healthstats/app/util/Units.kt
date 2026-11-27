package com.healthstats.app.util

import com.healthstats.app.data.model.RoutePoint
import com.healthstats.app.data.model.TimedValue
import java.time.LocalDate
import java.time.Period
import kotlin.math.roundToInt

/** Age in years from "yyyy-MM-dd", or null. */
fun ageYears(birth: String): Int? = try {
    if (birth.isEmpty()) null else Period.between(LocalDate.parse(birth), LocalDate.now()).years
} catch (e: Exception) {
    null
}

/** Estimated max heart rate. */
fun maxHrFor(age: Int?): Int = if (age == null) 0 else 220 - age

/** Zone 0..4 (Z1..Z5) of a heart rate. */
fun zoneOf(bpm: Double, maxHr: Int): Int {
    val r = bpm / maxHr
    return when {
        r < 0.60 -> 0
        r < 0.70 -> 1
        r < 0.80 -> 2
        r < 0.90 -> 3
        else -> 4
    }
}

/** Keeps at most [n] values by averaging buckets. */
fun downsample(values: List<TimedValue>, n: Int): List<TimedValue> {
    if (values.size <= n) return values
    val size = values.size.toDouble() / n
    return (0 until n).map { i ->
        val from = (i * size).toInt()
        val to = ((i + 1) * size).toInt().coerceAtMost(values.size).coerceAtLeast(from + 1)
        val part = values.subList(from, to)
        TimedValue(part.first().time, part.map { it.value }.average())
    }
}

fun thin(points: List<RoutePoint>, max: Int): List<RoutePoint> {
    if (points.size <= max) return points
    val step = (points.size + max - 1) / max
    val out = ArrayList<RoutePoint>()
    var i = 0
    while (i < points.size) { out.add(points[i]); i += step }
    if (out.last() !== points.last()) out.add(points.last())
    return out
}

private fun hasTimes(points: List<RoutePoint>) =
    points.size > 1 && points.first().time > 0 && points.last().time > points.first().time

/** The route point at [f] (0..1) of the workout. Used to move the marker on the map. */
fun pointAt(points: List<RoutePoint>, startMs: Long, endMs: Long, f: Float): RoutePoint? {
    if (points.isEmpty()) return null
    if (!hasTimes(points)) return points[(f * (points.size - 1)).roundToInt().coerceIn(0, points.size - 1)]
    val t = startMs + f * (endMs - startMs)
    var lo = 0
    var hi = points.size - 1
    while (lo < hi) {
        val mid = (lo + hi) / 2
        if (points[mid].time < t) lo = mid + 1 else hi = mid
    }
    return points[lo]
}

/** Position (0..1) of each route point along the workout. */
fun routeFractions(points: List<RoutePoint>, startMs: Long, endMs: Long): List<Float> {
    val span = (endMs - startMs).coerceAtLeast(1L).toFloat()
    return if (hasTimes(points)) points.map { ((it.time - startMs) / span).coerceIn(0f, 1f) }
    else points.indices.map { it.toFloat() / (points.size - 1).coerceAtLeast(1) }
}
