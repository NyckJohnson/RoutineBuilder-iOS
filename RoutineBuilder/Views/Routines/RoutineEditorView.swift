import SwiftUI
import SwiftData

struct RoutineEditorView: View {

    var routine: Routine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var routineManager: RoutineManager
    @EnvironmentObject private var alarmManager: AlarmManager
    @Query(sort: \Routine.orderIndex) private var allRoutines: [Routine]
    @Binding var selectedTab: ContentView.Tab

    @State private var editingCard: Card?
    @State private var showingDeleteConfirm = false
    @State private var timeConflictWarning = false

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                scheduleSection
                cardsSection
                startSection
                dangerSection
            }
            .navigationTitle(routine.name.isEmpty ? "New Routine" : routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingCard) { card in
                CardEditorView(card: card, routine: routine)
            }
            .confirmationDialog(
                "Delete \"\(routine.name)\"?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Routine", role: .destructive) {
                    routineManager.deleteRoutine(routine)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("Routine name", text: Binding(
                get: { routine.name },
                set: { routine.name = $0; routineManager.save() }
            ))
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Schedule this routine", isOn: Binding(
                get: { routine.isScheduled },
                set: {
                    routine.isScheduled = $0
                    routineManager.updateSchedule(for: routine)
                    routineManager.save()
                }
            ))

            if routine.isScheduled {
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { routine.scheduledTime ?? Date() },
                        set: { newTime in
                            if Routine.isTimeConflicting(newTime, among: allRoutines, excluding: routine) {
                                timeConflictWarning = true
                            } else {
                                routine.scheduledTime = newTime
                                routineManager.updateSchedule(for: routine)
                                routineManager.save()
                            }
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)

                if timeConflictWarning {
                    Label("Another routine is scheduled at this time.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                timeConflictWarning = false
                            }
                        }
                }
            }
        }
    }

    private var cardsSection: some View {
        Section {
            ForEach(routine.sortedCards) { card in
                CardRow(card: card)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingCard = card
                    }
            }
            .onMove { source, destination in
                var cards = routine.sortedCards
                routineManager.reorderCards(&cards, from: source, to: destination)
            }
            .onDelete { offsets in
                offsets.map { routine.sortedCards[$0] }.forEach {
                    routineManager.deleteCard($0, from: routine)
                }
            }

            Button {
                let card = routineManager.addCard(to: routine)
                editingCard = card
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Steps")
        } footer: {
            if routine.sortedCards.isEmpty {
                Text("Add steps to build your routine.")
            }
        }
    }

    private var startSection: some View {
        Section {
            Button {
                routineManager.startOrQueueRoutine(routine)
                selectedTab = .now
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Label(
                        routineManager.activeRoutineID != nil ? "Add to Queue" : "Start Routine",
                        systemImage: routineManager.activeRoutineID != nil ? "text.badge.plus" : "play.fill"
                    )
                    .font(.body.weight(.semibold))
                    Spacer()
                }
            }
            .disabled(routine.sortedCards.isEmpty)
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Delete Routine", role: .destructive) {
                showingDeleteConfirm = true
            }
        }
    }
}

// MARK: - CardRow

struct CardRow: View {
    var card: Card

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.title.isEmpty ? "Untitled Step" : card.title)
                    .font(.body)

                HStack(spacing: 8) {
                    if card.hasDuration {
                        Label("\(card.durationMinutes) min", systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !card.sortedTodos.isEmpty {
                        Label("\(card.sortedTodos.count) to-do\(card.sortedTodos.count == 1 ? "" : "s")", systemImage: "checklist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !card.notes.isEmpty {
                        Label("Notes", systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
