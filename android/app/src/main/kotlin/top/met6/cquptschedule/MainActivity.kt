package top.met6.cquptschedule

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.os.Environment
import android.provider.Settings
import android.net.Uri
import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.widget.RemoteViews
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val CHANNEL_WIDGET = "top.met6.cquptschedule/widget"
    private val CHANNEL_ALARM = "top.met6.cquptschedule/alarm"
    private val CHANNEL_UPDATE = "top.met6.cquptschedule/update"
    private val TAG = "WidgetChannel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. 小组件同步 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_WIDGET).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    Log.d(TAG, "updateWidgets called from Flutter")
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            Log.d(TAG, "Calling UpcomingWidget().updateAll()...")
                            UpcomingWidget().updateAll(this@MainActivity)
                            Log.d(TAG, "UpcomingWidget updated!")
                            
                            Log.d(TAG, "Calling TodayWidget().updateAll()...")
                            TodayWidget().updateAll(this@MainActivity)
                            Log.d(TAG, "TodayWidget updated!")
                            
                            WidgetAlarmManager.scheduleNextUpdate(this@MainActivity)
                            
                            launch(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error updating widgets: ${e.message}", e)
                            launch(Dispatchers.Main) {
                                result.error("UPDATE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 2. 实时活动与通知权限 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_ALARM).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNotificationPermission" -> {
                    val hasNotificationPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    } else {
                        true
                    }
                    result.success(hasNotificationPermission)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val hasNotificationPermission = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        if (!hasNotificationPermission) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 102)
                        }
                    }
                    result.success(true)
                }
                "startCourseLiveActivity" -> {
                    val arguments = call.arguments as? Map<String, Any>
                    if (arguments == null) {
                        result.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                        return@setMethodCallHandler
                    }
                    val courseId = arguments["courseId"] as? String ?: ""
                    val courseName = arguments["courseName"] as? String ?: ""
                    val classroom = arguments["classroom"] as? String ?: ""
                    val startTimeInMillis = (arguments["startTimeInMillis"] as? Number)?.toLong() ?: 0L
                    val endTimeInMillis = (arguments["endTimeInMillis"] as? Number)?.toLong() ?: 0L
                    val leadMinutes = (arguments["leadMinutes"] as? Number)?.toInt() ?: 15

                    startCourseLiveActivity(courseId, courseName, classroom, startTimeInMillis, endTimeInMillis, leadMinutes)
                    result.success(true)
                }
                "stopCourseLiveActivity" -> {
                    stopCourseLiveActivity()
                    result.success(true)
                }
                // 保留极简空桩实现，确保向前兼容性
                "requestPermission" -> result.success(true)
                "scheduleAlarms" -> result.success(true)
                "cancelAlarm" -> result.success(true)
                "clearAllAlarms" -> result.success(true)
                "checkOSVersionSupport" -> result.success(true)
                else -> result.notImplemented()
            }
        }

        // 3. Android App 更新 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_UPDATE).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkInstallPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestInstallPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", e.message, null)
                    }
                }
                "checkApkExists" -> {
                    val versionCode = (call.arguments as? Number)?.toInt()
                    if (versionCode == null) {
                        result.error("INVALID_ARGUMENTS", "versionCode is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        val apkFile = java.io.File(downloadsDir, "cqupt_schedule_update_$versionCode.apk")
                        if (apkFile.exists()) {
                            val info = packageManager.getPackageArchiveInfo(apkFile.absolutePath, 0)
                            val apkVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                info?.longVersionCode ?: 0L
                            } else {
                                info?.versionCode?.toLong() ?: 0L
                            }
                            if (apkVersionCode == versionCode.toLong()) {
                                result.success(apkFile.absolutePath)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e("UpdateChannel", "Error checking APK: ${e.message}", e)
                        result.success(null)
                    }
                }
                "startDownload" -> {
                    val arguments = call.arguments as? Map<String, Any>
                    val downloadUrl = arguments?.get("url") as? String
                    val versionCode = (arguments?.get("versionCode") as? Number)?.toInt()
                    if (downloadUrl == null || versionCode == null) {
                        result.error("INVALID_ARGUMENTS", "url and versionCode are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                        val request = DownloadManager.Request(Uri.parse(downloadUrl)).apply {
                            setTitle("重邮课表更新")
                            setDescription("正在下载新版本 v$versionCode...")
                            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                            setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "cqupt_schedule_update_$versionCode.apk")
                            setAllowedOverMetered(true)
                            setAllowedOverRoaming(true)
                        }
                        val downloadId = downloadManager.enqueue(request)
                        result.success(downloadId)
                    } catch (e: Exception) {
                        Log.e("UpdateChannel", "Error starting download: ${e.message}", e)
                        result.error("DOWNLOAD_ERROR", e.message, null)
                    }
                }
                "getDownloadProgress" -> {
                    val downloadId = (call.arguments as? Number)?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ARGUMENTS", "Download ID is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                        val query = DownloadManager.Query().setFilterById(downloadId)
                        val cursor = downloadManager.query(query)
                        if (cursor != null && cursor.moveToFirst()) {
                            val bytesDownloadedIndex = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                            val bytesTotalIndex = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                            val statusIndex = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                            
                            val bytesDownloaded = if (bytesDownloadedIndex != -1) cursor.getLong(bytesDownloadedIndex) else 0L
                            val bytesTotal = if (bytesTotalIndex != -1) cursor.getLong(bytesTotalIndex) else 0L
                            val status = if (statusIndex != -1) cursor.getInt(statusIndex) else DownloadManager.STATUS_FAILED
                            val progress = if (bytesTotal > 0) bytesDownloaded.toDouble() / bytesTotal else 0.0
                            
                            val resultMap = mapOf(
                                "progress" to progress,
                                "status" to status,
                                "bytesDownloaded" to bytesDownloaded,
                                "bytesTotal" to bytesTotal
                            )
                            cursor.close()
                            result.success(resultMap)
                        } else {
                            cursor?.close()
                            result.error("DOWNLOAD_NOT_FOUND", "No download found with ID $downloadId", null)
                        }
                    } catch (e: Exception) {
                        Log.e("UpdateChannel", "Error querying progress: ${e.message}", e)
                        result.error("QUERY_ERROR", e.message, null)
                    }
                }
                "installApk" -> {
                    val arguments = call.arguments as? Map<String, Any>
                    val apkPath = arguments?.get("apkPath") as? String
                    val downloadId = (arguments?.get("downloadId") as? Number)?.toLong()
                    
                    try {
                        if (apkPath != null) {
                            val file = java.io.File(apkPath)
                            if (!file.exists()) {
                                result.error("FILE_NOT_FOUND", "APK file does not exist at $apkPath", null)
                                return@setMethodCallHandler
                            }
                            
                            val apkUri = androidx.core.content.FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileprovider",
                                file
                            )
                            
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else if (downloadId != null) {
                            val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                            val uri = downloadManager.getUriForDownloadedFile(downloadId)
                            if (uri != null) {
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("URI_NULL", "Could not get Uri for download ID $downloadId", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENTS", "apkPath or downloadId is required", null)
                        }
                    } catch (e: Exception) {
                        Log.e("UpdateChannel", "Error installing APK: ${e.message}", e)
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }



    private val LIVE_ACTIVITY_NOTIFICATION_ID = 45678
    private val LIVE_CARD_NOTIFICATION_ID = 45679
    private val LIVE_CHANNEL_ID = "cqupt_schedule_live_channel"

    private fun startCourseLiveActivity(
        courseId: String,
        courseName: String,
        classroom: String,
        startTimeInMillis: Long,
        endTimeInMillis: Long,
        leadMinutes: Int
    ) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

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
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            courseId.hashCode(),
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val now = System.currentTimeMillis()
        val isOngoing = now >= startTimeInMillis && now < endTimeInMillis

        // Build title and text for modern Android 16+ Live Updates
        val contentTitle = courseName
        val contentText = classroom

        // 3. Build RemoteViews for iOS Dynamic Island style
        val remoteViews = RemoteViews(packageName, R.layout.notification_dynamic_island)
        remoteViews.setTextViewText(R.id.course_name_text, courseName)
        remoteViews.setTextViewText(R.id.classroom_text, classroom)

        // Collapsed layout: 左侧显示 地点 XXXX，右侧显示 离上课 / 离下课 00:00:00
        val collapsedViews = RemoteViews(packageName, R.layout.notification_dynamic_island_collapsed)
        collapsedViews.setTextViewText(R.id.classroom_text, "地点 $classroom")

        val targetTimeInMillis = if (isOngoing) endTimeInMillis else startTimeInMillis
        val delta = targetTimeInMillis - now
        val baseTime = android.os.SystemClock.elapsedRealtime() + delta

        // Query theme-aware colors defined in colors.xml
        val blueColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getColor(R.color.live_activity_blue)
        } else {
            @Suppress("DEPRECATION")
            resources.getColor(R.color.live_activity_blue)
        }
        val greenColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getColor(R.color.live_activity_green)
        } else {
            @Suppress("DEPRECATION")
            resources.getColor(R.color.live_activity_green)
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
            Notification.Builder(this, LIVE_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }


        builder.setSmallIcon(smallIconResId)
            .setContentTitle(stateText)      // 最顶部的"离上下课"说明：离下课/离上课
            .setContentText(contentText)     // 课程地点
            .setSubText(courseName)          // 课程名称
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
        configureAndroid16LiveUpdate(builder, isOngoing, startTimeInMillis, endTimeInMillis)

        try {
            notificationManager.notify(LIVE_ACTIVITY_NOTIFICATION_ID, builder.build())
            Log.d("MainActivity", "Merged Live Update Notification (ID: $LIVE_ACTIVITY_NOTIFICATION_ID) posted successfully. Ongoing: $isOngoing")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to post Merged Live Update Notification: ${e.message}", e)
        }
    }

    private fun stopCourseLiveActivity() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            notificationManager.cancel(LIVE_ACTIVITY_NOTIFICATION_ID)
            notificationManager.cancel(LIVE_CARD_NOTIFICATION_ID)
            Log.d("MainActivity", "Live Update notifications cancelled.")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to cancel Live Update notifications: ${e.message}", e)
        }
    }

    private fun configureAndroid16LiveUpdate(
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
                    val trackerIcon = android.graphics.drawable.Icon.createWithResource(this@MainActivity, smallIconResId)
                    setProgressTrackerIconMethod.invoke(progressStyle, trackerIcon)
                } catch (iconEx: Exception) {
                    Log.e("MainActivity", "Failed to set ProgressStyle tracker icon via reflection: ${iconEx.message}")
                }

                // Set style on the builder
                val setStyleMethod = builder.javaClass.getMethod("setStyle", Class.forName("android.app.Notification\$Style"))
                setStyleMethod.invoke(builder, progressStyle)
                
                Log.d("MainActivity", "Successfully configured Android 16 Live Update via reflection with ProgressStyle. Progress: $progressVal%")
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to configure Android 16 Live Update via reflection: ${e.message}", e)
            }
        }
    }
}
