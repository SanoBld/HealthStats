package com.healthstats.app.data.model

import kotlinx.serialization.Serializable

/** All times are epoch milliseconds. */

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
    val kcal: Double = 0.0,
    val steps: Int = 0,
    val hrAvg: Int = 0,
    val hrMax: Int = 0,
    val hrMin: Int = 0,
    val statsDone: Boolean = false,
    // Filled only after duplicates are merged: the other copies of this activity
    val alts: List<String> = emptyList(),
    val altSources: List<String> = emptyList(),
) {
    val sport: SportInfo get() = sportOf(type)
    val durationSec: Long get() = (end - start) / 1000
    val paceMinKm: Double?
        get() = if (distanceM > 100 && durationSec > 0) durationSec / 60.0 / (distanceM / 1000.0) else null
    val speedKmh: Double?
        get() = if (distanceM > 100 && durationSec > 0) (distanceM / 1000.0) / (durationSec / 3600.0) else null
}

/** Totals of one day. [epochDay] = LocalDate.toEpochDay(). */
@Serializable
data class DayStat(
    val epochDay: Long,
    val steps: Int = 0,
    val distanceM: Double = 0.0,
    val kcal: Double = 0.0,
)

/** One GPS point. [alt] is NaN when unknown, [time] is 0 when unknown. */
data class RoutePoint(val lat: Double, val lng: Double, val alt: Double = Double.NaN, val time: Long = 0L)

@Serializable
data class TimedValue(val time: Long, val value: Double)

/** One night of sleep (minutes). Stages are 0 when the app that wrote the sleep has no stages. */
@Serializable
data class SleepNight(
    val endMs: Long,
    val totalMin: Long,
    val deepMin: Long = 0,
    val remMin: Long = 0,
    val lightMin: Long = 0,
    val awakeMin: Long = 0,
)

/** Heart rate of one day (bpm). */
@Serializable
data class HrDay(val epochDay: Long, val avg: Int, val min: Int, val max: Int)

/** Everything besides workouts and daily totals. Lists are oldest first. */
@Serializable
data class BodyMetrics(
    val sleep: List<SleepNight> = emptyList(),
    val restingHr: List<TimedValue> = emptyList(),
    val weight: List<TimedValue> = emptyList(),   // kg
    val hrv: List<TimedValue> = emptyList(),      // ms
    val spo2: List<TimedValue> = emptyList(),     // %
    val vo2: List<TimedValue> = emptyList(),      // ml/min/kg
    val hrDays: List<HrDay> = emptyList(),
)

enum class HcStatus { Available, UpdateRequired, Unavailable }

sealed interface RouteResult {
    data class Data(val points: List<RoutePoint>) : RouteResult

    /** Android wants the user's approval for this session's route. */
    data class Consent(val sessionId: String) : RouteResult
    data object None : RouteResult
}
