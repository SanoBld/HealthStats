package com.healthstats.app

import com.healthstats.app.data.health.ActivityMerger
import com.healthstats.app.data.model.Workout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ActivityMergerTest {
    private val t0 = 1_700_000_000_000L

    private fun w(id: String, src: String, start: Long, route: Boolean = false, dist: Double = 0.0) =
        Workout(id = id, type = 56, source = src, start = start, end = start + 1_800_000, hasRoute = route, distanceM = dist)

    @Test
    fun mergesCopiesAndKeepsOriginalApp() {
        val r = ActivityMerger.dedupe(
            listOf(
                w("a", "com.nothing.x", t0, dist = 5000.0),
                w("b", "com.strava", t0 + 120_000, route = true, dist = 5100.0),
            )
        )
        assertEquals(1, r.workouts.size)
        assertEquals("a", r.workouts[0].id)        // original app wins
        assertTrue(r.workouts[0].hasRoute)          // map comes from Strava
        assertEquals(listOf("b"), r.alternates["a"])
    }

    @Test
    fun keepsFarApartActivities() {
        val r = ActivityMerger.dedupe(listOf(w("a", "x", t0), w("b", "x", t0 + 3_600_000)))
        assertEquals(2, r.workouts.size)
    }
}
