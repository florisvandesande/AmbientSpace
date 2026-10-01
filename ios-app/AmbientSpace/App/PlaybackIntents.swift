import AppIntents
import Foundation
import UIKit

struct AmbientSoundEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Ambient sound")
    static let defaultQuery = AmbientSoundQuery()

    let id: String
    let title: String
    let subtitle: String
    let sfSymbol: String?
    let colorStart: String
    let colorEnd: String

    init(id: String, title: String, subtitle: String, sfSymbol: String?, colorStart: String, colorEnd: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sfSymbol = sfSymbol
        self.colorStart = colorStart
        self.colorEnd = colorEnd
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: subtitle),
            image: sfSymbol.map { DisplayRepresentation.Image(systemName: $0) }
        )
    }

    init(track: AudioTrack) {
        id = track.id
        title = track.displayTitle
        subtitle = track.displaySubtitle
        sfSymbol = track.displaySFSymbol.flatMap { UIImage(systemName: $0) == nil ? nil : $0 }
        colorStart = track.colorStart
        colorEnd = track.colorEnd
    }
}

struct AmbientSoundQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AmbientSoundEntity] {
        let tracks = await availableTracks()
        return tracks.filter { identifiers.contains($0.id) }.map(AmbientSoundEntity.init)
    }

    func suggestedEntities() async throws -> [AmbientSoundEntity] {
        await availableTracks().map(AmbientSoundEntity.init)
    }

    private func availableTracks() async -> [AudioTrack] {
        #if WIDGET_EXTENSION
        return (try? AudioCatalogLoader(bundle: .main).load().tracks) ?? []
        #else
        return await MainActor.run { AudioPlaybackController.shared.tracks }
        #endif
    }
}

enum AmbientWidgetActionKind: String, Codable, Sendable {
    case random
    case playPause
    case sound
}

struct AmbientWidgetActionEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Widget action")
    static let defaultQuery = AmbientWidgetActionQuery()

    let id: String
    let kind: AmbientWidgetActionKind
    let sound: AmbientSoundEntity?

    var title: String {
        switch kind {
        case .random: return String(localized: "Random")
        case .playPause: return String(localized: "Play or pause")
        case .sound: return sound?.title ?? String(localized: "Unavailable sound")
        }
    }

    var sfSymbol: String {
        switch kind {
        case .random: return "shuffle"
        case .playPause: return "playpause.fill"
        case .sound: return sound?.sfSymbol ?? "waveform"
        }
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            image: .init(systemName: sfSymbol)
        )
    }

    static let random = AmbientWidgetActionEntity(id: "action:random", kind: .random, sound: nil)
    static let playPause = AmbientWidgetActionEntity(id: "action:play-pause", kind: .playPause, sound: nil)

    init(id: String, kind: AmbientWidgetActionKind, sound: AmbientSoundEntity?) {
        self.id = id
        self.kind = kind
        self.sound = sound
    }

    init(sound: AmbientSoundEntity) {
        id = "sound:\(sound.id)"
        kind = .sound
        self.sound = sound
    }
}

struct AmbientWidgetActionQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AmbientWidgetActionEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AmbientWidgetActionEntity] {
        let sounds = try await AmbientSoundQuery().suggestedEntities()
        return [.random, .playPause] + sounds.map(AmbientWidgetActionEntity.init(sound:))
    }
}

enum PlaybackIntentError: LocalizedError {
    case unavailableSound

    var errorDescription: String? {
        String(localized: "This sound is no longer available. Choose another sound in the widget settings.")
    }
}

struct PlayRandomSoundIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play a random sound"
    static let description = IntentDescription("Starts a random AmbientSpace sound.")

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        try await MainActor.run {
            let playback = AudioPlaybackController.shared
            guard let track = playback.tracks.randomElement() else { throw PlaybackIntentError.unavailableSound }
            playback.play(track)
        }
        #endif
        return .result()
    }
}

struct TogglePlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or pause"
    static let description = IntentDescription("Pauses playback or starts a random AmbientSpace sound.")

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        try await MainActor.run {
            let playback = AudioPlaybackController.shared
            if playback.isPlaying {
                playback.pause()
            } else if playback.currentTrack != nil {
                playback.resume()
            } else if let track = playback.tracks.randomElement() {
                playback.play(track)
            } else {
                throw PlaybackIntentError.unavailableSound
            }
        }
        #endif
        return .result()
    }
}

struct PlaySoundIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play sound"
    static let description = IntentDescription("Starts or pauses the selected AmbientSpace sound.")

    @Parameter(title: "Sound") var sound: AmbientSoundEntity

    init() {}
    init(sound: AmbientSoundEntity) { self.sound = sound }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        try await MainActor.run {
            let playback = AudioPlaybackController.shared
            guard let track = playback.tracks.first(where: { $0.id == sound.id }) else {
                throw PlaybackIntentError.unavailableSound
            }
            if playback.currentTrack?.id == track.id, playback.isPlaying {
                playback.pause()
            } else {
                playback.play(track)
            }
        }
        #endif
        return .result()
    }
}

struct PerformWidgetActionIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Perform widget action"

    @Parameter(title: "Action") var action: AmbientWidgetActionEntity

    init() {}
    init(action: AmbientWidgetActionEntity) { self.action = action }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        switch action.kind {
        case .random:
            _ = try await PlayRandomSoundIntent().perform()
        case .playPause:
            _ = try await TogglePlaybackIntent().perform()
        case .sound:
            guard let sound = action.sound else { throw PlaybackIntentError.unavailableSound }
            _ = try await PlaySoundIntent(sound: sound).perform()
        }
        #endif
        return .result()
    }
}

struct SoundWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "AmbientSpace controls"
    static let description = IntentDescription("Choose up to nine sound controls.")

    @Parameter(title: "Position 1") var position1: AmbientWidgetActionEntity?
    @Parameter(title: "Position 2") var position2: AmbientWidgetActionEntity?
    @Parameter(title: "Position 3") var position3: AmbientWidgetActionEntity?
    @Parameter(title: "Position 4") var position4: AmbientWidgetActionEntity?
    @Parameter(title: "Position 5") var position5: AmbientWidgetActionEntity?
    @Parameter(title: "Position 6") var position6: AmbientWidgetActionEntity?
    @Parameter(title: "Position 7") var position7: AmbientWidgetActionEntity?
    @Parameter(title: "Position 8") var position8: AmbientWidgetActionEntity?
    @Parameter(title: "Position 9") var position9: AmbientWidgetActionEntity?

    var positions: [AmbientWidgetActionEntity?] {
        [position1, position2, position3, position4, position5, position6, position7, position8, position9]
    }
}

struct LockScreenSoundConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Lock Screen sound"
    static let description = IntentDescription("Choose the sound shown on the Lock Screen.")

    @Parameter(title: "Sound") var sound: AmbientSoundEntity?
}

#if compiler(>=6.0)
@available(iOS 18.0, *)
struct SelectSoundControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Choose sound"
    @Parameter(title: "Sound") var sound: AmbientSoundEntity?
}
#endif

struct AmbientSpaceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayRandomSoundIntent(),
            phrases: [
                "Play a random sound with \(.applicationName)",
                "Speel een willekeurig geluid af met \(.applicationName)",
            ],
            shortTitle: "Play random sound",
            systemImageName: "shuffle"
        )
        AppShortcut(
            intent: PlaySoundIntent(),
            phrases: [
                "Play \(\.$sound) with \(.applicationName)",
                "Speel \(\.$sound) af met \(.applicationName)",
            ],
            shortTitle: "Play sound",
            systemImageName: "waveform"
        )
    }
}
