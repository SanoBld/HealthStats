package com.healthstats.app

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.LocalDateTime
import java.time.Period
import java.time.ZoneId
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withTimeoutOrNull

/** Reads Health Connect and returns plain Map/List values (serialized by the MethodChannel). */
class HealthBridge(private val ctx: Context) {

    companion object {
        const val ROUTE_PERM = "android.permission.health.READ_EXERCISE_ROUTE"
        const val HISTORY_PERM = "android.permission.health.READ_HEALTH_DATA_HISTORY"
        val PERMISSIONS: Set<String> = setOf(
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(DistanceRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(WeightRecord::class),
            HealthPermission.getReadPermission(HeightRecord::class),
            HealthPermission.getReadPermission(SpeedRecord::class),
            ROUTE_PERM,
            HISTORY_PERM,
        )
    }

    fun status(): String = when (HealthConnectClient.getSdkStatus(ctx)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
        else -> "unavailable"
    }

    private val client by lazy { HealthConnectClient.getOrCreate(ctx) }

    suspend fun granted(): List<String> =
        client.permissionController.getGrantedPermissions().filter { it in PERMISSIONS }

    private fun range(s: Long, e: Long) =
        TimeRangeFilter.between(Instant.ofEpochMilli(s), Instant.ofEpochMilli(e))

    /** Without the history permission Health Connect only gives ~30 days: avoid errors. */
    private suspend fun clampStart(startMs: Long): Long {
        val hasHistory = try {
            client.permissionController.getGrantedPermissions().contains(HISTORY_PERM)
        } catch (e: Exception) { false }
        if (hasHistory) return startMs
        val limit = System.currentTimeMillis() - 29L * 24 * 3600 * 1000
        return maxOf(startMs, limit)
    }

    private suspend fun sessionMap(r: ExerciseSessionRecord, lite: Boolean): Map<String, Any?> {
        // Stats are slow (one call per session): in lite mode we skip them
        val agg = if (lite) null else withTimeoutOrNull(8000) {
            try {
                client.aggregate(
                    AggregateRequest(
                        setOf(
                            DistanceRecord.DISTANCE_TOTAL,
                            ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                            TotalCaloriesBurnedRecord.ENERGY_TOTAL,
                            StepsRecord.COUNT_TOTAL,
                            HeartRateRecord.BPM_AVG,
                            HeartRateRecord.BPM_MAX,
                            HeartRateRecord.BPM_MIN,
                        ),
                        TimeRangeFilter.between(r.startTime, r.endTime)
                    )
                )
            } catch (e: Exception) { null }
        }
        val hasRoute = r.exerciseRouteResult is ExerciseRouteResult.Data ||
            r.exerciseRouteResult is ExerciseRouteResult.ConsentRequired
        return mapOf(
            "id" to r.metadata.id,
            "type" to r.exerciseType,
            "title" to r.title,
            "notes" to r.notes,
            "start" to r.startTime.toEpochMilli(),
            "end" to r.endTime.toEpochMilli(),
            "source" to r.metadata.dataOrigin.packageName,
            "hasRoute" to hasRoute,
            "distanceM" to agg?.get(DistanceRecord.DISTANCE_TOTAL)?.inMeters,
            "activeKcal" to agg?.get(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)?.inKilocalories,
            "totalKcal" to agg?.get(TotalCaloriesBurnedRecord.ENERGY_TOTAL)?.inKilocalories,
            "steps" to agg?.get(StepsRecord.COUNT_TOTAL),
            "hrAvg" to agg?.get(HeartRateRecord.BPM_AVG),
            "hrMax" to agg?.get(HeartRateRecord.BPM_MAX),
            "hrMin" to agg?.get(HeartRateRecord.BPM_MIN),
            "segments" to r.segments.map {
                mapOf(
                    "type" to it.segmentType,
                    "start" to it.startTime.toEpochMilli(),
                    "end" to it.endTime.toEpochMilli(),
                    "reps" to it.repetitions,
                )
            },
        )
    }

    /** Exercise sessions (without route: see [route]). [lite] = no stats, very fast. */
    suspend fun sessions(startMs: Long, endMs: Long, lite: Boolean): List<Map<String, Any?>> {
        val from = clampStart(startMs)
        val recs = ArrayList<ExerciseSessionRecord>()
        var token: String? = null
        do {
            val res = client.readRecords(
                ReadRecordsRequest(
                    ExerciseSessionRecord::class, range(from, endMs),
                    pageSize = 500, pageToken = token
                )
            )
            recs.addAll(res.records)
            token = res.pageToken
        } while (!token.isNullOrEmpty())
        // Stats are read 6 at a time (was one by one = very slow)
        val sem = Semaphore(6)
        return coroutineScope {
            recs.map { r -> async { sem.withPermit { sessionMap(r, lite) } } }.awaitAll()
        }
    }

    /** Last known height in cm, or -1. */
    suspend fun height(): Double {
        val res = client.readRecords(
            ReadRecordsRequest(
                HeightRecord::class, TimeRangeFilter.before(Instant.now()),
                ascendingOrder = false, pageSize = 1
            )
        )
        return res.records.firstOrNull()?.height?.inMeters?.times(100.0) ?: -1.0
    }

    private fun pts(route: ExerciseRoute): List<List<Double>> = route.route.map {
        listOf(
            it.latitude, it.longitude,
            it.altitude?.inMeters ?: Double.NaN,
            it.time.toEpochMilli().toDouble()
        )
    }

    /** GPS points of a session: list of [lat, lng, alt, timeMs]. [ask] runs the consent dialog if needed. */
    suspend fun route(sessionId: String, ask: (suspend (String) -> ExerciseRoute?)?, max: Int = 0): List<List<Double>> {
        val rec = client.readRecord(ExerciseSessionRecord::class, sessionId).record
        val all = when (val r = rec.exerciseRouteResult) {
            is ExerciseRouteResult.Data -> pts(r.exerciseRoute)
            is ExerciseRouteResult.ConsentRequired -> ask?.invoke(sessionId)?.let { pts(it) } ?: emptyList()
            else -> emptyList()
        }
        // [max] > 0: keep ~max points only (small and fast for the map tab)
        if (max <= 0 || all.size <= max) return all
        val step = (all.size + max - 1) / max
        val out = ArrayList<List<Double>>()
        var i = 0
        while (i < all.size) { out.add(all[i]); i += step }
        if (out.last() !== all.last()) out.add(all.last())
        return out
    }

    /** Heart-rate curve: list of [timeMs, bpm]. */
    suspend fun heartRate(startMs: Long, endMs: Long): List<List<Long>> {
        val out = ArrayList<List<Long>>()
        var token: String? = null
        do {
            val res = client.readRecords(
                ReadRecordsRequest(HeartRateRecord::class, range(clampStart(startMs), endMs), pageSize = 1000, pageToken = token)
            )
            for (rec in res.records) for (s in rec.samples) out.add(listOf(s.time.toEpochMilli(), s.beatsPerMinute))
            token = res.pageToken
        } while (token != null && token.isNotEmpty())
        return out
    }

    /** Daily totals (steps, distance, kcal) between two dates, read in chunks of 120 days. */
    suspend fun daily(startMs: Long, endMs: Long): List<Map<String, Any?>> {
        val zone = ZoneId.systemDefault()
        val from = LocalDateTime.ofInstant(Instant.ofEpochMilli(clampStart(startMs)), zone).toLocalDate().atStartOfDay()
        val to = LocalDateTime.ofInstant(Instant.ofEpochMilli(endMs), zone).toLocalDate().plusDays(1).atStartOfDay()
        val out = ArrayList<Map<String, Any?>>()
        var a = from
        while (a.isBefore(to)) {
            val next = a.plusDays(120)
            val b = if (next.isBefore(to)) next else to
            val res = withTimeoutOrNull(20000) {
                try {
                    client.aggregateGroupByPeriod(
                        AggregateGroupByPeriodRequest(
                            setOf(
                                StepsRecord.COUNT_TOTAL,
                                DistanceRecord.DISTANCE_TOTAL,
                                ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                                TotalCaloriesBurnedRecord.ENERGY_TOTAL,
                                HeartRateRecord.BPM_AVG,
                            ),
                            TimeRangeFilter.between(a, b),
                            Period.ofDays(1)
                        )
                    )
                } catch (e: Exception) { null }
            }
            res?.forEach {
                out.add(
                    mapOf(
                        "day" to it.startTime.atZone(zone).toInstant().toEpochMilli(),
                        "steps" to (it.result[StepsRecord.COUNT_TOTAL] ?: 0L),
                        "distanceM" to it.result[DistanceRecord.DISTANCE_TOTAL]?.inMeters,
                        "activeKcal" to it.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories,
                        "totalKcal" to it.result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories,
                        "hrAvg" to it.result[HeartRateRecord.BPM_AVG],
                    )
                )
            }
            a = b
        }
        return out
    }

    suspend fun sleep(startMs: Long, endMs: Long): List<Map<String, Any?>> {
        val res = client.readRecords(ReadRecordsRequest(SleepSessionRecord::class, range(startMs, endMs), pageSize = 500))
        return res.records.map {
            mapOf("start" to it.startTime.toEpochMilli(), "end" to it.endTime.toEpochMilli(), "title" to it.title)
        }
    }

    suspend fun weight(startMs: Long, endMs: Long): List<List<Double>> {
        val res = client.readRecords(ReadRecordsRequest(WeightRecord::class, range(startMs, endMs), pageSize = 500))
        return res.records.map { listOf(it.time.toEpochMilli().toDouble(), it.weight.inKilograms) }
    }
}
