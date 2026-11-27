package com.healthstats.app.ui.navigation

import android.net.Uri

object Routes {
    const val Onboarding = "onboarding"
    const val Home = "home"
    const val Activities = "activities"
    const val Charts = "charts"
    const val Settings = "settings"
    const val Detail = "workout/{id}"

    fun detail(id: String) = "workout/" + Uri.encode(id)
}
