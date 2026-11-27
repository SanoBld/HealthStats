package com.healthstats.app

import com.healthstats.app.data.health.ActivityMerger
import com.healthstats.app.data.model.Workout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ActivityMergerTest {

    private fun w(id: String, source: String, start: Long, route: Boolean = false, dist: Double = 0.0) =
        Workout(id = id, type = 56, source = source, start = start, end = start + 1_800_000, hasRoute = route, distanceM = dist)

    @Test
    fun sameRunFromTwoAppsIsMerged() {
        val list = listOf(
            w("a", "com.nothing.nothingx", 1_000_000, dist = 5000.0),
            w("b", "com.strava", 1_000_000 + 120_000, route = true),
        )
        val out = ActivityMerger.merge(list)
        assertEquals(1, out.size)
        assertEquals("a", out[0].id)          // original app wins
        assertTrue(out[0].hasRoute)           // route taken from the other copy
        assertEquals(listOf("b"), out[0].alts)
    }

    @Test
    fun farApartWorkoutsStaySeparate() {
        val list = listOf(w("a", "x", 0), w("b", "y", 3 * 3_600_000L))
        assertEquals(2, ActivityMerger.merge(list).size)
    }

    @Test
    fun sameSourceIsNeverMerged() {
        val list = listOf(w("a", "x", 0), w("b", "x", 60_000))
        assertEquals(2, ActivityMerger.merge(list).size)
    }
}
