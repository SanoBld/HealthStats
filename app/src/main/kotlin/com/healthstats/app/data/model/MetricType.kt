package com.healthstats.app.data.model

import androidx.annotation.StringRes
import com.healthstats.app.R

/** What the charts screen can draw. */
enum class ChartMetric(@StringRes val label: Int) {
    Steps(R.string.charts_steps),
    Kcal(R.string.charts_kcal),
    Distance(R.string.charts_distance),
    Workouts(R.string.charts_workouts),
    Heart(R.string.charts_hr),
}
