//
//  RoutineBuilderWidgetBundle.swift
//  RoutineBuilderWidget
//
//  Created by Nicholas Johnson on 3/9/26.
//

import WidgetKit
import SwiftUI

@main
struct RoutineBuilderWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoutineBuilderWidget()
        RoutineLiveActivity()
    }
}
