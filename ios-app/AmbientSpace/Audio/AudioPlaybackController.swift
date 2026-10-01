import AVFoundation
import Foundation
import OSLog
import WidgetKit

@MainActor
final class AudioPlaybackController: ObservableObject {
    static let shared = AudioPlaybackController()
    static let crossfadeDuration: TimeInterval = 6
    static let pauseFadeDuration: TimeInterval = 0.35

    @Published private(set) var tracks: [AudioTrack] = []
    @Published private(set) var currentTrack: AudioTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var audioMode: AudioMode = .background
    @Published private(set) var outputVolume: Float = 1
    @Published var errorMessage: String?

    let sleepTimer: SleepTimerController

    private let bundle: Bundle
    private let engine: AudioEngineType
    private let audioSession: AudioSessionManaging
    private let remoteControl: RemoteControlCoordinator?
    private let liveActivity: LiveActivityCoordinator?
    private let widgetStateStore: PlaybackWidgetStateStore?
    private let logger = Logger(
        subsystem: "com.florisvandesande.AmbientSpace",
        category: "AudioPlayback"
    )
    private var notificationTokens: [NSObjectProtocol] = []
    private var engineHasTrack = false
    private var wasPlayingBeforeInterruption = false

    init(
        bundle: Bundle = .main,
        tracks suppliedTracks: [AudioTrack]? = nil,
        engine suppliedEngine: AudioEngineType? = nil,
        audioSession suppliedAudioSession: AudioSessionManaging? = nil,
        now: @escaping () -> Date = Date.init,
        usesRemoteControls: Bool = true
    ) {
        self.bundle = bundle
        engine = suppliedEngine ?? DualPlayerAudioEngine()
        audioSession = suppliedAudioSession ?? AudioSessionManager()
        sleepTimer = SleepTimerController(now: now)
        remoteControl = usesRemoteControls ? RemoteControlCoordinator(bundle: bundle) : nil
        liveActivity = usesRemoteControls ? LiveActivityCoordinator() : nil
        widgetStateStore = usesRemoteControls ? PlaybackWidgetStateStore() : nil

        if let suppliedTracks {
            tracks = suppliedTracks.sorted { $0.index < $1.index }
        } else {
            do {
                tracks = try AudioCatalogLoader(bundle: bundle).load().tracks
            } catch {
                errorMessage = error.localizedDescription
                logger.error("Audio catalog load failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        configureSleepTimerCallbacks()
        configureRemoteControls()
        observeAudioEvents()
        publishWidgetState()

        do {
            try audioSession.configure(mode: .background, activate: false)
        } catch {
            logger.error("Initial audio session configuration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    deinit {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func togglePlayback(for track: AudioTrack) {
        if currentTrack?.id == track.id {
            isPlaying ? pause() : resume()
        } else {
            play(track)
        }
    }

    func setOutputVolume(_ volume: Float) {
        outputVolume = volume.isFinite ? min(max(volume, 0), 1) : 0
        engine.setOutputVolume(outputVolume)
    }

    func play(_ track: AudioTrack) {
        guard let audioURL = track.audioURL(in: bundle) else {
            presentError(String(localized: "The audio file for ‘\(track.displayTitle)’ is missing. Rebuild the app."))
            return
        }

        do {
            try audioSession.configure(mode: audioMode, activate: true)
            try engine.play(url: audioURL, crossfadeDuration: Self.crossfadeDuration)
            currentTrack = track
            isPlaying = true
            engineHasTrack = true
            refreshRemoteInformation()
            refreshLiveActivity()
            publishWidgetState()
        } catch let error as AudioEngineError {
            presentError(error.localizedDescription)
            logger.error("Track playback failed: \(error.localizedDescription, privacy: .public)")
        } catch {
            presentError(String(localized: "The audio file for ‘\(track.displayTitle)’ could not be opened."))
            logger.error("Track playback failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func pause() {
        wasPlayingBeforeInterruption = false
        guard isPlaying else {
            return
        }
        engine.pause(fadeDuration: Self.pauseFadeDuration)
        isPlaying = false
        refreshRemoteInformation()
        refreshLiveActivity()
        publishWidgetState()
    }

    func resume() {
        guard !isPlaying else {
            return
        }
        guard let currentTrack else {
            if let firstTrack = tracks.first {
                play(firstTrack)
            }
            return
        }

        if !engineHasTrack {
            play(currentTrack)
            return
        }

        do {
            try audioSession.configure(mode: audioMode, activate: true)
            engine.resume(fadeDuration: Self.pauseFadeDuration)
            isPlaying = true
            refreshRemoteInformation()
            refreshLiveActivity()
            publishWidgetState()
        } catch {
            presentError(String(localized: "Playback could not resume. Try again."))
            logger.error("Resume failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func playNext() {
        guard let nextTrack = PlaybackQueue(tracks: tracks).next(after: currentTrack) else {
            return
        }
        play(nextTrack)
    }

    func playPrevious() {
        guard let previousTrack = PlaybackQueue(tracks: tracks).previous(before: currentTrack) else {
            return
        }
        play(previousTrack)
    }

    func setAudioMode(_ newMode: AudioMode) {
        guard newMode != audioMode else {
            return
        }
        let previousMode = audioMode
        do {
            try audioSession.configure(mode: newMode, activate: isPlaying)
            audioMode = newMode
            remoteControl?.setEnabled(newMode == .foreground)
            refreshRemoteInformation()
        } catch {
            audioMode = previousMode
            try? audioSession.configure(mode: previousMode, activate: isPlaying)
            presentError(String(localized: "The audio mode could not be changed. Try again."))
            logger.error("Audio mode change failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func configureSleepTimerCallbacks() {
        sleepTimer.onFadeStart = { [weak self] duration in
            guard let self else { return }
            self.engine.fadeOut(duration: max(duration, 0.01))
        }
        sleepTimer.onFinish = { [weak self] in
            self?.stopAfterSleepTimer()
        }
        sleepTimer.onCancelFade = { [weak self] in
            self?.engine.restoreVolume(fadeDuration: Self.pauseFadeDuration)
        }
    }

    private func configureRemoteControls() {
        remoteControl?.onPlay = { [weak self] in self?.resume() }
        remoteControl?.onPause = { [weak self] in self?.pause() }
        remoteControl?.onTogglePlayPause = { [weak self] in
            guard let self else { return }
            self.isPlaying ? self.pause() : self.resume()
        }
        remoteControl?.onNext = { [weak self] in self?.playNext() }
        remoteControl?.onPrevious = { [weak self] in self?.playPrevious() }
        remoteControl?.setEnabled(false)
    }

    private func observeAudioEvents() {
        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleInterruption(notification)
                }
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleRouteChange(notification)
                }
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return
        }

        switch type {
        case .began:
            let shouldResumeLater = isPlaying
            pause()
            wasPlayingBeforeInterruption = shouldResumeLater
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) {
                resume()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
              reason == .oldDeviceUnavailable
        else {
            return
        }
        pause()
    }

    private func stopAfterSleepTimer() {
        engine.stop()
        engineHasTrack = false
        isPlaying = false
        refreshRemoteInformation()
        refreshLiveActivity()
        publishWidgetState()
        do {
            try audioSession.deactivate()
        } catch {
            logger.error("Audio session deactivation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshRemoteInformation() {
        guard audioMode == .foreground else {
            remoteControl?.update(track: nil, isPlaying: false, queue: tracks)
            return
        }
        remoteControl?.update(track: currentTrack, isPlaying: isPlaying, queue: tracks)
    }

    private func refreshLiveActivity() {
        liveActivity?.update(track: currentTrack, isPlaying: isPlaying)
    }

    private func publishWidgetState() {
        guard let widgetStateStore else { return }
        widgetStateStore.save(
            PlaybackWidgetState(currentTrackID: currentTrack?.id, isPlaying: isPlaying)
        )
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
    }
}
