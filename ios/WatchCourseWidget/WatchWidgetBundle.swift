import SwiftUI
import WidgetKit

@available(iOS 16.0, watchOS 9.0, *)
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
