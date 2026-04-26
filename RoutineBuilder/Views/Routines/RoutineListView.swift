import SwiftUI
import SwiftData

struct RoutineListView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var routineManager: RoutineManager
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    @Binding var selectedTab: ContentView.Tab

    @State private var editingRoutine: Routine?

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let routine = routineManager.addRoutine()
                        editingRoutine = routine
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine, selectedTab: $selectedTab)
            }
        }
    }

    // MARK: - Subviews

    private var list: some View {
        List {
            ForEach(routines) { routine in
                RoutineRow(routine: routine)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingRoutine = routine
                    }
            }
            .onMove { source, destination in
                var mutable = routines.map { $0 }
                routineManager.reorderRoutines(&mutable, from: source, to: destination)
            }
            .onDelete { offsets in
                offsets.map { routines[$0] }.forEach { routineManager.deleteRoutine($0) }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Routines Yet")
                .font(.title2.weight(.semibold))
            Text("Tap + to create your first routine.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                let routine = routineManager.addRoutine()
                editingRoutine = routine
            } label: {
                Label("Create Routine", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
    }
}

// MARK: - RoutineRow

struct RoutineRow: View {

    var routine: Routine
    @EnvironmentObject private var routineManager: RoutineManager

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name.isEmpty ? "Untitled Routine" : routine.name)
                    .font(.body.weight(.medium))

                if routine.isScheduled, let time = routine.scheduledTime {
                    Label(time.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(routine.sortedCards.count) step\(routine.sortedCards.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let pos = routine.queuePosition {
                Text("Up next" + (pos > 0 ? " (#\(pos + 1))" : ""))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange, in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
