# RoutineBuilder — Xcode Setup Instructions

## Opening the Project

1. Unzip and open `RoutineBuilder.xcodeproj` in Xcode 26+ (AlarmKit requires iOS 26)
2. Select your team under **Signing & Capabilities** for the `RoutineBuilder` target
3. Change the bundle ID from `com.yourteam.RoutineBuilder` to your own

---

## Required: Widget Extension for AlarmKit

AlarmKit countdown alarms **require** a widget extension with a Live Activity.
Without it, countdown alarms will be silently dismissed by the system.

### Steps:

**Current state:** the extension target and `RoutineLiveActivity` struct already
exist in the project and match the shape below — steps 1–3 are done. Steps 4–6
(the Alarms capability, AlarmKit linking, and swapping out the `AlarmManager`
stub) are still outstanding.

1. **Add the extension target:** ✅ done
   `File > New > Target > Widget Extension`
   - Name: `RoutineBuilderWidgetExtension`
   - Uncheck "Include Configuration App Intent"
   - Check "Include Live Activity"

   Note: this template also generates a placeholder `RoutineBuilderWidget.swift`
   (the default "My Widget" emoji example). It's currently still the
   unmodified Xcode boilerplate — delete it or repurpose it before shipping,
   and remove its entry from `RoutineBuilderWidgetBundle.swift` if deleted.

2. **Create the Live Activity in the extension target:** ✅ done — see
   `RoutineBuilderWidgetLiveActivity.swift`. Note this defines the *shape*
   of the Live Activity only; nothing yet calls
   `Activity<RoutineAttributes>.request(...)` to actually start or update
   one. That wiring depends on the real `AlarmManager` implementation (step 6).
   Implement `ActivityAttributes` using the shape from `Models.swift`:
   ```swift
   import ActivityKit
   import WidgetKit
   import SwiftUI

   struct RoutineAttributes: ActivityAttributes {
       struct ContentState: Codable, Hashable {
           var cardTitle: String
           var secondsRemaining: Int
           var totalSeconds: Int
       }
       var routineName: String
   }

   struct RoutineLiveActivity: Widget {
       var body: some WidgetConfiguration {
           ActivityConfiguration(for: RoutineAttributes.self) { context in
               // Lock Screen UI
               HStack {
                   Text(context.attributes.routineName)
                   Spacer()
                   Text("\(context.state.secondsRemaining / 60):\(String(format: "%02d", context.state.secondsRemaining % 60))")
                       .monospacedDigit()
               }
               .padding()
           } dynamicIsland: { context in
               DynamicIsland {
                   DynamicIslandExpandedRegion(.leading) {
                       Text(context.attributes.routineName).font(.caption)
                   }
                   DynamicIslandExpandedRegion(.trailing) {
                       Text("\(context.state.cardTitle)").font(.caption)
                   }
               } compactLeading: {
                   Image(systemName: "timer")
               } compactTrailing: {
                   Text("\(context.state.secondsRemaining / 60)m").monospacedDigit()
               } minimal: {
                   Image(systemName: "timer")
               }
           }
       }
   }
   ```

3. **Add App Group** (to share data between app and extension) — outstanding:
   - Main target: `Signing & Capabilities > + Capability > App Groups`
     Add: `group.com.yourteam.RoutineBuilder`
   - Widget extension target: same capability, same group ID

4. **Add Alarms capability** to the main app target:
   `Signing & Capabilities > + Capability > Alarms`

5. **Link AlarmKit** in the main app target:
   `Build Phases > Link Binary With Libraries > + > AlarmKit.framework`

6. **Swap in the real implementation** in `AlarmManager.swift`. The active
   code today is a plain 4-method stub class at the top of the file, with the
   real AlarmKit implementation (and its own fallback stub) commented out
   below it. Once AlarmKit is linked:
   - Delete the active stub class at the top of the file
   - Uncomment the `#if canImport(AlarmKit) ... #else ... #endif` block
   - The `#if` branch will compile once AlarmKit is linked; the `#else`
     branch in that block can then be deleted too

---

## Known Limitations

- **Custom alarm sounds** only play when the app is foregrounded — this is an AlarmKit constraint
- The `RoutineRunnerView` `StateObject` init uses a workaround due to SwiftUI's environment injection timing. If you refactor the runner, use a factory pattern to pass `RoutineManager` and `AlarmManager` directly.

---

## File Structure

```
RoutineBuilder/
├── App/
│   ├── RoutineBuilderApp.swift   — Entry point, container setup, permissions
│   └── ContentView.swift         — Tab bar shell
├── Models/
│   └── Models.swift              — SwiftData models + migration plan
├── Managers/
│   ├── RoutineManager.swift      — All CRUD, queue, state persistence, notifications
│   ├── AlarmManager.swift        — AlarmKit wrapper (with stub fallback)
│   ├── RoutineExporter.swift     — JSON import/export of routines
│   └── AudioUtils.swift          — Shared alarm sound resolution helpers
└── Views/
    ├── Onboarding/
    │   ├── OnboardingView.swift   — 3-page onboarding
    │   └── ResumePromptView.swift — Interrupted routine recovery sheet
    ├── Routines/
    │   ├── RoutineListView.swift  — Main list + empty state
    │   └── RoutineEditorView.swift— Routine editor + card list
    ├── Cards/
    │   ├── CardEditorView.swift   — Card editor sheet
    │   └── SoundPickerView.swift  — Alarm sound picker
    ├── Runner/
    │   ├── RoutineRunnerView.swift— Full-screen runner + RoutineRunner observable
    │   └── ActiveRoutineTabView.swift — "Now" tab wrapper
    └── Settings/
        └── SettingsView.swift     — Permissions status + debug tools
```
