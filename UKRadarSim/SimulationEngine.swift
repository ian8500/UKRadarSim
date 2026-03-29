import Foundation
import CoreGraphics

class SimulationEngine: ObservableObject {
    @Published var aircraft: [Aircraft] = []

    private var movementTimer: Timer?
    private var radarTimer: Timer?

    init() {
        setupTestAircraft()
        start()
    }

    deinit {
        movementTimer?.invalidate()
        radarTimer?.invalidate()
    }

    private func setupTestAircraft() {
        aircraft = [
            Aircraft(
                callsign: "EZY15WY",
                trueX: 240,
                trueY: 310,
                displayX: 240,
                displayY: 310,
                heading: 45,
                groundSpeed: 360,
                currentLevel: 107,
                selectedLevel: 80,
                trend: .descend,
                destination: "KK"
            )
        ]
    }

    private func start() {
        movementTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAircraftTruth()
        }

        radarTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            self?.updateRadarDisplayedPositions()
        }
    }

    private func updateAircraftTruth() {
        let dt: CGFloat = 0.1

        for i in aircraft.indices {
            let headingRad = CGFloat(aircraft[i].heading * .pi / 180.0)

            // Temporary pixels-per-knot scale for prototype
            let speedScale: CGFloat = 0.02
            let distance = CGFloat(aircraft[i].groundSpeed) * speedScale * dt

            aircraft[i].trueX += cos(headingRad) * distance
            aircraft[i].trueY -= sin(headingRad) * distance

            wrapAircraftIfNeeded(index: i)
        }
    }

    private func updateRadarDisplayedPositions() {
        for i in aircraft.indices {
            aircraft[i].displayX = aircraft[i].trueX
            aircraft[i].displayY = aircraft[i].trueY
        }
    }

    private func wrapAircraftIfNeeded(index: Int) {
        if aircraft[index].trueX > 1100 { aircraft[index].trueX = -100 }
        if aircraft[index].trueX < -100 { aircraft[index].trueX = 1100 }
        if aircraft[index].trueY > 900 { aircraft[index].trueY = -100 }
        if aircraft[index].trueY < -100 { aircraft[index].trueY = 900 }
    }
}
