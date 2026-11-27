package com.healthstats.app.data.health

import com.healthstats.app.data.model.Workout
import kotlin.math.abs

/**
 * Merges the same activity written by several apps (Nothing X, Strava, Google Fit...).
 * Rule: same sport family + start within 10 minutes + different source = same activity.
 * The app that created it wins, then Strava, then Google Fit.
 * Missing data (map, distance, heart rate...) is taken from the other copies.
 */
object ActivityMerger {

    private const val WINDOW_MS = 10 * 60_000L

    /** Lower = closer to the original app. */
    private fun rank(source: String): Int = when (source) {
        "com.strava" -> 1
        "", "com.google.android.apps.fitness", "com.google.android.apps.healthdata" -> 2
        else -> 0
    }

    private fun family(t: Int): Int = when (t) {
        56, 57 -> 1 // running, treadmill
        79, 37 -> 2 // walking, hiking
        8, 9 -> 3   // cycling, stationary bike
        74, 73 -> 4 // swimming
        else -> t
    }

    private fun sameSport(a: Workout, b: Workout) =
        a.type == 0 || b.type == 0 || family(a.type) == family(b.type)

    private fun score(w: Workout) =
        (if (w.hasRoute) 4 else 0) + (if (w.distanceM > 0) 2 else 0) + (if (w.hrAvg > 0) 2 else 0) + (if (w.kcal > 0) 1 else 0)

    private fun matches(group: List<Workout>, w: Workout) = group.any {
        it.source != w.source && abs(it.start - w.start) <= WINDOW_MS && sameSport(it, w)
    }

    fun merge(list: List<Workout>): List<Workout> {
        val groups = ArrayList<MutableList<Workout>>()
        for (w in list.sortedBy { it.start }) {
            var target: MutableList<Workout>? = null
            var i = groups.size - 1
            while (i >= 0 && i >= groups.size - 8) {
                if (matches(groups[i], w)) { target = groups[i]; break }
                i--
            }
            if (target == null) groups.add(mutableListOf(w)) else target.add(w)
        }
        return groups.map { if (it.size == 1) it.first() else combine(it) }
    }

    private fun combine(group: List<Workout>): Workout {
        val g = group.sortedWith(compareBy<Workout>({ rank(it.source) }, { -score(it) }))
        val p = g.first()
        val others = g.drop(1)
        fun pickD(f: (Workout) -> Double): Double = g.map(f).firstOrNull { it > 0 } ?: 0.0
        fun pickI(f: (Workout) -> Int): Int = g.map(f).firstOrNull { it > 0 } ?: 0
        return p.copy(
            type = if (p.type != 0) p.type else (g.firstOrNull { it.type != 0 }?.type ?: 0),
            title = g.map { it.title }.firstOrNull { it.isNotEmpty() } ?: "",
            notes = g.map { it.notes }.firstOrNull { it.isNotEmpty() } ?: "",
            hasRoute = g.any { it.hasRoute },
            distanceM = pickD { it.distanceM },
            kcal = pickD { it.kcal },
            steps = pickI { it.steps },
            hrAvg = pickI { it.hrAvg },
            hrMax = pickI { it.hrMax },
            hrMin = pickI { it.hrMin },
            statsDone = g.all { it.statsDone },
            alts = others.map { it.id },
            altSources = others.map { it.source }.filter { it != p.source }.distinct(),
        )
    }
}
