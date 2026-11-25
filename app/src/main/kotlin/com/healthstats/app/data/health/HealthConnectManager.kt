package com.healthstats.app.data.health

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.healthstats.app.data.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.time.Instant
import java.time.LocalDateTime
import java.time.Period
import java.time.ZoneId
import kotlin.reflect.KClass

/** Only place that talks to Health Connect. Returns plain app models. */
class HealthConnectManager(private val ctx: Context) {

    private val client by lazy { HealthConnectClient.getOrCreate(ctx) }

    fun status(): HcStatus = when (HealthConnectClient.getSdkStatus(ctx)) {
        HealthConnectClient.SDK_AVAILABLE -> HcStatus.Available
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> HcStatus.UpdateRequired
        else -> HcStatus.Unavailable
    }

    suspend fun granted(): Set<String> =
        client.permissionController.getGrantedPermissions().filter { it in HealthPermissions.ALL }.toSet()

    private fun range(s: Long, e: Long) = TimeRangeFilter.between(Instant.ofEpochMilli(s), Instant.ofEpochMilli(e))

    /** Without the history permission Health Connect only gives ~30 days: stay inside to avoid errors. */
    private suspend fun clampStart(startMs: Long): Long {
        val hasHistory = try {
            client.permissionController.getGrantedPermissions().contains(HealthPermissions.HISTORY)
        } catch (e: Exception) { false }
        if (hasHistory) return startMs
        return maxOf(startMs, System.currentTimeMillis() - 29L * 24 * 3600 * 1000)
    }

    // ---- App names and icons ----

    suspend fun appInfo(pkgs: List<String>): List<AppInfo> = withContext(Dispatchers.Default) {
        val pm = ctx.packageManager
        pkgs.map { pkg ->
            try {
                val label = pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                val d = pm.getApplicationIcon(pkg)
                val size = 96
                val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                d.setBounds(0, 0, size, size)
                d.draw(Canvas(bmp))
                AppInfo(pkg, label, bmp)
            } catch (e: Exception) {
                AppInfo(pkg, null, null) // app not installed
            }
        }
    }

    // ---- Exercise sessions ----

    private suspend fun toWorkout(r: ExerciseSessionRecord, lite: Boolean): Workout {
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
                        TimeRangeFilter.between(r.startTime, r.endTime),
                    )
                )
            } catch (e: Exception) { null }
        }
        val hasRoute = r.exerciseRouteResult is ExerciseRouteResult.Data ||
            r.exerciseRouteResult is ExerciseRouteResult.ConsentRequired
        return Workout(
            id = r.metadata.id,
            type = r.exerciseType,
            title = r.title ?: "",
            notes = r.notes ?: "",
            source = r.metadata.dataOrigin.packageName,
            start = r.startTime.toEpochMilli(),
            end = r.endTime.toEpochMilli(),
            hasRoute = hasRoute,
            distanceM = agg?.get(DistanceRecord.DISTANCE_TOTAL)?.inMeters ?: 0.0,
            activeKcal = agg?.get(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)?.inKilocalories ?: 0.0,
            totalKcal = agg?.get(TotalCaloriesBurnedRecord.ENERGY_TOTAL)?.inKilocalories ?: 0.0,
            steps = (agg?.get(StepsRecord.COUNT_TOTAL) ?: 0L).toInt(),
            hrAvg = (agg?.get(HeartRateRecord.BPM_AVG) ?: 0L).toDouble(),
            hrMax = (agg?.get(HeartRateRecord.BPM_MAX) ?: 0L).toDouble(),
            hrMin = (agg?.get(HeartRateRecord.BPM_MIN) ?: 0L).toDouble(),
            segments = r.segments.map { Segment(it.segmentType, it.startTime.toEpochMilli(), it.endTime.toEpochMilli(), it.repetitions) },
        )
    }

    /** Exercise sessions. [lite] = no stats, very fast (used to show the list at once). */
    suspend fun sessions(startMs: Long, endMs: Long, lite: Boolean): List<Workout> {
        val from = clampStart(startMs)
        val recs = ArrayList<ExerciseSessionRecord>()
        var token: String? = null
        do {
            val res = client.readRecords(
                ReadRecordsRequest(ExerciseSessionRecord::class, range(from, endMs), pageSize = 500, pageToken = token)
            )
            recs.addAll(res.records)
            token = res.pageToken
        } while (!token.isNullOrEmpty())
        if (lite) return recs.map { r -> toWorkoutLite(r) }
        val sem = Semaphore(6)
        return coroutineScope { recs.map { r -> async { sem.withPermit { toWorkout(r, false) } } }.awaitAll() }
    }

    private suspend fun toWorkoutLite(r: ExerciseSessionRecord) = toWorkout(r, true)

    /** Last known height in cm, or -1. */
    suspend fun height(): Double = try {
        val res = client.readRecords(
            ReadRecordsRequest(HeightRecord::class, TimeRangeFilter.before(Instant.now()), ascendingOrder = false, pageSize = 1)
        )
        res.records.firstOrNull()?.height?.inMeters?.times(100.0) ?: -1.0
    } catch (e: Exception) { -1.0 }

    // ---- GPS route ----

    fun pointsOf(route: ExerciseRoute, max: Int = 0): List<RoutePoint> =
        thin(route.route.map { RoutePoint(it.latitude, it.longitude, it.altitude?.inMeters ?: Double.NaN, it.time.toEpochMilli()) }, max)

    private fun thin(all: List<RoutePoint>, max: Int): List<RoutePoint> {
        if (max <= 0 || all.size <= max) return all
        val step = (all.size + max - 1) / max
        val out = ArrayList<RoutePoint>()
        var i = 0
        while (i < all.size) { out.add(all[i]); i += step }
        if (out.last() !== all.last()) out.add(all.last())
        return out
    }

    /** Route of a session. If Android needs the user's approval, returns ConsentRequired (the screen then asks). */
    suspend fun route(sessionId: String, maxPoints: Int = 0): RouteResult {
        val rec = client.readRecord(ExerciseSessionRecord::class, sessionId).record
        return when (val r = rec.exerciseRouteResult) {
            is ExerciseRouteResult.Data -> RouteResult.Data(pointsOf(r.exerciseRoute, maxPoints))
            is ExerciseRouteResult.ConsentRequired -> RouteResult.ConsentRequired
            else -> RouteResult.None
        }
    }

    // ---- Heart rate, curves, metrics ----

    suspend fun heartRate(startMs: Long, endMs: Long): List<TimedValue> {
        val out = ArrayList<TimedValue>()
        var token: String? = null
        val from = clampStart(startMs)
        do {
            val res = client.readRecords(
                ReadRecordsRequest(HeartRateRecord::class, range(from, endMs), pageSize = 1000, pageToken = token)
            )
            for (rec in res.records) for (s in rec.samples) out.add(TimedValue(s.time.toEpochMilli(), s.beatsPerMinute.toDouble()))
            token = res.pageToken
        } while (!token.isNullOrEmpty())
        return out.sortedBy { it.time }
    }

    /** Daily totals between two dates, read in chunks of 120 days. */
    suspend fun daily(startMs: Long, endMs: Long): List<DayStat> {
        val zone = ZoneId.systemDefault()
        val from = LocalDateTime.ofInstant(Instant.ofEpochMilli(clampStart(startMs)), zone).toLocalDate().atStartOfDay()
        val to = LocalDateTime.ofInstant(Instant.ofEpochMilli(endMs), zone).toLocalDate().plusDays(1).atStartOfDay()
        val out = ArrayList<DayStat>()
        var a = from
        while (a.isBefore(to)) {
            val next = a.plusDays(120)
            val b = if (next.isBefore(to)) next else to
            val res = withTimeoutOrNull(20_000) {
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
                            Period.ofDays(1),
                        )
                    )
                } catch (e: Exception) { null }
            }
            res?.forEach {
                out.add(
                    DayStat(
                        day = it.startTime.atZone(zone).toInstant().toEpochMilli(),
                        steps = (it.result[StepsRecord.COUNT_TOTAL] ?: 0L).toInt(),
                        distanceM = it.result[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0,
                        activeKcal = it.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0,
                        totalKcal = it.result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0,
                        hrAvg = (it.result[HeartRateRecord.BPM_AVG] ?: 0L).toDouble(),
                    )
                )
            }
            a = b
        }
        return out
    }

    /** Recorded curve of a session: speed (m/s) or power (W). Empty if no permission or no data. */
    suspend fun samples(kind: SampleKind, startMs: Long, endMs: Long): List<TimedValue> {
        val out = ArrayList<TimedValue>()
        val from = clampStart(startMs)
        try {
            var token: String? = null
            do {
                when (kind) {
                    SampleKind.Speed -> {
                        val r = client.readRecords(ReadRecordsRequest(SpeedRecord::class, range(from, endMs), pageSize = 1000, pageToken = token))
                        r.records.forEach { rec -> rec.samples.forEach { out.add(TimedValue(it.time.toEpochMilli(), it.speed.inMetersPerSecond)) } }
                        token = r.pageToken
                    }
                    SampleKind.Power -> {
                        val r = client.readRecords(ReadRecordsRequest(PowerRecord::class, range(from, endMs), pageSize = 1000, pageToken = token))
                        r.records.forEach { rec -> rec.samples.forEach { out.add(TimedValue(it.time.toEpochMilli(), it.power.inWatts)) } }
                        token = r.pageToken
                    }
                }
            } while (!token.isNullOrEmpty())
        } catch (e: Exception) { /* permission missing or no data */ }
        return out.sortedBy { it.time }
    }

    private suspend fun <T : Record> pull(
        c: KClass<T>, from: Long, to: Long, out: MutableList<TimedValue>, f: (T) -> TimedValue?,
    ) {
        var token: String? = null
        do {
            val r = client.readRecords(ReadRecordsRequest(c, range(from, to), pageSize = 1000, pageToken = token))
            r.records.forEach { rec -> f(rec)?.let { out.add(it) } }
            token = r.pageToken
        } while (!token.isNullOrEmpty())
    }

    /** Values of one metric over time. Empty if no permission or no data. */
    suspend fun metric(type: MetricType, startMs: Long, endMs: Long): List<TimedValue> {
        val out = ArrayList<TimedValue>()
        val from = clampStart(startMs)
        try {
            when (type) {
                MetricType.RestingHr -> pull(RestingHeartRateRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.beatsPerMinute.toDouble()) }
                MetricType.Hrv -> pull(HeartRateVariabilityRmssdRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.heartRateVariabilityMillis) }
                MetricType.Spo2 -> pull(OxygenSaturationRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.percentage.value) }
                MetricType.Vo2 -> pull(Vo2MaxRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.vo2MillilitersPerMinuteKilogram) }
                MetricType.Resp -> pull(RespiratoryRateRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.rate) }
                MetricType.BodyFat -> pull(BodyFatRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.percentage.value) }
                MetricType.Systolic -> pull(BloodPressureRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.systolic.inMillimetersOfMercury) }
                MetricType.Temp -> pull(BodyTemperatureRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.temperature.inCelsius) }
                MetricType.Weight -> pull(WeightRecord::class, from, endMs, out) { TimedValue(it.time.toEpochMilli(), it.weight.inKilograms) }
            }
        } catch (e: Exception) { /* permission missing */ }
        return out.sortedBy { it.time }
    }

    /** All sleep sessions, with real stages when the source gives them. */
    suspend fun sleep(startMs: Long, endMs: Long): List<SleepSession> {
        val out = ArrayList<SleepSession>()
        val from = clampStart(startMs)
        try {
            var token: String? = null
            do {
                val res = client.readRecords(ReadRecordsRequest(SleepSessionRecord::class, range(from, endMs), pageSize = 500, pageToken = token))
                res.records.forEach {
                    out.add(
                        SleepSession(
                            it.startTime.toEpochMilli(), it.endTime.toEpochMilli(), it.title ?: "",
                            it.stages.map { st ->
                                val t = when (st.stage) {
                                    SleepSessionRecord.STAGE_TYPE_AWAKE, SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED -> 1
                                    SleepSessionRecord.STAGE_TYPE_LIGHT, SleepSessionRecord.STAGE_TYPE_SLEEPING -> 2
                                    SleepSessionRecord.STAGE_TYPE_DEEP -> 3
                                    SleepSessionRecord.STAGE_TYPE_REM -> 4
                                    else -> 0
                                }
                                SleepStage(t, st.startTime.toEpochMilli(), st.endTime.toEpochMilli())
                            },
                        )
                    )
                }
                token = res.pageToken
            } while (!token.isNullOrEmpty())
        } catch (e: Exception) { /* permission missing */ }
        return out
    }
}
