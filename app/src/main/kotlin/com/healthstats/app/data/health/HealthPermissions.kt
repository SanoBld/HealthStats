package com.healthstats.app.data.health

import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
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
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        HISTORY,
    )

    /** Use with rememberLauncherForActivityResult: input = permissions to ask, output = permissions granted. */
    fun contract() = PermissionController.createRequestPermissionResultContract()
}
