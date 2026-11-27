package com.healthstats.app.viewmodel

import androidx.datastore.preferences.core.Preferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.healthstats.app.HealthStatsApp
import com.healthstats.app.data.AppContainer
import com.healthstats.app.data.health.HealthPermissions
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.local.SettingsStore.Keys
import com.healthstats.app.data.model.HcStatus
import com.healthstats.app.data.remote.IntervalsClient
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** One ViewModel for the whole app: settings + health data + actions. */
class AppViewModel(private val c: AppContainer) : ViewModel() {

    /** null until the settings file is read (the splash screen waits for this only). */
    val settings: StateFlow<AppSettings?> =
        c.settings.flow.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val health: StateFlow<HealthState> = c.repository.state

    init {
        viewModelScope.launch {
            c.repository.init()
            autoSync()
        }
    }

    /** Sync when we have permission and the data is older than 5 minutes. */
    private fun autoSync() {
        val h = health.value
        if (!h.permitted || h.status != HcStatus.Available) return
        if (h.lastSync == 0L || System.currentTimeMillis() - h.lastSync > 5 * 60_000L) c.repository.sync()
    }

    /** Call each time the app comes back to the screen. */
    fun onResume() {
        viewModelScope.launch {
            c.repository.refreshStatus()
            autoSync()
        }
    }

    fun sync() = c.repository.sync()

    /** Checks Health Connect, then tells the screen what to do next. */
    fun checkHealthConnect(result: (HcStatus) -> Unit) {
        viewModelScope.launch {
            c.repository.refreshStatus()
            result(health.value.status)
        }
    }

    /** Result of the Android permission dialog. */
    fun onPermissions(granted: Set<String>) {
        c.repository.onPermissionsResult(granted)
        if (HealthPermissions.EXERCISE in granted) {
            viewModelScope.launch {
                // Pre-fill the height from Health Connect if the user did not type one
                if ((settings.value?.heightCm ?: 0) == 0) {
                    val h = c.repository.heightCm()
                    if (h > 0) c.settings.set(Keys.HEIGHT, h)
                }
                c.repository.sync()
            }
        }
    }

    fun <T> set(key: Preferences.Key<T>, value: T) {
        viewModelScope.launch { c.settings.set(key, value) }
    }

    fun finishOnboarding(name: String, heightCm: Int, birthDate: String) {
        viewModelScope.launch {
            c.settings.set(Keys.NAME, name.trim())
            if (heightCm > 0) c.settings.set(Keys.HEIGHT, heightCm)
            c.settings.set(Keys.BIRTH, birthDate)
            c.settings.set(Keys.ONBOARDED, true)
        }
    }

    fun clearCache() {
        viewModelScope.launch { c.repository.clearCache() }
    }

    suspend fun testIntervals(id: String, key: String): Boolean = IntervalsClient(id, key).test()

    companion object {
        val Factory = viewModelFactory {
            initializer { AppViewModel((this[APPLICATION_KEY] as HealthStatsApp).container) }
        }
    }
}
