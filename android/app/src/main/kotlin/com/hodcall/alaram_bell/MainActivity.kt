package com.hodcall.alaram_bell

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets the app share its own installed APK ("Share CampusBell").
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "campusbell/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apkPath" -> result.success(applicationInfo.sourceDir)
                    else -> result.notImplemented()
                }
            }
    }
}
