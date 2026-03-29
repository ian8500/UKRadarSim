import Foundation
import CoreGraphics

final class SimulationClock: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published var speedMultiplier: Double = 1.0

    private weak var simulationEngine: SimulationEngine?
    private var timer: Timer?
    private let tickInterval: TimeInterval

    init(simulationEngine: SimulationEngine, tickInterval: TimeInterval = 0.1) {
        self.simulationEngine = simulationEngine
        self.tickInterval = tickInterval
    }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }
        let interval = tickInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let scaledDelta = interval * self.speedMultiplier
            self.simulationEngine?.step(dt: CGFloat(scaledDelta))
            self.elapsedSeconds += scaledDelta
        }
        isRunning = true
    }

    func pause() {
        stop()
    }

    func resume() {
        start()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func reset() {
        elapsedSeconds = 0
    }
}
