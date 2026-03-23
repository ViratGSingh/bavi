package com.example.bavi

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
                if (call.method == "getAvailableBytes") {
                    val stat = StatFs(Environment.getDataDirectory().path)
                    val availableBytes = stat.availableBlocksLong * stat.blockSizeLong
                    result.success(availableBytes)
                } else {
                    result.notImplemented()
                }
            }
    }
}
