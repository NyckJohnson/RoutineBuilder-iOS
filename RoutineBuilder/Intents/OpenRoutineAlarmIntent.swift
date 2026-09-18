//
//  OpenRoutineAlarmIntent.swift
//  RoutineBuilder
//
//  Created by Nicholas Johnson on 9/18/26.
//

import AppIntents

struct OpenRoutineAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start"
    static let description = IntentDescription("Opens the routine from the alarm alert.")
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
            name: .routineHeadsUpTapped,
            object: nil,
            userInfo: ["routineID": routineID]
        )
        return .result()
    }
}
