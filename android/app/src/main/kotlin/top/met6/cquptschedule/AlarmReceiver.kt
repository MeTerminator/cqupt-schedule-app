package top.met6.cquptschedule

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    private val TAG = "AlarmReceiver"
    private val CHANNEL_ID = "cqupt_schedule_alarm_channel"

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "课程闹钟提醒"
        val idStr = intent.getStringExtra("id") ?: "default_alarm_id"
        Log.d(TAG, "Alarm received! id: $idStr, title: $title")

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. 创建高优先级通知渠道 (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelName = "课程闹钟提醒"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, channelName, importance).apply {
                description = "用于课程开始提醒和早八早十起床闹钟"
                enableLights(true)
                enableVibration(true)
                
                // 设置系统默认闹铃作为提示音
                val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                setSound(alarmUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 2. 创建点击通知时跳转回到 App 的 PendingIntent
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            idStr.hashCode(),
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 3. 构建通知内容
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        
        val appIconResId = context.applicationInfo.icon
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(if (appIconResId != 0) appIconResId else android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("您的上课闹钟响了，请做好上课准备！")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setSound(alarmUri)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setFullScreenIntent(pendingIntent, true) // 作为全屏意图/横幅强力弹出
            .setContentIntent(pendingIntent)

        // 4. 发送通知
        try {
            notificationManager.notify(idStr.hashCode(), builder.build())
            Log.d(TAG, "Notification fired successfully for alarm id: $idStr")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fire notification: ${e.message}", e)
        }
    }
}
