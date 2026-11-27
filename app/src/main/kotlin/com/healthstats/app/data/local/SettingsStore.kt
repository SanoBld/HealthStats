package com.healthstats.app.data.local

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "settings")

enum class ThemeMode { System, Light, Dark }

data class AppSettings(
    val onboarded: Boolean = false,
    val name: String = "",
    val heightCm: Int = 0,
    val birthDate: String = "", // yyyy-MM-dd or empty
    val stepGoal: Int = 8000,
    val weeklyGoal: Int = 4,
    val theme: ThemeMode = ThemeMode.System,
    val dynamicColor: Boolean = true,
    val sportColors: Boolean = true,
    val intervalsId: String = "0",
    val intervalsKey: String = "",
)

class SettingsStore(private val ctx: Context) {

    object Keys {
        val ONBOARDED = booleanPreferencesKey("onboarded")
        val NAME = stringPreferencesKey("name")
        val HEIGHT = intPreferencesKey("height_cm")
        val BIRTH = stringPreferencesKey("birth_date")
        val STEP_GOAL = intPreferencesKey("step_goal")
        val WEEKLY_GOAL = intPreferencesKey("weekly_goal")
        val THEME = intPreferencesKey("theme")
        val DYNAMIC = booleanPreferencesKey("dynamic_color")
        val SPORT_COLORS = booleanPreferencesKey("sport_colors")
        val INTERVALS_ID = stringPreferencesKey("intervals_id")
        val INTERVALS_KEY = stringPreferencesKey("intervals_key")
    }

    val flow: Flow<AppSettings> = ctx.dataStore.data
        .catch { emit(emptyPreferences()) }
        .map { p ->
            val d = AppSettings()
            AppSettings(
                onboarded = p[Keys.ONBOARDED] ?: d.onboarded,
                name = p[Keys.NAME] ?: d.name,
                heightCm = p[Keys.HEIGHT] ?: d.heightCm,
                birthDate = p[Keys.BIRTH] ?: d.birthDate,
                stepGoal = p[Keys.STEP_GOAL] ?: d.stepGoal,
                weeklyGoal = p[Keys.WEEKLY_GOAL] ?: d.weeklyGoal,
                theme = ThemeMode.entries.getOrElse(p[Keys.THEME] ?: 0) { ThemeMode.System },
                dynamicColor = p[Keys.DYNAMIC] ?: d.dynamicColor,
                sportColors = p[Keys.SPORT_COLORS] ?: d.sportColors,
                intervalsId = p[Keys.INTERVALS_ID] ?: d.intervalsId,
                intervalsKey = p[Keys.INTERVALS_KEY] ?: d.intervalsKey,
            )
        }

    suspend fun <T> set(key: Preferences.Key<T>, value: T) {
        ctx.dataStore.edit { it[key] = value }
    }
}
