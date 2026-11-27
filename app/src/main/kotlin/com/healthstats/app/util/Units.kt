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

/** One kilometer (or the last part of it) of a route. */
class Split(val km: Int, val seconds: Long, val meters: Double) {
    val secPerKm: Double get() = seconds / (meters / 1000.0)
}

private fun distanceM(a: RoutePoint, b: RoutePoint): Double {
    val r = 6371000.0
    val dLat = Math.toRadians(b.lat - a.lat)
    val dLng = Math.toRadians(b.lng - a.lng)
    val h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(a.lat)) * Math.cos(Math.toRadians(b.lat)) * Math.sin(dLng / 2) * Math.sin(dLng / 2)
    return 2 * r * Math.asin(Math.sqrt(h))
}

/** Splits per kilometer from a route with times. Empty if the route has no times. */
fun splitsOf(points: List<RoutePoint>): List<Split> {
    if (points.size < 2 || points.first().time <= 0L || points.last().time <= points.first().time) return emptyList()
    val out = ArrayList<Split>()
    var cum = 0.0
    var nextKm = 1
    var lastKmTime = points.first().time
    for (i in 1 until points.size) {
        val a = points[i - 1]
        val b = points[i]
        val d = distanceM(a, b)
        val before = cum
        cum += d
        while (cum >= nextKm * 1000.0) {
            val frac = if (d > 0) (nextKm * 1000.0 - before) / d else 1.0
            val t = a.time + ((b.time - a.time) * frac).toLong()
            out.add(Split(nextKm, ((t - lastKmTime) / 1000).coerceAtLeast(1L), 1000.0))
            lastKmTime = t
            nextKm++
        }
    }
    val rest = cum - (nextKm - 1) * 1000.0
    if (rest >= 150) out.add(Split(nextKm, ((points.last().time - lastKmTime) / 1000).coerceAtLeast(1L), rest))
    return out
}
