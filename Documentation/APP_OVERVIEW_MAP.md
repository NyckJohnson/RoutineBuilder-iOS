# RoutineBuilder — App Overview Map

**Purpose of this doc:** a single reference to share (along with the specific
files relevant to whatever you're working on) so a future session doesn't
need the whole codebase re-explained from scratch.

One-liner: SwiftUI + SwiftData iOS 26 app for building and running timed,
step-by-step routines with alarms, to-dos, scheduling, and crash recovery.

---

## 1. File Map

### Main app target
| File | Purpose |
|---|---|
| `App/RoutineBuilderApp.swift` | Entry point. Builds `ModelContainer`, injects `RoutineManager`/`AlarmManager`, runs onboarding gate, checks for an interrupted routine on launch, requests notification permission, sets up `NotificationDelegate`. |
| `App/ContentView.swift` | Tab bar shell (Routines / Now / Settings). |
| `Models/Models.swift` | SwiftData models: `Routine`, `Card`, `TodoItem`, `ActiveRoutineState`. Schema versioning (`RoutineSchemaV1`, `RoutineMigrationPlan`). |
| `Managers/RoutineManager.swift` | All CRUD, routine queueing, active-state persistence, heads-up (`UNUserNotificationCenter`) scheduling. |
| `Managers/AlarmManager.swift` | AlarmKit wrapper. **Currently a no-op stub** — real implementation is fully written but commented out. See the dedicated alarm handoff memo. |
| `Managers/RoutineExporter.swift` | JSON export/import of routines (Codable mirror structs, not SwiftData-dependent). |
| `Managers/AudioUtils.swift` | Shared helpers: default alarm sound lookup, sound file URL resolution, audio session activation. |
| `Views/Onboarding/OnboardingView.swift` | 3-page walkthrough + requests notification permission (Stage 1–2 of the staged permission plan). |
| `Views/Onboarding/ResumePromptView.swift` | Sheet shown on launch if a routine was interrupted mid-run. |
| `Views/Routines/RoutineListView.swift` | Routine list, empty state, reorder/delete. |
| `Views/Routines/RoutineEditorView.swift` | Routine name/schedule/card list editor; Start/Add-to-Queue button. |
| `Views/Cards/CardEditorView.swift` | Card (step) editor sheet: title, notes, timer, snooze, alarm sound, to-dos. |
| `Views/Cards/SoundPickerView.swift` | Alarm sound picker — system sounds, ringtones, custom imports. Defines the `"alarm:"/"ringtone:"/"custom:"/"default"/"none"` naming convention used everywhere sound names are read. |
| `Views/Runner/RoutineRunnerView.swift` | `RoutineRunner` (the timer/state engine) + the full-screen runner UI. Handles acknowledge/snooze/complete, pre-start "nag" alarm, and foreground `AVAudioPlayer` playback. |
| `Views/Runner/ActiveRoutineTabView.swift` | "Now" tab wrapper — shows the runner or an empty state. |
| `Views/Settings/SettingsView.swift` | Permission status, import/export UI, app version, debug onboarding reset. |

### Widget extension target (`RoutineBuilderWidgetExtension`)
| File | Purpose |
|---|---|
| `RoutineBuilderWidgetBundle.swift` | `@main` bundle registering both widgets below. |
| `RoutineBuilderWidget.swift` | ⚠️ **Still the unmodified Xcode template** ("My Widget" emoji example) — not yet built out or removed. |
| `RoutineBuilderWidgetLiveActivity.swift` | `RoutineAttributes` + Lock Screen/Dynamic Island UI. Scaffolded and matches spec, but nothing currently starts or updates one (`Activity.request` is never called anywhere in the codebase). |
| `Info.plist` | Extension point identifier only — correct as-is. |

### Docs
| File | Purpose |
|---|---|
| `README.md` | Feature list, architecture, roadmap. Kept in sync with code as of this handoff. |
| `SETUP.md` | Xcode setup steps, now annotated with ✅/outstanding status per step. |
| `ROUTINE_BUILDER_APP_IMPLEMENTATION_MEMO_iOS.md` | Original planning + lessons-learned doc. Has some stale details vs. final code (`Todo` vs `TodoItem` naming, a `RoutineQueue` model example superseded by the simpler `Routine.queuePosition` field) — treat the code and README/SETUP as the source of truth over this memo where they disagree. |

---

## 2. Data Model

```
Routine (1) ──cascade──▶ Card (many) ──cascade──▶ TodoItem (many)
```
- Queueing: no separate queue model — `Routine.queuePosition: Int?` (`nil` = not queued, `0` = next up).
- Crash recovery: `ActiveRoutineState` is a **singleton row** — always deleted and recreated, never mutated in place.

---

## 3. Feature Status

| Feature | Status |
|---|---|
| Create/edit routines & cards, drag-reorder | ✅ Done |
| To-do completion gate before advancing | ✅ Done |
| Routine queueing (one active at a time) | ✅ Done |
| Crash recovery / resume prompt | ✅ Done |
| Scheduled heads-up push notification | ⚠️ Works, but has a scheduling bug (see TODO list) |
| Foreground alarm playback (system/ringtone/custom sounds) | ✅ Done |
| Pre-start "nag" alarm if step not acknowledged in 60s | ✅ Done (undocumented until recent README update) |
| Import/export routines as JSON | ✅ Done |
| **AlarmKit (real background/Silent-mode alarms)** | ❌ Stubbed — see alarm handoff memo |
| Widget extension + Live Activity | ⚠️ Scaffolded only, not wired to alarm data; placeholder widget not cleaned up |
| Onboarding Stage 3 (AlarmKit permission request) | ❌ Not implemented |
| Apple Watch, iPad layout, accessibility pass, iCloud sync | ❌ Not started |


