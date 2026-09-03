import AVFoundation
import Foundation

enum AudioEngineError: LocalizedError {
    case trackTooShort(duration: TimeInterval)
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case let .trackTooShort(duration):
            return String(localized: "This recording is only \(Int(duration.rounded())) seconds long. Use at least twelve seconds.")
        case .playbackFailed:
            return String(localized: "The recording could not be played. Check the audio file and try again.")
        }
    }
}

@MainActor
protocol AudioEngineType: AnyObject {
    func setOutputVolume(_ volume: Float)
    func play(url: URL, crossfadeDuration: TimeInterval) throws
    func pause(fadeDuration: TimeInterval)
    func resume(fadeDuration: TimeInterval)
    func fadeOut(duration: TimeInterval)
    func restoreVolume(fadeDuration: TimeInterval)
    func stop()
}

// A small adapter boundary makes crossfades testable without producing sound.
protocol AudioPlayerType: AnyObject {
    var duration: TimeInterval { get }
    var currentTime: TimeInterval { get set }
    var volume: Float { get set }
    var isPlaying: Bool { get }
    @discardableResult func prepareToPlay() -> Bool
    @discardableResult func play() -> Bool
    func pause()
    func stop()
}

extension AVAudioPlayer: AudioPlayerType {}

@MainActor
final class DualPlayerAudioEngine: AudioEngineType {
    private struct DeckTransition {
        let fromIndex: Int
        let toIndex: Int
        let startTime: TimeInterval
        let duration: TimeInterval
    }

    private struct GainRamp {
        let startValue: Float
        let targetValue: Float
        let startTime: TimeInterval
        let duration: TimeInterval
        let completion: (() -> Void)?
    }

    private struct OutgoingGroup {
        let players: [AudioPlayerType]
        let initialGains: [Float]
        let startTime: TimeInterval
        let duration: TimeInterval
    }

    private let minimumTrackDuration: TimeInterval = 12
    private let renderInterval: TimeInterval = 0.05

    private let makePlayer: (URL) throws -> AudioPlayerType
    private let now: () -> TimeInterval
    private let automaticallyRenders: Bool
    private var players: [AudioPlayerType] = []
    private var activeIndex = 0
    private var transition: DeckTransition?
    private var outgoingGroups: [OutgoingGroup] = []
    private var crossfadeDuration: TimeInterval = 6
    private var groupGain: Float = 1
    private var groupRamp: GainRamp?
    private var masterGain: Float = 1
    private var masterRamp: GainRamp?
    private var sleepGain: Float = 1
    private var sleepRamp: GainRamp?
    private var outputVolume: Float = 1
    private var pauseRequested = false
    private var isPaused = false
    private var renderTimer: DispatchSourceTimer?

    init(
        makePlayer: @escaping (URL) throws -> AudioPlayerType = { try AVAudioPlayer(contentsOf: $0) },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        automaticallyRenders: Bool = true
    ) {
        self.makePlayer = makePlayer
        self.now = now
        self.automaticallyRenders = automaticallyRenders
    }

    deinit {
        renderTimer?.cancel()
    }

    func setOutputVolume(_ volume: Float) {
        outputVolume = volume.isFinite ? min(max(volume, 0), 1) : 0
        render(at: now())
    }

    func play(url: URL, crossfadeDuration: TimeInterval) throws {
        let firstPlayer = try makePlayer(url)
        let secondPlayer = try makePlayer(url)
        guard firstPlayer.duration >= minimumTrackDuration else {
            throw AudioEngineError.trackTooShort(duration: firstPlayer.duration)
        }

        guard firstPlayer.prepareToPlay(), secondPlayer.prepareToPlay() else {
            throw AudioEngineError.playbackFailed
        }
        firstPlayer.volume = 0
        secondPlayer.volume = 0

        guard firstPlayer.play() else {
            throw AudioEngineError.playbackFailed
        }
        let now = self.now()
        render(at: now)
        if !players.isEmpty, !isPaused {
            outgoingGroups.append(
                OutgoingGroup(
                    players: players,
                    initialGains: currentGains(at: now).map { $0 * groupGain },
                    startTime: now,
                    duration: crossfadeDuration
                )
            )
        }

        players = [firstPlayer, secondPlayer]
        activeIndex = 0
        transition = nil
        self.crossfadeDuration = crossfadeDuration
        groupGain = 0
        groupRamp = GainRamp(
            startValue: 0,
            targetValue: 1,
            startTime: now,
            duration: crossfadeDuration,
            completion: nil
        )
        masterGain = 1
        masterRamp = nil
        isPaused = false
        pauseRequested = false
        ensureRenderTimer()
        render(at: now)
    }

    func pause(fadeDuration: TimeInterval) {
        guard !players.isEmpty, !isPaused else {
            return
        }
        pauseRequested = true
        setMasterGain(0, duration: fadeDuration) { [weak self] in
            self?.finishPause()
        }
    }

    func resume(fadeDuration: TimeInterval) {
        guard !players.isEmpty, isPaused || pauseRequested else {
            return
        }
        // A second tap during the pause fade cancels its pending completion.
        if isPaused {
            players[activeIndex].play()
            masterGain = 0
        }
        isPaused = false
        pauseRequested = false
        setMasterGain(1, duration: fadeDuration)
        ensureRenderTimer()
    }

    func fadeOut(duration: TimeInterval) {
        guard !players.isEmpty else {
            return
        }
        setSleepGain(0, duration: duration)
    }

    func restoreVolume(fadeDuration: TimeInterval) {
        guard !players.isEmpty else {
            return
        }
        setSleepGain(1, duration: fadeDuration)
    }

    func stop() {
        players.forEach { $0.stop() }
        outgoingGroups.flatMap(\.players).forEach { $0.stop() }
        players = []
        outgoingGroups = []
        transition = nil
        groupRamp = nil
        masterRamp = nil
        sleepRamp = nil
        groupGain = 1
        masterGain = 1
        sleepGain = 1
        pauseRequested = false
        isPaused = false
        renderTimer?.cancel()
        renderTimer = nil
    }

    private func ensureRenderTimer() {
        guard automaticallyRenders, renderTimer == nil else {
            return
        }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: renderInterval, leeway: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            if #available(macOS 14, *) {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.render(at: self.now())
                }
            } else {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.render(at: self.now())
                }
            }
        }
        timer.resume()
        renderTimer = timer
    }

    func render(at now: TimeInterval) {
        updateMasterGain(at: now)
        updateSleepGain(at: now)
        updateGroupGain(at: now)
        updateOutgoingGroups(at: now)

        guard !players.isEmpty else {
            return
        }

        if !isPaused, !pauseRequested {
            updateLoopTransition(at: now)
        }
        applyCurrentVolumes(at: now)
    }

    private func updateLoopTransition(at now: TimeInterval) {
        let activePlayer = players[activeIndex]

        if transition == nil {
            let remaining = activePlayer.duration - activePlayer.currentTime
            if remaining <= crossfadeDuration || !activePlayer.isPlaying {
                let standbyIndex = activeIndex == 0 ? 1 : 0
                let standbyPlayer = players[standbyIndex]
                standbyPlayer.stop()
                standbyPlayer.currentTime = 0
                standbyPlayer.volume = 0
                standbyPlayer.prepareToPlay()
                standbyPlayer.play()
                transition = DeckTransition(
                    fromIndex: activeIndex,
                    toIndex: standbyIndex,
                    startTime: now,
                    duration: crossfadeDuration
                )
            }
        }

        guard let transition else {
            return
        }
        let progress = normalizedProgress(
            now: now,
            start: transition.startTime,
            duration: transition.duration
        )
        if progress >= 1 {
            players[transition.fromIndex].stop()
            players[transition.fromIndex].currentTime = 0
            activeIndex = transition.toIndex
            self.transition = nil
        }
    }

    private func currentGains(at now: TimeInterval) -> [Float] {
        var baseGains: [Float] = [0, 0]
        if let transition {
            let progress = Float(
                normalizedProgress(
                    now: now,
                    start: transition.startTime,
                    duration: transition.duration
                )
            )
            baseGains[transition.fromIndex] = 1 - progress
            baseGains[transition.toIndex] = progress
        } else {
            baseGains[activeIndex] = 1
        }

        return baseGains
    }

    private func applyCurrentVolumes(at now: TimeInterval) {
        let gains = currentGains(at: now)
        for index in players.indices {
            players[index].volume = gains[index] * groupGain * masterGain * sleepGain * outputVolume
        }
    }

    private func updateOutgoingGroups(at now: TimeInterval) {
        outgoingGroups = outgoingGroups.filter { group in
            let progress = Float(
                normalizedProgress(now: now, start: group.startTime, duration: group.duration)
            )
            let remainingGain = 1 - progress
            for (index, player) in group.players.enumerated() {
                player.volume = group.initialGains[index] * remainingGain * masterGain * sleepGain * outputVolume
            }
            if progress >= 1 {
                group.players.forEach { $0.stop() }
                return false
            }
            return true
        }
    }

    private func updateGroupGain(at now: TimeInterval) {
        guard let ramp = groupRamp else {
            return
        }
        groupGain = interpolatedGain(for: ramp, at: now)
        if now >= ramp.startTime + ramp.duration {
            groupGain = ramp.targetValue
            groupRamp = nil
            ramp.completion?()
        }
    }

    private func updateMasterGain(at now: TimeInterval) {
        guard let ramp = masterRamp else {
            return
        }
        masterGain = interpolatedGain(for: ramp, at: now)
        if now >= ramp.startTime + ramp.duration {
            masterGain = ramp.targetValue
            masterRamp = nil
            ramp.completion?()
        }
    }

    private func setMasterGain(
        _ target: Float,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        let now = self.now()
        masterRamp = GainRamp(
            startValue: masterGain,
            targetValue: target,
            startTime: now,
            duration: max(duration, 0.01),
            completion: completion
        )
        ensureRenderTimer()
    }

    private func setSleepGain(_ target: Float, duration: TimeInterval) {
        updateSleepGain(at: now())
        sleepRamp = GainRamp(
            startValue: sleepGain, targetValue: target, startTime: now(),
            duration: max(duration, 0.01), completion: nil
        )
        ensureRenderTimer()
    }

    private func updateSleepGain(at now: TimeInterval) {
        guard let ramp = sleepRamp else { return }
        sleepGain = interpolatedGain(for: ramp, at: now)
        if now >= ramp.startTime + ramp.duration {
            sleepGain = ramp.targetValue
            sleepRamp = nil
        }
    }

    private func finishPause() {
        guard !players.isEmpty else {
            return
        }

        if let transition {
            let progress = normalizedProgress(
                now: now(),
                start: transition.startTime,
                duration: transition.duration
            )
            activeIndex = progress >= 0.5 ? transition.toIndex : transition.fromIndex
        }

        for index in players.indices {
            if index == activeIndex {
                players[index].pause()
            } else {
                players[index].stop()
                players[index].currentTime = 0
            }
        }
        transition = nil
        outgoingGroups.flatMap(\.players).forEach { $0.stop() }
        outgoingGroups = []
        isPaused = true
        pauseRequested = false
        renderTimer?.cancel()
        renderTimer = nil
    }

    private func interpolatedGain(for ramp: GainRamp, at now: TimeInterval) -> Float {
        let progress = Float(
            normalizedProgress(now: now, start: ramp.startTime, duration: ramp.duration)
        )
        return ramp.startValue + ((ramp.targetValue - ramp.startValue) * progress)
    }

    private func normalizedProgress(
        now: TimeInterval,
        start: TimeInterval,
        duration: TimeInterval
    ) -> Double {
        min(max((now - start) / max(duration, 0.01), 0), 1)
    }
}
