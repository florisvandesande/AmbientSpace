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
    let sfSymbol: String?
    var translations: [String: AudioTrackText]?

    var displayTitle: String { localizedText().title }
    var displaySubtitle: String { localizedText().subtitle }
    var displayDescription: String { localizedText().description }

    /// Empty JSON values deliberately behave like a missing symbol.
    var displaySFSymbol: String? {
        guard let sfSymbol = sfSymbol?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sfSymbol.isEmpty
        else {
            return nil
        }
        return sfSymbol
    }

    func localizedText(language: String = Bundle.main.preferredLocalizations.first ?? "en") -> AudioTrackText {
        let normalizedLanguage = language.replacingOccurrences(of: "_", with: "-")
        let languageCode = normalizedLanguage.split(separator: "-").first.map(String.init) ?? normalizedLanguage
        return translations?[normalizedLanguage]
            ?? translations?[languageCode]
            ?? AudioTrackText(title: title, subtitle: subtitle, description: description)
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
