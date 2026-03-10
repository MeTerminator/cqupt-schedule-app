package top.met6.cquptschedule

import java.text.SimpleDateFormat
import java.util.*
import org.json.JSONObject

// 课程实例模型
data class Course(
    val name: String,
    val location: String,
    val teacher: String?,
    val startTime: String,
    val endTime: String,
    val sortKey: Int
)

// 对齐 Swift 的数据结构
data class ScheduleInfo(
    val courses: List<Course>,
    val todayWeekInfo: String,
    val tomorrowWeekInfo: String,
    val todayDateStr: String,
    val tomorrowDateStr: String,
    val todayCourseCount: Int,
    val tomorrowCourseCount: Int
)

object ScheduleDataProcessor {

    fun process(jsonString: String?): ScheduleInfo? {
        if (jsonString.isNullOrBlank()) return null
        return try {
            val jsonObj = JSONObject(jsonString)
            val instances = jsonObj.getJSONArray("instances")
            val week1MondayStr = jsonObj.getString("week_1_monday")

            val cal = Calendar.getInstance()
            val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            
            // 计算当前日期信息
            val firstMonday = format.parse(week1MondayStr.substring(0, 10))!!
            val diffMs = cal.timeInMillis - firstMonday.time
            val diffDays = (diffMs / (1000 * 60 * 60 * 24)).toInt()
            val currentWeek = (diffDays / 7) + 1
            var currentDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) - 1
            if (currentDayOfWeek == 0) currentDayOfWeek = 7

            // 计算明天日期
            val tomorrowCal = Calendar.getInstance()
            tomorrowCal.add(Calendar.DAY_OF_YEAR, 1)
            val tomorrowDiffDays = ((tomorrowCal.timeInMillis - firstMonday.time) / (1000 * 60 * 60 * 24)).toInt()
            val tomorrowWeek = (tomorrowDiffDays / 7) + 1

            val todayCourses = mutableListOf<Course>()
            val tomorrowCourses = mutableListOf<Course>()
            val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

            for (i in 0 until instances.length()) {
                val c = instances.getJSONObject(i)
                val cWeek = c.getInt("week")
                val cDay = c.getInt("day")

                val isToday = (cWeek == currentWeek && cDay == currentDayOfWeek)
                val isTomorrow = (cWeek == tomorrowWeek && cDay == tomorrowCal.get(Calendar.DAY_OF_WEEK).let { if (it == 1) 7 else it - 1 })

                if (isToday) {
                    if (timeToMin(c.getString("end_time")) > currentMinutes) {
                        todayCourses.add(mapToCourse(c))
                    }
                } else if (isTomorrow) {
                    tomorrowCourses.add(mapToCourse(c))
                }
            }

            todayCourses.sortBy { it.sortKey }
            tomorrowCourses.sortBy { it.sortKey }

            ScheduleInfo(
                courses = todayCourses + tomorrowCourses,
                todayWeekInfo = "第 $currentWeek 周",
                tomorrowWeekInfo = "第 $tomorrowWeek 周",
                todayDateStr = SimpleDateFormat("MM/dd", Locale.getDefault()).format(cal.time),
                tomorrowDateStr = SimpleDateFormat("MM/dd", Locale.getDefault()).format(tomorrowCal.time),
                todayCourseCount = todayCourses.size,
                tomorrowCourseCount = tomorrowCourses.size
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun mapToCourse(c: JSONObject): Course {
        val startTime = c.getString("start_time")
        return Course(
            name = c.getString("course"),
            location = c.getString("location"),
            teacher = c.optString("teacher", "未知"),
            startTime = startTime,
            endTime = c.getString("end_time"),
            sortKey = timeToMin(startTime)
        )
    }

    private fun timeToMin(t: String): Int =
        try {
            t.split(":").let { it[0].toInt() * 60 + it[1].toInt() }
        } catch (e: Exception) {
            0
        }
}