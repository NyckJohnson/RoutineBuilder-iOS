import SwiftUI
import Combine
import SwiftData
import AVFoundation

// MARK: - RoutineRunner

@MainActor
final class RoutineRunner: ObservableObject {

    @Published var currentCardIndex: Int = 0
    @Published var secondsRemaining: Int = 0
    @Published var isAcknowledged: Bool = false
    @Published var timerFired: Bool = false
    @Published var hasStarted: Bool = false
    @Published var preStartSecondsRemaining: Int = 60

    private var timer: AnyCancellable?
    private var alarmDoneSubscription: AnyCancellable?
    private var cardStartedAt: Date = Date()

    let routine: Routine
    private let routineManager: RoutineManager
    private let alarmManager: AlarmManager
    private var audioPlayer: AVAudioPlayer?

    init(routine: Routine, routineManager: RoutineManager, alarmManager: AlarmManager, resumeFrom state: ActiveRoutineState? = nil) {
        self.routine = routine
        self.routineManager = routineManager
        self.alarmManager = alarmManager

        if let state = state {
            currentCardIndex = state.currentCardIndex
            isAcknowledged = state.isAcknowledged
            cardStartedAt = state.cardStartedAt
            // Recalculate remaining time
            let elapsed = Int(Date().timeIntervalSince(state.cardStartedAt))
            let total = currentCard?.durationMinutes ?? 0
            secondsRemaining = max(0, total * 60 - elapsed)
        } else {
            loadCard(at: 0)
        }

        startTimer()
        observeAlarmDoneTaps()
    }

    var currentCard: Card? {
        guard currentCardIndex < routine.sortedCards.count else { return nil }
        return routine.sortedCards[currentCardIndex]
    }

    var totalCards: Int { routine.sortedCards.count }
    var isLastCard: Bool { currentCardIndex >= totalCards - 1 }

    var canCompleteCard: Bool {
        currentCard?.allTodosCompleted ?? false
    }

    // MARK: - Actions

    func acknowledge() {
        stopAlarmSound()
        preStartSecondsRemaining = 60
        
        hasStarted = true
        isAcknowledged = true
        saveState()
    }

    func snooze() {
        stopAlarmSound()
        guard let card = currentCard else { return }
        secondsRemaining = card.snoozeMinutes * 60
        timerFired = false
        saveState()
    }

    func completeCard() {
        stopAlarmSound()
        guard canCompleteCard else { return }
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)

        let alarmManager = alarmManager
        let card = currentCard!
        Task { @MainActor in await alarmManager.cancelCardAlarm(for: card) }

        if isLastCard {
            routineManager.routineDidFinish()
        } else {
            loadCard(at: currentCardIndex + 1)
        }
    }

    func stop() {
        timer?.cancel()
        if let card = currentCard {
            let alarmManager = alarmManager
            let routine = routine
            Task { @MainActor in await alarmManager.cancelAllAlarms(for: routine) }
            _ = card // suppress warning
        }
        routineManager.cancelRoutine(routine)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func observeAlarmDoneTaps() {
        alarmDoneSubscription = NotificationCenter.default.publisher(for: .cardAlarmDoneTapped)
            .sink { [weak self] notification in
                guard let self,
                      let routineID = notification.userInfo?["routineID"] as? UUID,
                      let cardID = notification.userInfo?["cardID"] as? UUID,
                      routineID == self.routine.id,
                      cardID == self.currentCard?.id,
                      self.canCompleteCard else { return }
                self.completeCard()
            }
    }

    private func tick() {
        guard hasStarted else {
            // Pre-start countdown
            if preStartSecondsRemaining > 0 {
                preStartSecondsRemaining -= 1
            } else {
                // Time to nag — play alarm if not already playing
                if audioPlayer == nil {
                    playAlarmSound()
                }
            }
            return
        }
        guard secondsRemaining > 0 else {
            if !timerFired {
                timerFired = true
                saveState()
                playAlarmSound()
            }
            return
        }
        secondsRemaining -= 1
        // Persist state every 10 seconds to avoid too many writes
        if secondsRemaining % 10 == 0 { saveState() }
    }

    private func loadCard(at index: Int) {
        hasStarted = false
        currentCardIndex = index
        isAcknowledged = false
        timerFired = false
        cardStartedAt = Date()
        preStartSecondsRemaining = 60

        if let card = currentCard, card.hasDuration {
            secondsRemaining = card.durationMinutes * 60
            let alarmManager = alarmManager
            let card = card
            Task { @MainActor in await alarmManager.scheduleCardAlarm(for: card) }
        } else {
            secondsRemaining = 0
        }
        saveState()
    }

    private func saveState() {
        routineManager.saveActiveState(
            routineID: routine.id,
            cardIndex: currentCardIndex,
            startedAt: cardStartedAt,
            acknowledged: isAcknowledged,
            paused: false
        )
    }
    
    private func playAlarmSound() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Audio/UISounds/New")) ?? []
        print("[Sound] Available files: \(files.sorted())")
        
        let soundName = currentCard?.alarmSoundName ?? "default"
        print("[Sound] Playing sound for: \(soundName)")
        
        let url: URL?
        if soundName == "none" {
            return
        } else if soundName == "default" || soundName.hasPrefix("alarm:") {
            let name = soundName == "default" ? AudioUtils.defaultAlarmSoundName : String(soundName.dropFirst("alarm:".count))
            url = AudioUtils.resolvedURL(for: name, in: "/System/Library/Audio/UISounds/New")
        } else if soundName.hasPrefix("ringtone:") {
            let name = String(soundName.dropFirst("ringtone:".count))
            url = AudioUtils.resolvedURL(for: name, in: "/Library/Ringtones")
        } else if soundName.hasPrefix("custom:") {
            let name = String(soundName.dropFirst("custom:".count))
            let customDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RoutineBuilder/CustomSounds")
            url = customDir.appendingPathComponent(name)
        } else {
            url = nil
        }
        
        guard let url else {
            print("[Sound] No URL resolved")
            return
        }
        print("[Sound] Playing: \(url.path), exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = -1  // loop until stopped
        audioPlayer?.play()
    }

    func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - RoutineRunnerView

struct RoutineRunnerView: View {

    @StateObject private var runner: RoutineRunner
    @EnvironmentObject private var routineManager: RoutineManager
    @EnvironmentObject private var alarmManager: AlarmManager
    @Environment(\.dismiss) private var dismiss
    
    let resumeState: ActiveRoutineState?

    init(routine: Routine, routineManager: RoutineManager, alarmManager: AlarmManager, resumeState: ActiveRoutineState? = nil) {
        self.resumeState = resumeState
        _runner = StateObject(wrappedValue: RoutineRunner(
            routine: routine,
            routineManager: routineManager,
            alarmManager: alarmManager,
            resumeFrom: resumeState
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer()

                if let card = runner.currentCard {
                    cardContent(card)
                        .padding(.horizontal, 20)
                } else {
                    completionView
                }

                Spacer()

                if let card = runner.currentCard {
                    actionButtons(card)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .onChange(of: runner.timerFired) { _, fired in
            if fired { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(runner.routine.name)
                    .font(.headline)
                Text("Step \(runner.currentCardIndex + 1) of \(runner.totalCards)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func cardContent(_ card: Card) -> some View {
        VStack(spacing: 24) {
            // Title
            Text(card.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            // Timer ring
            if card.hasDuration {
                timerRing(card: card)
            }

            // Notes
            if !card.notes.isEmpty {
                Text(card.notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // To-dos
            if !card.sortedTodos.isEmpty {
                todoList(card: card)
            }
        }
    }

    private func timerRing(card: Card) -> some View {
        let total = Double(card.durationMinutes * 60)
        let remaining = Double(runner.secondsRemaining)
        let progress = total > 0 ? remaining / total : 0

        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    runner.timerFired ? Color.red : Color.accentColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: runner.secondsRemaining)
            VStack(spacing: 4) {
                Text(timeString(runner.secondsRemaining))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(runner.timerFired ? .red : .primary)
                Text("remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
    }

    private func todoList(card: Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(card.sortedTodos) { todo in
                Button {
                    todo.isCompleted.toggle()
                    routineManager.save()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                            .font(.title3)
                        Text(todo.title)
                            .strikethrough(todo.isCompleted)
                            .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private func actionButtons(_ card: Card) -> some View {
        VStack(spacing: 12) {
            if !runner.hasStarted {
                // Pre-start state — only show I'm Starting
                Button {
                    runner.acknowledge()
                } label: {
                    Label("I'm Starting", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                // Active state — show snooze (if timer fired) and done
                if runner.timerFired {
                    Button {
                        runner.snooze()
                    } label: {
                        Label("Snooze \(card.snoozeMinutes) min", systemImage: "zzz")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button {
                    runner.completeCard()
                } label: {
                    Label(runner.isLastCard ? "Finish Routine" : "Done with Step", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!runner.canCompleteCard)
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Routine Complete!")
                .font(.title.weight(.bold))
            Text("Great work.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
