package com.healthstats.app.data.remote

import android.util.Base64
import com.healthstats.app.data.model.RoutePoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.math.abs

/** Small client for Intervals.icu (backup source for GPS routes). Auth = basic, user "API_KEY". */
class IntervalsClient(athleteId: String, private val apiKey: String) {

    private val id = athleteId.trim().ifEmpty { "0" }
    private val base = "https://intervals.icu/api/v1"

    private fun get(path: String): String {
        val c = URL(base + path).openConnection() as HttpURLConnection
        try {
            c.connectTimeout = 15_000
            c.readTimeout = 20_000
            val token = Base64.encodeToString("API_KEY:$apiKey".toByteArray(), Base64.NO_WRAP)
            c.setRequestProperty("Authorization", "Basic $token")
            c.setRequestProperty("Accept", "application/json")
            if (c.responseCode != 200) error("HTTP ${c.responseCode}")
            return c.inputStream.bufferedReader().use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    /** True if the ID and the key work. */
    suspend fun test(): Boolean = withContext(Dispatchers.IO) {
        try { get("/athlete/$id"); true } catch (e: Exception) { false }
    }

    private fun parseTime(s: String?): Long? {
        if (s.isNullOrEmpty()) return null
        return try {
            Instant.parse(s).toEpochMilli()
        } catch (e: Exception) {
            try { LocalDateTime.parse(s).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli() } catch (e2: Exception) { null }
        }
    }

    /** GPS route of the activity that starts near [startMs] (within 10 minutes), or null. */
    suspend fun route(startMs: Long): List<RoutePoint>? = withContext(Dispatchers.IO) {
        try {
            val zone = ZoneId.systemDefault()
            val day = Instant.ofEpochMilli(startMs).atZone(zone).toLocalDate()
            val oldest = day.minusDays(1)
            val newest = day.plusDays(1)
            val list = Json.parseToJsonElement(get("/athlete/$id/activities?oldest=$oldest&newest=$newest")).jsonArray
            val match = list.map { it.jsonObject }.firstOrNull { a ->
                val t = parseTime(a["start_date"]?.jsonPrimitive?.contentOrNull)
                    ?: parseTime(a["start_date_local"]?.jsonPrimitive?.contentOrNull)
                t != null && abs(t - startMs) <= 10 * 60_000L
            } ?: return@withContext null
            val actId = match["id"]?.jsonPrimitive?.contentOrNull ?: return@withContext null
            val streams = Json.parseToJsonElement(get("/activity/$actId/streams.json?types=latlng,time")).jsonArray
            fun stream(type: String): JsonObject? =
                streams.map { it.jsonObject }.firstOrNull { it["type"]?.jsonPrimitive?.contentOrNull == type }
            val ll = stream("latlng") ?: return@withContext null
            val lat = (ll["data"] as? JsonArray)?.map { it.jsonPrimitive.doubleOrNull } ?: return@withContext null
            val lng = (ll["data2"] as? JsonArray)?.map { it.jsonPrimitive.doubleOrNull } ?: return@withContext null
            val secs = (stream("time")?.get("data") as? JsonArray)?.map { it.jsonPrimitive.doubleOrNull }
            val out = ArrayList<RoutePoint>()
            for (i in 0 until minOf(lat.size, lng.size)) {
                val a = lat[i]
                val b = lng[i]
                if (a == null || b == null) continue
                val sec = secs?.getOrNull(i)
                out.add(RoutePoint(a, b, Double.NaN, if (sec != null) startMs + (sec * 1000).toLong() else 0L))
            }
            if (out.size >= 2) out else null
        } catch (e: Exception) {
            null
        }
    }
}
