import Foundation
import CoreGraphics

class SimulationEngine: ObservableObject {
    @Published var aircraft: [Aircraft] = []
    @Published var strips: [EFPSStrip] = []

    private var movementTimer: Timer?
    private var radarTimer: Timer?

    private let touchdownPoint = CGPoint(x: 790, y: 232)
    private let finalApproachHeading = 29.0
    private let pixelsPerNauticalMile: CGFloat = 70

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
                currentLevel: 20,
                selectedLevel: 20,
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
                bay: item.isInbound ? .inbound : .departed,
                selectedLevel: item.selectedLevel,
                currentLevel: item.currentLevel,
                selectedHeading: Int(item.heading),
                selectedSpeed: item.groundSpeed,
                approachType: item.isInbound ? "ILS" : "SID",
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
            updateILSAutopilotIfNeeded(index: i, dt: dt)

            let headingRad = CGFloat(aircraft[i].heading * .pi / 180.0)

            // Temporary pixels-per-knot scale for prototype
            let speedScale: CGFloat = 0.02
            let distance = CGFloat(aircraft[i].groundSpeed) * speedScale * dt

            aircraft[i].trueX += cos(headingRad) * distance
            aircraft[i].trueY -= sin(headingRad) * distance

            wrapAircraftIfNeeded(index: i)
            syncStripFromAircraft(at: i)
        }

        removeLandedAircraft()
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

        strips[stripIndex].currentLevel = currentAircraft.currentLevel
    }

    private func updateILSAutopilotIfNeeded(index: Int, dt: CGFloat) {
        guard aircraft[index].approachMode == .ilsLocked else { return }

        let targetHeading = headingToTouchdown(from: aircraft[index])
        let turnRatePerSecond = 5.0
        let maxTurn = turnRatePerSecond * Double(dt)
        aircraft[index].heading = turnToward(
            current: aircraft[index].heading,
            target: targetHeading,
            maxStep: maxTurn
        )

        let distance = distanceToTouchdown(for: aircraft[index])
        let targetAltitudeFeet = max(0, Int((distance / 3.0) * 1000.0))
        let currentAltitudeFeet = levelToFeet(aircraft[index].currentLevel)
        let descentPerSecondFeet = 700
        let maxDescent = Int(CGFloat(descentPerSecondFeet) * dt)
        let newAltitude = max(targetAltitudeFeet, currentAltitudeFeet - maxDescent)
        aircraft[index].currentLevel = feetToLevel(newAltitude)
        aircraft[index].selectedLevel = feetToLevel(targetAltitudeFeet)
        aircraft[index].trend = currentAltitudeFeet > targetAltitudeFeet ? .descend : .level
        aircraft[index].groundSpeed = max(130, aircraft[index].groundSpeed - Int(8 * dt))
    }

    private func removeLandedAircraft() {
        let landedAircraftIDs = Set(
            aircraft
                .filter { distanceToTouchdown(for: $0) < 0.3 && levelToFeet($0.currentLevel) <= 100 }
                .map(\.id)
        )

        guard !landedAircraftIDs.isEmpty else { return }

        aircraft.removeAll { landedAircraftIDs.contains($0.id) }
        strips.removeAll { landedAircraftIDs.contains($0.aircraftID) }
    }

    private func distanceToTouchdown(for aircraft: Aircraft) -> Double {
        let dx = aircraft.trueX - touchdownPoint.x
        let dy = aircraft.trueY - touchdownPoint.y
        let pixelDistance = sqrt(dx * dx + dy * dy)
        return Double(pixelDistance / pixelsPerNauticalMile)
    }

    private func headingToTouchdown(from aircraft: Aircraft) -> Double {
        let dx = Double(touchdownPoint.x - aircraft.trueX)
        let dy = Double(aircraft.trueY - touchdownPoint.y)
        let bearing = atan2(dy, dx) * 180 / .pi
        return normalizeHeading(bearing)
    }

    private func levelToFeet(_ level: Int) -> Int {
        level * 100
    }

    private func feetToLevel(_ feet: Int) -> Int {
        max(0, feet / 100)
    }

    private func normalizeHeading(_ heading: Double) -> Double {
        var normalized = heading.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }

    private func headingDifference(_ lhs: Double, _ rhs: Double) -> Double {
        let delta = abs(normalizeHeading(lhs) - normalizeHeading(rhs))
        return min(delta, 360 - delta)
    }

    private func turnToward(current: Double, target: Double, maxStep: Double) -> Double {
        let currentN = normalizeHeading(current)
        let targetN = normalizeHeading(target)
        var delta = targetN - currentN

        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }

        let limitedDelta = min(max(delta, -maxStep), maxStep)
        return normalizeHeading(currentN + limitedDelta)
    }

    private func canCaptureILS(_ aircraft: Aircraft) -> Bool {
        let distance = distanceToTouchdown(for: aircraft)
        let altitudeFeet = levelToFeet(aircraft.currentLevel)

        if distance <= 6 {
            return true
        }

        let isHeadingEligible = headingDifference(aircraft.heading, finalApproachHeading) <= 40
        guard isHeadingEligible else { return false }

        if (8...12).contains(distance) {
            return altitudeFeet <= 3000
        }

        if (6...8).contains(distance) {
            return altitudeFeet <= 2000
        }

        return false
    }

    func sendInstruction(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        let strip = strips[stripIndex]
        let instruction = [
            strip.callsign,
            strip.aircraftType,
            "LVL \(strip.levelDisplay)",
            "HDG \(String(format: "%03d", strip.selectedHeading))",
            "SPD \(strip.selectedSpeed)KT",
            strip.approachType
        ].joined(separator: " | ")

        strips[stripIndex].instructionLog.insert(instruction, at: 0)
    }

    func armApproach(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        let strip = strips[stripIndex]
        guard let aircraftIndex = aircraft.firstIndex(where: { $0.id == strip.aircraftID }) else {
            return
        }

        guard strip.isInbound else {
            strips[stripIndex].instructionLog.insert("APPROACH rejected: outbound traffic", at: 0)
            return
        }

        if canCaptureILS(aircraft[aircraftIndex]) {
            aircraft[aircraftIndex].approachMode = .ilsLocked
            strips[stripIndex].approachType = "ILS"
            strips[stripIndex].bay = .approach
            strips[stripIndex].instructionLog.insert("APPROACH accepted: ILS lock captured", at: 0)
        } else {
            let distance = String(format: "%.1f", distanceToTouchdown(for: aircraft[aircraftIndex]))
            let altitude = levelToFeet(aircraft[aircraftIndex].currentLevel)
            strips[stripIndex].instructionLog.insert(
                "APPROACH rejected: \(distance)NM / \(altitude)FT / HDG \(Int(aircraft[aircraftIndex].heading))",
                at: 0
            )
        }
    }

    func flitStrip(stripID: UUID, to bay: StripBay) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].bay = bay
    }
}
