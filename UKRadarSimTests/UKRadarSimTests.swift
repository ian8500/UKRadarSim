import CoreGraphics
import Testing
@testable import UKRadarSim

struct UKRadarSimTests {

    private let startupScenario = ScenarioLibrary.default

    @Test func radarDisplayUpdatesOnlyOnRadarTick() {
        let engine = SimulationEngine(startupScenario: startupScenario)
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
        let engine = SimulationEngine(startupScenario: startupScenario)
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
        let engine = SimulationEngine(startupScenario: startupScenario)
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
        let strip = makeStrip(selectedHeading: 90, selectedSpeed: 250, lastIssuedSpeed: 220)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.speed])

        #expect(instruction == ["increase speed two five zero knots"])
    }

    @Test func speedReadbackUsesReduceWhenSpeedGoesDown() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedHeading: 90, selectedSpeed: 180, lastIssuedSpeed: 220)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.speed])

        #expect(instruction == ["reduce speed one eight zero knots"])
    }

    @Test func intentAwarePredictorUsesSelectedHeading() {
        let predictor = IntentAwareTrackPredictor()
        let aircraft = makeAircraft(heading: 90, groundSpeed: 220, currentLevel: 120)
        let neutralIntent = TrackIntent(selectedHeading: 90, selectedSpeed: 220, selectedLevel: 120)
        let turnIntent = TrackIntent(selectedHeading: 180, selectedSpeed: 220, selectedLevel: 120)

        let neutralProjection = predictor.predictedState(
            for: aircraft,
            intent: neutralIntent,
            lookaheadSeconds: 60,
            startPosition: CGPoint(x: aircraft.displayX, y: aircraft.displayY)
        )
        let turnedProjection = predictor.predictedState(
            for: aircraft,
            intent: turnIntent,
            lookaheadSeconds: 60,
            startPosition: CGPoint(x: aircraft.displayX, y: aircraft.displayY)
        )

        #expect(abs(neutralProjection.projectedPosition.x - turnedProjection.projectedPosition.x) > 0.01)
    }

    @Test func intentAwarePredictorUsesSelectedSpeed() {
        let predictor = IntentAwareTrackPredictor()
        let aircraft = makeAircraft(heading: 90, groundSpeed: 220, currentLevel: 120)
        let fastIntent = TrackIntent(selectedHeading: 90, selectedSpeed: 260, selectedLevel: 120)
        let slowIntent = TrackIntent(selectedHeading: 90, selectedSpeed: 180, selectedLevel: 120)

        let fastProjection = predictor.predictedState(
            for: aircraft,
            intent: fastIntent,
            lookaheadSeconds: 60,
            startPosition: CGPoint(x: aircraft.displayX, y: aircraft.displayY)
        )
        let slowProjection = predictor.predictedState(
            for: aircraft,
            intent: slowIntent,
            lookaheadSeconds: 60,
            startPosition: CGPoint(x: aircraft.displayX, y: aircraft.displayY)
        )

        #expect(abs(fastProjection.projectedPosition.y - slowProjection.projectedPosition.y) > 0.01)
    }

    @Test func intentAwarePredictorUsesSelectedLevel() {
        let predictor = IntentAwareTrackPredictor()
        let aircraft = makeAircraft(heading: 90, groundSpeed: 220, currentLevel: 120)
        let climbIntent = TrackIntent(selectedHeading: 90, selectedSpeed: 220, selectedLevel: 140)
        let descentIntent = TrackIntent(selectedHeading: 90, selectedSpeed: 220, selectedLevel: 100)

        let climbProjection = predictor.predictedState(
            for: aircraft,
            intent: climbIntent,
            lookaheadSeconds: 10,
            startPosition: CGPoint(x: aircraft.displayX, y: aircraft.displayY)
        )
        let descentProjection = predictor.predictedState(
            for: aircraft,
            intent: descentIntent,
            lookaheadSeconds: 10,
            startPosition: CGPoint(x: aircraft.displayX, y: aircraft.displayY)
        )

        #expect(climbProjection.projectedLevel > descentProjection.projectedLevel)
    }

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func makeStrip(selectedHeading: Int, selectedSpeed: Int = 220, lastIssuedSpeed: Int = 220) -> EFPSStrip {
        EFPSStrip(
            aircraftID: UUID(),
            callsign: "EZY123",
            aircraftType: "A320",
            destination: "EGKK",
            isInbound: true,
            bay: .inbound,
            selectedLevel: 100,
            currentLevel: 100,
            selectedHeading: selectedHeading,
            currentHeading: 0,
            selectedSpeed: selectedSpeed,
            approachType: "ILS",
            approachCleared: false,
            instructionLog: [],
            lastIssuedLevel: 100,
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
