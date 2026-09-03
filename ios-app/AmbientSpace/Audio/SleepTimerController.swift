import Foundation

@MainActor
final class SleepTimerController: ObservableObject {
    static let fadeDuration: TimeInterval = 15

    @Published private(set) var endDate: Date?
    @Published private(set) var remainingSeconds: TimeInterval = 0

    var onFadeStart: ((TimeInterval) -> Void)?
    var onFinish: (() -> Void)?
    var onCancelFade: (() -> Void)?

    private let now: () -> Date
    private var timer: Timer?
    private var hasStartedFade = false

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    deinit {
        timer?.invalidate()
    }

    var isActive: Bool {
        endDate != nil
    }

    func start(duration: TimeInterval) {
        guard duration.isFinite else { return }
        if hasStartedFade { onCancelFade?() }
        let boundedDuration = min(max(duration, 60), 12 * 60 * 60)
        endDate = now().addingTimeInterval(boundedDuration)
        remainingSeconds = boundedDuration
        hasStartedFade = false
        startTimer()
        refresh()
    }

    func cancel() {
        let shouldRestoreVolume = hasStartedFade
        timer?.invalidate()
        timer = nil
        endDate = nil
        remainingSeconds = 0
        hasStartedFade = false
        if shouldRestoreVolume {
            onCancelFade?()
        }
    }

    func refresh() {
        guard let endDate else {
            remainingSeconds = 0
            return
        }

        remainingSeconds = max(0, endDate.timeIntervalSince(now()))

        if remainingSeconds <= Self.fadeDuration, !hasStartedFade {
            hasStartedFade = true
            onFadeStart?(remainingSeconds)
        }

        if remainingSeconds <= 0 {
            timer?.invalidate()
            timer = nil
            self.endDate = nil
            hasStartedFade = false
            onFinish?()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            if #available(macOS 14, *) {
                MainActor.assumeIsolated { self?.refresh() }
            } else {
                Task { @MainActor [weak self] in self?.refresh() }
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
