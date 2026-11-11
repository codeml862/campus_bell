package com.hodcall.alaram_bell

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "campusbell/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareApk" -> try {
                        shareApk()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("share_failed", e.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Shares this phone's installed app as "CampusBell.apk".
     * The file is copied under that name and offered through our own
     * FileProvider, so WhatsApp and others show "CampusBell.apk"
     * instead of "Untitled".
     */
    private fun shareApk() {
        val dir = File(cacheDir, "share").apply { mkdirs() }
        val out = File(dir, "CampusBell.apk")
        File(applicationInfo.sourceDir).copyTo(out, overwrite = true)
        val uri = FileProvider.getUriForFile(this, "$packageName.share", out)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "*/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(contentResolver, "CampusBell.apk", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, "Share CampusBell").apply {
            clipData = send.clipData
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val resInfoList = packageManager.queryIntentActivities(chooser, PackageManager.MATCH_DEFAULT_ONLY)
        for (resolveInfo in resInfoList) {
            val pkg = resolveInfo.activityInfo.packageName
            grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(chooser)
    }
}

