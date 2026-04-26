import Foundation
import SwiftData

// MARK: - Codable transfer types
// These mirror the SwiftData models but are plain Codable structs
// so we don't depend on SwiftData for serialization.

struct RoutineExport: Codable {
    var version: Int = 1
    var exportedAt: Date
    var routines: [RoutineData]
}

struct RoutineData: Codable {
    var id: UUID
    var name: String
    var scheduledTime: Date?
    var isScheduled: Bool
    var orderIndex: Int
    var cards: [CardData]
}

struct CardData: Codable {
    var id: UUID
    var title: String
    var notes: String
    var durationMinutes: Int
    var snoozeMinutes: Int
    var alarmSoundName: String?
    var orderIndex: Int
    var todos: [TodoData]
}

struct TodoData: Codable {
    var id: UUID
    var title: String
    var orderIndex: Int
}

// MARK: - RoutineExporter

@MainActor
final class RoutineExporter {

    // MARK: - Export

    static func exportData(from routines: [Routine]) throws -> Data {
        let export = RoutineExport(
            exportedAt: Date(),
            routines: routines.map { routineData(from: $0) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    static func exportURL(from routines: [Routine]) throws -> URL {
        let data = try exportData(from: routines)
        let filename = "routines-\(Date().formatted(.iso8601)).json"
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: - Import

    static func importRoutines(from url: URL, into context: ModelContext) throws -> Int {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(RoutineExport.self, from: data)

        // Fetch existing IDs to avoid duplicates
        let existingIDs = Set(
            (try? context.fetch(FetchDescriptor<Routine>()))?.map { $0.id } ?? []
        )

        var imported = 0
        for routineData in export.routines {
            guard !existingIDs.contains(routineData.id) else { continue }
            let routine = routine(from: routineData)
            context.insert(routine)
            imported += 1
        }

        try context.save()
        return imported
    }

    // MARK: - Conversion helpers

    private static func routineData(from routine: Routine) -> RoutineData {
        RoutineData(
            id: routine.id,
            name: routine.name,
            scheduledTime: routine.scheduledTime,
            isScheduled: routine.isScheduled,
            orderIndex: routine.orderIndex,
            cards: routine.sortedCards.map { cardData(from: $0) }
        )
    }

    private static func cardData(from card: Card) -> CardData {
        CardData(
            id: card.id,
            title: card.title,
            notes: card.notes,
            durationMinutes: card.durationMinutes,
            snoozeMinutes: card.snoozeMinutes,
            alarmSoundName: card.alarmSoundName,
            orderIndex: card.orderIndex,
            todos: card.sortedTodos.map { todoData(from: $0) }
        )
    }

    private static func todoData(from todo: TodoItem) -> TodoData {
        TodoData(id: todo.id, title: todo.title, orderIndex: todo.orderIndex)
    }

    private static func routine(from data: RoutineData) -> Routine {
        let routine = Routine(name: data.name)
        routine.id = data.id
        routine.scheduledTime = data.scheduledTime
        routine.isScheduled = data.isScheduled
        routine.orderIndex = data.orderIndex
        routine.cards = data.cards.map { card(from: $0, routine: routine) }
        return routine
    }

    private static func card(from data: CardData, routine: Routine) -> Card {
        let card = Card(title: data.title)
        card.id = data.id
        card.notes = data.notes
        card.durationMinutes = data.durationMinutes
        card.snoozeMinutes = data.snoozeMinutes
        card.alarmSoundName = data.alarmSoundName
        card.orderIndex = data.orderIndex
        card.routine = routine
        card.todos = data.todos.map { todo(from: $0, card: card) }
        return card
    }

    private static func todo(from data: TodoData, card: Card) -> TodoItem {
        let todo = TodoItem(title: data.title)
        todo.id = data.id
        todo.orderIndex = data.orderIndex
        todo.card = card
        return todo
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case accessDenied
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Could not access the file."
            case .invalidFormat: return "The file doesn't appear to be a valid routines export."
            }
        }
    }
}
