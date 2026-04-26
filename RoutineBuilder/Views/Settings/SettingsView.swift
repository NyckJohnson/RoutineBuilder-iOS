import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var routineManager: RoutineManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        NavigationStack {
            Form {
                permissionsSection
                aboutSection
                debugSection
            }
            .navigationTitle("Settings")
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            if routineManager.permissionsDenied.contains(.notifications) {
                HStack {
                    Label("Notifications Disabled", systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Enable") { openSettings() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                Label("Notifications Enabled", systemImage: "bell.fill")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Alarm Access", systemImage: "alarm.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Settings") { openSettings() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
        }
    }

    private var debugSection: some View {
        Section {
            Button("Reset Onboarding") {
                hasCompletedOnboarding = false
            }
            .foregroundStyle(.orange)
        } header: {
            Text("Debug")
        } footer: {
            Text("For development use only.")
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
