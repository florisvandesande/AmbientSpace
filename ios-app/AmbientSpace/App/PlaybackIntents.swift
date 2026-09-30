import AppIntents
import Foundation

struct AmbientSoundEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Ambient sound")
    static let defaultQuery = AmbientSoundQuery()

    let id: String
    let title: String
    let subtitle: String
    let sfSymbol: String?

    init(id: String, title: String, subtitle: String, sfSymbol: String?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sfSymbol = sfSymbol
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
        sfSymbol = track.displaySFSymbol
    }
}

struct AmbientSoundQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AmbientSoundEntity] {
        #if WIDGET_EXTENSION
        return []
        #else
        await MainActor.run {
            AudioPlaybackController.shared.tracks
                .filter { identifiers.contains($0.id) }
                .map(AmbientSoundEntity.init)
        }
        #endif
    }

    func suggestedEntities() async throws -> [AmbientSoundEntity] {
        #if WIDGET_EXTENSION
        return []
        #else
        await MainActor.run {
            AudioPlaybackController.shared.tracks.map(AmbientSoundEntity.init)
        }
        #endif
    }
}

struct PlayRandomSoundIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play a random sound"
    static let description = IntentDescription("Starts a random AmbientSpace sound.")

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await MainActor.run {
            let playback = AudioPlaybackController.shared
            guard let track = playback.tracks.randomElement() else { return }
            playback.play(track)
        }
        #endif
        return .result()
    }
}

struct PlaySoundIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play sound"
    static let description = IntentDescription("Starts the selected AmbientSpace sound.")

    @Parameter(title: "Sound")
    var sound: AmbientSoundEntity

    init() {}

    init(sound: AmbientSoundEntity) {
        self.sound = sound
    }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await MainActor.run {
            let playback = AudioPlaybackController.shared
            guard let track = playback.tracks.first(where: { $0.id == sound.id }) else { return }
            playback.play(track)
        }
        #endif
        return .result()
    }
}

#if compiler(>=6.0)
@available(iOS 18.0, *)
struct SelectSoundControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Choose sound"

    @Parameter(title: "Sound")
    var sound: AmbientSoundEntity?
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
            systemImageName: "play.fill"
        )
    }
}
