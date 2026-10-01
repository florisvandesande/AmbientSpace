import Foundation

struct PlaybackWidgetState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let currentTrackID: String?
    let isPlaying: Bool

    init(currentTrackID: String?, isPlaying: Bool) {
        schemaVersion = Self.currentSchemaVersion
        self.currentTrackID = currentTrackID
        self.isPlaying = isPlaying
    }
}

struct PlaybackWidgetStateStore {
    static let stateKey = "playback-widget-state"

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: Self.appGroupIdentifier)) {
        self.defaults = defaults
    }

    func load() -> PlaybackWidgetState {
        guard let data = defaults?.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(PlaybackWidgetState.self, from: data),
              state.schemaVersion == PlaybackWidgetState.currentSchemaVersion
        else {
            return PlaybackWidgetState(currentTrackID: nil, isPlaying: false)
        }
        return state
    }

    @discardableResult
    func save(_ state: PlaybackWidgetState) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(state) else {
            return false
        }
        defaults.set(data, forKey: Self.stateKey)
        return true
    }

    static var appGroupIdentifier: String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.florisvandesande.AmbientSpace"
        let appIdentifier = bundleIdentifier.hasSuffix(".Widgets")
            ? String(bundleIdentifier.dropLast(".Widgets".count))
            : bundleIdentifier
        return "group.\(appIdentifier)"
    }
}

enum SoundWidgetLayout: Equatable {
    case empty
    case single
    case twoPills
    case fourCells
    case nineCells

    static func layout(configuredCount: Int) -> SoundWidgetLayout {
        switch configuredCount {
        case ...0: return .empty
        case 1: return .single
        case 2: return .twoPills
        case 3...4: return .fourCells
        default: return .nineCells
        }
    }
}
