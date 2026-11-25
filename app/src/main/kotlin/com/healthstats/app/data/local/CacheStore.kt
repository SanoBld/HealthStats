package com.healthstats.app.data.local

import com.healthstats.app.data.model.DayStat
import com.healthstats.app.data.model.RoutePoint
import com.healthstats.app.data.model.Workout
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File

/** One JSON config for the whole app. NaN is allowed (GPS altitude can be unknown). */
val HsJson = Json {
    ignoreUnknownKeys = true
    allowSpecialFloatingPointValues = true
    encodeDefaults = true
}

@Serializable
data class CacheData(
    val workouts: List<Workout> = emptyList(),
    val days: List<DayStat> = emptyList(),
    val lastSync: Long = 0L,
    val statsOk: Set<String> = emptySet(),        // sessions whose stats are already saved
    val hrGeneral: Set<String> = emptySet(),      // sessions whose heart rate comes from general heart-rate data
    val hrChecked: Map<String, Long> = emptyMap(), // session id -> last time we looked for general heart rate
)

@Serializable
data class TrackData(
    val tracks: Map<String, List<RoutePoint>> = emptyMap(),
    val noTrack: Set<String> = emptySet(),         // sessions with no readable route
)

/** Saves activities and GPS previews as JSON files in the app folder. */
class CacheStore(private val dir: File) {
    private val mutex = Mutex()
    private val cacheFile get() = File(dir, "hs_cache.json")
    private val trackFile get() = File(dir, "hs_tracks.json")

    private suspend inline fun <reified T> read(f: File): T? = withContext(Dispatchers.IO) {
        mutex.withLock {
            try {
                if (f.exists()) HsJson.decodeFromString<T>(f.readText()) else null
            } catch (e: Exception) { null } // corrupt file: start clean
        }
    }

    private suspend inline fun <reified T> write(f: File, data: T) = withContext(Dispatchers.IO) {
        mutex.withLock {
            try {
                // Write to a temp file first, so a crash never leaves a half-written file
                val tmp = File(f.parentFile, f.name + ".tmp")
                tmp.writeText(HsJson.encodeToString(data))
                if (!tmp.renameTo(f)) { f.delete(); tmp.renameTo(f) }
            } catch (e: Exception) { /* cache is best effort */ }
        }
    }

    suspend fun loadCache(): CacheData? = read<CacheData>(cacheFile)
    suspend fun saveCache(d: CacheData) = write(cacheFile, d)
    suspend fun loadTracks(): TrackData? = read<TrackData>(trackFile)
    suspend fun saveTracks(d: TrackData) = write(trackFile, d)

    /** Sizes in bytes: (activities, tracks). */
    suspend fun sizes(): Pair<Long, Long> = withContext(Dispatchers.IO) { cacheFile.length() to trackFile.length() }

    suspend fun clearTracks() = withContext(Dispatchers.IO) { mutex.withLock { trackFile.delete() }; Unit }
    suspend fun clearActivities() = withContext(Dispatchers.IO) { mutex.withLock { cacheFile.delete() }; Unit }
    suspend fun clearAll() { clearTracks(); clearActivities() }
}
