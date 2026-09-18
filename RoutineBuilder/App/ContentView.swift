import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var routineManager: RoutineManager
    @EnvironmentObject private var alarmManager: AlarmManager
    @State private var selectedTab: Tab = .routines
    
    enum Tab { case routines, now, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            RoutineListView(selectedTab: $selectedTab)
                .tabItem { Label("Routines", systemImage: "house.fill") }
                .tag(Tab.routines)

            ActiveRoutineTabView()
                .tabItem { Label("Now", systemImage: "play.circle.fill") }
                .tag(Tab.now)
                .badge(routineManager.activeRoutineID != nil ? " " : nil)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineHeadsUpTapped)) { _ in
            selectedTab = .routines
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineAlarmSnoozeTapped)) { notification in
            guard let routineID = notification.userInfo?["routineID"] as? UUID,
                  let routine = routineManager.fetchRoutine(by: routineID) else { return }
            Task {
                await alarmManager.snoozeRoutineAlarm(
                    routineID: routineID,
                    minutes: routine.scheduledAlarmSnoozeMinutes
                )
            }
        }
    }
}
