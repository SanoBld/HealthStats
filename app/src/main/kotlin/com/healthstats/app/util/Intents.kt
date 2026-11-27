package com.healthstats.app.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.health.connect.client.HealthConnectClient

private const val HC_PACKAGE = "com.google.android.apps.healthdata"

private fun Context.tryStart(intent: Intent): Boolean = try {
    startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    true
} catch (e: Exception) {
    false
}

/** Opens Health Connect on its "manage access" screen (falls back to the Play Store page). */
fun openHealthConnect(ctx: Context) {
    val ok = try {
        ctx.tryStart(HealthConnectClient.getHealthConnectManageDataIntent(ctx))
    } catch (e: Exception) {
        false
    }
    if (!ok) openHealthConnectStore(ctx)
}

fun openHealthConnectStore(ctx: Context) {
    val store = Intent(
        Intent.ACTION_VIEW,
        Uri.parse("market://details?id=$HC_PACKAGE&url=healthconnect%3A%2F%2Fonboarding"),
    ).setPackage("com.android.vending")
    if (!ctx.tryStart(store)) {
        ctx.tryStart(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$HC_PACKAGE")))
    }
}

/** Per-app language screen on Android 13+, system language screen before. */
fun openLanguageSettings(ctx: Context) {
    val intent = if (Build.VERSION.SDK_INT >= 33) {
        Intent(Settings.ACTION_APP_LOCALE_SETTINGS, Uri.parse("package:${ctx.packageName}"))
    } else {
        Intent(Settings.ACTION_LOCALE_SETTINGS)
    }
    ctx.tryStart(intent)
}
