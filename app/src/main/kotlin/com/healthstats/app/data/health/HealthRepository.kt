package com.healthstats.app.data.health

import com.healthstats.app.data.local.CacheData
import com.healthstats.app.data.local.CacheStore
import com.healthstats.app.data.model.DayStat
import com.healthstats.app.data.model.HcStatus
import com.healthstats.app.data.model.BodyMetrics
import com.healthstats.app.data.model.RoutePoint
import com.healthstats.app.data.model.RouteResult
import com.healthstats.app.data.model.TimedValue
import com.healthstats.app.data.model.Workout
import com.healthstats.app.data.remote.IntervalsClient
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

data class SyncError(val timeout: Boolean, val detail: String = "")

/** What the screens read. [loading] = first read in progress; [enriching] = stats of each workout are still coming. */
data class HealthState(
    val workouts: List<Workout> = emptyList(), // merged, newest first
    val days: List<DayStat> = emptyList(),     // oldest first
    val metrics: BodyMetrics = BodyMetrics(),
    val progress: Float = 0f,                  // 0..1 of the whole sync
    val granted: Set<String> = emptySet(),
    val loading: Boolean = false,
    val loadingStage: Int = 0,                 // 1 workouts, 2 daily totals, 3 sleep/heart/body, 4 workout stats
    val enriching: Boolean = false,
    val statsDone: Int = 0,
    val statsTotal: Int = 0,
    val error: SyncError? = null,
    val status: HcStatus = HcStatus.Unavailable,
    val permitted: Boolean = false,
    val lastSync: Long = 0L,
    val ready: Boolean = false,                // saved data is loaded (never blocks the UI)
) {
    /** True while any part of a sync is running. */
    val syncing: Boolean get() = loading || enriching
}

/** Holds the app data and does the sync. Screens only read [state]. */
class HealthRepository(
    private val hc: HealthConnectManager,
    private val cache: CacheStore,
    private val scope: CoroutineScope,
) {
    private companion object {
        const val DAY_MS = 86_400_000L
    }

    private val _state = MutableStateFlow(HealthState())
    val state: StateFlow<HealthState> = _state.asStateFlow()

    // Original sessions from Health Connect, before merging duplicates
    private val rawLock = Any()
    private var raw: List<Workout> = emptyList()
    private val routes = ConcurrentHashMap<String, List<RoutePoint>>()
    private val running = AtomicBoolean(false) // only one sync at a time

    private fun setRaw(f: (List<Workout>) -> List<Workout>) = synchronized(rawLock) {
        raw = f(raw)
        val merged = ActivityMerger.merge(raw).sortedByDescending { it.start }
        _state.update { it.copy(workouts = merged) }
    }

    // ---- Start and permissions ----

    /** Loads saved data, then checks Health Connect. Call once at app start. It never throws. */
    suspend fun init() {
        try {
            cache.load()?.let { c ->
                setRaw { c.workouts }
                _state.update { it.copy(days = c.days, lastSync = c.lastSync, metrics = c.metrics) }
            }
            refreshStatus()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // The app opens with empty data and the user can sync again
        } finally {
            _state.update { it.copy(ready = true) }
        }
    }

    /** Health Connect status + permissions right now. Call again when the app comes back to the screen. */
    suspend fun refreshStatus() {
        val st = try { hc.status() } catch (e: Exception) { HcStatus.Unavailable }
        val g: Set<String> = if (st == HcStatus.Available) {
            try { hc.granted() } catch (e: CancellationException) { throw e } catch (e: Exception) { emptySet() }
        } else emptySet()
        _state.update { it.copy(status = st, granted = g, permitted = HealthPermissions.EXERCISE in g) }
    }

    /** Call with the result of the permission dialog. */
    fun onPermissionsResult(granted: Set<String>) {
        val g = granted.filter { it in HealthPermissions.ALL }.toSet()
        _state.update { it.copy(permitted = HealthPermissions.EXERCISE in g, granted = g) }
    }

    suspend fun heightCm(): Int = hc.heightCm()

    // ---- Sync ----

    fun sync() {
        val s = _state.value
        if (s.loading || !s.permitted || s.status != HcStatus.Available) return
        if (!running.compareAndSet(false, true)) return
        scope.launch {
            try {
                runSync()
            } finally {
                running.set(false)
                _state.update { it.copy(loading = false, loadingStage = 0, enriching = false) }
            }
        }
    }

    private fun progress(p: Float, stage: Int = -1) {
        _state.update { it.copy(progress = p.coerceIn(0f, 1f), loadingStage = if (stage >= 0) stage else it.loadingStage) }
    }

    private suspend fun runSync() {
        _state.update { it.copy(loading = true, loadingStage = 1, progress = 0.02f, error = null, statsDone = 0, statsTotal = 0) }
        val now = System.currentTimeMillis()
        try {
            // 1) All workouts, no stats yet: the list shows up at once (0 - 20 %)
            val sessions = withTimeout(90_000) { hc.sessions(0L, now) }
            val old = synchronized(rawLock) { raw.associateBy { it.id } }
            setRaw {
                sessions.map { n ->
                    val o = old[n.id]
                    if (o != null && o.statsDone && o.start == n.start && o.end == n.end) {
                        n.copy(distanceM = o.distanceM, kcal = o.kcal, steps = o.steps, hrAvg = o.hrAvg, hrMax = o.hrMax, hrMin = o.hrMin, statsDone = true)
                    } else n
                }
            }
            progress(0.2f, 2)

            // 2) Daily totals: steps, distance, calories (20 - 50 %)
            val earliest = sessions.minOfOrNull { it.start } ?: now
            val from = maxOf(now - 5 * 365 * DAY_MS, minOf(earliest, now - 365 * DAY_MS))
            val days = withTimeoutOrNull(180_000) { hc.daily(from, now) { f -> progress(0.2f + 0.3f * f) } } ?: emptyList()
            _state.update { it.copy(days = days.sortedBy { d -> d.epochDay }, lastSync = now) }
            progress(0.5f, 3)

            // 3) Sleep, resting heart rate, weight, HRV, oxygen, VO2 max (50 - 60 %)
            val metrics = withTimeoutOrNull(90_000) { hc.metrics() }
            if (metrics != null) _state.update { it.copy(metrics = metrics) }
            _state.update { it.copy(loading = false) }
            progress(0.6f)
            persist()

            // 4) Stats of each workout, newest first, in the background (60 - 100 %)
            enrich()
            persist()
            progress(1f)
        } catch (e: TimeoutCancellationException) {
            _state.update { it.copy(error = SyncError(timeout = true)) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            _state.update { it.copy(error = SyncError(timeout = false, detail = e.message ?: e.javaClass.simpleName)) }
        }
    }

    private suspend fun enrich() {
        val pending = synchronized(rawLock) { raw.filter { !it.statsDone }.sortedByDescending { it.start } }
        if (pending.isEmpty()) return
        _state.update { it.copy(enriching = true, loadingStage = 4, statsDone = 0, statsTotal = pending.size) }
        var done = 0
        for (chunk in pending.chunked(6)) {
            val results = coroutineScope {
                chunk.map { w -> async { withTimeoutOrNull(12_000) { hc.stats(w) } ?: w } }.awaitAll()
            }
            val byId = results.associateBy { it.id }
            setRaw { list -> list.map { byId[it.id] ?: it } }
            done += chunk.size
            _state.update { it.copy(statsDone = done) }
            progress(0.6f + 0.4f * done / pending.size)
        }
        _state.update { it.copy(enriching = false) }
    }

    private suspend fun persist() {
        val s = _state.value
        val list = synchronized(rawLock) { raw }
        cache.save(CacheData(list, s.days, s.lastSync, s.metrics))
    }

    // ---- Detail screen helpers ----

    /**
     * Route of a workout. Order: Health Connect (this copy, then the merged copies),
     * then Intervals.icu if set up, then ask the user's approval in Health Connect.
     */
    suspend fun route(w: Workout, intervals: IntervalsClient?): RouteResult {
        routes[w.id]?.let { return RouteResult.Data(it) }
        var consent: RouteResult.Consent? = null
        for (id in listOf(w.id) + w.alts) {
            when (val r = hc.route(id)) {
                is RouteResult.Data -> if (r.points.size >= 2) { routes[w.id] = r.points; return r }
                is RouteResult.Consent -> if (consent == null) consent = r
                RouteResult.None -> {}
            }
        }
        if (intervals != null) {
            val pts = intervals.route(w.start)
            if (pts != null) { routes[w.id] = pts; return RouteResult.Data(pts) }
        }
        return consent ?: RouteResult.None
    }

    /** Called after the user approved a route in the Health Connect dialog. */
    fun saveRoute(workoutId: String, points: List<RoutePoint>) {
        routes[workoutId] = points
    }

    fun pointsOf(route: androidx.health.connect.client.records.ExerciseRoute): List<RoutePoint> = hc.pointsOf(route)

    suspend fun heartRate(w: Workout): List<TimedValue> = hc.heartRate(w.start, w.end, w.source)
    suspend fun speed(w: Workout): List<TimedValue> = hc.speed(w.start, w.end, w.source)
    suspend fun power(w: Workout): List<TimedValue> = hc.power(w.start, w.end, w.source)

    suspend fun clearCache() {
        cache.clear()
        synchronized(rawLock) { raw = emptyList() }
        routes.clear()
        _state.update { it.copy(workouts = emptyList(), days = emptyList(), metrics = BodyMetrics(), lastSync = 0L, error = null) }
    }
}
