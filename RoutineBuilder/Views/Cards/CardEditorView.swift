import SwiftUI

struct CardEditorView: View {

    var card: Card
    let routine: Routine

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var routineManager: RoutineManager

    @State private var showingDeleteConfirm = false
    @State private var showingSoundPicker = false
    @FocusState private var focusedTodoID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                notesSection
                timerSection
                alarmSection
                todosSection
                dangerSection
            }
            .navigationTitle(card.title.isEmpty ? "New Step" : card.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView(selectedSoundName: Binding(
                    get: { card.alarmSoundName },
                    set: { card.alarmSoundName = $0; routineManager.save() }
                ))
            }
            .confirmationDialog(
                "Delete \"\(card.title)\"?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Step", role: .destructive) {
                    routineManager.deleteCard(card, from: routine)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section("Title") {
            TextField("Step name", text: Binding(
                get: { card.title },
                set: { card.title = $0; routineManager.save() }
            ))
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: Binding(
                get: { card.notes },
                set: { card.notes = $0; routineManager.save() }
            ))
            .frame(minHeight: 80)
        }
    }

    private var timerSection: some View {
        Section("Timer") {
            Stepper(
                card.hasDuration ? "\(card.durationMinutes) minutes" : "No timer",
                value: Binding(
                    get: { card.durationMinutes },
                    set: { card.durationMinutes = max(0, $0); routineManager.save() }
                ),
                in: 0...240,
                step: 1
            )

            if card.hasDuration {
                Stepper(
                    "Snooze: \(card.snoozeMinutes) min",
                    value: Binding(
                        get: { card.snoozeMinutes },
                        set: { card.snoozeMinutes = max(1, $0); routineManager.save() }
                    ),
                    in: 1...30,
                    step: 1
                )
            }
        }
    }

    private var alarmSection: some View {
        Section {
            Button {
                showingSoundPicker = true
            } label: {
                HStack {
                    Text("Alarm Sound")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(card.alarmSoundName ?? "Default")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            if card.alarmSoundName != nil {
                Text("Custom sounds play only when the app is open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Alarm")
        }
    }

    private var todosSection: some View {
        Section {
            ForEach(card.sortedTodos) { todo in
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                    TextField("To-do item", text: Binding(
                        get: { todo.title },
                        set: { todo.title = $0; routineManager.save() }
                    ))
                    .focused($focusedTodoID, equals: todo.id)
                }
            }
            .onMove { source, detination in
                var todos = card.sortedTodos
                todos.move(fromOffsets: source, toOffset: source.first.map { $0 < todos.count ? $0 + 1 : $0 } ?? 0)
                for (index, t) in todos.enumerated() { t.orderIndex = index }
                routineManager.save()
            }
            .onDelete { offsets in
                offsets.map { card.sortedTodos[$0] }.forEach {
                    routineManager.deleteTodo($0, from: card)
                }
            }

            Button {
                let todo = routineManager.addTodo(to: card)
                focusedTodoID = todo.id
            } label: {
                Label("Add To-Do", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("To-Dos")
        } footer: {
            if !card.sortedTodos.isEmpty {
                Text("All to-dos must be checked before the step can be completed.")
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Delete Step", role: .destructive) {
                showingDeleteConfirm = true
            }
        }
    }
}
