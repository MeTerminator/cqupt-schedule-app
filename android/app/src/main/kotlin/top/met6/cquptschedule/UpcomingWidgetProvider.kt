package top.met6.cquptschedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class UpcomingWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            updateWidgetUI(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    private fun updateWidgetUI(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, widgetData: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming)
        try {
            val jsonString = widgetData.getString("full_schedule_json", null)
            if (jsonString != null) {
                val jsonObj = JSONObject(jsonString)
                val instances = jsonObj.getJSONArray("instances")
                val week1MondayStr = jsonObj.getString("week_1_monday")

                val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val firstMonday = format.parse(week1MondayStr.substring(0, 10))!!
                val cal = Calendar.getInstance()
                
                // --- 1. 计算日期和周数 ---
                val diffDays = ((cal.timeInMillis - firstMonday.time) / (1000 * 60 * 60 * 24)).toInt()
                val currentWeek = (diffDays / 7) + 1
                var currentDay = cal.get(Calendar.DAY_OF_WEEK) - 1
                if (currentDay == 0) currentDay = 7
                
                // 绑定日期和周数到 UI
                val displayFormat = SimpleDateFormat("MM/dd", Locale.getDefault())
                val dayNames = arrayOf("", "一", "二", "三", "四", "五", "六", "日")
                views.setTextViewText(R.id.tv_date, "${displayFormat.format(cal.time)} 星期${dayNames[currentDay]}")
                views.setTextViewText(R.id.tv_week, "第 $currentWeek 周")

                // --- 2. 课程逻辑 ---
                val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                val todayList = mutableListOf<JSONObject>()
                val tomorrowList = mutableListOf<JSONObject>()
                
                val tomorrowDay = if (currentDay == 7) 1 else currentDay + 1
                val tomorrowWeek = if (currentDay == 7) currentWeek + 1 else currentWeek

                for (i in 0 until instances.length()) {
                    val c = instances.getJSONObject(i)
                    if (c.getInt("week") == currentWeek && c.getInt("day") == currentDay) {
                        if (timeToMin(c.getString("end_time")) > currentMinutes) {
                            todayList.add(c)
                        }
                    } else if (c.getInt("week") == tomorrowWeek && c.getInt("day") == tomorrowDay) {
                        tomorrowList.add(c)
                    }
                }
                
                todayList.sortBy { timeToMin(it.getString("start_time")) }
                tomorrowList.sortBy { timeToMin(it.getString("start_time")) }

                val displayList = mutableListOf<JSONObject>()
                displayList.addAll(todayList)
                displayList.addAll(tomorrowList)

                // --- 3. UI 绑定 ---
                if (displayList.isNotEmpty()) {
                    val current = displayList[0]
                    views.setTextViewText(R.id.tv_current_name, current.getString("course"))
                    views.setTextViewText(R.id.tv_current_loc, "${current.getString("location")} ${current.optString("teacher", "")}")
                    views.setTextViewText(R.id.tv_current_time, "${current.getString("start_time")} - ${current.getString("end_time")}")
                    
                    if (displayList.size > 1) {
                        val next = displayList[1]
                        views.setTextViewText(R.id.tv_next_name, next.getString("course"))
                        views.setTextViewText(R.id.tv_next_loc, "${next.getString("location")} ${next.optString("teacher", "")}")
                        views.setTextViewText(R.id.tv_next_time, "${next.getString("start_time")} - ${next.getString("end_time")}")
                    } else {
                        views.setTextViewText(R.id.tv_next_name, "无")
                        views.setTextViewText(R.id.tv_next_loc, "")
                        views.setTextViewText(R.id.tv_next_time, "")
                    }
                }
                
                // --- 4. 尺寸逻辑 ---
                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val isSmall = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) < 230
                views.setViewVisibility(R.id.layout_next_course, if (isSmall) View.GONE else View.VISIBLE)
                views.setViewVisibility(R.id.divider_line, if (isSmall) View.GONE else View.VISIBLE)
            }
        } catch (e: Exception) { e.printStackTrace() }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        updateWidgetUI(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun timeToMin(time: String): Int {
        val parts = time.split(":")
        return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
    }
}