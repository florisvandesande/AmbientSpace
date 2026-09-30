import ActivityKit
import Foundation

struct AmbientPlaybackActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let title: String
        let subtitle: String
        let sfSymbol: String?
    }
}
