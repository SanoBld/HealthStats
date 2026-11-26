package com.healthstats.app.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.health.connect.client.HealthConnectClient

private fun Context.startSafe(i: Intent) {
    // NEW_TASK: the context may not be an Activity (language wrapper)
    i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try { startActivity(i) } catch (e: Exception) { /* nothing can open it */ }
}

/** Opens the Health Connect settings (to allow or change permissions). */
fun Context.openHealthConnectSettings() = startSafe(Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS))

/** Opens Health Connect in the Play Store (to install or update it). */
fun Context.openHealthConnectStore() = startSafe(
    Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.google.android.apps.healthdata"))
)
