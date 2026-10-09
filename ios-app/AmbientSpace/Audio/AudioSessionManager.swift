import AVFoundation

enum AudioMode: String, CaseIterable, Identifiable {
    case background
    case foreground

    var id: String { rawValue }

    var title: String {
        switch self {
        case .background:
            return String(localized: "Background")
        case .foreground:
            return String(localized: "Foreground")
        }
    }
}

@MainActor
protocol AudioSessionManaging: AnyObject {
    func configure(mode: AudioMode, activate: Bool) throws
    func deactivate() throws
}

@MainActor
final class AudioSessionManager: AudioSessionManaging {
#if targetEnvironment(macCatalyst)
    // macOS mixes application audio by default. Catalyst has no iOS audio-session
    // category to configure, so the controller keeps this boundary as a no-op.
    func configure(mode: AudioMode, activate: Bool) throws {}

    func deactivate() throws {}
#else
    private let session = AVAudioSession.sharedInstance()

    func configure(mode: AudioMode, activate: Bool) throws {
        let options: AVAudioSession.CategoryOptions = mode == .background
            ? [.mixWithOthers]
            : []
        try session.setCategory(.playback, mode: .default, options: options)
        if activate {
            try session.setActive(true)
        }
    }

    func deactivate() throws {
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
    }
#endif
}
