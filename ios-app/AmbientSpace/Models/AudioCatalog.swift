import Foundation

struct AudioCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let tracks: [AudioTrack]
}

enum AudioCatalogError: LocalizedError {
    case missingCatalog
    case unsupportedSchema(Int)
    case unreadableCatalog(Error)

    var errorDescription: String? {
        switch self {
        case .missingCatalog:
            return String(localized: "The audio catalog is missing. Rebuild the app in Xcode.")
        case let .unsupportedSchema(version):
            return String(localized: "Audio catalog version \(version) is not supported.")
        case .unreadableCatalog:
            return String(localized: "The audio catalog could not be read. Check the audio folders and rebuild.")
        }
    }
}

struct AudioCatalogLoader {
    let bundle: Bundle

    func load() throws -> AudioCatalog {
        guard let catalogURL = bundle.resourceURL?
            .appendingPathComponent("audio-files")
            .appendingPathComponent("catalog.json"),
            FileManager.default.fileExists(atPath: catalogURL.path)
        else {
            throw AudioCatalogError.missingCatalog
        }

        do {
            let data = try Data(contentsOf: catalogURL)
            let catalog = try JSONDecoder().decode(AudioCatalog.self, from: data)
            guard catalog.schemaVersion == 1 else {
                throw AudioCatalogError.unsupportedSchema(catalog.schemaVersion)
            }
            return AudioCatalog(
                schemaVersion: catalog.schemaVersion,
                tracks: catalog.tracks.sorted { first, second in
                    if first.index == second.index {
                        return first.id < second.id
                    }
                    return first.index < second.index
                }
            )
        } catch let error as AudioCatalogError {
            throw error
        } catch {
            throw AudioCatalogError.unreadableCatalog(error)
        }
    }
}

struct PlaybackQueue {
    let tracks: [AudioTrack]

    func next(after currentTrack: AudioTrack?) -> AudioTrack? {
        adjacentTrack(to: currentTrack, offset: 1)
    }

    func previous(before currentTrack: AudioTrack?) -> AudioTrack? {
        adjacentTrack(to: currentTrack, offset: -1)
    }

    private func adjacentTrack(to currentTrack: AudioTrack?, offset: Int) -> AudioTrack? {
        guard !tracks.isEmpty else {
            return nil
        }
        guard let currentTrack,
              let currentIndex = tracks.firstIndex(where: { $0.id == currentTrack.id })
        else {
            return offset > 0 ? tracks.first : tracks.last
        }

        let candidate = (currentIndex + offset + tracks.count) % tracks.count
        return tracks[candidate]
    }
}
