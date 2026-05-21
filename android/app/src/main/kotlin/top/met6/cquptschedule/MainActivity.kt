package top.met6.cquptschedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
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
