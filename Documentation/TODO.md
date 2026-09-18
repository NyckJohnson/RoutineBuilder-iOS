# RoutineBuilder — Next Steps

## High Priority — Core Alarm Functionality
1. Add the **Alarms** capability and link `AlarmKit.framework` to the main app target (`SETUP.md` steps 4–5).
2. Add `NSAlarmKitUsageDescription` to the **main app's** `Info.plist` — not yet confirmed to exist (only the widget extension's `Info.plist` has been reviewed).
3. In `AlarmManager.swift`: delete the active top-level stub class, uncomment the `#if canImport(AlarmKit) ... #endif` block, then delete the `#else` stub inside it. See the alarm handoff memo for the exact plan and known issues to fix while doing this.
4. Decide how the Live Activity gets started/updated (`Activity.request`, periodic `ContentState` updates) — nothing calls this today. Confirms whether the App Group capability is actually required.
5. Implement Onboarding Stage 3: request AlarmKit authorization the first time the user taps "Start Routine," per the staged-permissions plan.
6. Delete or repurpose the placeholder `RoutineBuilderWidget.swift` (still default Xcode template) and update `RoutineBuilderWidgetBundle.swift` if removed.
7. Test on a real device from the start — AlarmKit is unreliable in Simulator.

## Medium Priority — Bugs Found in Review
8. `RoutineManager.scheduleHeadsUpNotification` always sets `repeats: true` with hour/minute-only components, so the heads-up notification fires **daily** regardless of intent. Decide if routines should repeat daily or fire once, and fix the trigger accordingly.
9. `CardEditorView`'s "Custom sounds play only when the app is open" caption shows for **any** non-default sound (`"none"`, `"alarm:"`, `"ringtone:"`), not just `"custom:"` ones. Scope the condition to custom sounds only.
10. Reconcile `Card.alarmSoundName` semantics: `Models.swift`'s comment says `nil` = default, but `SoundPickerView` writes the literal string `"default"`. Pick one convention and use it consistently in reads (`AlarmManager`, `RoutineRunner`, `CardEditorView`) and writes.

## Lower Priority / Polish
11. Update `ROUTINE_BUILDER_APP_IMPLEMENTATION_MEMO_iOS.md` for the `Todo`/`TodoItem` naming and the `RoutineQueue` model example (superseded by `Routine.queuePosition`).
12. Roadmap items from README: Apple Watch support, iPad layout (`NavigationSplitView`), accessibility/VoiceOver pass, iCloud sync.
