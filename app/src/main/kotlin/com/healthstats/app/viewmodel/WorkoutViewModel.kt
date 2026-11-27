package com.healthstats.app.viewmodel

import androidx.health.connect.client.records.ExerciseRoute
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.healthstats.app.HealthStatsApp
import com.healthstats.app.data.AppContainer
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.data.model.RoutePoint
import com.healthstats.app.data.model.RouteResult
import com.healthstats.app.data.model.TimedValue
import com.healthstats.app.data.model.Workout
import com.healthstats.app.data.remote.IntervalsClient
import com.healthstats.app.util.ageYears
import com.healthstats.app.util.downsample
import com.healthstats.app.util.maxHrFor
import com.healthstats.app.util.zoneOf
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DetailState(
    val route: List<RoutePoint> = emptyList(),
    val routeLoading: Boolean = false,
    val consentId: String? = null,        // set when Android needs the user's approval for the route
    val hr: List<TimedValue> = emptyList(), // thinned, for the chart
    val zonesSec: List<Long> = emptyList(), // seconds in zone 1..5
    val maxHr: Int = 0,
)

/** Loads the route and the heart rate of one workout. */
class WorkoutViewModel(private val c: AppContainer, private val id: String) : ViewModel() {

    val workout: StateFlow<Workout?> = c.repository.state
        .map { s -> s.workouts.firstOrNull { it.id == id } }
        .stateIn(viewModelScope, SharingStarted.Eagerly, c.repository.state.value.workouts.firstOrNull { it.id == id })

    private val _detail = MutableStateFlow(DetailState())
    val detail: StateFlow<DetailState> = _detail.asStateFlow()

    init {
        viewModelScope.launch {
            val w = workout.filterNotNull().first()
            val settings = c.settings.flow.first()
            coroutineScope {
                launch { loadRoute(w, settings) }
                launch { loadHeartRate(w, settings) }
            }
        }
    }

    private suspend fun loadRoute(w: Workout, s: AppSettings) {
        _detail.update { it.copy(routeLoading = w.hasRoute) }
        val client = if (s.intervalsKey.isNotEmpty()) IntervalsClient(s.intervalsId, s.intervalsKey) else null
        when (val r = c.repository.route(w, client)) {
            is RouteResult.Data -> _detail.update { it.copy(route = r.points, routeLoading = false, consentId = null) }
            is RouteResult.Consent -> _detail.update { it.copy(routeLoading = false, consentId = r.sessionId) }
            RouteResult.None -> _detail.update { it.copy(routeLoading = false) }
        }
    }

    /** Called with what Android gives back after the user approved the route. */
    fun onConsentResult(route: ExerciseRoute?) {
        if (route == null) return
        val pts = c.repository.pointsOf(route)
        if (pts.size < 2) return
        c.repository.saveRoute(id, pts)
        _detail.update { it.copy(route = pts, consentId = null) }
    }

    private suspend fun loadHeartRate(w: Workout, s: AppSettings) {
        val samples = c.repository.heartRate(w)
        if (samples.size < 2) return
        val observedMax = samples.maxOf { it.value }.toInt()
        val maxHr = maxHrFor(ageYears(s.birthDate)).let { if (it > 0) it else maxOf(observedMax, 160) }
        val zones = LongArray(5)
        for (i in samples.indices) {
            val next = samples.getOrNull(i + 1)?.time ?: (samples[i].time + 5_000)
            val dt = ((next - samples[i].time) / 1000).coerceIn(0L, 30L)
            zones[zoneOf(samples[i].value, maxHr)] += dt
        }
        _detail.update { it.copy(hr = downsample(samples, 240), zonesSec = zones.toList(), maxHr = maxHr) }
    }

    companion object {
        fun factory(id: String) = viewModelFactory {
            initializer { WorkoutViewModel((this[APPLICATION_KEY] as HealthStatsApp).container, id) }
        }
    }
}
