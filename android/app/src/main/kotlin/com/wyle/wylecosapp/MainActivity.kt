package com.wyle.wylecosapp

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        // Channel names must match exactly what Dart uses
        const val EVENT_CHANNEL  = "com.wyle.wylecosapp/device_notifications"
        const val METHOD_CHANNEL = "com.wyle.wylecosapp/notification_permission"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── EventChannel: stream device notifications → Flutter ──────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationEventChannel.sink = events
                }
                override fun onCancel(arguments: Any?) {
                    NotificationEventChannel.sink = null
                }
            })

        // ── MethodChannel: permission check + open settings ──────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessGranted" ->
                        result.success(isNotificationServiceEnabled())

                    "openNotificationAccessSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** Returns true if Wyle is in the system's enabled notification-listener list. */
    private fun isNotificationServiceEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return flat.contains(packageName)
    }
}
