//
//  CourseWidgetBundle.swift
//  CourseWidget
//
//  Created by MeTerminator on 2026/3/6.
//

import WidgetKit
import SwiftUI

@main
struct CourseWidgetBundle: WidgetBundle {
    var body: some Widget {
        CourseWidget()
        CourseWidgetControl()
        CourseWidgetLiveActivity()
    }
}
