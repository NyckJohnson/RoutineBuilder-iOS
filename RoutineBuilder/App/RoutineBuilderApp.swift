import SwiftUI
import SwiftData
import UserNotifications

@main
struct RoutineBuilderApp: App {

    @StateObject private var routineManager: RoutineManager
    @StateObject private var alarmManager = AlarmManager.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showResumePrompt = false
    @State private var interruptedState: ActiveRoutineState?

    private let container: ModelContainer

    init() {
        print("App Starting")
        do {
            let container = try ModelContainer(
                for: Routine.self, Card.self, TodoItem.self, ActiveRoutineState.self,
                migrationPlan: RoutineMigrationPlan.self
            )
            self.container = container
            _routineManager = StateObject(
                wrappedValue: RoutineManager(modelContext: container.mainContext)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(isPresented: Binding(
                        get: { !hasCompletedOnboarding },
                        set: { if !$0 { hasCompletedOnboarding = true } }
                    ))
                } else {
                    ContentView()
                        .sheet(isPresented: $showResumePrompt) {
                            if let state = interruptedState {
                                ResumePromptView(state: state) {
                                    showResumePrompt = false
                                    interruptedState = nil
                                }
                            }
                        }
                        .task { await checkForInterruptedRoutine() }
                }
            }
            .environmentObject(routineManager)
            .environmentObject(alarmManager)
            .modelContainer(container)
            .task { await setupPermissions() }
        }
    }

    // MARK: - Interrupted routine recovery

    private func checkForInterruptedRoutine() async {
        guard let state = routineManager.loadActiveRoutineState(),
              routineManager.fetchRoutine(by: state.routineID) != nil else {
            routineManager.clearActiveRoutineState()
            return
        }
        interruptedState = state
        showResumePrompt = true
    }

    // MARK: - Permissions

    private func setupPermissions() async {
        // Stage 1: notifications only — AlarmKit is requested on first routine start
        await routineManager.requestNotificationPermission()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
}

// MARK: - NotificationDelegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let routineIDString = response.notification.request.content.userInfo["routineID"] as? String,
              let routineID = UUID(uuidString: routineIDString) else { return }
        // Post to navigate to runner — observed in ContentView
        NotificationCenter.default.post(
            name: .routineHeadsUpTapped,
            object: nil,
            userInfo: ["routineID": routineID]
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension Notification.Name {
    static let routineHeadsUpTapped = Notification.Name("routineHeadsUpTapped")
}
