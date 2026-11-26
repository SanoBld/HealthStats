package com.healthstats.app.viewmodel

import androidx.datastore.preferences.core.Preferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.healthstats.app.HealthStatsApp
import com.healthstats.app.data.AppContainer
import com.healthstats.app.data.health.HealthState
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.local.SettingsStore.Keys
import com.healthstats.app.data.local.ThemeMode
import com.healthstats.app.data.model.HcStatus
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** What the user typed in onboarding. */
data class OnboardingData(
    val name: String,
    val heightCm: Float,
    val weightKg: Float,
    val birthDate: String, // yyyy-MM-dd or empty
    val sex: String,
    val stepGoal: Int,
    val weeklyGoal: Int,
)

/** One ViewModel for the whole app: settings + health data + actions. */
class AppViewModel(private val c: AppContainer) : ViewModel() {

    /** null until the settings file is read. */
    val settings: StateFlow<AppSettings?> =
        c.settings.flow.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val health: StateFlow<HealthState> = c.repository.state

    /** True when settings and saved data are loaded (the splash screen waits for it). */
    val ready: StateFlow<Boolean> =
        combine(settings, health) { s, h -> s != null && h.ready }
            .stateIn(viewModelScope, SharingStarted.Eagerly, false)

    init {
        viewModelScope.launch {
            c.repository.init()
            autoSync()
        }
    }

    /** Sync when we have permission and the data is older than 5 minutes. */
    private fun autoSync() {
        val h = health.value
        if (!h.ready || !h.permitted) return
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

    fun onPermissionsResult(granted: Set<String>) = c.repository.onPermissionsResult(granted)

    /** Checks Health Connect, then calls [whenAvailable] (the screen then shows the permission dialog). */
    fun checkHealthConnect(onUnavailable: () -> Unit, whenAvailable: () -> Unit) {
        viewModelScope.launch {
            c.repository.refreshStatus()
            if (health.value.status == HcStatus.Available) whenAvailable() else onUnavailable()
        }
    }

    fun <T> set(key: Preferences.Key<T>, value: T) {
        viewModelScope.launch { c.settings.set(key, value) }
    }

    fun setThemeMode(m: ThemeMode) {
        viewModelScope.launch { c.settings.setThemeMode(m) }
    }

    fun finishOnboarding(d: OnboardingData) {
        viewModelScope.launch {
            val s = c.settings
            s.set(Keys.NAME, d.name)
            s.set(Keys.HEIGHT, d.heightCm)
            s.set(Keys.WEIGHT, d.weightKg)
            s.set(Keys.BIRTH, d.birthDate)
            s.set(Keys.SEX, d.sex)
            s.set(Keys.STEP_GOAL, d.stepGoal)
            s.set(Keys.WEEKLY_GOAL, d.weeklyGoal)
            s.set(Keys.ONBOARDED, true)
            autoSync()
        }
    }

    companion object {
        val Factory = viewModelFactory {
            initializer { AppViewModel((this[APPLICATION_KEY] as HealthStatsApp).container) }
        }
    }
}
