package com.example.bavi

import android.app.ActivityManager
import android.content.Context
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.bavi/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAvailableBytes" -> {
                        val path = context.getExternalFilesDir(null)?.path
                            ?: Environment.getExternalStorageDirectory().path
                        val stat = StatFs(path)
                        result.success(stat.availableBlocksLong * stat.blockSizeLong)
                    }
                    "getPhysicalMemoryBytes" -> {
                        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memInfo = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(memInfo)
                        result.success(memInfo.totalMem)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
