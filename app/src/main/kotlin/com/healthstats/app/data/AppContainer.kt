package com.healthstats.app.data

import android.app.Application
import com.healthstats.app.data.health.HealthConnectManager
import com.healthstats.app.data.health.HealthRepository
import com.healthstats.app.data.local.CacheStore
import com.healthstats.app.data.local.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/** Creates the shared objects once (poor man's dependency injection). */
class AppContainer(app: Application) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val settings = SettingsStore(app)
    val cache = CacheStore(app.filesDir)
    val healthConnect = HealthConnectManager(app)
    val repository = HealthRepository(healthConnect, cache, settings, scope)
}
