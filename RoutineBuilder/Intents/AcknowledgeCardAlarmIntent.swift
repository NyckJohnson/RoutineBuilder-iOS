//
//  AcknowledgeCardAlarmIntent.swift
//  RoutineBuilder
//
//  Created by Nicholas Johnson on 9/17/26.
//

import AppIntents

struct AcknowledgeCardAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Done"
    static let description = IntentDescription("Marks the current routine step done from the alarm alert.")
    static let supportedModes: IntentModes = [.foreground(.immediate)]

    @Parameter(title: "Routine ID")
    var routineIDString: String

    @Parameter(title: "Card ID")
    var cardIDString: String

    init(routineID: UUID, cardID: UUID) {
        self.routineIDString = routineID.uuidString
        self.cardIDString = cardID.uuidString
    }

    init() {
        self.routineIDString = ""
        self.cardIDString = ""
    }

    func perform() async throws -> some IntentResult {
        guard let routineID = UUID(uuidString: routineIDString),
              let cardID = UUID(uuidString: cardIDString) else {
            return .result()
        }
        NotificationCenter.default.post(
            name: .cardAlarmDoneTapped,
            object: nil,
            userInfo: ["routineID": routineID, "cardID": cardID]
        )
        return .result()
    }
}
