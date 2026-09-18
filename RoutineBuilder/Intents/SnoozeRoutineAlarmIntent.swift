//
//  SnoozeRoutineAlarmIntent.swift
//  RoutineBuilder
//
//  Created by Nicholas Johnson on 9/18/26.
//

import AppIntents

struct SnoozeRoutineAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze"
    static let description = IntentDescription("Snoozes the routine alarm for the configured duration.")
    static let supportedModes: IntentModes = [.foreground(.immediate)]

    @Parameter(title: "Routine ID")
    var routineIDString: String

    init(routineID: UUID) {
        self.routineIDString = routineID.uuidString
    }

    init() {
        self.routineIDString = ""
    }

    func perform() async throws -> some IntentResult {
        guard let routineID = UUID(uuidString: routineIDString) else {
            return .result()
        }
        NotificationCenter.default.post(
            name: .routineAlarmSnoozeTapped,
            object: nil,
            userInfo: ["routineID": routineID]
        )
        return .result()
    }
}
