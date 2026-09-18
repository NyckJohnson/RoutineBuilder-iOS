import Foundation

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
#if canImport(AlarmKit)
import AlarmKit
import ActivityKit

@MainActor
final class AlarmManager: ObservableObject {

    static let shared = AlarmManager()
    private nonisolated(unsafe) let manager = AlarmKit.AlarmManager.shared

    // MARK: - Authorization

    var authorizationState: AlarmKit.AlarmManager.AuthorizationState {
        manager.authorizationState
    }

    func requestAuthorization() async -> Bool {
        print("[AlarmKit] Auth state: \(manager.authorizationState)")
        guard manager.authorizationState == .notDetermined else {
            return manager.authorizationState == .authorized
        }
        do {
            let result = try await manager.requestAuthorization()
            print("[AlarmKit] Auth result: \(result)")
            return result == .authorized
        } catch {
            print("[AlarmKit] Auth error: \(error)")
            return false
        }
    }

    // MARK: - Schedule card-end countdown alarm

    nonisolated struct CardAlarmMetadata: AlarmMetadata {
        var routineID: UUID
        var cardID: UUID
    }

    func scheduleCardAlarm(for card: Card) async {
        guard card.hasDuration else { return }
        guard card.alarmSoundName != "none" else { return }
        guard card.alarmSoundName?.hasPrefix("custom:") != true else { return }
        guard let routineID = card.routine?.id else { return }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: card.title),
            stopButton: AlarmButton(
                text: "Done",
                textColor: .white,
                systemImageName: "checkmark"
            )
        )
        let attributes = AlarmAttributes<CardAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .orange
        )
        try? manager.cancel(id: card.id)
        try? await manager.schedule(
            id: card.id,
            configuration: .timer(
                duration: card.durationSeconds,
                attributes: attributes,
                stopIntent: AcknowledgeCardAlarmIntent(routineID: routineID, cardID: card.id),
                secondaryIntent: nil,
                sound: alarmSound(for: card) ?? .default
            )
        )
        print("[AlarmKit] Scheduled alarm for: \(card.title), duration: \(card.durationSeconds)s")
    }

    private func alarmSound(for card: Card) -> AlertConfiguration.AlertSound? {
        guard let soundName = card.alarmSoundName,
            soundName != "default",
            soundName != "none" else { return nil }  // nil = system default

        // Strip prefix to get the raw filename
        let fileName: String
        if soundName.hasPrefix("alarm:") {
            fileName = String(soundName.dropFirst("alarm:".count))
        } else if soundName.hasPrefix("ringtone:") {
            fileName = String(soundName.dropFirst("ringtone:".count))
        } else if soundName.hasPrefix("custom:") {
            fileName = String(soundName.dropFirst("custom:".count))
        } else {
            return nil
        }

        return .named(fileName)
    }

    // MARK: - Cancel alarm for a card

    func cancelCardAlarm(for card: Card) async {
        try? manager.cancel(id: card.id)
    }

     // MARK: - Cancel all alarms for a routine

     func cancelAllAlarms(for routine: Routine) async {
         for card in routine.cards {
             await cancelCardAlarm(for: card)
         }
     }

    nonisolated struct RoutineAlarmMetadata: AlarmMetadata {
        var routineID: UUID
    }

    func scheduleRoutineAlarm(for routine: Routine) async {
        guard routine.isScheduled, let time = routine.scheduledTime else { return }
        guard routine.scheduledAlarmSoundName != "none" else { return }
        guard routine.scheduledAlarmSoundName?.hasPrefix("custom:") != true else { return }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: routine.name),
            stopButton: AlarmButton(text: "Start", textColor: .white, systemImageName: "play.fill"),
            secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "moon.zzz.fill"),
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes<RoutineAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .orange
        )
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else { return }

        try? manager.cancel(id: routine.id)
        try? await manager.schedule(
            id: routine.id,
            configuration: .alarm(
                schedule: .relative(.init(time: .init(hour: hour, minute: minute), repeats: .never)),
                attributes: attributes,
                stopIntent: OpenRoutineAlarmIntent(routineID: routine.id),
                secondaryIntent: SnoozeRoutineAlarmIntent(routineID: routine.id),
                sound: routineAlarmSound(for: routine) ?? .default
            )
        )
        print("[AlarmKit] Scheduled routine alarm for: \(routine.name) at \(hour):\(minute)")
    }

    func cancelRoutineAlarm(for routine: Routine) async {
        try? manager.cancel(id: routine.id)
    }

    func snoozeRoutineAlarm(routineID: UUID, minutes: Int) async {
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let components = Calendar.current.dateComponents([.hour, .minute], from: fireDate)
        guard let hour = components.hour, let minute = components.minute else { return }
        // Reuses a plain "Done" stop button — no secondary snooze-of-a-snooze
        let alert = AlarmPresentation.Alert(
            title: "Routine (snoozed)",
            stopButton: AlarmButton(text: "Start", textColor: .white, systemImageName: "play.fill")
        )
        let attributes = AlarmAttributes<RoutineAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .orange
        )
        try? await manager.schedule(
            id: routineID,
            configuration: .alarm(
                schedule: .relative(.init(time: .init(hour: hour, minute: minute), repeats: .never)),
                attributes: attributes,
                stopIntent: OpenRoutineAlarmIntent(routineID: routineID),
                secondaryIntent: nil,
                sound: .default
            )
        )
    }

    private func routineAlarmSound(for routine: Routine) -> AlertConfiguration.AlertSound? {
        guard let soundName = routine.scheduledAlarmSoundName,
              soundName != "default", soundName != "none" else { return nil }
        let fileName: String
        if soundName.hasPrefix("alarm:") {
            fileName = String(soundName.dropFirst("alarm:".count))
        } else if soundName.hasPrefix("ringtone:") {
            fileName = String(soundName.dropFirst("ringtone:".count))
        } else if soundName.hasPrefix("custom:") {
            fileName = String(soundName.dropFirst("custom:".count))
        } else {
            return nil
        }
        return .named(fileName)
    }
}

#endif
