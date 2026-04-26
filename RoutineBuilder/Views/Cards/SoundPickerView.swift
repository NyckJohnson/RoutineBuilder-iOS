import SwiftUI
import AVFoundation

@MainActor
struct SoundPickerView: View {

    @Binding var selectedSoundName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingImporter = false

    private let alarmSounds: [String] = {
        let dir = "/System/Library/Audio/UISounds/New"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        return files
            .filter { $0.hasSuffix(".caf") || $0.hasSuffix(".m4r") }
            .map { $0.replacingOccurrences(of: ".caf", with: "").replacingOccurrences(of: ".m4r", with: "") }
            .sorted()
    }()

    private let ringtones: [String] = {
        let dir = "/Library/Ringtones"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        return files
            .filter { $0.hasSuffix(".m4r") || $0.hasSuffix(".caf") }
            .map { $0.replacingOccurrences(of: ".m4r", with: "").replacingOccurrences(of: ".caf", with: "") }
            .sorted()
    }()

    private var customSounds: [String] {
        let dir = customSoundsDir
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.sorted()
    }

    private var customSoundsDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RoutineBuilder/CustomSounds")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    soundRow(name: "default", label: "Default")
                    soundRow(name: "none", label: "None")
                }

                Section("Custom") {
                    ForEach(customSounds, id: \.self) { name in
                        soundRow(name: "custom:\(name)", label: name)
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Sound File", systemImage: "plus.circle.fill")
                    }

                    Text("Custom sounds play only when the app is open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !ringtones.isEmpty {
                    Section("Ringtones") {
                        ForEach(ringtones, id: \.self) { name in
                            soundRow(name: "ringtone:\(name)", label: name)
                        }
                    }
                }

                if !alarmSounds.isEmpty {
                    Section("Alarm Sounds") {
                        ForEach(alarmSounds, id: \.self) { name in
                            soundRow(name: "alarm:\(name)", label: name)
                        }
                    }
                }
            }
            .navigationTitle("Alarm Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        stopCurrentSound()
                        dismiss()
                    }
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio]) { result in
                guard let url = try? result.get() else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                let dest = customSoundsDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.createDirectory(at: customSoundsDir, withIntermediateDirectories: true)
                try? FileManager.default.copyItem(at: url, to: dest)
            }
        }
        .onDisappear { stopCurrentSound() }
    }

    // MARK: - Row

    private func soundRow(name: String?, label: String) -> some View {
        Button {
            selectedSoundName = name
            preview(name)
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedSoundName == name {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playback

    // Sound names are prefixed with their source: "alarm:Radar", "ringtone:Marimba", "custom:mysound.mp3"
    private func preview(_ name: String?) {
        stopCurrentSound()
        guard let name else { return }

        let url: URL?

        if name.hasPrefix("alarm:") {
            let soundName = String(name.dropFirst("alarm:".count))
            url = resolvedURL(for: soundName, in: "/System/Library/Audio/UISounds/New")
        } else if name.hasPrefix("ringtone:") {
            let soundName = String(name.dropFirst("ringtone:".count))
            url = resolvedURL(for: soundName, in: "/Library/Ringtones")
        } else if name.hasPrefix("custom:") {
            let soundName = String(name.dropFirst("custom:".count))
            url = customSoundsDir.appendingPathComponent(soundName)
        } else if name == "none" {
            return  // silence, nothing to preview
        } else if name == "default" {
            // Default — preview Radar as representative
            url = resolvedURL(for: "Radar", in: "/System/Library/Audio/UISounds/New")
        } else {
            url = nil
        }

        guard let url else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }

    private func resolvedURL(for name: String, in dir: String) -> URL? {
        for ext in ["caf", "m4r", "mp3", "aiff"] {
            let url = URL(fileURLWithPath: "\(dir)/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func stopCurrentSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
