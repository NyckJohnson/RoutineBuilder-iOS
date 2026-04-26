//
//  RoutineBuilderWidgetLiveActivity.swift
//  RoutineBuilderWidget
//
//  Created by Nicholas Johnson on 3/9/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RoutineAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var cardTitle: String
        var secondsRemaining: Int
        var totalSeconds: Int
    }
    var routineName: String
}

struct RoutineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineAttributes.self) { context in
            // Lock Screen UI
            HStack {
                Text(context.attributes.routineName)
                Spacer()
                Text("\(context.state.secondsRemaining / 60):\(String(format: "%02d", context.state.secondsRemaining % 60))")
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.routineName).font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.cardTitle)").font(.caption)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text("\(context.state.secondsRemaining / 60)m").monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}
