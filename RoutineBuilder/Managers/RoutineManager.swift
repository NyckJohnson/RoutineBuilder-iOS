import Foundation
import SwiftData
import UserNotifications
import Combine

@MainActor
final class RoutineManager: ObservableObject {

    // MARK: - Published state

    @Published var activeRoutineID: UUID?
    @Published var queuedRoutineIDs: [UUID] = []
    @Published var permissionsDenied: Set<PermissionType> = []

    enum PermissionType { case notifications }

    // MARK: - Init

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Routine CRUD

    func addRoutine() -> Routine {
        let routine = Routine()
        let descriptor = FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.orderIndex, order: .reverse)])
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        routine.orderIndex = (existing.first?.orderIndex ?? -1) + 1
        modelContext.insert(routine)
        save()
        return routine
    }

    func deleteRoutine(_ routine: Routine) {
        cancelNotification(for: routine)
        modelContext.delete(routine)
        save()
    }

    func reorderRoutines(_ routines: inout [Routine], from source: IndexSet, to destination: Int) {
        routines.move(fromOffsets: source, toOffset: destination)
        for (index, routine) in routines.enumerated() {
            routine.orderIndex = index
        }
        save()
    }

    // MARK: - Card CRUD

    func addCard(to routine: Routine) -> Card {
        let card = Card()
        card.orderIndex = routine.sortedCards.count
        card.routine = routine
        routine.cards.append(card)
        save()
        return card
    }

    func deleteCard(_ card: Card, from routine: Routine) {
        routine.cards.removeAll { $0.id == card.id }
        modelContext.delete(card)
        // Re-index remaining cards
        for (index, c) in routine.sortedCards.enumerated() {
            c.orderIndex = index
        }
        save()
    }

    func reorderCards(_ cards: inout [Card], from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
        for (index, card) in cards.enumerated() {
            card.orderIndex = index
        }
        save()
    }

    // MARK: - Todo CRUD

    func addTodo(to card: Card) -> TodoItem {
        let todo = TodoItem()
        todo.orderIndex = card.sortedTodos.count
        todo.card = card
        card.todos.append(todo)
        save()
        return todo
    }

    func deleteTodo(_ todo: TodoItem, from card: Card) {
        card.todos.removeAll { $0.id == todo.id }
        modelContext.delete(todo)
        for (index, t) in card.sortedTodos.enumerated() {
            t.orderIndex = index
        }
        save()
    }

    // MARK: - Routine Scheduling

    func updateSchedule(for routine: Routine) {
        cancelNotification(for: routine)
        guard routine.isScheduled, routine.scheduledTime != nil else { return }
        scheduleHeadsUpNotification(for: routine)
    }

    // MARK: - Routine Queue

    func startOrQueueRoutine(_ routine: Routine) {
        if activeRoutineID == nil {
            startRoutine(routine)
        } else {
            if !queuedRoutineIDs.contains(routine.id) {
                queuedRoutineIDs.append(routine.id)
                routine.queuePosition = queuedRoutineIDs.count - 1
                save()
            }
        }
    }

    func routineDidFinish() {
        clearActiveRoutineState()
        activeRoutineID = nil

        guard !queuedRoutineIDs.isEmpty else { return }

        let nextID = queuedRoutineIDs.removeFirst()
        // Re-index queue positions
        for (i, id) in queuedRoutineIDs.enumerated() {
            if let r = fetchRoutine(by: id) { r.queuePosition = i }
        }
        save()

        if let next = fetchRoutine(by: nextID) {
            startRoutine(next)
        }
    }

    func cancelRoutine(_ routine: Routine) {
        if activeRoutineID == routine.id {
            clearActiveRoutineState()
            activeRoutineID = nil
            routineDidFinish() // advance queue
        } else {
            queuedRoutineIDs.removeAll { $0 == routine.id }
            routine.queuePosition = nil
            save()
        }
    }

    // MARK: - Active State Persistence

    func saveActiveState(routineID: UUID, cardIndex: Int, startedAt: Date, acknowledged: Bool, paused: Bool) {
        clearActiveRoutineState()
        let state = ActiveRoutineState(routineID: routineID, currentCardIndex: cardIndex)
        state.cardStartedAt = startedAt
        state.isAcknowledged = acknowledged
        state.isPaused = paused
        modelContext.insert(state)
        save()
    }

    func loadActiveRoutineState() -> ActiveRoutineState? {
        let descriptor = FetchDescriptor<ActiveRoutineState>()
        return try? modelContext.fetch(descriptor).first
    }

    func clearActiveRoutineState() {
        let descriptor = FetchDescriptor<ActiveRoutineState>()
        if let states = try? modelContext.fetch(descriptor) {
            states.forEach { modelContext.delete($0) }
        }
        save()
    }

    // MARK: - Notifications (UNUserNotificationCenter — heads-up only)

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .notDetermined else {
            if status == .denied { permissionsDenied.insert(.notifications) }
            return
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if !granted { permissionsDenied.insert(.notifications) }
    }

    private func scheduleHeadsUpNotification(for routine: Routine) {
        guard let time = routine.scheduledTime else { return }

        let content = UNMutableNotificationContent()
        content.title = routine.name
        content.body = "Your routine starts in 5 minutes."
        content.sound = .default
        content.userInfo = ["routineID": routine.id.uuidString]

        var components = Calendar.current.dateComponents([.hour, .minute, .weekday], from: time)
        // Subtract 5 minutes
        let adjusted = Calendar.current.date(byAdding: .minute, value: -5, to: time) ?? time
        components = Calendar.current.dateComponents([.hour, .minute], from: adjusted)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "headsup-\(routine.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for routine: Routine) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["headsup-\(routine.id.uuidString)"]
        )
    }

    // MARK: - Helpers

    func fetchRoutine(by id: UUID) -> Routine? {
        let descriptor = FetchDescriptor<Routine>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    func fetchCard(by id: UUID) -> Card? {
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    func save() {
        try? modelContext.save()
    }

    // MARK: - Private

    private func startRoutine(_ routine: Routine) {
        // Reset all to-do completion state
        for card in routine.cards {
            for todo in card.todos {
                todo.isCompleted = false
            }
        }
        activeRoutineID = routine.id
        routine.queuePosition = nil
        let state = ActiveRoutineState(routineID: routine.id)
        modelContext.insert(state)
        save()
    }
}
