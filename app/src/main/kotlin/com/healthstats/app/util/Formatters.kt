package com.healthstats.app.util

import java.text.NumberFormat
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private fun loc(): Locale = Locale.getDefault()
private fun zone(): ZoneId = ZoneId.systemDefault()

fun fmtInt(n: Int): String = NumberFormat.getIntegerInstance(loc()).format(n)

fun fmtDuration(sec: Long): String {
    val h = sec / 3600
    val m = (sec % 3600) / 60
    val s = sec % 60
    return when {
        h > 0 -> String.format(loc(), "%dh%02d", h, m)
        m > 0 -> String.format(loc(), "%d min", m)
        else -> String.format(loc(), "%d s", s)
    }
}

fun fmtDistance(meters: Double): String =
    if (meters >= 1000) String.format(loc(), "%.2f km", meters / 1000.0) else String.format(loc(), "%d m", meters.toInt())

fun fmtPace(minPerKm: Double): String {
    val total = (minPerKm * 60).toInt()
    return String.format(loc(), "%d:%02d /km", total / 60, total % 60)
}

fun fmtSpeed(kmh: Double): String = String.format(loc(), "%.1f km/h", kmh)

fun fmtKcal(kcal: Double): String = String.format(loc(), "%d kcal", kcal.toInt())

fun fmtDate(ms: Long): String =
    DateTimeFormatter.ofPattern("d MMM yyyy", loc()).format(Instant.ofEpochMilli(ms).atZone(zone()))

fun fmtTime(ms: Long): String =
    DateTimeFormatter.ofPattern("HH:mm", loc()).format(Instant.ofEpochMilli(ms).atZone(zone()))

fun fmtDateTime(ms: Long): String = fmtDate(ms) + " " + fmtTime(ms)

fun fmtMonth(ms: Long): String {
    val s = DateTimeFormatter.ofPattern("LLLL yyyy", loc()).format(Instant.ofEpochMilli(ms).atZone(zone()))
    return s.replaceFirstChar { it.uppercase() }
}
