package com.healthstats.app.data

import android.content.Context
import com.healthstats.app.data.health.HealthConnectManager
import com.healthstats.app.data.health.HealthRepository
import com.healthstats.app.data.local.CacheStore
import com.healthstats.app.data.local.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/** Creates the app's long-lived objects once. Screens get them from here. */
class AppContainer(ctx: Context) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val settings = SettingsStore(ctx)
    private val cache = CacheStore(ctx)
    private val hc = HealthConnectManager(ctx)
    val repository = HealthRepository(hc, cache, scope)
}
