import Foundation
import CoreGraphics

protocol SimulationStepping: AnyObject {
    func step(dt: CGFloat)
}

extension SimulationEngine: SimulationStepping {}

final class SimulationClock: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published var speedMultiplier: Double = 1.0

    private weak var simulationStepper: (any SimulationStepping)?
    private var timer: Timer?
    private let tickInterval: TimeInterval
    private let maximumFrameDelta: TimeInterval
    private let nowProvider: () -> TimeInterval
    private var lastTickTime: TimeInterval?

    init(
        simulationEngine: SimulationEngine,
        tickInterval: TimeInterval = 0.1,
        maximumFrameDelta: TimeInterval = 0.25,
        nowProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.simulationStepper = simulationEngine
        self.tickInterval = tickInterval
        self.maximumFrameDelta = maximumFrameDelta
        self.nowProvider = nowProvider
    }

    init(
        simulationStepper: any SimulationStepping,
        tickInterval: TimeInterval = 0.1,
        maximumFrameDelta: TimeInterval = 0.25,
        nowProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.simulationStepper = simulationStepper
        self.tickInterval = tickInterval
        self.maximumFrameDelta = maximumFrameDelta
        self.nowProvider = nowProvider
    }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }
        lastTickTime = nowProvider()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.advanceFrame(to: self.nowProvider())
        }
        isRunning = true
    }

    func pause() {
        stop()
    }

    func resume() {
        start()
    }

    func advanceFrame(to currentTime: TimeInterval) {
        guard isRunning else { return }
        guard let lastTickTime else {
            self.lastTickTime = currentTime
            return
        }

        let rawDelta = max(0, currentTime - lastTickTime)
        self.lastTickTime = currentTime

        let clampedDelta = min(rawDelta, maximumFrameDelta)
        let scaledDelta = clampedDelta * speedMultiplier
        guard scaledDelta > 0 else { return }

        simulationStepper?.step(dt: CGFloat(scaledDelta))
        elapsedSeconds += scaledDelta
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        lastTickTime = nil
        isRunning = false
    }

    func reset() {
        elapsedSeconds = 0
    }
}
