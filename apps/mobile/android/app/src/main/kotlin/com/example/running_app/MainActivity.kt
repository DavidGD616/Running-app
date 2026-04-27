package com.example.running_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.davidgd616.striviq/live_activity"
    private val eventsChannelName = "com.davidgd616.striviq/live_activity_events"

    override fun getInitialRoute(): String? {
        return if (isActiveRunIntent(intent)) "/active-run" else super.getInitialRoute()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        openActiveRunFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startActivity" -> {
                        startRunService(call.arguments as? Map<*, *>)
                        result.success(true)
                    }
                    "updateActivity" -> {
                        updateRunService(call.arguments as? Map<*, *>)
                        result.success(true)
                    }
                    "endActivity" -> {
                        endRunService()
                        result.success(true)
                    }
                    "androidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "getRunState" -> result.success(RunForegroundService.current?.snapshotState())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    RunForegroundService.eventsSink = sink
                }
                override fun onCancel(args: Any?) {
                    RunForegroundService.eventsSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        openActiveRunFromIntent(intent)
    }

    private fun startRunService(data: Map<*, *>?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!canPostRunNotification()) return

        val serviceIntent = RunForegroundService.intent(
            this,
            RunForegroundService.ACTION_START,
            data,
        )
        startForegroundService(serviceIntent)
    }

    private fun updateRunService(data: Map<*, *>?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!canPostRunNotification()) return

        val service = RunForegroundService.current
        if (service != null && data != null) {
            service.updateRun(data)
            return
        }

        val serviceIntent = RunForegroundService.intent(
            this,
            RunForegroundService.ACTION_UPDATE,
            data,
        )
        startForegroundService(serviceIntent)
    }

    private fun endRunService() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val serviceIntent = RunForegroundService.intent(
            this,
            RunForegroundService.ACTION_END,
        )
        stopService(serviceIntent)
        RunForegroundService.current?.endRun()
    }

    private fun canPostRunNotification(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun openActiveRunFromIntent(intent: Intent?) {
        if (isActiveRunIntent(intent)) {
            flutterEngine?.navigationChannel?.pushRoute("/active-run")
        }
    }

    private fun isActiveRunIntent(intent: Intent?): Boolean {
        val uri: Uri = intent?.data ?: return false
        return uri.scheme == "striviq" && uri.host == "active-run"
    }
}
