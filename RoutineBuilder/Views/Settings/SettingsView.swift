import SwiftUI
import SwiftData

struct SettingsView: View {

    @EnvironmentObject private var routineManager: RoutineManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var showingImporter = false
    @State private var exportURL: URL?
    @State private var importResult: String?
    @State private var showingImportResult = false
    @State private var showingImportError = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                dataSection
                permissionsSection
                aboutSection
                debugSection
            }
            .navigationTitle("Settings")
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result: result)
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK") {}
            } message: {
                Text(importResult ?? "")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK") {}
            } message: {
                Text(importError ?? "Unknown error")
            }
        }
    }

    // MARK: - Sections

    private var dataSection: some View {
        Section("Data") {
            Button {
                exportRoutines()
            } label: {
                Label("Export Routines", systemImage: "square.and.arrow.up")
            }
            .disabled(routines.isEmpty)

            Button {
                showingImporter = true
            } label: {
                Label("Import Routines", systemImage: "square.and.arrow.down")
            }

            if routines.isEmpty {
                Text("No routines to export yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(routines.count) routine\(routines.count == 1 ? "" : "s") saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    // MARK: - Actions

    private func exportRoutines() {
        do {
            let url = try RoutineExporter.exportURL(from: routines.map { $0 })
            exportURL = url
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
    }

    private func handleImport(result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let count = try RoutineExporter.importRoutines(from: url, into: modelContext)
            importResult = count == 0
                ? "No new routines found — all routines in the file already exist."
                : "Successfully imported \(count) routine\(count == 1 ? "" : "s")."
            showingImportResult = true
        } catch {
            importError = error.localizedDescription
            showingImportError = true
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

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
