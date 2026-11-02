package com.healthstats.app

import android.os.Bundle
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.contracts.ExerciseRouteRequestContract
import androidx.health.connect.client.records.ExerciseRoute
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import android.app.DownloadManager
import android.content.ComponentName
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import android.content.ContentValues
import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val bridge by lazy { HealthBridge(this) }
    private var pendingPerm: Result? = null
    private lateinit var permLauncher: ActivityResultLauncher<Set<String>>
    private lateinit var routeLauncher: ActivityResultLauncher<String>
    private var routeWait: CompletableDeferred<ExerciseRoute?>? = null
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        permLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            pendingPerm?.success(granted.toList())
            pendingPerm = null
        }
        routeLauncher = registerForActivityResult(ExerciseRouteRequestContract()) { route ->
            routeWait?.complete(route)
            routeWait = null
        }
    }

    // One consent dialog at a time (several at once = the earlier ones never finished)
    private val routeMutex = Mutex()
    private suspend fun askRoute(id: String): ExerciseRoute? = routeMutex.withLock {
        withContext(Dispatchers.Main) {
            val d = CompletableDeferred<ExerciseRoute?>()
            routeWait = d
            routeLauncher.launch(id)
            d.await()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "healthstats/installer")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "canInstall" -> result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls())
                        "openSettings" -> {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")))
                            result.success(true)
                        }
                        "install" -> {
                            val file = File(call.argument<String>("path")!!)
                            val uri = FileProvider.getUriForFile(this, "$packageName.updatefileprovider", file)
                            val i = Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        }
                        "openDownloads" -> {
                            startActivity(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        }
                        "saveToDownloads" -> {
                            val src  = File(call.argument<String>("path")!!)
                            val name = call.argument<String>("name")!!
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val mime = if (name.endsWith(".apk", true))
                                    "application/vnd.android.package-archive" else "application/octet-stream"
                                val values = ContentValues().apply {
                                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                                    put(MediaStore.Downloads.MIME_TYPE, mime)
                                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                                    put(MediaStore.Downloads.IS_PENDING, 1)
                                }
                                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)!!
                                contentResolver.openOutputStream(uri)!!.use { out ->
                                    src.inputStream().use { it.copyTo(out) }
                                }
                                values.clear()
                                values.put(MediaStore.Downloads.IS_PENDING, 0)
                                contentResolver.update(uri, values, null, null)
                                result.success("Downloads/$name")
                            } else {
                                val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)!!
                                val dst = File(dir, name)
                                src.copyTo(dst, true)
                                result.success(dst.absolutePath)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "healthstats/health")
            .setMethodCallHandler { call, result ->
                if (call.method == "status") { result.success(bridge.status()); return@setMethodCallHandler }
                if (call.method == "requestPermissions") {
                    // never leave an old request waiting forever
                    pendingPerm?.success(emptyList<String>())
                    pendingPerm = result
                    try {
                        permLauncher.launch(HealthBridge.PERMISSIONS)
                    } catch (e: Exception) {
                        pendingPerm = null
                        result.error("perm", e.message, null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "openSettings") {
                    try {
                        startActivity(Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"))
                        result.success(true)
                    } catch (e: Exception) { result.success(false) }
                    return@setMethodCallHandler
                }
                scope.launch {
                    try {
                        val a = call.arguments as? Map<*, *>
                        val s = (a?.get("start") as? Number)?.toLong() ?: 0L
                        val e = (a?.get("end") as? Number)?.toLong() ?: 0L
                        val out: Any? = withContext(Dispatchers.IO) {
                            when (call.method) {
                                "granted" -> bridge.granted()
                                "sessions" -> bridge.sessions(s, e, a?.get("lite") == true)
                                "height" -> bridge.height()
                                "appInfo" -> bridge.appInfo((a?.get("pkgs") as? List<*>)?.map { it.toString() } ?: emptyList())
                                "route" -> bridge.route(a!!["id"] as String, if (a["ask"] == true) { id: String -> askRoute(id) } else null, (a["max"] as? Number)?.toInt() ?: 0)
                                "heartRate" -> bridge.heartRate(s, e)
                                "samples" -> bridge.samples(a!!["kind"] as String, s, e)
                                "metric" -> bridge.metric(a!!["kind"] as String, s, e)
                                "daily" -> bridge.daily(s, e)
                                "sleep" -> bridge.sleep(s, e)
                                "weight" -> bridge.weight(s, e)
                                else -> null
                            }
                        }
                        if (out == null) result.notImplemented() else result.success(out)
                    } catch (ex: Exception) {
                        result.error("health", ex.message, null)
                    }
                }
            }
    }
}
