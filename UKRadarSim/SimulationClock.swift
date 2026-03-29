import Foundation
import CoreGraphics

final class SimulationClock: ObservableObject {
    @Published private(set) var isRunning = false

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
            self?.simulationEngine?.step(dt: CGFloat(interval))
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
}
