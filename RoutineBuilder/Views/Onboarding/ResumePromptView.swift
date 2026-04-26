import SwiftUI
import SwiftData

struct ResumePromptView: View {

    let state: ActiveRoutineState
    let onDismiss: () -> Void

    @EnvironmentObject private var routineManager: RoutineManager
    @EnvironmentObject private var alarmManager: AlarmManager
    @Query private var routines: [Routine]

    var routine: Routine? {
        routines.first { $0.id == state.routineID }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Resume Routine?")
                    .font(.title2.weight(.bold))

                if let routine = routine {
                    Text("You were mid-way through \"\(routine.name)\"")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    let cardIndex = state.currentCardIndex
                    let card = routine.sortedCards[safe: cardIndex]
                    if let card {
                        Text("Step \(cardIndex + 1): \(card.title)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    // Resume — RoutineRunner will pick up ActiveRoutineState on init
                    if let routine = routine {
                        routineManager.activeRoutineID = routine.id
                    }
                    onDismiss()
                } label: {
                    Text("Resume")
                        .frame(maxWidth: .infinity)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Dismiss", role: .destructive) {
                    if let routine = routine {
                        let alarmManager = alarmManager
                        Task { await alarmManager.cancelAllAlarms(for: routine) }
                    }
                    routineManager.clearActiveRoutineState()
                    onDismiss()
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
