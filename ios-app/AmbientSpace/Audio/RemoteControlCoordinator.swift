import MediaPlayer
import UIKit

@MainActor
final class RemoteControlCoordinator {
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private let bundle: Bundle
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var isInstalled = false

    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?

    init(bundle: Bundle) {
        self.bundle = bundle
    }

    deinit {
        for (command, target) in commandTargets { command.removeTarget(target) }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled { installHandlersIfNeeded() }
        commandCenter.playCommand.isEnabled = enabled
        commandCenter.pauseCommand.isEnabled = enabled
        commandCenter.togglePlayPauseCommand.isEnabled = enabled
        commandCenter.nextTrackCommand.isEnabled = enabled
        commandCenter.previousTrackCommand.isEnabled = enabled

        if !enabled {
            nowPlayingCenter.nowPlayingInfo = nil
            for (command, target) in commandTargets { command.removeTarget(target) }
            commandTargets = []
            isInstalled = false
        }
    }

    func update(track: AudioTrack?, isPlaying: Bool, queue: [AudioTrack]) {
        guard let track else {
            nowPlayingCenter.nowPlayingInfo = nil
            return
        }

        var information: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayTitle,
            MPMediaItemPropertyAlbumTitle: "AmbientSpace",
            MPMediaItemPropertyArtist: track.displaySubtitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackQueueCount: queue.count,
        ]

        if let queueIndex = queue.firstIndex(where: { $0.id == track.id }) {
            information[MPNowPlayingInfoPropertyPlaybackQueueIndex] = queueIndex
        }

        if let coverURL = track.coverURL(in: bundle),
           let image = UIImage(contentsOfFile: coverURL.path) {
            information[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: image.size
            ) { _ in image }
        }

        nowPlayingCenter.nowPlayingInfo = information
    }

    private func installHandlersIfNeeded() {
        guard !isInstalled else {
            return
        }
        isInstalled = true

        commandTargets.append((commandCenter.playCommand, commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        }))
        commandTargets.append((commandCenter.pauseCommand, commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        }))
        commandTargets.append((commandCenter.togglePlayPauseCommand, commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onTogglePlayPause?() }
            return .success
        }))
        commandTargets.append((commandCenter.nextTrackCommand, commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onNext?() }
            return .success
        }))
        commandTargets.append((commandCenter.previousTrackCommand, commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPrevious?() }
            return .success
        }))
    }
}
