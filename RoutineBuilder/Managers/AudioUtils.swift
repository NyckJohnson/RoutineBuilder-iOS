import Foundation
import AVFoundation

enum AudioUtils {

    // MARK: - Default alarm sound

    /// Returns the first available alarm sound on this device, sorted alphabetically.
    /// Falls back to "Anticipate" if the directory is empty or unreadable.
    static var defaultAlarmSoundName: String {
        let dir = "/System/Library/Audio/UISounds/New"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        return files
            .filter { $0.hasSuffix(".caf") }
            .sorted()
            .first
            .map { $0.replacingOccurrences(of: ".caf", with: "") }
            ?? "Anticipate"
    }

    // MARK: - URL resolution

    /// Finds the actual file URL for a sound name in a given directory,
    /// trying common audio extensions in order.
    static func resolvedURL(for name: String, in dir: String) -> URL? {
        for ext in ["caf", "m4r", "mp3", "aiff"] {
            let url = URL(fileURLWithPath: "\(dir)/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    // MARK: - Playback setup

    static func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
