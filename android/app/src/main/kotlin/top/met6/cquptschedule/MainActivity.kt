package top.met6.cquptschedule

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val CHANNEL = "top.met6.cquptschedule/widget"
    private val TAG = "WidgetChannel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    Log.d(TAG, "updateWidgets called from Flutter")
                    // 官方建议在主线程范围之外启动 suspend 函数
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            Log.d(TAG, "Calling UpcomingWidget().updateAll()...")
                            UpcomingWidget().updateAll(this@MainActivity)
                            Log.d(TAG, "UpcomingWidget updated!")
                            
                            Log.d(TAG, "Calling TodayWidget().updateAll()...")
                            TodayWidget().updateAll(this@MainActivity)
                            Log.d(TAG, "TodayWidget updated!")
                            
                            WidgetAlarmManager.scheduleNextUpdate(this@MainActivity)
                            
                            // 必须在主线程回调 result
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
    }
}
