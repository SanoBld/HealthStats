package com.healthstats.app.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "hs_settings")

enum class ThemeMode { System, Light, Dark }

data class AppSettings(
    val themeMode: ThemeMode = ThemeMode.System,
    val accent: Int = 0xFFFF2020.toInt(),
    val dynamicColor: Boolean = true,
    val harmony: String = "mono",        // mono | classic | tinted | vivid | soft
    val locale: String = "fr",           // fr | en
    val amoled: Boolean = false,
    val haptics: Boolean = true,
    val navLabels: Boolean = true,
    val textScale: Float = 1.1f,
    val font: String = "GoogleSansFlex",
    val name: String = "",
    val heightCm: Float = 0f,
    val weightKg: Float = 0f,
    val birthDate: String = "",          // yyyy-MM-dd
    val sex: String = "",                // m | f | x
    val stepGoal: Int = 10000,
    val weeklyGoal: Int = 3,             // sessions per week
    val metric: Boolean = true,
    val onboarded: Boolean = false,
    val sportColors: Boolean = true,     // one color per sport (off = accent only)
    val showAdvice: Boolean = true,
    val hiddenTabs: Set<String> = emptySet(),  // activities, map, search, charts
    val hiddenCards: Set<String> = emptySet(), // sleep, heart, vitals, week
    val intervalsKey: String = "",
    val intervalsAthlete: String = "",
)

/** App settings, saved with DataStore. */
class SettingsStore(private val ctx: Context) {

    object Keys {
        val THEME = intPreferencesKey("theme")
        val ACCENT = intPreferencesKey("accent")
        val DYNAMIC = booleanPreferencesKey("dynamic")
        val HARMONY = stringPreferencesKey("harmony")
        val LOCALE = stringPreferencesKey("locale")
        val AMOLED = booleanPreferencesKey("amoled")
        val HAPTICS = booleanPreferencesKey("haptics")
        val NAV_LABELS = booleanPreferencesKey("nav_labels")
        val TEXT_SCALE = floatPreferencesKey("text_scale")
        val FONT = stringPreferencesKey("font")
        val NAME = stringPreferencesKey("name")
        val HEIGHT = floatPreferencesKey("height_cm")
        val WEIGHT = floatPreferencesKey("weight_kg")
        val BIRTH = stringPreferencesKey("birth_date")
        val SEX = stringPreferencesKey("sex")
        val STEP_GOAL = intPreferencesKey("step_goal")
        val WEEKLY_GOAL = intPreferencesKey("weekly_goal")
        val METRIC = booleanPreferencesKey("metric")
        val ONBOARDED = booleanPreferencesKey("onboarded")
        val SPORT_COLORS = booleanPreferencesKey("sport_colors")
        val ADVICE = booleanPreferencesKey("advice")
        val HIDDEN_TABS = stringPreferencesKey("hidden_tabs")
        val HIDDEN_CARDS = stringPreferencesKey("hidden_cards")
        val INTERVALS_KEY = stringPreferencesKey("intervals_key")
        val INTERVALS_ATHLETE = stringPreferencesKey("intervals_athlete")
    }

    val flow: Flow<AppSettings> = ctx.dataStore.data.map { p ->
        val d = AppSettings()
        AppSettings(
            themeMode = ThemeMode.entries[(p[Keys.THEME] ?: 0).coerceIn(0, 2)],
            accent = p[Keys.ACCENT] ?: d.accent,
            dynamicColor = p[Keys.DYNAMIC] ?: d.dynamicColor,
            harmony = p[Keys.HARMONY] ?: d.harmony,
            locale = p[Keys.LOCALE] ?: d.locale,
            amoled = p[Keys.AMOLED] ?: d.amoled,
            haptics = p[Keys.HAPTICS] ?: d.haptics,
            navLabels = p[Keys.NAV_LABELS] ?: d.navLabels,
            textScale = p[Keys.TEXT_SCALE] ?: d.textScale,
            font = p[Keys.FONT] ?: d.font,
            name = p[Keys.NAME] ?: "",
            heightCm = p[Keys.HEIGHT] ?: 0f,
            weightKg = p[Keys.WEIGHT] ?: 0f,
            birthDate = p[Keys.BIRTH] ?: "",
            sex = p[Keys.SEX] ?: "",
            stepGoal = p[Keys.STEP_GOAL] ?: d.stepGoal,
            weeklyGoal = p[Keys.WEEKLY_GOAL] ?: d.weeklyGoal,
            metric = p[Keys.METRIC] ?: d.metric,
            onboarded = p[Keys.ONBOARDED] ?: d.onboarded,
            sportColors = p[Keys.SPORT_COLORS] ?: d.sportColors,
            showAdvice = p[Keys.ADVICE] ?: d.showAdvice,
            hiddenTabs = splitSet(p[Keys.HIDDEN_TABS]),
            hiddenCards = splitSet(p[Keys.HIDDEN_CARDS]),
            intervalsKey = p[Keys.INTERVALS_KEY] ?: "",
            intervalsAthlete = p[Keys.INTERVALS_ATHLETE] ?: "",
        )
    }

    suspend fun current(): AppSettings = flow.first()

    suspend fun <T> set(key: Preferences.Key<T>, value: T) {
        ctx.dataStore.edit { it[key] = value }
    }

    suspend fun setThemeMode(m: ThemeMode) = set(Keys.THEME, m.ordinal)

    /** Hide or show a tab / card. [key] = Keys.HIDDEN_TABS or Keys.HIDDEN_CARDS. */
    suspend fun setHidden(key: Preferences.Key<String>, item: String, hide: Boolean) {
        ctx.dataStore.edit { p ->
            val s = splitSet(p[key]).toMutableSet()
            if (hide) s.add(item) else s.remove(item)
            p[key] = s.joinToString(",")
        }
    }

    private fun splitSet(s: String?): Set<String> = s.orEmpty().split(',').filter { it.isNotEmpty() }.toSet()
}
