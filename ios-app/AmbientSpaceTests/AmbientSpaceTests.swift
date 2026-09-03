import XCTest
@testable import AmbientSpace

final class TrackGradientTests: XCTestCase {
    private func rgb(_ hex: String) -> RGBComponents { RGBComponents(hex: hex)! }

    func testHexParsingRejectsNonHexCharacters() {
        XCTAssertEqual(rgb("#aBcD12"), rgb("#ABCD12"))
        for invalid in ["#FFF", "#1234567", "#+12345", "#１２３４５６", "123456"] {
            XCTAssertNil(RGBComponents(hex: invalid))
        }
    }

    func testActiveColorsAreOriginalAndInactiveColorsUseHalfSaturation() {
        let start = rgb("#FF0000")
        let end = rgb("#92FFC0")
        let active = TrackGradient(start: start, end: end, isPlaying: true)
        XCTAssertEqual(active.start, start)
        XCTAssertEqual(active.end, end)
        let inactive = TrackGradient(start: start, end: end, isPlaying: false)
        XCTAssertEqual(inactive.start.red, 0.6063, accuracy: 0.000001)
        XCTAssertEqual(inactive.start.green, 0.1063, accuracy: 0.000001)
        XCTAssertEqual(inactive.start.blue, 0.1063, accuracy: 0.000001)
    }

    func testNeutralColorsAreNotDarkened() {
        for hex in ["#000000", "#777777", "#FFFFFF"] {
            let color = rgb(hex)
            XCTAssertEqual(color.saturated(0.5).red, color.red, accuracy: 0.000001)
            XCTAssertEqual(color.saturated(0.5).green, color.green, accuracy: 0.000001)
            XCTAssertEqual(color.saturated(0.5).blue, color.blue, accuracy: 0.000001)
        }
    }

    func testAllCurrentPalettesPreserveActiveColorsAndHalveInactiveColorDifferences() {
        let palettes = [("#FFD26F", "#3677FF"), ("#FFDB01", "#0E197D"), ("#43CBFF", "#9708CC"), ("#92FFC0", "#002661")]
        for (start, end) in palettes {
            let active = TrackGradient(start: rgb(start), end: rgb(end), isPlaying: true)
            let inactive = TrackGradient(start: rgb(start), end: rgb(end), isPlaying: false)
            XCTAssertEqual(active.start, rgb(start))
            XCTAssertEqual(active.end, rgb(end))
            for (original, muted) in [(active.start, inactive.start), (active.end, inactive.end)] {
                XCTAssertEqual(muted.red - muted.green, (original.red - original.green) * 0.5, accuracy: 0.000001)
                XCTAssertEqual(muted.green - muted.blue, (original.green - original.blue) * 0.5, accuracy: 0.000001)
                let originalGray = original.red * 0.2126 + original.green * 0.7152 + original.blue * 0.0722
                let mutedGray = muted.red * 0.2126 + muted.green * 0.7152 + muted.blue * 0.0722
                XCTAssertEqual(mutedGray, originalGray, accuracy: 0.000001)
            }
        }
    }
}

final class AudioCatalogTests: XCTestCase {
    func testTrackTranslationAndFallback() {
        var track = makeTrack(id: "rain", index: 1)
        track.translations = ["fr": AudioTrackText(title: "Pluie", subtitle: "Douce", description: "Une averse.")]
        XCTAssertEqual(track.localizedText(language: "fr-FR").title, "Pluie")
        XCTAssertEqual(track.localizedText(language: "nl").title, track.title)
        XCTAssertEqual(track.localizedText(language: "de").title, track.title)
    }

    func testEmptyQueueReturnsNoTrack() {
        XCTAssertNil(PlaybackQueue(tracks: []).next(after: nil))
        XCTAssertNil(PlaybackQueue(tracks: []).previous(before: nil))
    }

    func testCatalogDecodesDocumentedContract() throws {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "tracks": [
                {
                  "id": "zomerstorm",
                  "index": 1,
                  "title": "Zomerstorm",
                  "subtitle": "Regen met verre donder",
                  "description": "Rustige regen.",
                  "colorStart": "#18324A",
                  "colorEnd": "#6E8FA8",
                  "audioPath": "audio-files/zomerstorm/audio.m4a",
                  "coverPath": "audio-files/zomerstorm/cover.jpg"
                }
              ]
            }
            """.utf8
        )

        let catalog = try JSONDecoder().decode(AudioCatalog.self, from: data)

        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertEqual(catalog.tracks.first?.id, "zomerstorm")
    }

    func testQueueWrapsInBothDirections() {
        let first = makeTrack(id: "first", index: 1)
        let second = makeTrack(id: "second", index: 2)
        let queue = PlaybackQueue(tracks: [first, second])

        XCTAssertEqual(queue.next(after: second), first)
        XCTAssertEqual(queue.previous(before: first), second)
        XCTAssertEqual(queue.next(after: nil), first)
        XCTAssertEqual(queue.previous(before: nil), second)
    }
}

#if os(iOS)
@MainActor
final class AudioPlaybackControllerTests: XCTestCase {
    func testOutputVolumeNeverReconfiguresTheAudioSession() {
        let engine = FakeAudioEngine()
        let session = FakeAudioSession()
        let controller = AudioPlaybackController(tracks: [], engine: engine, audioSession: session, usesRemoteControls: false)
        let initialCalls = session.configureCount
        controller.setOutputVolume(0.25)
        XCTAssertEqual(engine.outputVolume, 0.25)
        XCTAssertEqual(controller.outputVolume, 0.25)
        XCTAssertEqual(session.configureCount, initialCalls)
        controller.setOutputVolume(2)
        XCTAssertEqual(engine.outputVolume, 1)
        controller.setOutputVolume(-1)
        XCTAssertEqual(engine.outputVolume, 0)
        controller.setOutputVolume(.nan)
        XCTAssertEqual(engine.outputVolume, 0)
    }

    func testInitialStateAndCatalogOrder() {
        let controller = AudioPlaybackController(
            tracks: [makeTrack(id: "b", index: 2), makeTrack(id: "a", index: 1)],
            engine: FakeAudioEngine(), audioSession: FakeAudioSession(), usesRemoteControls: false
        )
        XCTAssertFalse(controller.isPlaying)
        XCTAssertFalse(controller.sleepTimer.isActive)
        XCTAssertEqual(controller.audioMode, .background)
        XCTAssertEqual(controller.tracks.map(\.index), [1, 2])
    }

    func testReplacingTimerDuringFadeRestoresGain() {
        var currentDate = Date(timeIntervalSince1970: 1000)
        let timer = SleepTimerController(now: { currentDate })
        var restores = 0
        timer.onCancelFade = { restores += 1 }
        timer.start(duration: 60)
        currentDate += 50
        timer.refresh()
        timer.start(duration: 120)
        XCTAssertEqual(restores, 1)
        XCTAssertEqual(timer.remainingSeconds, 120)
        timer.cancel()
    }

    func testPlaybackStateAndModeUseInjectedServices() {
        let track = makeTrack(id: "rain", index: 1)
        let engine = FakeAudioEngine()
        let session = FakeAudioSession()
        let controller = AudioPlaybackController(
            tracks: [track],
            engine: engine,
            audioSession: session,
            usesRemoteControls: false
        )

        controller.play(track)
        XCTAssertTrue(controller.isPlaying)
        XCTAssertEqual(controller.currentTrack, track)
        XCTAssertEqual(engine.playCount, 1)

        controller.pause()
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(engine.pauseCount, 1)

        controller.resume()
        XCTAssertTrue(controller.isPlaying)
        XCTAssertEqual(engine.resumeCount, 1)

        controller.setAudioMode(.foreground)
        XCTAssertEqual(controller.audioMode, .foreground)
        XCTAssertEqual(session.lastMode, .foreground)
    }

    func testSleepTimerFadesAndFinishesFromAbsoluteTime() {
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let timer = SleepTimerController(now: { currentDate })
        var fadeDuration: TimeInterval?
        var didFinish = false
        timer.onFadeStart = { fadeDuration = $0 }
        timer.onFinish = { didFinish = true }

        timer.start(duration: 60)
        currentDate = currentDate.addingTimeInterval(46)
        timer.refresh()
        XCTAssertNotNil(fadeDuration)
        XCTAssertEqual(fadeDuration ?? 0, 14, accuracy: 0.01)

        currentDate = currentDate.addingTimeInterval(14)
        timer.refresh()
        XCTAssertTrue(didFinish)
        XCTAssertFalse(timer.isActive)
    }
}

#endif

private func makeTrack(id: String, index: Int) -> AudioTrack {
    AudioTrack(
        id: id,
        index: index,
        title: id.capitalized,
        subtitle: "Subtitel",
        description: "Beschrijving",
        colorStart: "#18324A",
        colorEnd: "#6E8FA8",
        audioPath: "missing-audio.m4a",
        coverPath: "missing-cover.jpg"
    )
}

@MainActor
private final class FakeAudioEngine: AudioEngineType {
    var outputVolume: Float = 1
    func setOutputVolume(_ volume: Float) { outputVolume = volume }
    var playCount = 0
    var pauseCount = 0
    var resumeCount = 0

    func play(url: URL, crossfadeDuration: TimeInterval) throws {
        playCount += 1
    }

    func pause(fadeDuration: TimeInterval) {
        pauseCount += 1
    }

    func resume(fadeDuration: TimeInterval) {
        resumeCount += 1
    }

    func fadeOut(duration: TimeInterval) {}
    func restoreVolume(fadeDuration: TimeInterval) {}
    func stop() {}
}

#if os(iOS)
@MainActor
private final class FakeAudioSession: AudioSessionManaging {
    var lastMode: AudioMode?
    var configureCount = 0

    func configure(mode: AudioMode, activate: Bool) throws {
        lastMode = mode
        configureCount += 1
    }

    func deactivate() throws {}
}
#endif

@MainActor
final class SleepTimerCoreTests: XCTestCase {
    func testAbsoluteDeadlineAndFadeCancellation() {
        var date = Date(timeIntervalSince1970: 1000)
        let timer = SleepTimerController(now: { date })
        var fades: [TimeInterval] = []
        var restores = 0
        var finishes = 0
        timer.onFadeStart = { fades.append($0) }
        timer.onCancelFade = { restores += 1 }
        timer.onFinish = { finishes += 1 }
        timer.start(duration: 60)
        date += 50
        timer.refresh()
        XCTAssertEqual(fades, [10])
        timer.cancel()
        XCTAssertEqual(restores, 1)
        XCTAssertFalse(timer.isActive)
        timer.start(duration: 60)
        date += 70
        timer.refresh()
        XCTAssertEqual(finishes, 1)
        XCTAssertFalse(timer.isActive)
    }

    func testDurationBoundsAndReplacingFadingTimer() {
        var date = Date(timeIntervalSince1970: 1000)
        let timer = SleepTimerController(now: { date })
        var restores = 0
        timer.onCancelFade = { restores += 1 }
        timer.start(duration: 1)
        XCTAssertEqual(timer.remainingSeconds, 60)
        date += 50
        timer.refresh()
        timer.start(duration: 100000)
        XCTAssertEqual(restores, 1)
        XCTAssertEqual(timer.remainingSeconds, 43200)
        timer.cancel()
    }
}

@MainActor
final class DualPlayerAudioEngineTests: XCTestCase {
    private var clock: TimeInterval = 0
    private var players: [FakePlayer] = []

    private func makeEngine() -> DualPlayerAudioEngine {
        DualPlayerAudioEngine(makePlayer: { _ in
            let player = FakePlayer()
            self.players.append(player)
            return player
        }, now: { self.clock }, automaticallyRenders: false)
    }

    func testVolumeAffectsIncomingAndOutgoingTracksWithoutCompounding() throws {
        let engine = makeEngine()
        engine.setOutputVolume(0.4)
        try engine.play(url: URL(fileURLWithPath: "/first"), crossfadeDuration: 6)
        clock = 6
        engine.render(at: clock)
        XCTAssertEqual(players[0].volume, 0.4, accuracy: 0.001)
        try engine.play(url: URL(fileURLWithPath: "/second"), crossfadeDuration: 6)
        clock = 9
        engine.render(at: clock)
        XCTAssertEqual(players[0].volume, 0.2, accuracy: 0.001)
        XCTAssertEqual(players[2].volume, 0.2, accuracy: 0.001)
        engine.setOutputVolume(0.2)
        XCTAssertEqual(players[0].volume, 0.1, accuracy: 0.001)
        XCTAssertEqual(players[2].volume, 0.1, accuracy: 0.001)
    }

    func testLoopCrossfadeUsesAppVolumeOnBothDecks() throws {
        let engine = makeEngine()
        engine.setOutputVolume(0.3)
        try engine.play(url: URL(fileURLWithPath: "/first"), crossfadeDuration: 6)
        clock = 24
        players[0].currentTime = 24
        engine.render(at: clock)
        clock = 27
        engine.render(at: clock)
        XCTAssertEqual(players[0].volume, 0.15, accuracy: 0.001)
        XCTAssertEqual(players[1].volume, 0.15, accuracy: 0.001)
        clock = 30
        engine.render(at: clock)
        XCTAssertFalse(players[0].isPlaying)
        XCTAssertEqual(players[1].volume, 0.3, accuracy: 0.001)
    }

    func testRapidPauseResumeCancelsPendingPause() throws {
        let engine = makeEngine()
        try engine.play(url: URL(fileURLWithPath: "/first"), crossfadeDuration: 6)
        clock = 6
        engine.render(at: clock)
        engine.pause(fadeDuration: 0.35)
        clock = 6.1
        engine.render(at: clock)
        engine.resume(fadeDuration: 0.35)
        clock = 7
        engine.render(at: clock)
        XCTAssertTrue(players[0].isPlaying)
        XCTAssertEqual(players[0].volume, 1, accuracy: 0.001)
    }

    func testTimerGainIsIndependentOfVolumeAndTrackChanges() throws {
        let engine = makeEngine()
        try engine.play(url: URL(fileURLWithPath: "/first"), crossfadeDuration: 6)
        clock = 6
        engine.render(at: clock)
        engine.fadeOut(duration: 15)
        clock = 13.5
        engine.setOutputVolume(0.4)
        XCTAssertEqual(players[0].volume, 0.2, accuracy: 0.001)
        try engine.play(url: URL(fileURLWithPath: "/second"), crossfadeDuration: 6)
        clock = 21
        engine.render(at: clock)
        XCTAssertEqual(players[2].volume, 0, accuracy: 0.001)
        engine.restoreVolume(fadeDuration: 0.35)
        clock = 22
        engine.render(at: clock)
        XCTAssertEqual(players[2].volume, 0.4, accuracy: 0.001)
    }

    func testMuteDoesNotStopPlaybackAndSurvivesTrackChange() throws {
        let engine = makeEngine()
        engine.setOutputVolume(0)
        try engine.play(url: URL(fileURLWithPath: "/first"), crossfadeDuration: 6)
        clock = 6
        engine.render(at: clock)
        try engine.play(url: URL(fileURLWithPath: "/second"), crossfadeDuration: 6)
        clock = 12
        engine.render(at: clock)
        XCTAssertTrue(players[2].isPlaying)
        XCTAssertEqual(players[2].volume, 0)
    }
}

private final class FakePlayer: AudioPlayerType {
    var duration: TimeInterval = 30
    var currentTime: TimeInterval = 0
    var volume: Float = 1
    var isPlaying = false
    func prepareToPlay() -> Bool { true }
    func play() -> Bool { isPlaying = true; return true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false }
}
