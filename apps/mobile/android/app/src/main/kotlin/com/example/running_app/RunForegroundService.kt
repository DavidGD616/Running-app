package com.example.running_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

class RunForegroundService : Service() {
    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private var latestData = RunNotificationData.empty()

    override fun onCreate() {
        super.onCreate()
        current = this
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_END -> {
                endRun()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                val data = RunNotificationData.fromBundle(intent.extras)
                startOrUpdate(data)
            }
            else -> {
                val data = RunNotificationData.fromBundle(intent?.extras)
                startOrUpdate(data)
            }
        }

        return START_STICKY
    }

    fun updateRun(data: Map<*, *>) {
        startOrUpdate(RunNotificationData.fromMap(data))
    }

    fun endRun() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // App swiped from recents: tear down activity instead of leaving stale notification.
        endRun()
    }

    private var foregroundStarted = false

    private fun startOrUpdate(data: RunNotificationData) {
        latestData = data
        createChannel()
        val notification = buildNotification(latestData)
        try {
            if (!foregroundStarted) {
                startForeground(NOTIFICATION_ID, notification)
                foregroundStarted = true
            } else {
                notificationManager.notify(NOTIFICATION_ID, notification)
            }
        } catch (_: RuntimeException) {
            stopSelf()
        }
    }

    private fun buildNotification(data: RunNotificationData): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                setData(Uri.parse(ACTIVE_RUN_DEEP_LINK))
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_run_notification)
            .setContentTitle(data.workoutName)
            .setContentText("${data.distanceLabel} ${data.currentPaceLabel}")
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setLocalOnly(true)
            .setContentIntent(contentIntent)
            .setCustomContentView(collapsedViews(data))
            .setCustomBigContentView(expandedViews(data))
            .setStyle(Notification.DecoratedCustomViewStyle())
            .build()
    }

    private fun collapsedViews(data: RunNotificationData): RemoteViews {
        return RemoteViews(packageName, R.layout.notification_run_collapsed).apply {
            setTextViewText(R.id.run_workout_name, data.workoutName)
            setTextViewText(R.id.run_status_label, data.statusLabel)
            setTextViewText(R.id.run_distance_label, data.distanceLabel)
            setTextViewText(R.id.run_current_pace_label, data.currentPaceLabel)
            bindElapsed(this, data)
        }
    }

    private fun expandedViews(data: RunNotificationData): RemoteViews {
        return RemoteViews(packageName, R.layout.notification_run_expanded).apply {
            setTextViewText(R.id.run_workout_name, data.workoutName)
            setTextViewText(R.id.run_status_label, data.statusLabel)
            setTextViewText(R.id.run_distance_label, data.distanceLabel)
            setTextViewText(R.id.run_current_block_label, data.currentBlockLabel)
            setTextViewText(R.id.run_current_pace_title, data.currentPaceTitleLabel)
            setTextViewText(R.id.run_current_pace_label, data.currentPaceLabel)
            setTextViewText(R.id.run_avg_pace_title, data.avgPaceTitleLabel)
            setTextViewText(R.id.run_avg_pace_label, data.avgPaceLabel)
            setOptionalText(R.id.run_next_block_label, data.nextBlockLabel)
            setOptionalText(R.id.run_rep_label, data.repLabel)
            bindElapsed(this, data)
        }
    }

    private fun bindElapsed(views: RemoteViews, data: RunNotificationData) {
        val base = SystemClock.elapsedRealtime() - data.elapsedSeconds * 1000L
        views.setChronometer(R.id.run_elapsed_chrono, base, null, !data.isPaused)
        views.setTextViewText(R.id.run_elapsed_static, data.elapsedLabel)
        views.setViewVisibility(
            R.id.run_elapsed_chrono,
            if (data.isPaused) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.run_elapsed_static,
            if (data.isPaused) View.VISIBLE else View.GONE,
        )
    }

    private fun RemoteViews.setOptionalText(viewId: Int, value: String?) {
        if (value.isNullOrBlank()) {
            setViewVisibility(viewId, View.GONE)
        } else {
            setViewVisibility(viewId, View.VISIBLE)
            setTextViewText(viewId, value)
        }
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.run_notification_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.davidgd616.striviq.action.START_RUN"
        const val ACTION_UPDATE = "com.davidgd616.striviq.action.UPDATE_RUN"
        const val ACTION_END = "com.davidgd616.striviq.action.END_RUN"
        const val ACTIVE_RUN_DEEP_LINK = "striviq://active-run"
        const val NOTIFICATION_ID = 61002
        private const val CHANNEL_ID = "active_run"

        var current: RunForegroundService? = null
            private set

        fun intent(context: Context, action: String, data: Map<*, *>? = null): Intent {
            return Intent(context, RunForegroundService::class.java).apply {
                this.action = action
                data?.let { putExtras(RunNotificationData.fromMap(it).toBundle()) }
            }
        }
    }
}

private data class RunNotificationData(
    val workoutName: String,
    val statusLabel: String,
    val elapsedSeconds: Long,
    val elapsedLabel: String,
    val distanceLabel: String,
    val currentPaceTitleLabel: String,
    val currentPaceLabel: String,
    val avgPaceTitleLabel: String,
    val avgPaceLabel: String,
    val currentBlockLabel: String,
    val nextBlockLabel: String?,
    val repLabel: String?,
    val isPaused: Boolean,
) {
    fun toBundle(): Bundle = Bundle().apply {
        putString("workoutName", workoutName)
        putString("statusLabel", statusLabel)
        putLong("elapsedSeconds", elapsedSeconds)
        putString("elapsedLabel", elapsedLabel)
        putString("distanceLabel", distanceLabel)
        putString("currentPaceTitleLabel", currentPaceTitleLabel)
        putString("currentPaceLabel", currentPaceLabel)
        putString("avgPaceTitleLabel", avgPaceTitleLabel)
        putString("avgPaceLabel", avgPaceLabel)
        putString("currentBlockLabel", currentBlockLabel)
        putString("nextBlockLabel", nextBlockLabel)
        putString("repLabel", repLabel)
        putBoolean("isPaused", isPaused)
    }

    companion object {
        fun empty(): RunNotificationData = RunNotificationData(
            workoutName = "",
            statusLabel = "",
            elapsedSeconds = 0,
            elapsedLabel = "00:00",
            distanceLabel = "",
            currentPaceTitleLabel = "",
            currentPaceLabel = "",
            avgPaceTitleLabel = "",
            avgPaceLabel = "",
            currentBlockLabel = "",
            nextBlockLabel = null,
            repLabel = null,
            isPaused = false,
        )

        fun fromBundle(bundle: Bundle?): RunNotificationData {
            if (bundle == null) return empty()
            return RunNotificationData(
                workoutName = bundle.getString("workoutName").orEmpty(),
                statusLabel = bundle.getString("statusLabel").orEmpty(),
                elapsedSeconds = bundle.getLong("elapsedSeconds"),
                elapsedLabel = bundle.getString("elapsedLabel") ?: "00:00",
                distanceLabel = bundle.getString("distanceLabel").orEmpty(),
                currentPaceTitleLabel =
                    bundle.getString("currentPaceTitleLabel").orEmpty(),
                currentPaceLabel = bundle.getString("currentPaceLabel").orEmpty(),
                avgPaceTitleLabel = bundle.getString("avgPaceTitleLabel").orEmpty(),
                avgPaceLabel = bundle.getString("avgPaceLabel").orEmpty(),
                currentBlockLabel = bundle.getString("currentBlockLabel").orEmpty(),
                nextBlockLabel = bundle.getString("nextBlockLabel"),
                repLabel = bundle.getString("repLabel"),
                isPaused = bundle.getBoolean("isPaused"),
            )
        }

        fun fromMap(map: Map<*, *>?): RunNotificationData {
            if (map == null) return empty()
            return RunNotificationData(
                workoutName = map.stringValue("workoutName"),
                statusLabel = map.stringValue("statusLabel"),
                elapsedSeconds = map.longValue("elapsedSeconds"),
                elapsedLabel = map.stringValue("elapsedLabel", "00:00"),
                distanceLabel = map.stringValue("distanceLabel"),
                currentPaceTitleLabel = map.stringValue("currentPaceTitleLabel"),
                currentPaceLabel = map.stringValue("currentPaceLabel"),
                avgPaceTitleLabel = map.stringValue("avgPaceTitleLabel"),
                avgPaceLabel = map.stringValue("avgPaceLabel"),
                currentBlockLabel = map.stringValue("currentBlockLabel"),
                nextBlockLabel = map.optionalStringValue("nextBlockLabel"),
                repLabel = map.optionalStringValue("repLabel"),
                isPaused = map.booleanValue("isPaused"),
            )
        }
    }
}

private fun Map<*, *>.stringValue(key: String, fallback: String = ""): String {
    return this[key] as? String ?: fallback
}

private fun Map<*, *>.optionalStringValue(key: String): String? {
    return this[key] as? String
}

private fun Map<*, *>.longValue(key: String): Long {
    return when (val value = this[key]) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: 0L
        else -> 0L
    }
}

private fun Map<*, *>.booleanValue(key: String): Boolean {
    return this[key] as? Boolean ?: false
}
