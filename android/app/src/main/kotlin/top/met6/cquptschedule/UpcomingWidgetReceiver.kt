package top.met6.cquptschedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver

class UpcomingWidgetReceiver : GlanceAppWidgetReceiver() {
    
    override val glanceAppWidget: GlanceAppWidget = UpcomingWidget()

    override fun onReceive(context: Context, intent: Intent) {
        // super.onReceive handles triggering provideGlance() automatically
        super.onReceive(context, intent)
        
        // Schedule next alarm-based refresh (non-blocking, no Glance interference)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            WidgetAlarmManager.scheduleNextUpdate(context)
        }
    }
}