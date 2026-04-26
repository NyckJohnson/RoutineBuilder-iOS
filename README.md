# RoutineBuilder

A modern iOS app for building and running timed routines — morning rituals, bedtime wind-downs, workout flows, and anything else you do step by step.

Built with SwiftUI and SwiftData for iOS 26+.

---

## Features

- **Create routines** with sequential steps, each with a timer, notes, and a to-do checklist
- **Run routines** with a full-screen timer UI — tap to acknowledge a step, check off to-dos, and advance when ready
- **Scheduled routines** with push notification reminders 5 minutes before start
- **Routine queue** — start a second routine while one is running and it will wait its turn
- **Custom alarm sounds** — choose from built-in alarm sounds, ringtones, or import your own
- **Crash recovery** — if the app is force-quit mid-routine, it offers to resume where you left off
- **Onboarding flow** with staged permission requests

## Screenshots

*Coming soon*

---

## Requirements

- iOS 26.1+
- Xcode 26+

---

## Getting Started

1. Clone the repo
   ```bash
   git clone https://github.com/NyckJohnson/RoutineBuilder-iOS.git
   cd RoutineBuilder-iOS
   ```

2. Open `RoutineBuilder.xcodeproj` in Xcode 26+

3. Set your development team under **Signing & Capabilities**

4. Change the bundle identifier from `com.yourteam.RoutineBuilder` to your own

5. Follow the setup instructions in [`SETUP.md`](SETUP.md) to wire up the widget extension and AlarmKit capability

6. Build and run on a real device (iOS 26+ required)

---

## Architecture

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Data | SwiftData |
| Notifications | UserNotifications |

### Project Structure

```
RoutineBuilder/
├── App/                    — Entry point, tab bar shell
├── Models/                 — SwiftData models + migration plan
├── Managers/               — RoutineManager, AlarmManager
└── Views/
    ├── Onboarding/         — First launch flow, resume prompt
    ├── Routines/           — Routine list and editor
    ├── Cards/              — Card editor, sound picker
    ├── Runner/             — Active routine timer UI
    └── Settings/           — Permissions and app info
```

---

## Known Limitations

- Background alarms are not yet implemented — the app works as a foreground timer only

---

## Contributing

Contributions are welcome. Please open an issue before starting work on a significant change so we can discuss the approach first.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

Please follow the existing code style and keep changes focused — one feature or fix per PR.

---

## Roadmap

- [ ] AlarmKit full integration (paid developer account required)
- [ ] Widget extension + Live Activity for Lock Screen countdown
- [ ] Apple Watch support
- [ ] iPad layout (NavigationSplitView)
- [ ] Accessibility / VoiceOver pass
- [ ] iCloud sync

---

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — free for personal and non-commercial use.

---

*Built with SwiftUI · iOS 26 · Made by [@NyckJohnson](https://github.com/NyckJohnson)*
