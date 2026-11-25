package com.healthstats.app

import android.app.Application
import com.healthstats.app.data.AppContainer

// App class: creates the shared objects (settings, cache, Health Connect, repository)
class HealthStatsApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
