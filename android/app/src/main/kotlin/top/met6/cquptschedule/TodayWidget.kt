package top.met6.cquptschedule

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider

class TodayWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = prefs.getString("full_schedule_json", null)
        val data = ScheduleDataProcessor.process(jsonString)

        provideContent {
            GlanceTheme {
                Column(
                        modifier =
                                GlanceModifier.fillMaxSize()
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    if (data == null || data.courses.isEmpty()) {
                        Text("近期无课程", modifier = GlanceModifier.padding(16.dp))
                    } else {
                        // 头部：使用新数据模型中的字段
                        HeaderView(data.todayDateStr, data.todayCourseCount, data.todayWeekInfo)

                        // 课程列表：使用 data.courses 列表渲染
                        Column(modifier = GlanceModifier.padding(top = 4.dp)) {
                            data.courses.forEachIndexed { index, course ->
                                // 增加间隙的逻辑：如果不是第一行，添加 Spacer
                                if (index > 0 && index != data.todayCourseCount) {
                                    Spacer(modifier = GlanceModifier.height(4.dp))
                                }
                                // 如果到了明天课程的开始，插入明日Header
                                if (index == data.todayCourseCount) {
                                    Spacer(modifier = GlanceModifier.height(8.dp))
                                    HeaderView(
                                            data.tomorrowDateStr,
                                            data.tomorrowCourseCount,
                                            data.tomorrowWeekInfo
                                    )
                                    Spacer(modifier = GlanceModifier.height(4.dp))
                                }
                                CourseRow(course)
                            }
                        }
                    }
                    Spacer(modifier = GlanceModifier.defaultWeight())
                }
            }
        }
    }
}

@Composable
private fun HeaderView(dateStr: String, count: Int, weekInfo: String) {
    Row(modifier = GlanceModifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp)) {
        Text(
                "$dateStr · $count 节课",
                style = TextStyle(fontSize = 12.sp, color = GlanceTheme.colors.onSurfaceVariant)
        )
        Spacer(modifier = GlanceModifier.defaultWeight())
        Text(
                weekInfo,
                style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color(0xFF007AFF)))
        )
    }
}

@Composable
private fun CourseRow(course: Course) {
    Row(
            modifier =
                    GlanceModifier.fillMaxWidth()
                            // 关键：这里去掉了垂直 padding，改用 Widget 内部排列时的 Spacer 控制
                            .background(GlanceTheme.colors.secondaryContainer)
                            .cornerRadius(10.dp)
                            .padding(horizontal = 10.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
                modifier =
                        GlanceModifier.width(4.dp)
                                .height(34.dp)
                                .background(ColorProvider(getColorForCourse(course.name)))
                                .cornerRadius(2.dp)
        ) { Spacer(modifier = GlanceModifier.fillMaxSize()) }

        Column(modifier = GlanceModifier.padding(start = 8.dp).defaultWeight()) {
            Text(
                    course.name,
                    style = TextStyle(fontSize = 14.sp, color = GlanceTheme.colors.onSurface),
                    maxLines = 1
            )
            Text(
                    "${course.location}  ${course.teacher ?: ""}",
                    style =
                            TextStyle(
                                    fontSize = 14.sp,
                                    color = GlanceTheme.colors.onSurfaceVariant
                            ),
                    maxLines = 1
            )
        }

        Column(horizontalAlignment = Alignment.End) {
            Text(
                    course.startTime,
                    style = TextStyle(fontSize = 13.sp, color = GlanceTheme.colors.onSurface)
            )
            Text(
                    course.endTime,
                    style = TextStyle(fontSize = 13.sp, color = GlanceTheme.colors.onSurface)
            )
        }
    }
}

private fun getColorForCourse(name: String): Color {
    val colors =
            listOf(
                    Color(0xFFFF9500),
                    Color(0xFF007AFF),
                    Color(0xFF34C759),
                    Color(0xFFAF52DE),
                    Color(0xFFFF2D55),
                    Color(0xFFFF3B30),
                    Color(0xFF5AC8FA)
            )
    return colors[Math.abs(name.hashCode()) % colors.size]
}
