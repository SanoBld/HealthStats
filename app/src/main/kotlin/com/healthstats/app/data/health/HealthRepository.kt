package com.healthstats.app.data.health

import androidx.health.connect.client.records.ExerciseRoute
import com.healthstats.app.data.local.CacheData
import com.healthstats.app.data.local.CacheStore
import com.healthstats.app.data.local.SettingsStore
import com.healthstats.app.data.model.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

enum class SyncStage { Idle, ReadingActivities, ComputingStats, Totals, History }

/** What the loader shows. Text is built by the screen (so it can be translated). */
data class SyncProgress(
    val stage: SyncStage = SyncStage.Idle,
    val done: Int = 0,
    val total: Int = 0,
    val year: Int = 0,
    val fraction: Float? = null, // null = unknown
)

data class SyncError(val kind: Kind, val detail: String? = null) {
    enum class Kind { Timeout, PartialStats, Other }
}

data class HealthState(
    val workouts: List<Workout> = emptyList(), // merged, newest first
    val days: List<DayStat> = emptyList(),     // oldest first
    val loading: Boolean = false,
    val progress: SyncProgress = SyncProgress(),
    val error: SyncError? = null,
    val status: HcStatus = HcStatus.Unavailable,
    val grantedPerms: Set<String> = emptySet(),
    val lastSync: Long = 0L,
    val appInfo: Map<String, AppInfo> = emptyMap(),
    val tracks: Map<String, List<RoutePoint>> = emptyMap(), // small route previews
    val hrGeneral: Set<String> = emptySet(),
    val ready: Boolean = false, // saved data is loaded
) {
    val permitted: Boolean get() = grantedPerms.isNotEmpty()
    val hasRoutePerm: Boolean get() = hasPerm("READ_EXERCISE_ROUTE")
    fun hasPerm(name: String): Boolean = grantedPerms.any { it.endsWith(name) }
    fun sourceName(pkg: String): String = sourceLabel(pkg, appInfo[pkg]?.label)
}

/** Holds the app data and does the sync. Screens only read [state]. */
class HealthRepository(
    private val hc: HealthConnectManager,
    private val cache: CacheStore,
    private val settings: SettingsStore,
    private val scope: CoroutineScope,
) {
    companion object {
        const val ALL_DAYS = 365 * 30
        private const val DAY_MS = 86_400_000L
    }

    private val _state = MutableStateFlow(HealthState())
    val state: StateFlow<HealthState> = _state.asStateFlow()

    // Original sessions from Health Connect (before merging duplicates)
    private val rawLock = Any()
    private var raw: List<Workout> = emptyList()
    private var alternates: Map<String, List<String>> = emptyMap()
    private val statsOk = ConcurrentHashMap.newKeySet<String>()
    private val hrChecked = ConcurrentHashMap<String, Long>()
    private val noTrack = ConcurrentHashMap.newKeySet<String>()

    private val running = AtomicBoolean(false) // only one sync at a time

    private class SyncTimeout : Exception()

    /** Ids of the other copies merged into [id]. */
    fun mergedWith(id: String): List<String> = alternates[id].orEmpty()

    private fun setRaw(f: (List<Workout>) -> List<Workout>) = synchronized(rawLock) {
        raw = f(raw)
        val m = ActivityMerger.dedupe(raw)
        alternates = m.alternates
        val sorted = m.workouts.sortedByDescending { it.start }
        _state.update { it.copy(workouts = sorted) }
    }

    // ---- Start and permissions ----

    /** Loads saved data, then checks Health Connect. Call once at app start. */
    suspend fun init() {
        val c = cache.loadCache()
        if (c != null) {
            statsOk.addAll(c.statsOk)
            hrChecked.putAll(c.hrChecked)
            setRaw { c.workouts }
            _state.update { it.copy(days = c.days, lastSync = c.lastSync, hrGeneral = c.hrGeneral) }
        }
        cache.loadTracks()?.let { t ->
            noTrack.addAll(t.noTrack)
            _state.update { it.copy(tracks = t.tracks) }
        }
        refreshStatus()
        _state.update { it.copy(ready = true) }
    }

    /** Status of Health Connect + permissions granted right now. Call again when the app comes back to the screen. */
    suspend fun refreshStatus() {
        val st = hc.status()
        val granted = if (st == HcStatus.Available) {
            try { hc.granted() } catch (e: Exception) { emptySet() }
        } else emptySet()
        _state.update { it.copy(status = st, grantedPerms = granted) }
    }

    /** Call with the result of the permission dialog. */
    fun onPermissionsResult(granted: Set<String>) {
        _state.update { it.copy(grantedPerms = granted.filter { p -> p in HealthPermissions.ALL }.toSet()) }
    }

    // ---- Sync ----

    fun sync(daysBack: Int = ALL_DAYS) {
        val s = _state.value
        if (s.loading || !s.permitted) return
        if (!running.compareAndSet(false, true)) return
        scope.launch { doSync(daysBack) }
    }

    private fun progress(p: SyncProgress) = _state.update { it.copy(progress = p) }

    private suspend fun doSync(daysBack: Int) {
        _state.update { it.copy(loading = true, error = null, progress = SyncProgress(SyncStage.ReadingActivities)) }
        try {
            val end = System.currentTimeMillis()
            val start = end - daysBack.toLong() * DAY_MS

            // 1) quick list without stats: the screen shows it at once
            val lite = withTimeoutOrNull(45_000) { hc.sessions(start, end, true) } ?: throw SyncTimeout()
            setRaw { old ->
                val oldById = old.associateBy { it.id }
                val ids = lite.map { it.id }.toSet()
                lite.map { oldById[it.id] ?: it } + old.filter { it.id !in ids } // saved activities stay
            }
            progress(SyncProgress(SyncStage.ComputingStats, 0, raw.size, fraction = 0.4f))

            // 2) stats, newest first, 25 sessions at a time (the screen updates after each group)
            val need = raw.filter { it.id !in statsOk }.sortedByDescending { it.start }
            var fails = 0
            var i = 0
            while (i < need.size && fails < 2) {
                val g = need.subList(i, minOf(i + 25, need.size))
                try {
                    val ws = withTimeoutOrNull(60_000) {
                        hc.sessions(g.last().start - 1000, g.first().end + 1000, false)
                    } ?: throw SyncTimeout()
                    val byId = ws.associateBy { it.id }
                    setRaw { cur -> cur.map { byId[it.id] ?: it } }
                    ws.forEach { statsOk.add(it.id); hrChecked.remove(it.id) }
                    _state.update { it.copy(hrGeneral = it.hrGeneral - byId.keys) }
                    fails = 0
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    fails++
                    _state.update { it.copy(error = SyncError(SyncError.Kind.PartialStats, e.message)) }
                }
                i += 25
                val done = minOf(i, need.size)
                progress(SyncProgress(SyncStage.ComputingStats, done, need.size, fraction = 0.4f + 0.4f * done / need.size))
            }
            progress(SyncProgress(SyncStage.Totals, fraction = 0.8f))

            // 3) daily totals: last year first, then each older year (stops after 5 empty years in a row)
            try {
                val byDay = _state.value.days.associateBy { it.day }.toMutableMap()
                var hi = LocalDate.now()
                var empty = 0
                var y = 0
                val zone = ZoneId.systemDefault()
                while (y < 100 && empty < 5) {
                    val lo = hi.minusYears(1)
                    progress(SyncProgress(SyncStage.History, year = lo.year, fraction = 0.8f))
                    val ds = hc.daily(
                        lo.atStartOfDay(zone).toInstant().toEpochMilli(),
                        hi.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli(),
                    )
                    var any = false
                    for (d in ds) { byDay[d.day] = d; if (d.steps > 0 || d.hrAvg > 0) any = true }
                    empty = if (any) 0 else empty + 1
                    val sortedDays = byDay.values.sortedBy { it.day }
                    _state.update { it.copy(days = sortedDays) } // the screen already shows this period
                    hi = lo
                    y++
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) { /* totals are optional */ }

            _state.update { it.copy(lastSync = System.currentTimeMillis()) }
            saveCache()
            scope.launch { fillHeight() }
            scope.launch { fillMissingHr() }
            scope.launch { loadAppInfo() }
            scope.launch { loadTracks(_state.value.workouts.filter { it.hasRoute }.take(60)) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: SyncTimeout) {
            _state.update { it.copy(error = SyncError(SyncError.Kind.Timeout)) }
        } catch (e: Exception) {
            _state.update { it.copy(error = SyncError(SyncError.Kind.Other, e.message ?: e.toString())) }
        } finally {
            _state.update { it.copy(loading = false, progress = SyncProgress()) }
            running.set(false)
        }
    }

    private suspend fun saveCache() {
        val s = _state.value
        val rawNow = synchronized(rawLock) { raw }
        cache.saveCache(
            CacheData(rawNow, s.days, s.lastSync, statsOk.toSet(), s.hrGeneral, hrChecked.toMap())
        )
    }

    private suspend fun saveTracks() {
        cache.saveTracks(com.healthstats.app.data.local.TrackData(_state.value.tracks, noTrack.toSet()))
    }

    // ---- Extras filled after a sync ----

    /** Reads name + icon of the source apps (only the ones not loaded yet). */
    private suspend fun loadAppInfo() {
        val have = _state.value.appInfo.keys
        val pkgs = synchronized(rawLock) { raw }.map { it.source }.filter { it.isNotEmpty() && it !in have }.distinct()
        if (pkgs.isEmpty()) return
        try {
            val infos = hc.appInfo(pkgs)
            _state.update { it.copy(appInfo = it.appInfo + infos.associateBy { i -> i.pkg }) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) { /* names are optional */ }
    }

    /** Takes the height from Health Connect if the user has not set one. */
    private suspend fun fillHeight() {
        try {
            if (settings.current().heightCm > 0f) return
            val h = hc.height()
            if (h > 0) settings.set(SettingsStore.Keys.HEIGHT, h.toFloat())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) { /* optional */ }
    }

    /** For sessions without heart rate, uses the phone's general heart-rate data (max [max] sessions per call). */
    suspend fun fillMissingHr(max: Int = 40) {
        val now = System.currentTimeMillis()
        val todo = _state.value.workouts
            .filter { it.hrAvg <= 0 && (now - (hrChecked[it.id] ?: 0L)) > DAY_MS }
            .take(max)
        if (todo.isEmpty()) return
        for (w in todo) {
            try {
                val hr = hc.heartRate(w.start, w.end)
                hrChecked[w.id] = now
                if (hr.isNotEmpty()) {
                    val vals = hr.map { it.value }
                    setRaw { cur ->
                        cur.map {
                            if (it.id == w.id) it.copy(hrAvg = vals.average(), hrMax = vals.max(), hrMin = vals.min()) else it
                        }
                    }
                    _state.update { it.copy(hrGeneral = it.hrGeneral + w.id) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) { /* skip this one */ }
        }
        saveCache()
    }

    // ---- GPS ----

    /** Small route previews for the list. Sessions that need approval are skipped (no pop-up). */
    suspend fun loadTracks(ws: List<Workout>) {
        var changed = false
        for (w in ws) {
            if (_state.value.tracks.containsKey(w.id) || noTrack.contains(w.id)) continue
            try {
                when (val r = hc.route(w.id, 60)) {
                    is RouteResult.Data -> {
                        if (r.points.size > 1) {
                            _state.update { it.copy(tracks = it.tracks + (w.id to r.points)) }
                        } else noTrack.add(w.id)
                    }
                    else -> noTrack.add(w.id)
                }
                changed = true
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) { /* try again next time */ }
        }
        if (changed) saveTracks()
    }

    /** Full route for the detail screen. May return ConsentRequired: the screen then shows the Health Connect dialog. */
    suspend fun route(id: String): RouteResult = try {
        hc.route(id)
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) { RouteResult.None }

    /** Turns the route given by the consent dialog into points. */
    fun pointsOf(route: ExerciseRoute): List<RoutePoint> = hc.pointsOf(route)

    // ---- Curves and metrics (read when a screen needs them) ----

    suspend fun heartRate(w: Workout): List<TimedValue> = try {
        hc.heartRate(w.start, w.end)
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) { emptyList() }

    suspend fun samples(kind: SampleKind, w: Workout): List<TimedValue> = hc.samples(kind, w.start, w.end)

    suspend fun metric(type: MetricType, days: Int = ALL_DAYS): List<TimedValue> {
        val end = System.currentTimeMillis()
        return hc.metric(type, end - days.toLong() * DAY_MS, end)
    }

    suspend fun sleep(days: Int = ALL_DAYS): List<SleepSession> {
        val end = System.currentTimeMillis()
        return hc.sleep(end - days.toLong() * DAY_MS, end)
    }

    // ---- Cache screen ----

    suspend fun cacheSizes(): Pair<Long, Long> = cache.sizes()

    suspend fun clearTracks() {
        cache.clearTracks()
        noTrack.clear()
        _state.update { it.copy(tracks = emptyMap()) }
    }

    suspend fun clearActivities() {
        cache.clearActivities()
        statsOk.clear(); hrChecked.clear()
        setRaw { emptyList() }
        _state.update { it.copy(days = emptyList(), lastSync = 0L, hrGeneral = emptySet()) }
    }

    suspend fun clearCache() {
        clearActivities()
        clearTracks()
    }
}
