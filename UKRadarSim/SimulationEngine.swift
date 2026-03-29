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

    private var movementTimer: Timer?
    private var radarTimer: Timer?
    private var approachGuidance = ApproachGuidance()
    private var verticalProgressByAircraft: [UUID: Double] = [:]

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
            applyControllerTargetsIfNeeded(index: i, dt: dt)
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
            let previousDisplayPoint = CGPoint(x: aircraft[i].displayX, y: aircraft[i].displayY)
            aircraft[i].historyDots.insert(previousDisplayPoint, at: 0)
            aircraft[i].historyDots = Array(aircraft[i].historyDots.prefix(6))
            aircraft[i].displayX = aircraft[i].trueX
            aircraft[i].displayY = aircraft[i].trueY
        }
    }

    private func wrapAircraftIfNeeded(index: Int) {
        var didWrap = false
        if aircraft[index].trueX > 1100 {
            aircraft[index].trueX = -100
            didWrap = true
        }
        if aircraft[index].trueX < -100 {
            aircraft[index].trueX = 1100
            didWrap = true
        }
        if aircraft[index].trueY > 900 {
            aircraft[index].trueY = -100
            didWrap = true
        }
        if aircraft[index].trueY < -100 {
            aircraft[index].trueY = 900
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
            maxDelta: Double(dt) * 3.0
        )

        let speedTarget = strips[stripIndex].selectedSpeed
        if aircraft[index].groundSpeed < speedTarget {
            let increase = max(1, Int((Double(dt) * 8.0).rounded()))
            aircraft[index].groundSpeed = min(speedTarget, aircraft[index].groundSpeed + increase)
        } else if aircraft[index].groundSpeed > speedTarget {
            let decrease = max(1, Int((Double(dt) * 10.0).rounded()))
            aircraft[index].groundSpeed = max(speedTarget, aircraft[index].groundSpeed - decrease)
        }

        let levelTarget = strips[stripIndex].selectedLevel
        if aircraft[index].currentLevel != levelTarget {
            let direction = levelTarget > aircraft[index].currentLevel ? 1 : -1
            let progressKey = aircraftID
            let verticalRateFLPerSecond = 0.2
            verticalProgressByAircraft[progressKey, default: 0] += verticalRateFLPerSecond * Double(dt)

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
        guard let aircraftIndex = aircraft.firstIndex(where: { $0.id == strips[stripIndex].aircraftID }) else {
            return
        }

        strips[stripIndex].approachType = "ILS"
        strips[stripIndex].approachCleared = true
        aircraft[aircraftIndex].autoLandingActive = true
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
        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == aircraftID }) else {
            return
        }

        approachGuidance.applyIfNeeded(
            aircraft: &aircraft[index],
            strip: &strips[stripIndex],
            dt: dt
        )
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
}
