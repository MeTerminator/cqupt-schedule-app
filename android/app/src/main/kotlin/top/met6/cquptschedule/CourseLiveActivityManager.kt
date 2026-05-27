package top.met6.cquptschedule

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.RemoteViews

object CourseLiveActivityManager {
    const val LIVE_ACTIVITY_NOTIFICATION_ID = 45678
    const val LIVE_CARD_NOTIFICATION_ID = 45679
    const val LIVE_CHANNEL_ID = "cqupt_schedule_live_channel"

    fun startCourseLiveActivity(
        context: Context,
        courseId: String,
        courseName: String,
        classroom: String,
        startTimeInMillis: Long,
        endTimeInMillis: Long,
        leadMinutes: Int
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. Create channel (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelName = "今日上课实时状态"
            val importance = NotificationManager.IMPORTANCE_DEFAULT // Must not be IMPORTANCE_MIN to support Live Updates!
            val channel = NotificationChannel(LIVE_CHANNEL_ID, channelName, importance).apply {
                description = "用于在状态栏和通知栏展示今日上课实时状态及倒计时"
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 2. Open App Intent
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            courseId.hashCode(),
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val now = System.currentTimeMillis()
        val isOngoing = now >= startTimeInMillis && now < endTimeInMillis

        // Build title and text for modern Android 16+ Live Updates
        val contentTitle = "$classroom · $courseName · ${if (isOngoing) "课中" else "课间"}"
        val contentText = "重邮课表"

        // 3. Build RemoteViews for iOS Dynamic Island style
        val remoteViews = RemoteViews(context.packageName, R.layout.notification_dynamic_island)
        remoteViews.setTextViewText(R.id.course_name_text, courseName)
        remoteViews.setTextViewText(R.id.classroom_text, classroom)

        // Collapsed layout: 左侧显示 地点 XXXX，右侧显示 离上课 / 离下课 00:00:00
        val collapsedViews = RemoteViews(context.packageName, R.layout.notification_dynamic_island_collapsed)
        collapsedViews.setTextViewText(R.id.classroom_text, "地点 $classroom")

        val targetTimeInMillis = if (isOngoing) endTimeInMillis else startTimeInMillis
        val delta = targetTimeInMillis - now
        val baseTime = android.os.SystemClock.elapsedRealtime() + delta

        // Query theme-aware colors defined in colors.xml
        val blueColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.getColor(R.color.live_activity_blue)
        } else {
            @Suppress("DEPRECATION")
            context.resources.getColor(R.color.live_activity_blue)
        }
        val greenColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.getColor(R.color.live_activity_green)
        } else {
            @Suppress("DEPRECATION")
            context.resources.getColor(R.color.live_activity_green)
        }

        val accentColor = if (isOngoing) greenColor else blueColor
        val stateText = if (isOngoing) "离下课" else "离上课"

        // Setup expanded view
        remoteViews.setTextViewText(R.id.state_label, stateText)
        remoteViews.setTextColor(R.id.state_label, accentColor)
        remoteViews.setTextColor(R.id.chronometer, accentColor)
        remoteViews.setChronometer(R.id.chronometer, baseTime, null, true)

        // Setup collapsed view (spacing is handled via XML layout margins)
        collapsedViews.setTextViewText(R.id.state_label, stateText)
        collapsedViews.setTextColor(R.id.state_label, accentColor)
        collapsedViews.setTextColor(R.id.chronometer, accentColor)
        collapsedViews.setChronometer(R.id.chronometer, baseTime, null, true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            remoteViews.setChronometerCountDown(R.id.chronometer, true)
            collapsedViews.setChronometerCountDown(R.id.chronometer, true)
        }

        // 4. Build Merged Live Update Notification (LIVE_ACTIVITY_NOTIFICATION_ID)
        val smallIconResId = if (isOngoing) R.drawable.ic_live_book else R.drawable.ic_live_clock
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, LIVE_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder.setSmallIcon(smallIconResId)
            .setContentTitle(contentTitle)   // 课程名 · 课中/课间
            .setContentText(contentText)     // 固定字样 “重邮课表”
            .setSubText(classroom)           // 地点
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setUsesChronometer(true)
            .setShowWhen(true)

        if (Build.VERSION.SDK_INT >= 36) { // Android 16 (BAKLAVA)
            // On Android 16+, do NOT set custom RemoteViews to ensure the OS elevates the notification to a status bar capsule countdown timer natively
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setChronometerCountDown(true)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setChronometerCountDown(true)
            builder.setCustomContentView(collapsedViews)
            builder.setCustomBigContentView(remoteViews)
        } else {
            @Suppress("DEPRECATION")
            builder.setContent(collapsedViews)
        }

        if (isOngoing) {
            builder.setWhen(endTimeInMillis)
        } else {
            builder.setWhen(startTimeInMillis)
        }

        // Apply Android 16 Live Updates configurations using Reflection
        configureAndroid16LiveUpdate(context, builder, isOngoing, startTimeInMillis, endTimeInMillis)

        try {
            notificationManager.notify(LIVE_ACTIVITY_NOTIFICATION_ID, builder.build())
            Log.d("CourseLiveActivity", "Merged Live Update Notification (ID: $LIVE_ACTIVITY_NOTIFICATION_ID) posted successfully. Ongoing: $isOngoing")
        } catch (e: Exception) {
            Log.e("CourseLiveActivity", "Failed to post Merged Live Update Notification: ${e.message}", e)
        }
    }

    fun stopCourseLiveActivity(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            notificationManager.cancel(LIVE_ACTIVITY_NOTIFICATION_ID)
            notificationManager.cancel(LIVE_CARD_NOTIFICATION_ID)
            Log.d("CourseLiveActivity", "Live Update notifications cancelled.")
        } catch (e: Exception) {
            Log.e("CourseLiveActivity", "Failed to cancel Live Update notifications: ${e.message}", e)
        }
    }

    private fun configureAndroid16LiveUpdate(
        context: Context,
        builder: Notification.Builder,
        isOngoing: Boolean,
        startTimeInMillis: Long,
        endTimeInMillis: Long
    ) {
        if (Build.VERSION.SDK_INT >= 36) { // 36 is Android 16 (BAKLAVA)
            try {
                // 1. Call setRequestPromotedOngoing(true) to request elevation to status bar capsule chip
                val setRequestPromotedOngoingMethod = builder.javaClass.getMethod("setRequestPromotedOngoing", Boolean::class.java)
                setRequestPromotedOngoingMethod.invoke(builder, true)

                // 2. Create ProgressStyle via reflection to make it a promoted Live Update
                val progressStyleClass = Class.forName("android.app.Notification\$ProgressStyle")
                val progressStyle = progressStyleClass.getConstructor().newInstance()

                // Calculate progress based on class time elapsed
                val now = System.currentTimeMillis()
                val progressVal = if (isOngoing) {
                    val total = endTimeInMillis - startTimeInMillis
                    if (total > 0) {
                        ((now - startTimeInMillis) * 100 / total).toInt().coerceIn(0, 100)
                    } else 0
                } else 0

                val setProgressMethod = progressStyleClass.getMethod("setProgress", Int::class.java)
                setProgressMethod.invoke(progressStyle, progressVal)

                // 3. Set the progress tracker icon (clock/book) dynamically on the progress style via reflection
                try {
                    val setProgressTrackerIconMethod = progressStyleClass.getMethod(
                        "setProgressTrackerIcon", 
                        android.graphics.drawable.Icon::class.java
                    )
                    val smallIconResId = if (isOngoing) R.drawable.ic_live_book else R.drawable.ic_live_clock
                    val trackerIcon = android.graphics.drawable.Icon.createWithResource(context, smallIconResId)
                    setProgressTrackerIconMethod.invoke(progressStyle, trackerIcon)
                } catch (iconEx: Exception) {
                    Log.e("CourseLiveActivity", "Failed to set ProgressStyle tracker icon via reflection: ${iconEx.message}")
                }

                // Set style on the builder
                val setStyleMethod = builder.javaClass.getMethod("setStyle", Class.forName("android.app.Notification\$Style"))
                setStyleMethod.invoke(builder, progressStyle)
                
                Log.d("CourseLiveActivity", "Successfully configured Android 16 Live Update via reflection with ProgressStyle. Progress: $progressVal%")
            } catch (e: Exception) {
                Log.e("CourseLiveActivity", "Failed to configure Android 16 Live Update via reflection: ${e.message}", e)
            }
        }
    }
}
