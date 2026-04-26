import SwiftUI
import SwiftData

struct ActiveRoutineTabView: View {

    @EnvironmentObject private var routineManager: RoutineManager
    @EnvironmentObject private var alarmManager: AlarmManager
    @Query private var routines: [Routine]

    var activeRoutine: Routine? {
        guard let id = routineManager.activeRoutineID else { return nil }
        return routines.first { $0.id == id }
    }

    var body: some View {
        if let routine = activeRoutine {
            RoutineRunnerView(routine: routine, routineManager: routineManager, alarmManager: alarmManager)
        } else {
            NavigationStack {
                emptyState
                    .navigationTitle("Now")
                    .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Active Routine")
                .font(.title2.weight(.semibold))
            Text("Start a routine from your list.")
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}
