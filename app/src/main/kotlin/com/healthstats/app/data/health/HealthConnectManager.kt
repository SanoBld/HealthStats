package com.healthstats.app.data.health

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.aggregate.AggregationResult
import com.healthstats.app.data.model.DayStat
import com.healthstats.app.data.model.HcStatus
import com.healthstats.app.data.model.Latest
import com.healthstats.app.data.model.RoutePoint
import com.healthstats.app.data.model.RouteResult
import com.healthstats.app.data.model.TimedValue
import com.healthstats.app.data.model.Workout
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withTimeoutOrNull
import java.time.Duration
import java.time.Instant
import java.time.LocalDateTime
import java.time.Period
import java.time.ZoneId
import kotlin.reflect.KClass

/** The only place that talks to Health Connect. Returns plain app models. */
class HealthConnectManager(private val ctx: Context) {

    private val client by lazy { HealthConnectClient.getOrCreate(ctx) }

    /** Runs [block]; returns null on any error. Cancellation (timeouts) still goes through. */
    private inline fun <T> safe(block: () -> T): T? = try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        null
    }

    fun status(): HcStatus = when (HealthConnectClient.getSdkStatus(ctx)) {
        HealthConnectClient.SDK_AVAILABLE -> HcStatus.Available
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> HcStatus.UpdateRequired
        else -> HcStatus.Unavailable
    }

    suspend fun granted(): Set<String> =
        client.permissionController.getGrantedPermissions().filter { it in HealthPermissions.ALL }.toSet()

    private fun range(s: Long, e: Long) =
        TimeRangeFilter.between(Instant.ofEpochMilli(s), Instant.ofEpochMilli(e))

    /** Without the history permission Health Connect only allows ~30 days back: stay inside to avoid errors. */
    private suspend fun clampStart(startMs: Long): Long {
        val hasHistory = safe { client.permissionController.getGrantedPermissions().contains(HealthPermissions.HISTORY) } ?: false
        return if (hasHistory) startMs else maxOf(startMs, System.currentTimeMillis() - 29L * 24 * 3600 * 1000)
    }

    // ---- Workouts ----

    /** All exercise sessions, without stats (fast). Stats come later with [stats]. */
    suspend fun sessions(startMs: Long, endMs: Long): List<Workout> {
        val from = clampStart(startMs)
        val out = ArrayList<Workout>()
        var token: String? = null
        do {
            val res = client.readRecords(
                ReadRecordsRequest(
                    recordType = ExerciseSessionRecord::class,
                    timeRangeFilter = range(from, endMs),
                    pageSize = 500,
                    pageToken = token,
                )
            )
            for (r in res.records) {
                val route = r.exerciseRouteResult
                out.add(
                    Workout(
                        id = r.metadata.id,
                        type = r.exerciseType,
                        title = r.title ?: "",
                        notes = r.notes ?: "",
                        source = r.metadata.dataOrigin.packageName,
                        start = r.startTime.toEpochMilli(),
                        end = r.endTime.toEpochMilli(),
                        hasRoute = route is ExerciseRouteResult.Data || route is ExerciseRouteResult.ConsentRequired,
                    )
                )
            }
            token = res.pageToken
        } while (!token.isNullOrEmpty())
        return out
    }

    private val statMetrics = setOf(
        DistanceRecord.DISTANCE_TOTAL,
        ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
        TotalCaloriesBurnedRecord.ENERGY_TOTAL,
        StepsRecord.COUNT_TOTAL,
        HeartRateRecord.BPM_AVG,
        HeartRateRecord.BPM_MAX,
        HeartRateRecord.BPM_MIN,
    )

    private suspend fun aggregate(w: Workout, origins: Set<DataOrigin>): AggregationResult? = safe {
        client.aggregate(
            AggregateRequest(
                metrics = statMetrics,
                timeRangeFilter = range(w.start, w.end),
                dataOriginFilter = origins,
            )
        )
    }

    private fun AggregationResult.hasNoData(): Boolean =
        (this[DistanceRecord.DISTANCE_TOTAL] == null) &&
            (this[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL] == null) &&
            (this[TotalCaloriesBurnedRecord.ENERGY_TOTAL] == null) &&
            (this[StepsRecord.COUNT_TOTAL] == null) &&
            (this[HeartRateRecord.BPM_AVG] == null)

    /** Distance, calories, steps and heart rate of one workout. Uses only the app that wrote the workout first. */
    suspend fun stats(w: Workout): Workout {
        var res = if (w.source.isNotEmpty()) aggregate(w, setOf(DataOrigin(w.source))) else null
        if (res == null || res.hasNoData()) res = aggregate(w, emptySet()) ?: res
        if (res == null) return w
        val active = res[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0
        val total = res[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0
        return w.copy(
            distanceM = res[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0,
            kcal = if (active > 0) active else total,
            steps = (res[StepsRecord.COUNT_TOTAL] ?: 0L).toInt(),
            hrAvg = (res[HeartRateRecord.BPM_AVG] ?: 0L).toInt(),
            hrMax = (res[HeartRateRecord.BPM_MAX] ?: 0L).toInt(),
            hrMin = (res[HeartRateRecord.BPM_MIN] ?: 0L).toInt(),
            statsDone = true,
        )
    }

    // ---- GPS route ----

    fun pointsOf(route: ExerciseRoute): List<RoutePoint> = route.route.map {
        RoutePoint(it.latitude, it.longitude, it.altitude?.inMeters ?: Double.NaN, it.time.toEpochMilli())
    }

    /** Route of one session. If Android needs the user's approval, returns Consent (the screen then asks). */
    suspend fun route(sessionId: String): RouteResult {
        val rec = safe { client.readRecord(ExerciseSessionRecord::class, sessionId).record } ?: return RouteResult.None
        return when (val r = rec.exerciseRouteResult) {
            is ExerciseRouteResult.Data -> RouteResult.Data(pointsOf(r.exerciseRoute))
            is ExerciseRouteResult.ConsentRequired -> RouteResult.Consent(sessionId)
            else -> RouteResult.None
        }
    }

    // ---- Samples during a workout (heart rate, speed, power) ----

    /** Reads one kind of record over a time range. Uses the workout's app first, then all apps. */
    private suspend fun <T : Record> series(
        type: KClass<T>, startMs: Long, endMs: Long, source: String, extract: (T) -> List<TimedValue>,
    ): List<TimedValue> {
        suspend fun read(origins: Set<DataOrigin>): List<TimedValue> {
            val out = ArrayList<TimedValue>()
            var token: String? = null
            do {
                val res = client.readRecords(
                    ReadRecordsRequest(
                        recordType = type,
                        timeRangeFilter = range(startMs, endMs),
                        dataOriginFilter = origins,
                        pageSize = 1000,
                        pageToken = token,
                    )
                )
                for (rec in res.records) out.addAll(extract(rec))
                token = res.pageToken
            } while (!token.isNullOrEmpty())
            return out.sortedBy { it.time }
        }
        val first = if (source.isNotEmpty()) safe { read(setOf(DataOrigin(source))) } else null
        if (!first.isNullOrEmpty()) return first
        return safe { read(emptySet()) } ?: emptyList()
    }

    suspend fun heartRate(startMs: Long, endMs: Long, source: String): List<TimedValue> =
        series(HeartRateRecord::class, startMs, endMs, source) { r ->
            r.samples.map { TimedValue(it.time.toEpochMilli(), it.beatsPerMinute.toDouble()) }
        }

    /** Speed in km/h. */
    suspend fun speed(startMs: Long, endMs: Long, source: String): List<TimedValue> =
        series(SpeedRecord::class, startMs, endMs, source) { r ->
            r.samples.map { TimedValue(it.time.toEpochMilli(), it.speed.inMetersPerSecond * 3.6) }
        }

    /** Power in watts. */
    suspend fun power(startMs: Long, endMs: Long, source: String): List<TimedValue> =
        series(PowerRecord::class, startMs, endMs, source) { r ->
            r.samples.map { TimedValue(it.time.toEpochMilli(), it.power.inWatts) }
        }

    // ---- Daily totals ----

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
            val chunkStart = a
            val res = withTimeoutOrNull(25_000) {
                safe {
                    client.aggregateGroupByPeriod(
                        AggregateGroupByPeriodRequest(
                            metrics = setOf(
                                StepsRecord.COUNT_TOTAL,
                                DistanceRecord.DISTANCE_TOTAL,
                                ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                                TotalCaloriesBurnedRecord.ENERGY_TOTAL,
                            ),
                            timeRangeFilter = TimeRangeFilter.between(chunkStart, b),
                            timeRangeSlicer = Period.ofDays(1),
                        )
                    )
                }
            }
            res?.forEach {
                val active = it.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0
                val total = it.result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0
                out.add(
                    DayStat(
                        epochDay = it.startTime.toLocalDate().toEpochDay(),
                        steps = (it.result[StepsRecord.COUNT_TOTAL] ?: 0L).toInt(),
                        distanceM = it.result[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0,
                        kcal = if (active > 0) active else total,
                    )
                )
            }
            a = b
        }
        return out
    }

    // ---- Latest values ----

    suspend fun latest(): Latest {
        val now = Instant.now()
        val rhr = safe {
            client.readRecords(
                ReadRecordsRequest(RestingHeartRateRecord::class, TimeRangeFilter.before(now), ascendingOrder = false, pageSize = 1)
            ).records.firstOrNull()?.beatsPerMinute?.toDouble()
        }
        val weight = safe {
            client.readRecords(
                ReadRecordsRequest(WeightRecord::class, TimeRangeFilter.before(now), ascendingOrder = false, pageSize = 1)
            ).records.firstOrNull()?.weight?.inKilograms
        }
        val sleep = safe {
            client.readRecords(
                ReadRecordsRequest(SleepSessionRecord::class, TimeRangeFilter.before(now), ascendingOrder = false, pageSize = 1)
            ).records.firstOrNull()?.let { Duration.between(it.startTime, it.endTime).toMinutes() }
        }
        return Latest(rhr, weight, sleep)
    }

    /** Last known height in cm, or 0. */
    suspend fun heightCm(): Int = safe {
        client.readRecords(
            ReadRecordsRequest(HeightRecord::class, TimeRangeFilter.before(Instant.now()), ascendingOrder = false, pageSize = 1)
        ).records.firstOrNull()?.height?.inMeters?.times(100.0)?.toInt()
    } ?: 0
}
