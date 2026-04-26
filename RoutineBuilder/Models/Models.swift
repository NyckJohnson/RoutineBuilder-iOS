import Foundation
import SwiftData

// MARK: - Schema versioning

enum RoutineSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Routine.self, Card.self, TodoItem.self, ActiveRoutineState.self] }
}

enum RoutineMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [RoutineSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// MARK: - Routine

@Model
final class Routine {
    var id: UUID
    var name: String
    var scheduledTime: Date?
    var isScheduled: Bool
    var orderIndex: Int
    var queuePosition: Int?         // nil = not queued, 0 = next up
    @Relationship(deleteRule: .cascade, inverse: \Card.routine) var cards: [Card]

    init(name: String = "New Routine") {
        self.id = UUID()
        self.name = name
        self.isScheduled = false
        self.orderIndex = 0
        self.cards = []
    }

    var sortedCards: [Card] {
        cards.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Returns true if another routine already occupies this scheduled time
    static func isTimeConflicting(_ date: Date, among routines: [Routine], excluding routine: Routine) -> Bool {
        let cal = Calendar.current
        let candidate = cal.dateComponents([.hour, .minute], from: date)
        return routines
            .filter { $0.id != routine.id && $0.isScheduled }
            .contains {
                guard let t = $0.scheduledTime else { return false }
                return cal.dateComponents([.hour, .minute], from: t) == candidate
            }
    }
}

// MARK: - Card

@Model
final class Card {
    var id: UUID
    var title: String
    var notes: String
    var durationMinutes: Int        // 0 means no timer
    var snoozeMinutes: Int
    var alarmSoundName: String?     // nil = default system sound
    var orderIndex: Int
    var routine: Routine?
    @Relationship(deleteRule: .cascade, inverse: \TodoItem.card) var todos: [TodoItem]

    init(title: String = "New Step") {
        self.id = UUID()
        self.title = title
        self.notes = ""
        self.durationMinutes = 5
        self.snoozeMinutes = 5
        self.orderIndex = 0
        self.todos = []
    }

    var sortedTodos: [TodoItem] {
        todos.sorted { $0.orderIndex < $1.orderIndex }
    }

    var hasDuration: Bool { durationMinutes > 0 }

    var allTodosCompleted: Bool {
        todos.isEmpty || todos.allSatisfy { $0.isCompleted }
    }

    var durationSeconds: TimeInterval {
        TimeInterval(durationMinutes * 60)
    }
}

// MARK: - TodoItem

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var orderIndex: Int
    var card: Card?

    init(title: String = "") {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.orderIndex = 0
    }
}

// MARK: - ActiveRoutineState
// Singleton — always delete and recreate, never mutate in place.

@Model
final class ActiveRoutineState {
    var routineID: UUID
    var currentCardIndex: Int
    var cardStartedAt: Date
    var isAcknowledged: Bool
    var isPaused: Bool

    init(routineID: UUID, currentCardIndex: Int = 0) {
        self.routineID = routineID
        self.currentCardIndex = currentCardIndex
        self.cardStartedAt = Date()
        self.isAcknowledged = false
        self.isPaused = false
    }
}
