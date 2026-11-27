package com.healthstats.app.data.health

import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord

/**
 * Everything the app asks for. IMPORTANT: every permission here must also be in AndroidManifest.xml,
 * otherwise Android silently refuses to show the request (= no data, endless loading).
 * GPS routes are not in this list: Android asks for them one route at a time (see ExerciseRouteRequestContract).
 */
object HealthPermissions {
    const val HISTORY = "android.permission.health.READ_HEALTH_DATA_HISTORY"

    val EXERCISE: String = HealthPermission.getReadPermission(ExerciseSessionRecord::class)

    val ALL: Set<String> = setOf(
        EXERCISE,
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class),
        HealthPermission.getReadPermission(HeightRecord::class),
        HealthPermission.getReadPermission(SpeedRecord::class),
        HealthPermission.getReadPermission(PowerRecord::class),
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        HealthPermission.getReadPermission(Vo2MaxRecord::class),
        HISTORY,
    )

    /** Short name of each data type and its permission (used by the access check in Settings). */
    val NAMED: List<Pair<String, String>> = listOf(
        "exercise" to EXERCISE,
        "steps" to HealthPermission.getReadPermission(StepsRecord::class),
        "heart_rate" to HealthPermission.getReadPermission(HeartRateRecord::class),
        "distance" to HealthPermission.getReadPermission(DistanceRecord::class),
        "kcal" to HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        "sleep" to HealthPermission.getReadPermission(SleepSessionRecord::class),
        "weight" to HealthPermission.getReadPermission(WeightRecord::class),
        "height" to HealthPermission.getReadPermission(HeightRecord::class),
        "resting" to HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        "hrv" to HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        "spo2" to HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        "vo2" to HealthPermission.getReadPermission(Vo2MaxRecord::class),
        "speed" to HealthPermission.getReadPermission(SpeedRecord::class),
        "power" to HealthPermission.getReadPermission(PowerRecord::class),
        "history" to HISTORY,
    )

    /** Use with rememberLauncherForActivityResult: input = permissions to ask, output = permissions granted. */
    fun contract() = PermissionController.createRequestPermissionResultContract()
}
