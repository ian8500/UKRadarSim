import Foundation
import CoreGraphics

class SimulationEngine: ObservableObject {
    @Published var aircraft: [Aircraft] = []
    @Published var strips: [EFPSStrip] = []

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
                destination: "KK",
                isInbound: true
            ),
            Aircraft(
                callsign: "BAW214",
                trueX: 530,
                trueY: 450,
                displayX: 530,
                displayY: 450,
                heading: 230,
                groundSpeed: 280,
                currentLevel: 40,
                selectedLevel: 50,
                trend: .climb,
                destination: "EGLL",
                isInbound: false
            )
        ]

        strips = aircraft.map { item in
            EFPSStrip(
                aircraftID: item.id,
                callsign: item.callsign,
                aircraftType: item.isInbound ? "A320" : "B738",
                destination: item.destination,
                isInbound: item.isInbound,
                bay: item.isInbound ? .inbound : .outbound,
                selectedLevel: item.selectedLevel,
                currentLevel: item.currentLevel,
                selectedHeading: Int(item.heading),
                selectedSpeed: item.groundSpeed,
                approachType: item.isInbound ? "ILS" : "SID",
                approachCleared: false,
                instructionLog: []
            )
        }
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
            applyStripClearancesToAircraft(at: i, dt: dt)

            let headingRad = CGFloat(aircraft[i].heading * .pi / 180.0)

            // Temporary pixels-per-knot scale for prototype
            let speedScale: CGFloat = 0.02
            let distance = CGFloat(aircraft[i].groundSpeed) * speedScale * dt

            aircraft[i].trueX += cos(headingRad) * distance
            aircraft[i].trueY -= sin(headingRad) * distance

            wrapAircraftIfNeeded(index: i)
            syncStripFromAircraft(at: i)
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

    private func syncStripFromAircraft(at index: Int) {
        let currentAircraft = aircraft[index]
        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == currentAircraft.id }) else {
            return
        }

        strips[stripIndex].selectedLevel = currentAircraft.selectedLevel
        strips[stripIndex].currentLevel = currentAircraft.currentLevel
        strips[stripIndex].selectedHeading = Int(currentAircraft.heading.rounded()) % 360
        strips[stripIndex].selectedSpeed = currentAircraft.groundSpeed
    }

    private func applyStripClearancesToAircraft(at index: Int, dt: CGFloat) {
        let currentAircraft = aircraft[index]
        guard let strip = strips.first(where: { $0.aircraftID == currentAircraft.id }) else {
            return
        }

        var updatedAircraft = currentAircraft

        let turnRateDegreesPerSecond: Double = 2.5
        let maxTurnThisTick = turnRateDegreesPerSecond * Double(dt)
        updatedAircraft.heading = turnToward(
            current: updatedAircraft.heading,
            target: Double(strip.selectedHeading),
            maxDelta: maxTurnThisTick
        )

        let speedChangePerSecond = strip.approachCleared ? 25 : 12
        let maxSpeedDelta = max(1, Int((CGFloat(speedChangePerSecond) * dt).rounded()))
        updatedAircraft.groundSpeed = stepToward(
            current: updatedAircraft.groundSpeed,
            target: strip.selectedSpeed,
            maxStep: maxSpeedDelta
        )

        updatedAircraft.selectedLevel = strip.selectedLevel
        let levelStep = strip.approachCleared ? 2 : 1
        updatedAircraft.currentLevel = stepToward(
            current: updatedAircraft.currentLevel,
            target: strip.selectedLevel,
            maxStep: levelStep
        )

        if updatedAircraft.currentLevel < strip.selectedLevel {
            updatedAircraft.trend = .climb
        } else if updatedAircraft.currentLevel > strip.selectedLevel {
            updatedAircraft.trend = .descend
        } else {
            updatedAircraft.trend = .level
        }

        aircraft[index] = updatedAircraft
    }

    private func stepToward(current: Int, target: Int, maxStep: Int) -> Int {
        guard maxStep > 0 else { return current }
        if current < target {
            return min(current + maxStep, target)
        }
        if current > target {
            return max(current - maxStep, target)
        }
        return current
    }

    private func turnToward(current: Double, target: Double, maxDelta: Double) -> Double {
        guard maxDelta > 0 else { return normalizedHeading(current) }

        let normalizedCurrent = normalizedHeading(current)
        let normalizedTarget = normalizedHeading(target)
        let delta = shortestTurnDelta(from: normalizedCurrent, to: normalizedTarget)

        if abs(delta) <= maxDelta {
            return normalizedTarget
        }

        let stepped = normalizedCurrent + (delta.sign == .minus ? -maxDelta : maxDelta)
        return normalizedHeading(stepped)
    }

    private func shortestTurnDelta(from current: Double, to target: Double) -> Double {
        var delta = target - current
        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }
        return delta
    }

    private func normalizedHeading(_ heading: Double) -> Double {
        let wrapped = heading.truncatingRemainder(dividingBy: 360)
        return wrapped >= 0 ? wrapped : wrapped + 360
    }

    func sendInstruction(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        let strip = strips[stripIndex]
        let phraseology = VoiceReadbackService.shared.buildCAAReadback(for: strip)

        strips[stripIndex].instructionLog.insert(phraseology, at: 0)
        VoiceReadbackService.shared.speakReadback(for: strip)
    }

    func flitStrip(stripID: UUID, to bay: StripBay) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].bay = bay
    }

    func clearForApproach(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].approachCleared = true
        let strip = strips[stripIndex]
        let instruction = "\(strip.callsign) | CLEARED \(strip.approachType) APPROACH"
        strips[stripIndex].instructionLog.insert(instruction, at: 0)
    }
}
