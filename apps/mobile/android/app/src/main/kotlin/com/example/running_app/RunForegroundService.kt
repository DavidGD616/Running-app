package com.example.running_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.EventChannel
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

class RunForegroundService : Service() {
    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private var latestData = RunNotificationData.empty()

    // Service-owned, ticked natively. Survives app backgrounding.
    private var serviceDistanceKm: Double = 0.0
    private var serviceElapsedMs: Long = 0L
    private var lastTickRealtime: Long = 0L
    private var seeded: Boolean = false

    // Timeline (block) tracking — service advances blocks natively while
    // Flutter is backgrounded so the notification reflects the correct
    // block/rep/status even across multi-block transitions.
    private var timeline: List<TimelineBlock> = emptyList()
    private var blockIndex: Int = 0
    private var blockElapsedMs: Long = 0L
    private var blockDistanceKm: Double = 0.0

    private val tickHandler = Handler(Looper.getMainLooper())
    private val tickRunnable = object : Runnable {
        override fun run() {
            tick()
            tickHandler.postDelayed(this, TICK_INTERVAL_MS)
        }
    }
    private var tickRunning = false

    override fun onCreate() {
        super.onCreate()
        current = this
    }

    override fun onDestroy() {
        stopTickLoop()
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
                applyData(data, isInitial = false)
            }
            else -> {
                val data = RunNotificationData.fromBundle(intent?.extras)
                applyData(data, isInitial = !seeded)
            }
        }

        return START_STICKY
    }

    fun updateRun(data: Map<*, *>) {
        applyData(RunNotificationData.fromMap(data), isInitial = !seeded)
    }

    fun snapshotState(): Map<String, Any> = mapOf(
        "distanceKm" to serviceDistanceKm,
        "elapsedMs" to serviceElapsedMs,
        "isPaused" to latestData.isPaused,
        "seeded" to seeded,
        "blockIndex" to blockIndex,
        "blockElapsedMs" to blockElapsedMs,
        "blockDistanceKm" to blockDistanceKm,
    )

    fun endRun() {
        stopTickLoop()
        emitFinishedEvent()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun emitFinishedEvent() {
        if (!seeded) return
        val sink = eventsSink ?: return
        val payload = mapOf(
            "type" to "finished",
            "distanceKm" to serviceDistanceKm,
            "elapsedMs" to serviceElapsedMs,
            "blockIndex" to blockIndex,
        )
        Handler(Looper.getMainLooper()).post {
            try { sink.success(payload) } catch (_: Exception) {}
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // App swiped from recents: tear down activity instead of leaving stale notification.
        endRun()
    }

    private var foregroundStarted = false

    private fun applyData(data: RunNotificationData, isInitial: Boolean) {
        if (isInitial) {
            // Seed service state from Flutter on first start. Subsequent
            // updates only mutate labels + pace; distance/elapsed stay
            // service-owned to avoid stomping on values accumulated while
            // Flutter was backgrounded.
            serviceDistanceKm = data.distanceKm
            serviceElapsedMs = data.elapsedSeconds * 1000L
            lastTickRealtime = SystemClock.elapsedRealtime()
            seeded = true
            blockIndex = 0
            blockElapsedMs = 0L
            blockDistanceKm = 0.0
        }
        if (data.timeline.isNotEmpty()) {
            // Timeline only seeded once (length/contents stable for a session).
            if (timeline.isEmpty()) timeline = data.timeline
        }
        latestData = data
        pushNotification()
        if (data.isPaused) stopTickLoop() else startTickLoop()
    }

    private fun advanceTimelineIfNeeded() {
        if (timeline.isEmpty()) return
        while (blockIndex < timeline.size - 1) {
            val block = timeline[blockIndex]
            val durComplete = block.durationMs != null && blockElapsedMs >= block.durationMs
            val distComplete =
                block.distanceMeters != null && blockDistanceKm * 1000 >= block.distanceMeters
            if (!durComplete && !distComplete) return
            blockIndex += 1
            blockElapsedMs = 0L
            blockDistanceKm = 0.0
        }
    }

    private fun startTickLoop() {
        if (tickRunning) return
        lastTickRealtime = SystemClock.elapsedRealtime()
        tickHandler.postDelayed(tickRunnable, TICK_INTERVAL_MS)
        tickRunning = true
    }

    private fun stopTickLoop() {
        if (!tickRunning) return
        tickHandler.removeCallbacks(tickRunnable)
        tickRunning = false
    }

    private fun tick() {
        val now = SystemClock.elapsedRealtime()
        val deltaMs = (now - lastTickRealtime).coerceAtLeast(0L)
        lastTickRealtime = now
        if (latestData.isPaused) return

        serviceElapsedMs += deltaMs
        blockElapsedMs += deltaMs
        val pace = latestData.paceSecondsPerKm
        if (pace > 0) {
            val distDelta = (deltaMs / 1000.0) / pace
            serviceDistanceKm += distDelta
            blockDistanceKm += distDelta
        }
        advanceTimelineIfNeeded()
        pushNotification()
    }

    private fun pushNotification() {
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

    private fun computedDistanceLabel(): String {
        val unit = latestData.distanceUnit.ifBlank { "km" }
        val value = serviceDistanceKm * latestData.unitFactor
        val format = if (value < 1.0) "%.2f %s" else "%.1f %s"
        return String.format(Locale.US, format, value, unit)
    }

    private fun distanceParts(label: String, data: RunNotificationData): Pair<String, String> {
        val trimmed = label.trim()
        val splitAt = trimmed.lastIndexOf(' ')
        if (splitAt > 0 && splitAt < trimmed.length - 1) {
            return Pair(trimmed.substring(0, splitAt), trimmed.substring(splitAt + 1))
        }
        return Pair(trimmed, data.distanceUnit)
    }

    private fun computedCurrentPaceLabel(): String {
        val basePace = latestData.paceSecondsPerKm
        if (basePace <= 0) return latestData.currentPaceLabel
        val factor = latestData.unitFactor
        val secondsInUnit = if (factor > 0) (basePace / factor).toInt() else basePace
        return formatPace(secondsInUnit, latestData.paceUnit)
    }

    private fun computedAvgPaceLabel(): String {
        if (serviceDistanceKm < 0.005) return latestData.avgPaceLabel
        val avgSecPerKm = (serviceElapsedMs / 1000.0) / serviceDistanceKm
        val factor = latestData.unitFactor
        val secondsInUnit = if (factor > 0) (avgSecPerKm / factor).toInt() else avgSecPerKm.toInt()
        return formatPace(secondsInUnit, latestData.paceUnit)
    }

    private fun formatPace(seconds: Int, unitSuffix: String): String {
        val safe = seconds.coerceAtLeast(0)
        val minutes = safe / 60
        val rem = safe % 60
        val unit = unitSuffix.ifBlank { "min/km" }
        return String.format(Locale.US, "%d:%02d %s", minutes, rem, unit)
    }

    private fun computedProgressPermille(data: RunNotificationData): Int {
        val distanceTarget = data.plannedDistanceKm
        if (distanceTarget != null && distanceTarget > 0.0) {
            return visibleProgress((serviceDistanceKm / distanceTarget).coerceIn(0.0, 1.0))
        }
        val durationTarget = data.plannedDurationMs
        if (durationTarget != null && durationTarget > 0L) {
            return visibleProgress((serviceElapsedMs.toDouble() / durationTarget).coerceIn(0.0, 1.0))
        }
        return 0
    }

    private fun visibleProgress(progress: Double): Int {
        if (progress <= 0.0) return 0
        return (progress * 1000).toInt().coerceAtLeast(24)
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
            .setColor(NOTIFICATION_BACKGROUND_COLOR)
            .setColorized(true)
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

    private fun currentTimelineBlock(): TimelineBlock? =
        timeline.getOrNull(blockIndex)

    private fun resolvedCurrentBlockLabel(data: RunNotificationData): String =
        currentTimelineBlock()?.blockLabel ?: data.currentBlockLabel

    private fun resolvedNextBlockLabel(data: RunNotificationData): String? =
        currentTimelineBlock()?.nextLabel ?: data.nextBlockLabel

    private fun resolvedRepLabel(data: RunNotificationData): String? =
        currentTimelineBlock()?.repLabel ?: data.repLabel

    private fun collapsedViews(data: RunNotificationData): RemoteViews {
        val distance = if (seeded) computedDistanceLabel() else data.distanceLabel
        val (distanceValue, distanceUnit) = distanceParts(distance, data)
        return RemoteViews(packageName, R.layout.notification_run_collapsed).apply {
            setTextViewText(R.id.run_distance_value_label, distanceValue)
            setTextViewText(R.id.run_distance_unit_label, distanceUnit)
            setTextViewText(R.id.run_elapsed_unit_label, data.elapsedUnitLabel)
            setProgressBar(R.id.run_progress_bar, 1000, computedProgressPermille(data), false)
            bindElapsed(this, data)
        }
    }

    private fun expandedViews(data: RunNotificationData): RemoteViews {
        val distance = if (seeded) computedDistanceLabel() else data.distanceLabel
        val currentPace = if (seeded) computedCurrentPaceLabel() else data.currentPaceLabel
        val avgPace = if (seeded) computedAvgPaceLabel() else data.avgPaceLabel
        return RemoteViews(packageName, R.layout.notification_run_expanded).apply {
            setTextViewText(R.id.run_workout_name, data.workoutName)
            setTextViewText(R.id.run_status_label, data.statusLabel)
            setTextViewText(R.id.run_distance_label, distance)
            setTextViewText(R.id.run_current_block_label, resolvedCurrentBlockLabel(data))
            setTextViewText(R.id.run_current_pace_title, data.currentPaceTitleLabel)
            setTextViewText(R.id.run_current_pace_label, currentPace)
            setTextViewText(R.id.run_avg_pace_title, data.avgPaceTitleLabel)
            setTextViewText(R.id.run_avg_pace_label, avgPace)
            setOptionalText(R.id.run_next_block_label, resolvedNextBlockLabel(data))
            setOptionalText(R.id.run_rep_label, resolvedRepLabel(data))
            bindElapsed(this, data)
        }
    }

    private fun bindElapsed(views: RemoteViews, data: RunNotificationData) {
        val elapsedSec = if (seeded) serviceElapsedMs / 1000L else data.elapsedSeconds
        val base = SystemClock.elapsedRealtime() - elapsedSec * 1000L
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
        private const val TICK_INTERVAL_MS = 1000L
        private val NOTIFICATION_BACKGROUND_COLOR: Int = Color.rgb(21, 21, 21)

        var current: RunForegroundService? = null
            private set

        // Set by MainActivity when Dart subscribes via the event channel.
        var eventsSink: EventChannel.EventSink? = null

        fun intent(context: Context, action: String, data: Map<*, *>? = null): Intent {
            return Intent(context, RunForegroundService::class.java).apply {
                this.action = action
                data?.let { putExtras(RunNotificationData.fromMap(it).toBundle()) }
            }
        }
    }
}

internal data class TimelineBlock(
    val durationMs: Long?,
    val distanceMeters: Int?,
    val blockLabel: String,
    val nextLabel: String?,
    val repLabel: String?,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("durationMs", durationMs ?: JSONObject.NULL)
        put("distanceMeters", distanceMeters ?: JSONObject.NULL)
        put("blockLabel", blockLabel)
        put("nextLabel", nextLabel ?: JSONObject.NULL)
        put("repLabel", repLabel ?: JSONObject.NULL)
    }

    companion object {
        fun fromJson(obj: JSONObject): TimelineBlock = TimelineBlock(
            durationMs = if (obj.isNull("durationMs")) null else obj.optLong("durationMs"),
            distanceMeters = if (obj.isNull("distanceMeters")) null else obj.optInt("distanceMeters"),
            blockLabel = obj.optString("blockLabel", ""),
            nextLabel = if (obj.isNull("nextLabel")) null else obj.optString("nextLabel"),
            repLabel = if (obj.isNull("repLabel")) null else obj.optString("repLabel"),
        )

        fun fromMap(map: Map<*, *>): TimelineBlock {
            fun longOrNull(key: String): Long? = when (val v = map[key]) {
                is Number -> v.toLong()
                is String -> v.toLongOrNull()
                else -> null
            }
            fun intOrNull(key: String): Int? = when (val v = map[key]) {
                is Number -> v.toInt()
                is String -> v.toIntOrNull()
                else -> null
            }
            return TimelineBlock(
                durationMs = longOrNull("durationMs"),
                distanceMeters = intOrNull("distanceMeters"),
                blockLabel = map["blockLabel"] as? String ?: "",
                nextLabel = map["nextLabel"] as? String,
                repLabel = map["repLabel"] as? String,
            )
        }
    }
}

private fun List<TimelineBlock>.toJsonString(): String =
    JSONArray().apply { this@toJsonString.forEach { put(it.toJson()) } }.toString()

private fun timelineFromJsonString(json: String?): List<TimelineBlock> {
    if (json.isNullOrEmpty()) return emptyList()
    return try {
        val arr = JSONArray(json)
        (0 until arr.length()).map { TimelineBlock.fromJson(arr.getJSONObject(it)) }
    } catch (_: Exception) {
        emptyList()
    }
}

private data class RunNotificationData(
    val workoutName: String,
    val statusTitleLabel: String,
    val statusLabel: String,
    val elapsedSeconds: Long,
    val elapsedLabel: String,
    val elapsedUnitLabel: String,
    val distanceTitleLabel: String,
    val distanceLabel: String,
    val currentPaceShortTitleLabel: String,
    val currentPaceTitleLabel: String,
    val currentPaceLabel: String,
    val avgPaceTitleLabel: String,
    val avgPaceLabel: String,
    val currentBlockLabel: String,
    val nextBlockLabel: String?,
    val repLabel: String?,
    val isPaused: Boolean,
    val distanceKm: Double,
    val paceSecondsPerKm: Int,
    val unitFactor: Double,
    val distanceUnit: String,
    val paceUnit: String,
    val plannedDistanceKm: Double?,
    val plannedDurationMs: Long?,
    val timeline: List<TimelineBlock>,
) {
    fun toBundle(): Bundle = Bundle().apply {
        putString("workoutName", workoutName)
        putString("statusTitleLabel", statusTitleLabel)
        putString("statusLabel", statusLabel)
        putLong("elapsedSeconds", elapsedSeconds)
        putString("elapsedLabel", elapsedLabel)
        putString("elapsedUnitLabel", elapsedUnitLabel)
        putString("distanceTitleLabel", distanceTitleLabel)
        putString("distanceLabel", distanceLabel)
        putString("currentPaceShortTitleLabel", currentPaceShortTitleLabel)
        putString("currentPaceTitleLabel", currentPaceTitleLabel)
        putString("currentPaceLabel", currentPaceLabel)
        putString("avgPaceTitleLabel", avgPaceTitleLabel)
        putString("avgPaceLabel", avgPaceLabel)
        putString("currentBlockLabel", currentBlockLabel)
        putString("nextBlockLabel", nextBlockLabel)
        putString("repLabel", repLabel)
        putBoolean("isPaused", isPaused)
        putDouble("distanceKm", distanceKm)
        putInt("paceSecondsPerKm", paceSecondsPerKm)
        putDouble("unitFactor", unitFactor)
        putString("distanceUnit", distanceUnit)
        putString("paceUnit", paceUnit)
        plannedDistanceKm?.let { putDouble("plannedDistanceKm", it) }
        plannedDurationMs?.let { putLong("plannedDurationMs", it) }
        if (timeline.isNotEmpty()) putString("timelineJson", timeline.toJsonString())
    }

    companion object {
        fun empty(): RunNotificationData = RunNotificationData(
            workoutName = "",
            statusTitleLabel = "",
            statusLabel = "",
            elapsedSeconds = 0,
            elapsedLabel = "00:00",
            elapsedUnitLabel = "",
            distanceTitleLabel = "",
            distanceLabel = "",
            currentPaceShortTitleLabel = "",
            currentPaceTitleLabel = "",
            currentPaceLabel = "",
            avgPaceTitleLabel = "",
            avgPaceLabel = "",
            currentBlockLabel = "",
            nextBlockLabel = null,
            repLabel = null,
            isPaused = false,
            distanceKm = 0.0,
            paceSecondsPerKm = 0,
            unitFactor = 1.0,
            distanceUnit = "km",
            paceUnit = "min/km",
            plannedDistanceKm = null,
            plannedDurationMs = null,
            timeline = emptyList(),
        )

        fun fromBundle(bundle: Bundle?): RunNotificationData {
            if (bundle == null) return empty()
            return RunNotificationData(
                workoutName = bundle.getString("workoutName").orEmpty(),
                statusTitleLabel = bundle.getString("statusTitleLabel").orEmpty(),
                statusLabel = bundle.getString("statusLabel").orEmpty(),
                elapsedSeconds = bundle.getLong("elapsedSeconds"),
                elapsedLabel = bundle.getString("elapsedLabel") ?: "00:00",
                elapsedUnitLabel = bundle.getString("elapsedUnitLabel").orEmpty(),
                distanceTitleLabel = bundle.getString("distanceTitleLabel").orEmpty(),
                distanceLabel = bundle.getString("distanceLabel").orEmpty(),
                currentPaceShortTitleLabel =
                    bundle.getString("currentPaceShortTitleLabel").orEmpty(),
                currentPaceTitleLabel =
                    bundle.getString("currentPaceTitleLabel").orEmpty(),
                currentPaceLabel = bundle.getString("currentPaceLabel").orEmpty(),
                avgPaceTitleLabel = bundle.getString("avgPaceTitleLabel").orEmpty(),
                avgPaceLabel = bundle.getString("avgPaceLabel").orEmpty(),
                currentBlockLabel = bundle.getString("currentBlockLabel").orEmpty(),
                nextBlockLabel = bundle.getString("nextBlockLabel"),
                repLabel = bundle.getString("repLabel"),
                isPaused = bundle.getBoolean("isPaused"),
                distanceKm = bundle.getDouble("distanceKm"),
                paceSecondsPerKm = bundle.getInt("paceSecondsPerKm"),
                unitFactor = bundle.getDouble("unitFactor", 1.0),
                distanceUnit = bundle.getString("distanceUnit") ?: "km",
                paceUnit = bundle.getString("paceUnit") ?: "min/km",
                plannedDistanceKm =
                    if (bundle.containsKey("plannedDistanceKm")) bundle.getDouble("plannedDistanceKm") else null,
                plannedDurationMs =
                    if (bundle.containsKey("plannedDurationMs")) bundle.getLong("plannedDurationMs") else null,
                timeline = timelineFromJsonString(bundle.getString("timelineJson")),
            )
        }

        fun fromMap(map: Map<*, *>?): RunNotificationData {
            if (map == null) return empty()
            return RunNotificationData(
                workoutName = map.stringValue("workoutName"),
                statusTitleLabel = map.stringValue("statusTitleLabel"),
                statusLabel = map.stringValue("statusLabel"),
                elapsedSeconds = map.longValue("elapsedSeconds"),
                elapsedLabel = map.stringValue("elapsedLabel", "00:00"),
                elapsedUnitLabel = map.stringValue("elapsedUnitLabel"),
                distanceTitleLabel = map.stringValue("distanceTitleLabel"),
                distanceLabel = map.stringValue("distanceLabel"),
                currentPaceShortTitleLabel = map.stringValue("currentPaceShortTitleLabel"),
                currentPaceTitleLabel = map.stringValue("currentPaceTitleLabel"),
                currentPaceLabel = map.stringValue("currentPaceLabel"),
                avgPaceTitleLabel = map.stringValue("avgPaceTitleLabel"),
                avgPaceLabel = map.stringValue("avgPaceLabel"),
                currentBlockLabel = map.stringValue("currentBlockLabel"),
                nextBlockLabel = map.optionalStringValue("nextBlockLabel"),
                repLabel = map.optionalStringValue("repLabel"),
                isPaused = map.booleanValue("isPaused"),
                distanceKm = map.doubleValue("distanceKm", 0.0),
                paceSecondsPerKm = map.intValue("paceSecondsPerKm"),
                unitFactor = map.doubleValue("unitFactor", 1.0),
                distanceUnit = map.stringValue("distanceUnit", "km"),
                paceUnit = map.stringValue("paceUnit", "min/km"),
                plannedDistanceKm = map.optionalDoubleValue("plannedDistanceKm"),
                plannedDurationMs = map.optionalLongValue("plannedDurationMs"),
                timeline = (map["timeline"] as? List<*>)
                    ?.mapNotNull { it as? Map<*, *> }
                    ?.map { TimelineBlock.fromMap(it) }
                    ?: emptyList(),
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

private fun Map<*, *>.optionalLongValue(key: String): Long? {
    return when (val value = this[key]) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull()
        else -> null
    }
}

private fun Map<*, *>.booleanValue(key: String): Boolean {
    return this[key] as? Boolean ?: false
}

private fun Map<*, *>.intValue(key: String): Int {
    return when (val value = this[key]) {
        is Number -> value.toInt()
        is String -> value.toIntOrNull() ?: 0
        else -> 0
    }
}

private fun Map<*, *>.doubleValue(key: String, fallback: Double): Double {
    return when (val value = this[key]) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull() ?: fallback
        else -> fallback
    }
}

private fun Map<*, *>.optionalDoubleValue(key: String): Double? {
    return when (val value = this[key]) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull()
        else -> null
    }
}
