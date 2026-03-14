import SwiftUI
import WidgetKit

@main
struct CquptScheduleWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpcomingCourseWidget()
        TodayCourseWidget()
        LockScreenWidget()
    }
}
