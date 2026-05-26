package top.met6.cquptschedule

import android.app.AlarmManager
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

        // 2. 闹钟设置 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_ALARM).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val hasAlarmPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        alarmManager.canScheduleExactAlarms()
                    } else {
                        true
                    }
                    
                    val hasNotificationPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    } else {
                        true
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasNotificationPermission) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                        result.success(true) // 返回 true 以防止 Flutter 等待挂起
                    } else {
                        result.success(hasAlarmPermission)
                    }
                }
                "scheduleAlarms" -> {
                    val arguments = call.arguments as? List<Map<String, Any>>
                    if (arguments == null) {
                        result.error("INVALID_ARGUMENTS", "Arguments must be a list of maps", null)
                        return@setMethodCallHandler
                    }
                    
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    try {
                        for (alarmDict in arguments) {
                            val id = alarmDict["id"] as? String ?: continue
                            val title = alarmDict["title"] as? String ?: continue
                            val timeInMillis = (alarmDict["timeInMillis"] as? Number)?.toLong() ?: continue
                            
                            val intent = Intent(this, AlarmReceiver::class.java).apply {
                                putExtra("id", id)
                                putExtra("title", title)
                            }
                            
                            val pendingIntent = PendingIntent.getBroadcast(
                                this,
                                id.hashCode(),
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                if (alarmManager.canScheduleExactAlarms()) {
                                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                                } else {
                                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                                }
                            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                            } else {
                                alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                            }
                            
                            // 保存已设置的闹钟 ID 到本地 SharedPreferences
                            saveScheduledId(id)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }
                "cancelAlarm" -> {
                    val id = call.arguments as? String
                    if (id == null) {
                        result.error("INVALID_ARGUMENTS", "Argument must be a string", null)
                        return@setMethodCallHandler
                    }
                    
                    cancelAlarm(id)
                    result.success(true)
                }
                "clearAllAlarms" -> {
                    val ids = getScheduledIds()
                    for (id in ids) {
                        cancelAlarm(id)
                    }
                    clearScheduledIds()
                    result.success(true)
                }
                "checkOSVersionSupport" -> {
                    result.success(true)
                }
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

    private fun cancelAlarm(id: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
        removeScheduledId(id)
    }

    private fun getScheduledIds(): Set<String> {
        val prefs = getSharedPreferences("cqupt_schedule_alarms_pref", Context.MODE_PRIVATE)
        return prefs.getStringSet("scheduled_ids", emptySet()) ?: emptySet()
    }
    
    private fun saveScheduledId(id: String) {
        val prefs = getSharedPreferences("cqupt_schedule_alarms_pref", Context.MODE_PRIVATE)
        val current = prefs.getStringSet("scheduled_ids", emptySet())?.toMutableSet() ?: mutableSetOf()
        current.add(id)
        prefs.edit().putStringSet("scheduled_ids", current).apply()
    }
    
    private fun removeScheduledId(id: String) {
        val prefs = getSharedPreferences("cqupt_schedule_alarms_pref", Context.MODE_PRIVATE)
        val current = prefs.getStringSet("scheduled_ids", emptySet())?.toMutableSet() ?: mutableSetOf()
        if (current.remove(id)) {
            prefs.edit().putStringSet("scheduled_ids", current).apply()
        }
    }
    
    private fun clearScheduledIds() {
        val prefs = getSharedPreferences("cqupt_schedule_alarms_pref", Context.MODE_PRIVATE)
        prefs.edit().remove("scheduled_ids").apply()
    }
}
