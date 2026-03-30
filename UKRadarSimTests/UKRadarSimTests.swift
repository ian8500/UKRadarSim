import CoreGraphics
import Testing
@testable import UKRadarSim

struct UKRadarSimTests {

    private let startupScenario = ScenarioLibrary.default

    @Test func radarDisplayUpdatesOnlyOnRadarTick() {
        let engine = SimulationEngine(startupScenario: ScenarioLibrary.default)
        #expect(!engine.aircraft.isEmpty)

        let baselineDisplay = CGPoint(x: engine.aircraft[0].displayX, y: engine.aircraft[0].displayY)

        engine.step(dt: 1.0)

        let afterOneSecond = engine.aircraft[0]
        #expect(afterOneSecond.trueX != baselineDisplay.x || afterOneSecond.trueY != baselineDisplay.y)
        #expect(afterOneSecond.displayX == baselineDisplay.x)
        #expect(afterOneSecond.displayY == baselineDisplay.y)

        engine.step(dt: 5.1)

        let afterRadarTick = engine.aircraft[0]
        #expect(afterRadarTick.displayX == afterRadarTick.trueX)
        #expect(afterRadarTick.displayY == afterRadarTick.trueY)
        #expect(!afterRadarTick.historyDots.isEmpty)
    }

    @Test func headingTargetConvergesGradually() {
        let engine = SimulationEngine(startupScenario: ScenarioLibrary.default)
        #expect(!engine.aircraft.isEmpty)
        #expect(!engine.strips.isEmpty)

        let startHeading = engine.aircraft[0].heading
        let targetHeading = Int((startHeading + 90).truncatingRemainder(dividingBy: 360))
        engine.strips[0].selectedHeading = targetHeading

        engine.step(dt: 1.0)

        let updatedHeading = engine.aircraft[0].heading
        let startError = angularDifference(startHeading, Double(targetHeading))
        let newError = angularDifference(updatedHeading, Double(targetHeading))

        #expect(newError < startError)
        #expect(newError > 0)
    }

    @Test func levelOffOccursWhenSelectedLevelReached() {
        let engine = SimulationEngine(startupScenario: ScenarioLibrary.default)
        #expect(!engine.aircraft.isEmpty)
        #expect(!engine.strips.isEmpty)

        let startLevel = engine.aircraft[0].currentLevel
        engine.strips[0].selectedLevel = startLevel + 2

        engine.step(dt: 10.0)

        let aircraft = engine.aircraft[0]
        #expect(aircraft.currentLevel == startLevel + 2)
        switch aircraft.trend {
        case .level:
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
    }

    @Test func levelReadbackUsesClimbWording() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedLevel: 120, currentLevel: 100, lastIssuedLevel: 100)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.level])

        #expect(instruction == ["climb flight level one two zero"])
    }

    @Test func levelReadbackUsesDescendWording() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedLevel: 80, currentLevel: 100, lastIssuedLevel: 100)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.level])

        #expect(instruction == ["descend flight level eight zero"])
    }

    @Test func levelReadbackUsesMaintainWording() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedLevel: 100, currentLevel: 100, lastIssuedLevel: 120)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.level])

        #expect(instruction == ["maintain flight level one zero zero"])
    }

    @Test func headingReadbackIncludesDegreesForHeadingsEndingInZero() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedHeading: 30)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.heading])

        #expect(instruction == ["turn right heading zero three zero degrees"])
    }

    @Test func headingReadbackOmitsDegreesForHeadingsNotEndingInZero() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedHeading: 27)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.heading])

        #expect(instruction == ["turn right heading zero two seven"])
    }

    @Test func speedReadbackUsesIncreaseWhenSpeedGoesUp() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedSpeed: 250, lastIssuedSpeed: 220)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.speed])

        #expect(instruction == ["increase speed two five zero knots"])
    }

    @Test func speedReadbackUsesReduceWhenSpeedGoesDown() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedSpeed: 180, lastIssuedSpeed: 220)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.speed])

        #expect(instruction == ["reduce speed one eight zero knots"])
    }

    @Test func aircraftMotionServiceMovesHeadingTowardTarget() {
        let service = AircraftMotionService()
        var aircraft = makeAircraft(heading: 10, groundSpeed: 220, currentLevel: 80, selectedLevel: 80)
        let strip = makeStrip(selectedHeading: 100, selectedSpeed: 220, selectedLevel: 80)
        var verticalProgress = 0.0

        service.applyControllerTargets(to: &aircraft, strip: strip, dt: 1.0, verticalProgress: &verticalProgress)

        #expect(aircraft.heading == 13)
    }

    @Test func aircraftMotionServiceUsesAircraftSpecificTurnRates() {
        let profile = AircraftPerformanceProfile(
            maxTurnRateDegreesPerSecond: 1.0,
            climbRateFLPerSecond: 2.0,
            descentRateFLPerSecond: 2.0,
            accelerationRateKnotsPerSecond: 2.0,
            decelerationRateKnotsPerSecond: 2.0,
            typicalApproachSpeedKnots: 150
        )
        let service = AircraftMotionService(
            performanceProvider: StubPerformanceProvider(
                profiles: ["A320": profile],
                fallback: .genericJet
            )
        )
        var aircraft = makeAircraft(heading: 10, groundSpeed: 220, currentLevel: 80, selectedLevel: 80)
        let strip = makeStrip(selectedHeading: 100, selectedSpeed: 220, selectedLevel: 80)
        var verticalProgress = 0.0

        service.applyControllerTargets(to: &aircraft, strip: strip, dt: 1.0, verticalProgress: &verticalProgress)

        #expect(aircraft.heading == 11)
    }

    @Test func predictorUsesAircraftSpecificAcceleration() {
        let profile = AircraftPerformanceProfile(
            maxTurnRateDegreesPerSecond: 3.0,
            climbRateFLPerSecond: 2.0,
            descentRateFLPerSecond: 2.0,
            accelerationRateKnotsPerSecond: 1.0,
            decelerationRateKnotsPerSecond: 2.0,
            typicalApproachSpeedKnots: 150
        )
        let predictor = IntentAwareTrackPredictor(
            performanceProvider: StubPerformanceProvider(
                profiles: ["A320": profile],
                fallback: .genericJet
            )
        )
        let aircraft = makeAircraft(heading: 0, groundSpeed: 200, currentLevel: 90)
        let intent = TrackIntent(selectedHeading: 0, selectedSpeed: 210, selectedLevel: 90)

        let prediction = predictor.predictedState(
            for: aircraft,
            intent: intent,
            lookaheadSeconds: 1.0,
            startPosition: CGPoint(x: aircraft.trueX, y: aircraft.trueY)
        )

        let distanceTravelled = prediction.projectedPosition.x - aircraft.trueX
        let expectedDistance = CGFloat(201) * MotionProjection.speedScale

        #expect(abs(distanceTravelled - expectedDistance) < 0.0001)
    }

    @Test func approachAutomationServiceCapturesAndLands() {
        let service = ApproachAutomationService()
        let geometry = RadarGeometry.default
        var aircraft = makeAircraft(
            trueX: geometry.runwayThreshold.x,
            trueY: geometry.runwayThreshold.y,
            heading: geometry.approachCourseHeading,
            groundSpeed: 160,
            currentLevel: 0,
            selectedLevel: 0,
            isInbound: true,
            approachCaptured: false
        )
        let strip = makeStrip(selectedHeading: 0, selectedSpeed: 160, selectedLevel: 0, approachCleared: true)

        let outcome = service.apply(to: &aircraft, strip: strip, geometry: geometry, dt: 1.0)

        #expect(outcome.didCaptureLocalizer)
        #expect(outcome.didLand)
        #expect(aircraft.isLanded)
        #expect(aircraft.groundSpeed == 0)
    }

    @Test func conflictDetectionServiceDetectsWarning() {
        let service = ConflictDetectionService()
        let first = makeAircraft(callsign: "AAL1", trueX: 10, trueY: 10, currentLevel: 100, selectedLevel: 100)
        let second = makeAircraft(callsign: "BAW2", trueX: 20, trueY: 20, currentLevel: 105, selectedLevel: 105)

        let conflicts = service.detectConflicts(aircraft: [first, second]) { aircraft, _ in
            CGPoint(x: aircraft.trueX, y: aircraft.trueY)
        }

        #expect(conflicts.count == 1)
        switch conflicts[0].severity {
        case .warning:
            #expect(Bool(true))
        case .advisory:
            #expect(Bool(false))
        }
    }

    @Test func stripSyncServiceCopiesTrackState() {
        let service = StripSyncService()
        let aircraft = makeAircraft(heading: 274.6, currentLevel: 90, selectedLevel: 90, approachCaptured: true, isLanded: true)
        var strip = makeStrip(selectedHeading: 90, selectedSpeed: 220, selectedLevel: 100)

        service.syncStrip(from: aircraft, strip: &strip)

        #expect(strip.currentLevel == 90)
        #expect(strip.currentHeading == 275)
        #expect(strip.approachCaptured)
        #expect(strip.isLanded)
    }

    @Test func scoringServiceAppliesBonusesAndPenalties() {
        let service = ScoringService()
        let conflicts = [
            ConflictDetectionService.Conflict(callsignPair: "A/B", severity: .warning, message: "x"),
            ConflictDetectionService.Conflict(callsignPair: "C/D", severity: .advisory, message: "y")
        ]

        let score = service.computeScore(landedCount: 2, conflicts: conflicts)

        #expect(score == 93)
    }

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func makeAircraft(
        callsign: String = "EZY123",
        trueX: CGFloat = 100,
        trueY: CGFloat = 100,
        heading: Double = 90,
        groundSpeed: Int = 220,
        currentLevel: Int = 100,
        selectedLevel: Int = 100,
        isInbound: Bool = true,
        approachCaptured: Bool = false,
        isLanded: Bool = false
    ) -> Aircraft {
        Aircraft(
            callsign: callsign,
            trueX: trueX,
            trueY: trueY,
            displayX: trueX,
            displayY: trueY,
            heading: heading,
            groundSpeed: groundSpeed,
            currentLevel: currentLevel,
            selectedLevel: selectedLevel,
            trend: .level,
            aircraftType: "A320",
            destination: "EGKK",
            isInbound: isInbound,
            approachCaptured: approachCaptured,
            isLanded: isLanded
        )
    }

    private func makeStrip(
        selectedHeading: Int,
        selectedSpeed: Int = 220,
        selectedLevel: Int = 100,
        lastIssuedSpeed: Int = 220,
        approachCleared: Bool = false
    ) -> EFPSStrip {
        EFPSStrip(
            aircraftID: UUID(),
            callsign: callsign,
            aircraftType: "A320",
            destination: "EGKK",
            isInbound: true,
            bay: .inbound,
            selectedLevel: selectedLevel,
            currentLevel: selectedLevel,
            selectedHeading: selectedHeading,
            currentHeading: 0,
            selectedSpeed: selectedSpeed,
            approachType: "ILS",
            approachCleared: approachCleared,
            instructionLog: [],
            lastIssuedLevel: selectedLevel,
            lastIssuedHeading: 0,
            lastIssuedSpeed: lastIssuedSpeed,
            lastIssuedApproachType: "ILS"
        )
    }

    private func makeAircraft(heading: Double, groundSpeed: Int, currentLevel: Int) -> Aircraft {
        Aircraft(
            callsign: "TEST123",
            trueX: 500,
            trueY: 500,
            displayX: 500,
            displayY: 500,
            heading: heading,
            groundSpeed: groundSpeed,
            currentLevel: currentLevel,
            selectedLevel: currentLevel,
            trend: .level,
            aircraftType: "A320",
            destination: "EGKK",
            isInbound: true
        )
    }
}

private final class MockSimulationStepper: SimulationStepping {
    private(set) var receivedDeltas: [CGFloat] = []

    func step(dt: CGFloat) {
        receivedDeltas.append(dt)
    }
}

private struct StubPerformanceProvider: AircraftPerformanceProviding {
    let profiles: [String: AircraftPerformanceProfile]
    let fallback: AircraftPerformanceProfile

    func profile(for aircraftType: String) -> AircraftPerformanceProfile {
        profiles[aircraftType.uppercased()] ?? fallback
    }
}
