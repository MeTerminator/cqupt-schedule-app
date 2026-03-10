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
                // 最外层容器：设置白色/深色背景和圆角
                Column(
                        modifier =
                                GlanceModifier.fillMaxSize()
                                        .background(GlanceTheme.colors.surface) // 自动适配亮/暗主题
                                        .cornerRadius(16.dp) // 圆角适配
                                        .padding(8.dp) // 组件内边距
                ) {
                    if (data == null || data.courses.isEmpty()) {
                        Text("近期无课程", modifier = GlanceModifier.padding(16.dp))
                    } else {
                        // 头部
                        HeaderView(data.todayDateStr, data.todayCourseCount, data.todayWeekInfo)

                        // 课程列表
                        Column(modifier = GlanceModifier.padding(top = 4.dp)) {
                            data.courses.forEachIndexed { index, course ->
                                if (index > 0 && index != data.todayCourseCount) {
                                    Spacer(modifier = GlanceModifier.height(4.dp))
                                }
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
