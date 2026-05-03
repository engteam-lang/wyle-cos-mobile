package com.wyle.wylecosapp

import android.app.Notification
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Captures notifications from every app on the device and forwards them
 * to Flutter via [NotificationEventChannel].
 *
 * Permission required: Settings → Apps → Special App Access →
 *   Notification Access → Wyle (toggle on).
 *
 * The service is declared in AndroidManifest.xml with
 *   android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
 * so only the Android system can bind to it.
 */
class WyleNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "WyleNotifListener"
    }

    // Apps whose notifications we never forward (system noise / our own)
    private val blocklist = setOf(
        "com.wyle.wylecosapp",          // Wyle itself
        "android",                       // System
        "com.android.systemui",          // Status bar
        "com.google.android.gms",        // Play Services (silent background)
    )

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification listener connected — ready to receive notifications")
        // Flush any payloads that arrived before Flutter subscribed to the channel
        NotificationEventChannel.flushPending()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "Notification listener disconnected")
        // Request rebind so the service comes back automatically
        requestRebind(componentName)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg in blocklist) return

        val extras = sbn.notification?.extras ?: return

        // Pull title and body; BigText / InboxStyle fallback included
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val body  = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim() ?: ""

        // Skip completely empty or ongoing/silent notifications
        if (title.isEmpty() && body.isEmpty()) return
        if (sbn.notification.flags and Notification.FLAG_ONGOING_EVENT != 0) return

        val appName = try {
            val ai = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(ai).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            pkg
        }

        Log.d(TAG, "Notification from $appName ($pkg): $title")

        val payload = mapOf(
            "appName"     to appName,
            "packageName" to pkg,
            "title"       to title,
            "body"        to body,
            "timestamp"   to System.currentTimeMillis(),
        )

        // Deliver to Flutter — if sink is null (Flutter not yet listening),
        // queue it so it's sent as soon as the channel is ready.
        NotificationEventChannel.send(payload)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Not needed for this feature
    }
}

/** Shared singleton so MainActivity can set the EventSink. */
object NotificationEventChannel {
    @Volatile var sink: EventChannel.EventSink? = null

    // Payloads that arrived before Flutter subscribed to the EventChannel.
    private val pending = mutableListOf<Map<String, Any>>()
    private val lock    = Any()

    /** Send a payload immediately if Flutter is listening, or queue it. */
    fun send(payload: Map<String, Any>) {
        synchronized(lock) {
            if (sink != null) {
                sink?.success(payload)
            } else {
                // Keep last 20 notifications max to avoid unbounded memory
                if (pending.size >= 20) pending.removeAt(0)
                pending.add(payload)
            }
        }
    }

    /**
     * Called from [WyleNotificationListenerService.onListenerConnected] and
     * from MainActivity when Flutter subscribes.  Drains any queued payloads.
     */
    fun flushPending() {
        synchronized(lock) {
            val s = sink ?: return
            pending.forEach { s.success(it) }
            pending.clear()
        }
    }
}
