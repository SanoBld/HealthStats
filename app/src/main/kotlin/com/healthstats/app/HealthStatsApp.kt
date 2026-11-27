package com.healthstats.app

import android.app.Application
import com.healthstats.app.data.AppContainer
import org.osmdroid.config.Configuration
import java.io.File

class HealthStatsApp : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        // OpenStreetMap needs a user agent, and the map cache goes in the app cache folder (no storage permission)
        Configuration.getInstance().apply {
            userAgentValue = packageName
            osmdroidBasePath = File(cacheDir, "osmdroid")
            osmdroidTileCache = File(cacheDir, "osmdroid/tiles")
        }
    }
}
