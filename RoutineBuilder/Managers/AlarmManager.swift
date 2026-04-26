import Foundation

@MainActor
final class AlarmManager: ObservableObject {
    @MainActor static let shared = AlarmManager()
    
    func requestAuthorization() async -> Bool { return false }
    func scheduleCardAlarm(for card: Card) async {}
    func cancelCardAlarm(for card: Card) async {}
    func cancelAllAlarms(for routine: Routine) async {}
}

// MARK: - AlarmManager
//
// This file wraps AlarmKit. AlarmKit is available on iOS 26+.
//
// XCODE SETUP REQUIRED before this compiles:
//   1. Add a Widget Extension target: File > New > Target > Widget Extension
//      Name it "RoutineBuilderWidgetExtension"
//   2. In the widget target, create a Live Activity conforming to ActivityAttributes
//      (see RoutineAttributes in Models.swift for the shape)
//   3. Add NSAlarmKitUsageDescription to Info.plist:
//      "Routine Builder uses alarms to alert you when each step ends."
//   4. Enable the "Alarms" capability on the main app target
//   5. Add AlarmKit.framework under Frameworks, Libraries, and Embedded Content
//
// Until the widget extension is set up, this file uses stub implementations
// so the rest of the app compiles and runs.
//
//#if canImport(AlarmKit)
//import AlarmKit
//import ActivityKit
//
//final class AlarmManager: ObservableObject {
//
//    @MainActor static let shared = AlarmManager()
//    private let manager = AlarmKit.AlarmManager.shared
//
//    // MARK: - Authorization
//
//    var authorizationState: AlarmKit.AlarmManager.AuthorizationState {
//        manager.authorizationState
//    }
//
//    func requestAuthorization() async -> Bool {
//        print("[AlarmKit] Auth state: \(manager.authorizationState)")
//        guard manager.authorizationState == .notDetermined else {
//            return manager.authorizationState == .authorized
//        }
//        do {
//            let result = try await manager.requestAuthorization()
//            print("[AlarmKit] Auth result: \(result)")
//            return result == .authorized
//        } catch {
//            print("[AlarmKit] Auth error: \(error)")
//            return false
//        }
//    }
//
//    // MARK: - Schedule card-end countdown alarm
//
//    nonisolated struct CardAlarmMetadata: AlarmMetadata {
//        var routineID: UUID
//        var cardID: UUID
//    }
//
//    func scheduleCardAlarm(for card: Card) async {
//        guard card.hasDuration else { return }
//        guard card.alarmSoundName != "none" else { return }
//        
//        let alert = AlarmPresentation.Alert(
//            title: LocalizedStringResource(stringLiteral: card.title),
//            stopButton: AlarmButton(
//                text: "Done",
//                textColor: .white,
//                systemImageName: "checkmark"
//            )
//        )
//        let attributes = AlarmAttributes<CardAlarmMetadata>(
//            presentation: AlarmPresentation(alert: alert),
//            tintColor: .orange
//        )
//        try? await manager.schedule(
//            id: card.id,
//            configuration: .timer(
//                duration: card.durationSeconds,
//                attributes: attributes,
//                stopIntent: nil,
//                secondaryIntent: nil,
//                sound: alarmSound(for: card) ?? .default
//            )
//        )
//        print("[AlarmKit] Scheduled alarm for: \(card.title), duration: \(card.durationSeconds)s")
//    }
//
//    private func alarmSound(for card: Card) -> AlertConfiguration.AlertSound? {
//        guard let soundName = card.alarmSoundName,
//              soundName != "default",
//              soundName != "none" else { return nil }  // nil = system default
//
//        // Strip prefix to get the raw filename
//        let fileName: String
//        if soundName.hasPrefix("alarm:") {
//            fileName = String(soundName.dropFirst("alarm:".count))
//        } else if soundName.hasPrefix("ringtone:") {
//            fileName = String(soundName.dropFirst("ringtone:".count))
//        } else if soundName.hasPrefix("custom:") {
//            fileName = String(soundName.dropFirst("custom:".count))
//        } else {
//            return nil
//        }
//
//        return .named(fileName)
//    }
//    
//    // MARK: - Cancel alarm for a card
//
//    func cancelCardAlarm(for card: Card) async {
//        try? await manager.cancel(id: card.id)
//    }
//
//    // MARK: - Cancel all alarms for a routine
//
//    func cancelAllAlarms(for routine: Routine) async {
//        for card in routine.cards {
//            await cancelCardAlarm(for: card)
//        }
//    }
//}
//
//#else
//
//// MARK: - Stub (compiles without AlarmKit — remove once framework is linked)
//
//@MainActor
//final class AlarmManager: ObservableObject {
//
//    static let shared = AlarmManager()
//
//    var authorizationState: String { "stub" }
//
//    func requestAuthorization() async -> Bool {
//        print("[AlarmManager] Stub — AlarmKit not linked. Returning false.")
//        return false
//    }
//
//    func scheduleCardAlarm(for card: Card) async {
//        print("[AlarmManager] Stub — would schedule alarm for card: \(card.title)")
//    }
//
//    func cancelCardAlarm(for card: Card) async {
//        print("[AlarmManager] Stub — would cancel alarm for card: \(card.title)")
//    }
//
//    func cancelAllAlarms(for routine: Routine) async {
//        print("[AlarmManager] Stub — would cancel alarms for routine: \(routine.name)")
//    }
//}
//
//#endif
