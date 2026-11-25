package com.healthstats.app.data.model

import android.graphics.Bitmap
import kotlinx.serialization.Serializable

/** All times are epoch milliseconds. */

@Serializable
data class Segment(val type: Int, val start: Long, val end: Long, val reps: Int = 0)

@Serializable
data class Workout(
    val id: String,
    val type: Int = 0,
    val title: String = "",
    val notes: String = "",
    val source: String = "",
    val start: Long,
    val end: Long,
    val hasRoute: Boolean = false,
    val distanceM: Double = 0.0,
    val activeKcal: Double = 0.0,
    val totalKcal: Double = 0.0,
    val steps: Int = 0,
    val hrAvg: Double = 0.0,
    val hrMax: Double = 0.0,
    val hrMin: Double = 0.0,
    val segments: List<Segment> = emptyList(),
) {
    val sport: SportInfo get() = sportOf(type)
    val unknownType: Boolean get() = !Sports.containsKey(type)
    val durationSec: Long get() = (end - start) / 1000
    val kcal: Double get() = if (activeKcal > 0) activeKcal else totalKcal
    val paceMinKm: Double? get() = if (distanceM > 100 && durationSec > 0) durationSec / 60.0 / (distanceM / 1000) else null
    val speedKmh: Double? get() = if (distanceM > 100 && durationSec > 0) (distanceM / 1000) / (durationSec / 3600.0) else null
    val totalReps: Int get() = segments.sumOf { it.reps }
}

@Serializable
data class DayStat(
    val day: Long,
    val steps: Int = 0,
    val distanceM: Double = 0.0,
    val activeKcal: Double = 0.0,
    val totalKcal: Double = 0.0,
    val hrAvg: Double = 0.0,
)

/** One GPS point. [alt] is NaN when unknown. */
@Serializable
data class RoutePoint(val lat: Double, val lng: Double, val alt: Double = Double.NaN, val time: Long = 0L)

data class TimedValue(val time: Long, val value: Double)

data class SleepStage(val type: Int, val start: Long, val end: Long) // type: 0 unknown, 1 awake, 2 light, 3 deep, 4 REM

data class SleepSession(val start: Long, val end: Long, val title: String, val stages: List<SleepStage>)

/** Name and icon of an app that wrote data. */
data class AppInfo(val pkg: String, val label: String?, val icon: Bitmap?)

enum class HcStatus { Available, UpdateRequired, Unavailable }

sealed interface RouteResult {
    data class Data(val points: List<RoutePoint>) : RouteResult
    /** The user must approve this route in a Health Connect dialog. */
    data object ConsentRequired : RouteResult
    data object None : RouteResult
}
