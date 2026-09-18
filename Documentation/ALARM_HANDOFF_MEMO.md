# Alarm Functionality — Handoff Memo

**Goal:** replace the current foreground-only `AVAudioPlayer` alarms with real
AlarmKit alarms that break through Silent mode and Focus, per the original
implementation memo's design.

## Files relevant to this work
- `Managers/AlarmManager.swift` — the wrapper itself (currently stubbed)
- `Models/Models.swift` — `Card.alarmSoundName`, `Card.durationSeconds`, `Card.hasDuration`
- `Views/Runner/RoutineRunnerView.swift` — `RoutineRunner` calls `scheduleCardAlarm` / `cancelCardAlarm` / `cancelAllAlarms`, and contains the foreground fallback player (`playAlarmSound`)
- `Views/Cards/SoundPickerView.swift` + `Managers/AudioUtils.swift` — define and resolve the sound-name convention
- `RoutineBuilderWidgetLiveActivity.swift` + `RoutineBuilderWidgetBundle.swift` — the widget extension target
- `SETUP.md` — Xcode-side setup steps (capability, framework link, Info.plist key)
- Main app's `Info.plist` — **not yet reviewed**, confirm `NSAlarmKitUsageDescription` is present

## Current State
`AlarmManager.swift` contains two implementations:
1. An **active** top-level stub class (4 no-op methods) — this is what actually compiles and runs today.
2. A fully-written real AlarmKit implementation, entirely commented out, itself wrapped in `#if canImport(AlarmKit) ... #else ... #endif` with its own internal fallback stub.

To activate AlarmKit: delete implementation #1, uncomment the block containing #2, then delete the `#else` stub inside that block (see `SETUP.md` step 6).

## Sound-Name Convention (already established — don't reinvent)
`Card.alarmSoundName` values, written by `SoundPickerView`:
- `nil` — never opened the picker (untouched default)
- `"default"` — explicit default system sound
- `"none"` — silent
- `"alarm:<name>"` — a bundled UISound
- `"ringtone:<name>"` — a bundled ringtone
- `"custom:<filename>"` — a user-imported file in `CustomSounds/`

The commented-out `AlarmManager.alarmSound(for:)` already parses this convention correctly for `"alarm:"`/`"ringtone:"`/`"custom:"` prefixes. No changes needed to the naming scheme itself.

## Known Issues to Fix During Integration

1. **Custom sounds will be (incorrectly) sent to AlarmKit.** The commented `scheduleCardAlarm` only skips scheduling when `card.alarmSoundName == "none"`. AlarmKit can only play locally bundled sounds — it **cannot** play user-imported custom files. Per the design (documented in the original memo and `SETUP.md`), custom-sound cards should skip AlarmKit entirely and rely on the existing foreground `AVAudioPlayer` fallback in `RoutineRunner.playAlarmSound`. Add a guard: if `alarmSoundName` starts with `"custom:"`, don't call AlarmKit's `schedule`.

2. **No re-cancel-before-reschedule check.** The memo's lesson is "always cancel the existing alarm before rescheduling, using a stable ID." The commented code schedules by `card.id` but doesn't explicitly cancel first. Confirm whether `AlarmKit.AlarmManager.schedule(id:configuration:)` implicitly replaces an alarm with the same ID — if not, add an explicit cancel call before each schedule.

3. **No `AppIntent` exists anywhere in the codebase.** The original memo describes an `AcknowledgeCardIntent` (App Intent) to handle the system alert's custom button, since AlarmKit does not wake the app on its own. This intent — and any others needed for "Done" from the lock screen — has not been built at all. This needs to be created from scratch, wired into `AlarmPresentation`'s buttons, and connected back to `RoutineRunner`/`RoutineManager` state (likely via the same `NotificationCenter` pattern already used for the heads-up notification tap in `RoutineBuilderApp.swift`).

4. **Live Activity isn't started anywhere.** `RoutineLiveActivity`/`RoutineAttributes` exist in the widget extension, but nothing in the app calls `Activity<RoutineAttributes>.request(...)`. Before wiring this up, confirm current AlarmKit behavior: it's possible AlarmKit auto-manages its own system Live Activity via `AlarmPresentation` without requiring a hand-built `ActivityKit` Live Activity at all — worth checking current Apple documentation before investing time in manual `Activity.request`/`ContentState` update code. This also determines whether the App Group capability (`SETUP.md` step 3) is actually necessary.

5. **Timer capture safety.** `RoutineRunner.completeCard()` and `loadCard(at:)` grab `let card = currentCard!` before handing off into a `Task { await alarmManager... }`. These are short-lived and on `@MainActor`, so likely fine, but worth a second look once real AlarmKit calls (which may take longer / retry) are in place — the project's own lesson is "never capture SwiftData model objects across an async boundary; capture the ID and refetch."

## Suggested Order of Work
1. Xcode: Alarms capability + link `AlarmKit.framework` + confirm `NSAlarmKitUsageDescription`.
2. Swap in the real `AlarmManager` implementation (delete stub, uncomment, clean up).
3. Fix the custom-sound guard (issue #1 above) before testing on device.
4. Build the `AppIntent`(s) for alert-button actions (issue #3).
5. Investigate Live Activity requirement (issue #4) before building manual `Activity.request` code.
6. Wire Onboarding Stage 3 to request AlarmKit authorization on first "Start Routine" tap.
7. Test exclusively on a real device — Simulator behavior for AlarmKit is unreliable per the original memo.
