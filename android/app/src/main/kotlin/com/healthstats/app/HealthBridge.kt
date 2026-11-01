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

/** Lecture Health Connect -> Map/List simples (sérialisés par le MethodChannel). */
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
            ROUTE_PERM,
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

    /** Séances d'exercice (sans trajet : voir [route]). */
    suspend fun sessions(startMs: Long, endMs: Long): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        var token: String? = null
        do {
            val res = client.readRecords(
                ReadRecordsRequest(
                    ExerciseSessionRecord::class, range(startMs, endMs),
                    pageSize = 500, pageToken = token
                )
            )
            for (r in res.records) {
                val agg = try {
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
                val hasRoute = r.exerciseRouteResult is ExerciseRouteResult.Data ||
                    r.exerciseRouteResult is ExerciseRouteResult.ConsentRequired
                out.add(
                    mapOf(
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
                        "laps" to r.laps.map {
                            mapOf(
                                "start" to it.startTime.toEpochMilli(),
                                "end" to it.endTime.toEpochMilli(),
                                "lengthM" to it.length?.inMeters,
                            )
                        },
                    )
                )
            }
            token = res.pageToken
        } while (token != null && token.isNotEmpty())
        return out
    }

    /** Points GPS d'une séance : liste de [lat, lng, alt, timeMs]. */
    suspend fun route(sessionId: String): List<List<Double>> {
        val res = client.readRecord(ExerciseSessionRecord::class, sessionId)
        val r = res.record.exerciseRouteResult
        if (r !is ExerciseRouteResult.Data) return emptyList()
        return r.exerciseRoute.route.map {
            listOf(
                it.latitude, it.longitude,
                it.altitude?.inMeters ?: Double.NaN,
                it.time.toEpochMilli().toDouble()
            )
        }
    }

    /** Courbe de fréquence cardiaque : liste de [timeMs, bpm]. */
    suspend fun heartRate(startMs: Long, endMs: Long): List<List<Long>> {
        val out = ArrayList<List<Long>>()
        var token: String? = null
        do {
            val res = client.readRecords(
                ReadRecordsRequest(HeartRateRecord::class, range(startMs, endMs), pageSize = 1000, pageToken = token)
            )
            for (rec in res.records) for (s in rec.samples) out.add(listOf(s.time.toEpochMilli(), s.beatsPerMinute))
            token = res.pageToken
        } while (token != null && token.isNotEmpty())
        return out
    }

    /** Totaux quotidiens (pas, distance, kcal) entre deux dates locales. */
    suspend fun daily(startMs: Long, endMs: Long): List<Map<String, Any?>> {
        val zone = ZoneId.systemDefault()
        val from = LocalDateTime.ofInstant(Instant.ofEpochMilli(startMs), zone).toLocalDate().atStartOfDay()
        val to = LocalDateTime.ofInstant(Instant.ofEpochMilli(endMs), zone).toLocalDate().plusDays(1).atStartOfDay()
        val res = client.aggregateGroupByPeriod(
            AggregateGroupByPeriodRequest(
                setOf(
                    StepsRecord.COUNT_TOTAL,
                    DistanceRecord.DISTANCE_TOTAL,
                    ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                    TotalCaloriesBurnedRecord.ENERGY_TOTAL,
                    HeartRateRecord.BPM_AVG,
                ),
                TimeRangeFilter.between(from, to),
                Period.ofDays(1)
            )
        )
        return res.map {
            mapOf(
                "day" to it.startTime.atZone(zone).toInstant().toEpochMilli(),
                "steps" to (it.result[StepsRecord.COUNT_TOTAL] ?: 0L),
                "distanceM" to it.result[DistanceRecord.DISTANCE_TOTAL]?.inMeters,
                "activeKcal" to it.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories,
                "totalKcal" to it.result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories,
                "hrAvg" to it.result[HeartRateRecord.BPM_AVG],
            )
        }
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
