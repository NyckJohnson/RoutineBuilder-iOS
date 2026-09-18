# Routine Builder - Implementation Memo & Lessons Learned

**Platform:** iOS 26+ (iPhone)
**Architecture:** SwiftUI + SwiftData + AlarmKit + ActivityKit (WidgetKit extension required)

The app should feel at home on iPhone — gesture-driven, thumb-friendly, and consistent with the latest iOS design language (dynamic island awareness, live activities, haptics).

---

## Project Overview

### What It Does
A mobile-first routine management app. Users can:
- Create multiple routines with scheduled times
- Add cards to routines (steps with duration, alarms, to-dos, notes)
- Reorder cards via long-press drag and drop
- Run routines with countdown timers, alarms, and snooze
- Check off individual to-dos and complete cards to advance the routine
- Receive push notifications when a scheduled routine is about to start
- Customize alarm sounds (system sounds + custom imports from Files)
- View a full-screen card runner UI while a routine is active
- Acknowledge starting a step (silences alarm until timer ends) or snooze it
- Complete a step (moves to next card) — requires all to-dos checked first
- Queue routines — if a scheduled routine fires while another is running, it waits until the active one finishes

### Core Use Case
User creates a "Bedtime Routine" scheduled for 10 PM with cards like:
1. "Prepare clothes" - 5 min - todos: [pick outfit, iron shirt]
2. "Shower" - 15 min - todos: [brush teeth, floss]
3. "Reading" - 30 min - alarm plays when time's up
4. "Sleep" - notes: "Lights off, phone on charger"

At 9:55 PM a push notification fires: "Bedtime Routine starts in 5 minutes." Tapping it opens directly into the routine runner.

---

## Navigation Architecture

### Recommended: Tab Bar + NavigationStack

```
TabView {
    RoutineListView()       // Tab 1: "Routines"  (house.fill)
    ActiveRoutineView()     // Tab 2: "Now"        (play.circle.fill) — badge when running
    SettingsView()          // Tab 3: "Settings"   (gearshape.fill)
}
```

**Why tab bar over drill-down:**
- Routine list and active runner are peer-level concerns, not parent/child
- Active routine tab can show a badge dot when a routine is running
- Settings is naturally a separate tab
- Familiar pattern — users know where everything is

**NavigationStack within each tab** handles drill-down (routine → card editor, etc.).

---

## Key Implementation Decisions

### 1. Data Layer: SwiftData (not Core Data)
**Approach:** SwiftData with `@Model` classes

```swift
@Model
class Routine {
    var id: UUID
    var name: String
    var scheduledTime: Date?
    var isScheduled: Bool
    var orderIndex: Int
    @Relationship(deleteRule: .cascade) var cards: [Card]
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.orderIndex = 0
        self.isScheduled = false
    }
}
```

**Why SwiftData over Core Data:**
- Native Swift syntax, no `@NSManaged`, no `.xcdatamodeld` file
- `@Query` replaces `@FetchRequest` with cleaner syntax
- Automatic relationship management
- Still backed by Core Data under the hood — same reliability

**Thread safety:** Mark `@MainActor` on managers just as with Core Data. SwiftData contexts are not thread-safe.

### 2. Alarms & Timers: AlarmKit (iOS 26+)

AlarmKit replaces the combination of `UNUserNotificationCenter` + `AVAudioPlayer` for all card-end alarms. It fires even in Silent mode and Focus modes — something previously impossible without a special entitlement from Apple.

**Two scheduling modes used by this app:**
- `Alarm.Schedule.fixed(date)` — for routine start-time alarms
- `Alarm.Schedule.countdown(duration:)` — for card end-of-timer alarms

**Setup — add to Info.plist:**
```xml
<key>NSAlarmKitUsageDescription</key>
<string>Routine Builder uses alarms to alert you when each step ends.</string>
```

**Authorization (must request before scheduling):**
```swift
import AlarmKit

let manager = AlarmManager.shared

func requestAlarmAuthorization() async {
    guard manager.authorizationState == .notDetermined else { return }
    try? await manager.requestAuthorization()
}
```

**Scheduling a card-end countdown alarm:**
```swift
nonisolated struct CardAlarmMetadata: AlarmMetadata {
    var routineID: UUID
    var cardID: UUID
}

func scheduleCardAlarm(for card: Card, duration: TimeInterval) async throws {
    let metadata = CardAlarmMetadata(routineID: card.routine.id, cardID: card.id)
    
    let presentation = AlarmPresentation(
        alert: AlarmPresentation.Alert(
            title: card.title,
            secondaryButton: .snoozeButton,          // built-in snooze
            secondaryButtonBehavior: .countdown
        )
    )
    
    let alarm = Alarm(
        schedule: .countdown(duration: duration),
        metadata: metadata,
        presentation: presentation
    )
    
    try await manager.schedule(alarm)
}
```

**Custom "Acknowledge" and "Done" actions via App Intents:**
```swift
struct AcknowledgeCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Acknowledge Step"
    
    @Parameter(title: "Card ID") var cardIDString: String
    
    func perform() async throws -> some IntentResult {
        // Navigate to runner, silence in-app UI alarm
        return .result()
    }
}
```
Pass as a custom secondary button in `AlarmPresentation` to hook into the system alert UI.

**Routine start-time notification:** Use `UNUserNotificationCenter` (standard push) for the 5-minute heads-up before a routine begins — AlarmKit is reserved for the step-end alarms where breaking through Silent mode is critical.

**LESSON:** Always cancel the existing alarm before rescheduling. Use `card.id.uuidString` as a stable identifier. AlarmKit does not wake your app when an alarm fires — use the metadata + App Intents to handle user responses.

**LIMITATION — Custom Sounds:** AlarmKit only plays local bundled sounds, not user-imported files. For cards where the user has selected a custom sound, fall back to an `AVAudioPlayer` alarm triggered while the app is foregrounded, and a standard (non-AlarmKit) notification if backgrounded. Document this limitation clearly in the UI.

### 3. Timer Management & Memory Safety

Same rules apply as macOS — never capture SwiftData model objects in closures.

```swift
// WRONG
Timer.scheduledTimer(withTimeInterval: 1) { _ in
    self.processCard(card)  // card could be stale or deleted
}

// CORRECT
let cardID = card.id
Timer.scheduledTimer(withTimeInterval: 1) { [weak self] _ in
    guard let self else { return }
    guard let card = self.fetchCard(by: cardID) else { return }
    self.processCard(card)
}
```

Use `@MainActor` on your `RoutineRunner` class to keep timer callbacks on the main thread.

### 4. Live Activity (Required when using AlarmKit countdowns)

AlarmKit countdown alarms **require** a widget extension with a Live Activity — the system will unexpectedly dismiss alarms without one. This is no longer optional.

```swift
// Define in RoutineWidgetExtension target
struct RoutineAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var cardTitle: String
        var secondsRemaining: Int
        var totalSeconds: Int
        var alarmState: AlarmPresentationState  // provided by AlarmKit
    }
    var routineName: String
}
```

---

## Critical Implementation Details

### Auto-Save Pattern
No save button. Use `.onChange` or SwiftData's automatic save:

```swift
// SwiftData auto-saves on context change by default
// For explicit saves:
TextField("Routine name", text: $routine.name)
    .onChange(of: routine.name) {
        try? modelContext.save()
    }
```

### Live-Updating Lists with @Query

```swift
struct RoutineListView: View {
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    
    var body: some View {
        List {
            ForEach(routines) { routine in
                RoutineRow(routine: routine)
            }
            .onMove { source, destination in
                // reindex and save
            }
            .onDelete { offsets in
                // delete and save
            }
        }
    }
}
```

### Haptic Feedback
Add haptics at key moments — it's expected on iPhone:

```swift
// When completing a to-do
let generator = UIImpactFeedbackGenerator(style: .light)
generator.impactOccurred()

// When completing a card / advancing routine
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success)
```

---

## Feature Implementation

### ✅ Card Drag & Drop Reordering

Same `List` + `.onMove` approach as macOS — it's SwiftUI's recommended pattern on iOS too.

```swift
List {
    ForEach(routine.sortedCards, id: \.id) { card in
        CardRow(card: card)
    }
    .onMove { source, destination in
        var cards = routine.sortedCards
        cards.move(fromOffsets: source, toOffset: destination)
        for (index, card) in cards.enumerated() {
            card.orderIndex = index
        }
        try? modelContext.save()
    }
}
.environment(\.editMode, .constant(.active))  // Always show drag handles
```

### ✅ Routine Runner Full-Screen UI

When a routine starts, present a full-screen sheet:

```swift
.fullScreenCover(isPresented: $routineIsRunning) {
    RoutineRunnerView(routine: routine)
}
```

Runner UI layout (thumb-friendly — actions at bottom):
```
┌─────────────────────────┐
│  Routine Name    ✕ Stop │
│                         │
│  [Card Title]           │
│  [Progress ring / bar]  │
│  14:32 remaining        │
│                         │
│  To-Dos:                │
│  ☐ Pick outfit          │
│  ☐ Iron shirt           │
│                         │
│  [   Snooze 5 min   ]   │
│  [✓  Done with step ]   │  ← Primary action, large
└─────────────────────────┘
```

**Acknowledge start:** Tap "I'm starting" → silences alarm, starts countdown.
**Snooze:** Delays alarm re-trigger by N minutes (user-configurable per card).
**Done:** Only enabled when all to-dos are checked. Advances to next card.

### ✅ To-Do Completion Gate

```swift
var canCompleteCard: Bool {
    card.todosArray.allSatisfy { $0.isCompleted }
}

Button("Done with step") {
    advanceToNextCard()
}
.disabled(!canCompleteCard)
.buttonStyle(.borderedProminent)
.controlSize(.large)
```

### ✅ Custom Alarm Sounds

**Important:** AlarmKit only plays locally bundled sounds. Custom user-imported sounds cannot be used as AlarmKit alert sounds. The strategy is:

- **App foregrounded:** Use `AVAudioPlayer` to play the custom sound when the card timer ends
- **App backgrounded / default sound cards:** Use AlarmKit (system sound only)
- Make this limitation visible in the sound picker UI — e.g. a note: "Custom sounds play when app is open"

Import sounds via `.fileImporter`:

```swift
.fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio]) { result in
    guard let url = try? result.get() else { return }
    
    // Must security-scope on iOS
    guard url.startAccessingSecurityScopedResource() else { return }
    defer { url.stopAccessingSecurityScopedResource() }
    
    let dest = appSupportDir.appendingPathComponent("CustomSounds/\(url.lastPathComponent)")
    try? FileManager.default.copyItem(at: url, to: dest)
}
```

Play via `AVAudioPlayer` (not `NSSound`):
```swift
import AVFoundation

var audioPlayer: AVAudioPlayer?

func playSound(named name: String) {
    audioPlayer?.stop()
    
    if let url = Bundle.main.url(forResource: name, withExtension: nil) {
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
    } else {
        let custom = appSupportDir.appendingPathComponent("CustomSounds/\(name)")
        audioPlayer = try? AVAudioPlayer(contentsOf: custom)
    }
    audioPlayer?.play()
}
```

**LESSON:** Always stop the previous player before starting a new one. Keep a reference to `AVAudioPlayer` or it will be deallocated and stop immediately.

**Background audio:** Add `audio` to `UIBackgroundModes` in `Info.plist` so alarms fire when the app is backgrounded.

---

## UI/UX Decisions

### Routine List Screen
- Large title navigation bar: "Routines"
- Each row: routine name, scheduled time, chevron
- Swipe-left to delete
- "+" button top-right to add routine
- Tap → pushes to Routine Editor

### Routine Editor Screen
- Inline editable title (`.font(.title2)`)
- Toggle: "Schedule this routine" → shows time picker inline (`.datePickerStyle(.compact)`)
- Card list with drag handles always visible
- "Add Card" button at bottom of list
- Swipe-left on card to delete

### Card Editor Sheet (`.sheet` presentation)
- Presented as a bottom sheet from card tap
- Sections: Title, Notes, Duration, Snooze Duration, Alarm Sound, To-Dos
- To-dos: inline add/delete, tap to reorder
- "Delete Card" as destructive button at bottom

### Active Routine Tab ("Now")
- Empty state when nothing is running: "No active routine. Start one from your list."
- When running: mirrors the runner UI, shows current card + progress
- Badge on tab icon while running

### Design System
**Principles:**
- 44pt minimum tap targets (Apple HIG requirement)
- Bottom-heavy layout (thumbs reach bottom easily)
- SF Symbols throughout
- System colors only (supports Dark Mode automatically)
- `List` for all scrollable content
- `.buttonStyle(.borderedProminent)` for primary actions
- Sections via `Form` + `Section` in editors
- Smooth transitions with `.animation(.spring, value: ...)` for state changes

---

## Onboarding & Permissions Flow

First launch requires two permissions: AlarmKit and `UNUserNotificationCenter`. Asking for both at once feels aggressive and leads to users denying both. Follow this staged approach:

**Stage 1 — Value screen (no permissions yet)**
Show a simple 2–3 screen walkthrough explaining what the app does. No permission prompts here.

**Stage 2 — Request notifications first**
After the walkthrough, explain why: "We'll remind you 5 minutes before a routine starts." Then request `UNUserNotificationCenter` authorization. This is the lower-stakes ask — users are more comfortable with it.

**Stage 3 — Request AlarmKit on first routine start**
Don't ask for AlarmKit upfront. Wait until the user taps "Start Routine" for the first time, then explain: "To alert you when each step ends — even in Silent mode — we need alarm access." Request then.

**If either permission is denied:**
- Degrade gracefully — the app still works, alarms just won't break through Focus/Silent
- Show a persistent but non-blocking banner in Settings tab: "Enable alarms for full functionality" with a deep-link to the system Settings page:
```swift
URL(string: UIApplication.openSettingsURLString)
```

**LESSON:** Never ask for permissions before the user understands why. Context-at-the-moment-of-need dramatically improves grant rates.

---

## Routine Scheduling & Queue Behavior

Two routines must never run simultaneously. The rules:

- **No two routines can be scheduled for the same time.** Enforce this in the time picker — when a user selects a time already taken, show an inline error and prevent saving.
- **If a scheduled routine fires while another is active**, it enters a queue and starts automatically when the active routine finishes.
- **Manual starts** follow the same rule — tapping "Start" on a second routine while one is running adds it to the queue rather than interrupting.

**Data model additions needed:**
```swift
@Model
class RoutineQueue {
    var queuedRoutineIDs: [UUID]  // ordered list of waiting routines
    var updatedAt: Date
}
```

Or more simply, add a `queuePosition: Int?` property to `Routine` — `nil` means not queued, `0` means next up.

**Conflict validation in the time picker:**
```swift
func isTimeConflicting(_ date: Date, excluding routine: Routine) -> Bool {
    let calendar = Calendar.current
    return allRoutines
        .filter { $0.id != routine.id && $0.isScheduled }
        .contains {
            guard let t = $0.scheduledTime else { return false }
            return calendar.dateComponents([.hour, .minute], from: t) ==
                   calendar.dateComponents([.hour, .minute], from: date)
        }
}
```

**UX:** In the Routine List, show queued routines with a subtle "Up next" badge so the user knows what's waiting.

---

## SwiftData Migration Strategy

Every schema version you ship is permanent. Plan properties carefully before v1.

**Versioning approach:**
```swift
enum RoutineSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Routine.self, Card.self, Todo.self] }
}

enum RoutineMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [RoutineSchemaV1.self] }
    static var stages: [MigrationStage] { [] }  // add stages between versions here
}
```

Pass the plan to the `ModelContainer`:
```swift
let container = try ModelContainer(
    for: Routine.self,
    migrationPlan: RoutineMigrationPlan.self
)
```

**Rules:**
- Adding an **optional** property → lightweight migration, no stage needed
- Adding a **non-optional** property → requires a migration stage with a default value
- Renaming or removing a property → custom migration stage required
- Never rename a model class without a migration — SwiftData treats it as a new entity and will lose existing data

**LESSON:** Add a new `VersionedSchema` enum for every shipped app version that changes the schema, even minor ones. Retrofitting this later is painful.

---

## Force-Quit & State Recovery

AlarmKit alarms will still fire if the app is force-quit — the system handles them. The problem is restoring the in-app runner state when the user taps through the alarm.

**What to persist (write to SwiftData on every state change):**
```swift
@Model
class ActiveRoutineState {
    var routineID: UUID
    var currentCardIndex: Int
    var cardStartedAt: Date        // used to recalculate time remaining on resume
    var isAcknowledged: Bool       // whether user tapped "I'm starting"
    var isPaused: Bool
}
```

**On app launch, check for interrupted state:**
```swift
func checkForInterruptedRoutine() -> ActiveRoutineState? {
    // fetch ActiveRoutineState from SwiftData
    // if exists and routine still valid, offer resume
}
```

**Resume prompt UI:**
On launch with a saved state, show a sheet before the main UI:
```
┌─────────────────────────────┐
│  You were mid-routine       │
│  "Bedtime Routine"          │
│  Step 2 of 5: Shower        │
│                             │
│  [Resume]   [Dismiss]       │
└─────────────────────────────┘
```

- **Resume:** Recalculate remaining time from `cardStartedAt`, restore runner UI
- **Dismiss:** Delete `ActiveRoutineState`, cancel any pending AlarmKit alarms for that routine

**LESSON:** `ActiveRoutineState` should be a single-row singleton in SwiftData — delete and recreate it rather than updating in place to avoid stale state bugs.

---

## Gotchas & Non-Obvious Pitfalls

Things that will bite you and aren't obvious from the docs:

- **Never capture SwiftData model objects in closures** — capture `UUID` or `PersistentIdentifier` and refetch. This applies everywhere: timers, async tasks, App Intents.
- **AlarmKit silently fails without `NSAlarmKitUsageDescription`** in Info.plist — no error, alarms just don't schedule.
- **AlarmKit countdown alarms will be dismissed by the system** if the widget extension / Live Activity is not set up. Build the extension early, not at the end.
- **AlarmKit does not wake your app** when an alarm fires — all user interaction from the alarm must go through `AppIntent`.
- **Test AlarmKit on a real device from day one** — Simulator behavior is unreliable.
- **`AVAudioPlayer` deallocates immediately** if you don't hold a strong reference to it. Always store it as a property, never a local variable.
- **Don't try to keep a `Timer` alive in the background** — it won't work. AlarmKit owns backgrounded alerts; the in-app timer is foregrounded-only.
- **Renaming a SwiftData model class without a migration** is treated as a new entity — existing user data is silently lost.
- **`ActiveRoutineState` should be deleted and recreated**, never mutated in place — stale property values from a previous session will cause hard-to-debug resume behavior.
