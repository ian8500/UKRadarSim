import Foundation
import CoreGraphics

class SimulationEngine: ObservableObject {
    @Published var aircraft: [Aircraft] = []
    @Published var strips: [EFPSStrip] = []

    private var movementTimer: Timer?
    private var radarTimer: Timer?
    private let approachCourseHeading: Double = 34.5
    private let centerlineStart = CGPoint(x: 180, y: 576)
    private let runwayThreshold = CGPoint(x: 790, y: 232)

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
            if aircraft[i].isLanded { continue }
            let headingRad = CGFloat(aircraft[i].heading * .pi / 180.0)

            // Temporary pixels-per-knot scale for prototype
            let speedScale: CGFloat = 0.02
            let distance = CGFloat(aircraft[i].groundSpeed) * speedScale * dt

            aircraft[i].trueX += cos(headingRad) * distance
            aircraft[i].trueY -= sin(headingRad) * distance

            applyApproachAutomationIfNeeded(index: i, dt: dt)
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

        strips[stripIndex].currentLevel = currentAircraft.currentLevel
        strips[stripIndex].approachCaptured = currentAircraft.approachCaptured
        strips[stripIndex].isLanded = currentAircraft.isLanded
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
        guard let aircraftIndex = aircraft.firstIndex(where: { $0.id == strips[stripIndex].aircraftID }) else {
            return
        }

        strips[stripIndex].approachCleared = true
        aircraft[aircraftIndex].autoLandingActive = true
        let strip = strips[stripIndex]
        let instruction = "\(strip.callsign) | CLEARED \(strip.approachType) APPROACH"
        strips[stripIndex].instructionLog.insert(instruction, at: 0)
    }

    private func applyApproachAutomationIfNeeded(index: Int, dt: CGFloat) {
        let aircraftID = aircraft[index].id
        guard aircraft[index].isInbound,
              let stripIndex = strips.firstIndex(where: { $0.aircraftID == aircraftID }),
              strips[stripIndex].approachCleared
        else {
            return
        }

        let position = CGPoint(x: aircraft[index].trueX, y: aircraft[index].trueY)
        let distanceToLocalizer = distanceFromPoint(position, toSegmentFrom: centerlineStart, to: runwayThreshold)
        let headingError = angularDifference(aircraft[index].heading, approachCourseHeading)

        if !aircraft[index].approachCaptured, distanceToLocalizer < 24, headingError < 35 {
            aircraft[index].approachCaptured = true
            strips[stripIndex].instructionLog.insert("\(aircraft[index].callsign) | LOC CAPTURED", at: 0)
        }

        guard aircraft[index].approachCaptured else {
            return
        }

        let newHeading = moveAngle(aircraft[index].heading, toward: approachCourseHeading, maxDelta: Double(dt) * 8)
        aircraft[index].heading = newHeading

        if aircraft[index].groundSpeed > 145 {
            aircraft[index].groundSpeed = max(145, aircraft[index].groundSpeed - 1)
        }

        if aircraft[index].currentLevel > 0 {
            aircraft[index].currentLevel = max(0, aircraft[index].currentLevel - 1)
            aircraft[index].trend = aircraft[index].currentLevel == 0 ? .level : .descend
        }

        let distanceToThreshold = hypot(position.x - runwayThreshold.x, position.y - runwayThreshold.y)
        if distanceToThreshold < 26, aircraft[index].currentLevel == 0, aircraft[index].groundSpeed <= 150 {
            aircraft[index].isLanded = true
            aircraft[index].groundSpeed = 0
            aircraft[index].trend = .level
            aircraft[index].trueX = runwayThreshold.x
            aircraft[index].trueY = runwayThreshold.y
            aircraft[index].displayX = runwayThreshold.x
            aircraft[index].displayY = runwayThreshold.y
            strips[stripIndex].instructionLog.insert("\(aircraft[index].callsign) | LANDED", at: 0)
        }
    }

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func moveAngle(_ current: Double, toward target: Double, maxDelta: Double) -> Double {
        let delta = ((target - current + 540).truncatingRemainder(dividingBy: 360)) - 180
        let clamped = min(max(delta, -maxDelta), maxDelta)
        var adjusted = current + clamped
        if adjusted < 0 { adjusted += 360 }
        if adjusted >= 360 { adjusted -= 360 }
        return adjusted
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}
