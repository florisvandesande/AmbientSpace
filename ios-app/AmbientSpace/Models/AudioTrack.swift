import Foundation

struct AudioTrack: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let index: Int
    let title: String
    let subtitle: String
    let description: String
    let colorStart: String
    let colorEnd: String
    let audioPath: String
    let coverPath: String
    var translations: [String: AudioTrackText]?

    var displayTitle: String { localizedText().title }
    var displaySubtitle: String { localizedText().subtitle }
    var displayDescription: String { localizedText().description }

    func localizedText(language: String = Bundle.main.preferredLocalizations.first ?? "en") -> AudioTrackText {
        let languageCode = language.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init) ?? language
        return translations?[languageCode] ?? AudioTrackText(title: title, subtitle: subtitle, description: description)
    }

    func audioURL(in bundle: Bundle) -> URL? {
        bundle.resourceURL?.appendingPathComponent(audioPath)
    }

    func coverURL(in bundle: Bundle) -> URL? {
        bundle.resourceURL?.appendingPathComponent(coverPath)
    }
}

struct AudioTrackText: Codable, Equatable, Sendable {
    let title: String
    let subtitle: String
    let description: String
}
