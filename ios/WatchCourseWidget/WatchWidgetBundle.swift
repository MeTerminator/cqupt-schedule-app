import SwiftUI
import WidgetKit

@main
struct WatchCourseWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchRectangularWidget()
        WatchCircularWidget()
        WatchInlineWidget()
        WatchCornerWidget()
    }
}
