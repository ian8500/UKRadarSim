import Foundation
import CoreGraphics

enum InstructionChange: Hashable {
    case level
    case heading
    case speed
    case approachType
    case ilsClearance
}

class SimulationEngine: ObservableObject {
    @Published var aircraft: [Aircraft] = []
    @Published var strips: [EFPSStrip] = []

    private let truthUpdateInterval: CGFloat = 0.1
    private let radarUpdateInterval: CGFloat = 6.0
    private var elapsedSinceRadarUpdate: CGFloat = 0
    private let approachCourseHeading: Double = 34.5
    private let centerlineStart = CGPoint(x: 180, y: 576)
    private let runwayThreshold = CGPoint(x: 790, y: 232)
    private var verticalProgressByAircraft: [UUID: Double] = [:]

    init(geometry: RadarGeometry = .default) {
        self.geometry = geometry
        setupTestAircraft()
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
                currentHeading: Int(item.heading),
                selectedSpeed: item.groundSpeed,
                approachType: item.isInbound ? "ILS" : "SID",
                approachCleared: false,
                instructionLog: [],
                lastIssuedLevel: nil,
                lastIssuedHeading: nil,
                lastIssuedSpeed: nil,
                lastIssuedApproachType: nil
            )
        }
    }

    func step(dt: CGFloat) {
        guard dt > 0 else { return }
        var remainingStep = dt

        while remainingStep > 0 {
            let truthDelta = min(truthUpdateInterval, remainingStep)
            updateAircraftTruth(dt: truthDelta)
            elapsedSinceRadarUpdate += truthDelta

            while elapsedSinceRadarUpdate >= radarUpdateInterval {
                updateRadarDisplayedPositions()
                elapsedSinceRadarUpdate -= radarUpdateInterval
            }

            remainingStep -= truthDelta
        }
    }

    private func updateAircraftTruth(dt: CGFloat) {

        for i in aircraft.indices {
            if aircraft[i].isLanded { continue }
            applyControllerTargetsIfNeeded(index: i, dt: dt)
            let updatedPosition = MotionProjection.project(
                from: CGPoint(x: aircraft[i].trueX, y: aircraft[i].trueY),
                headingDegrees: aircraft[i].heading,
                groundSpeed: aircraft[i].groundSpeed,
                elapsedSeconds: dt
            )
            aircraft[i].trueX = updatedPosition.x
            aircraft[i].trueY = updatedPosition.y

            applyApproachAutomationIfNeeded(index: i, dt: dt)
            wrapAircraftIfNeeded(index: i)
            syncStripFromAircraft(at: i)
        }
    }

    private func updateRadarDisplayedPositions() {
        for i in aircraft.indices {
            let previousDisplayPoint = CGPoint(x: aircraft[i].displayX, y: aircraft[i].displayY)
            aircraft[i].historyDots.insert(previousDisplayPoint, at: 0)
            aircraft[i].historyDots = Array(aircraft[i].historyDots.prefix(6))
            aircraft[i].displayX = aircraft[i].trueX
            aircraft[i].displayY = aircraft[i].trueY
        }
    }

    private func wrapAircraftIfNeeded(index: Int) {
        var didWrap = false
        let wrapBounds = geometry.wrapBounds
        if aircraft[index].trueX > wrapBounds.maxX {
            aircraft[index].trueX = wrapBounds.minX
            didWrap = true
        }
        if aircraft[index].trueX < wrapBounds.minX {
            aircraft[index].trueX = wrapBounds.maxX
            didWrap = true
        }
        if aircraft[index].trueY > wrapBounds.maxY {
            aircraft[index].trueY = wrapBounds.minY
            didWrap = true
        }
        if aircraft[index].trueY < wrapBounds.minY {
            aircraft[index].trueY = wrapBounds.maxY
            didWrap = true
        }

        if didWrap {
            aircraft[index].historyDots.removeAll()
        }
    }

    private func syncStripFromAircraft(at index: Int) {
        let currentAircraft = aircraft[index]
        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == currentAircraft.id }) else {
            return
        }

        strips[stripIndex].currentLevel = currentAircraft.currentLevel
        strips[stripIndex].currentHeading = Int(currentAircraft.heading.rounded())
        strips[stripIndex].approachCaptured = currentAircraft.approachCaptured
        strips[stripIndex].isLanded = currentAircraft.isLanded
    }

    private func applyControllerTargetsIfNeeded(index: Int, dt: CGFloat) {
        let aircraftID = aircraft[index].id
        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == aircraftID }) else {
            return
        }

        if aircraft[index].isInbound && strips[stripIndex].approachCleared && aircraft[index].approachCaptured {
            return
        }

        aircraft[index].selectedLevel = strips[stripIndex].selectedLevel

        let headingTarget = Double(strips[stripIndex].selectedHeading)
        aircraft[index].heading = moveAngle(
            aircraft[index].heading,
            toward: headingTarget,
            maxDelta: Double(dt) * config.headingTurnRateDegreesPerSecond
        )

        let speedTarget = strips[stripIndex].selectedSpeed
        if aircraft[index].groundSpeed < speedTarget {
            let increase = max(1, Int((Double(dt) * config.accelerationRateKnotsPerSecond).rounded()))
            aircraft[index].groundSpeed = min(speedTarget, aircraft[index].groundSpeed + increase)
        } else if aircraft[index].groundSpeed > speedTarget {
            let decrease = max(1, Int((Double(dt) * config.decelerationRateKnotsPerSecond).rounded()))
            aircraft[index].groundSpeed = max(speedTarget, aircraft[index].groundSpeed - decrease)
        }

        let levelTarget = strips[stripIndex].selectedLevel
        if aircraft[index].currentLevel != levelTarget {
            let direction = levelTarget > aircraft[index].currentLevel ? 1 : -1
            let progressKey = aircraftID
            verticalProgressByAircraft[progressKey, default: 0] += config.climbDescentRateFLPerSecond * Double(dt)

            while verticalProgressByAircraft[progressKey, default: 0] >= 1.0,
                  aircraft[index].currentLevel != levelTarget {
                aircraft[index].currentLevel += direction
                verticalProgressByAircraft[progressKey, default: 0] -= 1.0
            }

            if aircraft[index].currentLevel != levelTarget {
                aircraft[index].trend = direction > 0 ? .climb : .descend
            } else {
                aircraft[index].trend = .level
            }
        } else {
            verticalProgressByAircraft[aircraftID] = 0
            aircraft[index].trend = .level
        }
    }

    func sendInstruction(stripID: UUID, changedFields: Set<InstructionChange> = []) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        let instruction = VoiceReadbackService.shared.buildIssuedInstruction(
            for: strips[stripIndex],
            changedFields: changedFields
        )
        guard !instruction.isEmpty else {
            strips[stripIndex].instructionLog.insert("\(strips[stripIndex].callsign) | NO NEW INSTRUCTION", at: 0)
            return
        }

        let strip = strips[stripIndex]
        let phraseology = VoiceReadbackService.shared.buildCAAReadback(for: strip, instruction: instruction)

        strips[stripIndex].instructionLog.insert(phraseology, at: 0)
        strips[stripIndex].lastIssuedLevel = strip.selectedLevel
        strips[stripIndex].lastIssuedHeading = strip.selectedHeading
        strips[stripIndex].lastIssuedSpeed = strip.selectedSpeed
        strips[stripIndex].lastIssuedApproachType = strip.approachType
        VoiceReadbackService.shared.speakReadback(phraseology: phraseology, callsign: strip.callsign)
    }

    func flitStrip(stripID: UUID, to bay: StripBay) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].bay = bay
    }


    func armILSIntercept(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].approachType = "ILS"
        strips[stripIndex].approachCleared = true
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

    private func applyApproachAutomationIfNeeded(index: Int, dt: CGFloat) {
        let aircraftID = aircraft[index].id
        // Approach automation is intentionally gated by strip clearance state.
        // Capture state then controls whether full localizer/glideslope tracking is active.
        guard aircraft[index].isInbound,
              let stripIndex = strips.firstIndex(where: { $0.aircraftID == aircraftID }),
              strips[stripIndex].approachCleared
        else {
            return
        }

        let position = CGPoint(x: aircraft[index].trueX, y: aircraft[index].trueY)
        let distanceToLocalizer = distanceFromPoint(position, toSegmentFrom: geometry.centerlineStart, to: geometry.runwayThreshold)
        let headingError = angularDifference(aircraft[index].heading, geometry.approachCourseHeading)

        if !aircraft[index].approachCaptured,
           distanceToLocalizer < config.localizerCapture.maxDistancePixels,
           headingError < config.localizerCapture.maxHeadingErrorDegrees {
            aircraft[index].approachCaptured = true
            strips[stripIndex].instructionLog.insert("\(aircraft[index].callsign) | LOC CAPTURED", at: 0)
        }

        guard aircraft[index].approachCaptured else {
            return
        }

        let newHeading = moveAngle(aircraft[index].heading, toward: geometry.approachCourseHeading, maxDelta: Double(dt) * 8)
        aircraft[index].heading = newHeading

        if aircraft[index].groundSpeed > config.approachTargetGroundSpeedKnots {
            aircraft[index].groundSpeed = max(
                config.approachTargetGroundSpeedKnots,
                aircraft[index].groundSpeed - config.approachDecelerationKnotsPerTick
            )
        }

        if aircraft[index].currentLevel > 0 {
            aircraft[index].currentLevel = max(0, aircraft[index].currentLevel - config.approachDescentFLPerTick)
            aircraft[index].trend = aircraft[index].currentLevel == 0 ? .level : .descend
        }

        let runwayThreshold = geometry.runwayThreshold
        let distanceToThreshold = hypot(position.x - runwayThreshold.x, position.y - runwayThreshold.y)
        if distanceToThreshold < config.landing.maxDistanceToThresholdPixels,
           aircraft[index].currentLevel == 0,
           aircraft[index].groundSpeed <= config.landing.maxTouchdownSpeedKnots {
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
        // Simulation heading geometry increases counterclockwise (screen/math convention),
        // so we invert the standard compass delta to make "right" turn calls animate right.
        let delta = ((current - target + 540).truncatingRemainder(dividingBy: 360)) - 180
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
