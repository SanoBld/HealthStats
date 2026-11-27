package com.healthstats.app.data.local

import android.content.Context
import com.healthstats.app.data.model.BodyMetrics
import com.healthstats.app.data.model.DayStat
import com.healthstats.app.data.model.Workout
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File

@Serializable
data class CacheData(
    val workouts: List<Workout> = emptyList(),
    val days: List<DayStat> = emptyList(),
    val lastSync: Long = 0L,
    val metrics: BodyMetrics = BodyMetrics(),
)

/** Saves the last sync in one JSON file so the app opens with data at once. */
class CacheStore(ctx: Context) {
    private val file = File(ctx.filesDir, "cache.json")
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    suspend fun load(): CacheData? = withContext(Dispatchers.IO) {
        try {
            if (!file.exists()) null else json.decodeFromString(CacheData.serializer(), file.readText())
        } catch (e: Exception) {
            null // a broken file must never crash the app
        }
    }

    suspend fun save(data: CacheData) = withContext(Dispatchers.IO) {
        try {
            val tmp = File(file.parentFile, "cache.tmp")
            tmp.writeText(json.encodeToString(CacheData.serializer(), data))
            if (!tmp.renameTo(file)) {
                file.delete()
                tmp.renameTo(file)
            }
        } catch (e: Exception) {
            // not saving is not a problem: the next sync fills it again
        }
    }

    suspend fun clear() = withContext(Dispatchers.IO) {
        try { file.delete() } catch (e: Exception) { /* ignore */ }
    }
}
