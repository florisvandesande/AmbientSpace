import ActivityKit
import Foundation
import OSLog

@MainActor
final class LiveActivityCoordinator {
    private let logger = Logger(
        subsystem: "com.florisvandesande.AmbientSpace",
        category: "LiveActivity"
    )
    private var activity: Activity<AmbientPlaybackActivityAttributes>?

    func update(track: AudioTrack?, isPlaying: Bool) {
        guard isPlaying, let track else {
            end()
            return
        }

        let content = ActivityContent(
            state: AmbientPlaybackActivityAttributes.ContentState(
                title: track.displayTitle,
                subtitle: track.displaySubtitle,
                sfSymbol: track.displaySFSymbol
            ),
            staleDate: nil
        )

        if let activity {
            Task { await activity.update(content) }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        do {
            activity = try Activity.request(
                attributes: AmbientPlaybackActivityAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            logger.error("Live Activity could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func end() {
        guard let activity else {
            return
        }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
