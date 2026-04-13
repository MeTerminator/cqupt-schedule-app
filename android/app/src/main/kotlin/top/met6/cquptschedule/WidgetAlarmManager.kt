package top.met6.cquptschedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.*

object WidgetAlarmManager {
    private const val TAG = "WidgetAlarmManager"
    private const val REQUEST_CODE_UPCOMING = 1001
    private const val REQUEST_CODE_TODAY = 1002

    fun scheduleNextUpdate(context: Context) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = prefs.getString("full_schedule_json", null)
        val scheduleData = ScheduleDataProcessor.process(jsonString) ?: return

        val now = Calendar.getInstance()
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        var nextUpdateTime: Calendar? = null
        var minDiff = Int.MAX_VALUE

        // 遍历今日课程，找出最近的一个时间点（开始或结束）
        for (course in scheduleData.courses) {
            val startMin = timeToMin(course.startTime)
            val endMin = timeToMin(course.endTime)

            // 如果课程还没开始
            if (startMin > currentMinutes) {
                if (startMin - currentMinutes < minDiff) {
                    minDiff = startMin - currentMinutes
                    nextUpdateTime = getCalendarWithTime(startMin)
                }
            }
            // 如果课程正在进行
            if (endMin > currentMinutes) {
                if (endMin - currentMinutes < minDiff) {
                    minDiff = endMin - currentMinutes
                    nextUpdateTime = getCalendarWithTime(endMin)
                }
            }
        }

        // 如果今天没课了，或者所有课都结束了，预约明天凌晨 0:01 刷新
        if (nextUpdateTime == null) {
            nextUpdateTime = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
            }
        }

        if (nextUpdateTime != null) {
            setAlarm(context, nextUpdateTime)
        }
    }

    private fun setAlarm(context: Context, time: Calendar) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // 为两个 Widget 各设置一个 PendingIntent
        val upcomingIntent = Intent(context, UpcomingWidgetReceiver::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val todayIntent = Intent(context, TodayWidgetReceiver::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        
        val upcomingPendingIntent = PendingIntent.getBroadcast(
            context, REQUEST_CODE_UPCOMING, upcomingIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val todayPendingIntent = PendingIntent.getBroadcast(
            context, REQUEST_CODE_TODAY, todayIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            // 用 setExact 设置两个独立的闹钟
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.timeInMillis, upcomingPendingIntent)
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.timeInMillis, todayPendingIntent)
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.timeInMillis, upcomingPendingIntent)
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.timeInMillis, todayPendingIntent)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.timeInMillis, upcomingPendingIntent)
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.timeInMillis, todayPendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, time.timeInMillis, upcomingPendingIntent)
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, time.timeInMillis, todayPendingIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling alarm: ${e.message}")
        }
    }

    private fun timeToMin(t: String): Int =
        try {
            t.split(":").let { it[0].toInt() * 60 + it[1].toInt() }
        } catch (e: Exception) {
            0
        }

    private fun getCalendarWithTime(minutes: Int): Calendar {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
        }
    }
}
