# RoutineBuilder — Xcode Setup Instructions

## Opening the Project

1. Unzip and open `RoutineBuilder.xcodeproj` in Xcode 16+
2. Select your team under **Signing & Capabilities** for the `RoutineBuilder` target
3. Change the bundle ID from `com.yourteam.RoutineBuilder` to your own

---

## Required: Widget Extension for AlarmKit

AlarmKit countdown alarms **require** a widget extension with a Live Activity.
Without it, countdown alarms will be silently dismissed by the system.

### Steps:

1. **Add the extension target:**
   `File > New > Target > Widget Extension`
   - Name: `RoutineBuilderWidgetExtension`
   - Uncheck "Include Configuration App Intent"
   - Check "Include Live Activity"

2. **Create the Live Activity in the extension target:**
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

3. **Add App Group** (to share data between app and extension):
   - Main target: `Signing & Capabilities > + Capability > App Groups`
     Add: `group.com.yourteam.RoutineBuilder`
   - Widget extension target: same capability, same group ID

4. **Add Alarms capability** to the main app target:
   `Signing & Capabilities > + Capability > Alarms`

5. **Link AlarmKit** in the main app target:
   `Build Phases > Link Binary With Libraries > + > AlarmKit.framework`

6. **Remove the stub** in `AlarmManager.swift` once AlarmKit is linked —
   the `#if canImport(AlarmKit)` block will automatically use the real implementation.

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
│   └── AlarmManager.swift        — AlarmKit wrapper (with stub fallback)
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
