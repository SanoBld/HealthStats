package com.healthstats.app.data.health

import com.healthstats.app.data.model.Workout
import kotlin.math.abs

/**
 * Merges the same activity written by several apps (Nothing X, Strava, Google Fit...).
 * Rule: same sport family and start within 10 minutes = same activity.
 * The app that created the activity wins, then Google Fit, Strava, Intervals, files.
 * Missing data (map, distance, heart rate...) is filled from the other copies.
 */
object ActivityMerger {

    class Result(val workouts: List<Workout>, val alternates: Map<String, List<String>>)

    private const val WINDOW_MS = 10 * 60_000L

    /** Lower = closer to the original app. */
    private fun rank(s: String): Int = when {
        s == "com.strava" -> 3
        s == "intervals" -> 4
        s == "import" -> 5
        s.isEmpty() || s == "com.google.android.apps.fitness" || s == "com.google.android.apps.healthdata" -> 2
        else -> 0
    }

    private fun family(t: Int): Int = when (t) {
        56, 57 -> 1   // running, treadmill
        79, 37 -> 2   // walking, hiking
        8, 9 -> 3     // cycling, stationary bike
        74, 73 -> 4   // swimming, open water
        else -> t
    }

    private fun sameSport(a: Workout, b: Workout) = a.type == 0 || b.type == 0 || family(a.type) == family(b.type)

    private fun score(w: Workout) =
        (if (w.hasRoute) 4 else 0) + (if (w.distanceM > 0) 2 else 0) + (if (w.hrAvg > 0) 2 else 0) + (if (w.kcal > 0) 1 else 0)

    fun dedupe(list: List<Workout>): Result {
        val sorted = list.sortedBy { it.start }
        val groups = ArrayList<MutableList<Workout>>()
        for (w in sorted) {
            var g: MutableList<Workout>? = null
            var i = groups.size - 1
            while (i >= 0 && i >= groups.size - 6) {
                if (groups[i].any { abs(it.start - w.start) <= WINDOW_MS && sameSport(it, w) }) { g = groups[i]; break }
                i--
            }
            if (g == null) groups.add(mutableListOf(w)) else g.add(w)
        }
        val alt = HashMap<String, List<String>>()
        val out = groups.map { g ->
            if (g.size == 1) g.first() else merge(g, alt)
        }
        return Result(out, alt)
    }

    private fun merge(group: List<Workout>, alt: MutableMap<String, List<String>>): Workout {
        val g = group.sortedWith(compareBy<Workout>({ rank(it.source) }, { -score(it) }))
        val p = g.first()
        fun pick(f: (Workout) -> Double): Double = g.map(f).firstOrNull { it > 0 } ?: 0.0
        alt[p.id] = g.drop(1).map { it.id }
        return p.copy(
            type = if (p.type != 0) p.type else (g.firstOrNull { it.type != 0 }?.type ?: p.type),
            title = g.map { it.title }.firstOrNull { it.isNotEmpty() } ?: "",
            notes = g.map { it.notes }.firstOrNull { it.isNotEmpty() } ?: "",
            hasRoute = g.any { it.hasRoute },
            distanceM = pick { it.distanceM },
            activeKcal = pick { it.activeKcal },
            totalKcal = pick { it.totalKcal },
            steps = g.map { it.steps }.firstOrNull { it > 0 } ?: 0,
            hrAvg = pick { it.hrAvg },
            hrMax = pick { it.hrMax },
            hrMin = pick { it.hrMin },
            segments = g.map { it.segments }.firstOrNull { it.isNotEmpty() } ?: emptyList(),
        )
    }
}
