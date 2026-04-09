import SwiftUI
import WidgetKit

@available(iOS 14.0, watchOS 7.0, *)
@main
struct WatchCourseWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchRectangularWidget()
        WatchCircularWidget()
        WatchInlineWidget()
        #if os(watchOS)
        WatchCornerWidget()
        #endif
    }
}
