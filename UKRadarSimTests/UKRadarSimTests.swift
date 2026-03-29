import CoreGraphics
import Testing
@testable import UKRadarSim

struct UKRadarSimTests {

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

    @Test func simulationClockAppliesSpeedMultiplierToElapsedDelta() {
        let stepper = MockSimulationStepper()
        var now = 100.0
        let clock = SimulationClock(
            simulationStepper: stepper,
            tickInterval: 0.1,
            maximumFrameDelta: 5.0,
            nowProvider: { now }
        )
        clock.speedMultiplier = 2.0

        clock.start()
        now = 100.5
        clock.advanceFrame(to: now)

        #expect(stepper.receivedDeltas.count == 1)
        #expect(stepper.receivedDeltas[0] == 1.0)
        #expect(clock.elapsedSeconds == 1.0)
    }

    @Test func simulationClockPauseAndResumeDoesNotAccumulatePausedTime() {
        let stepper = MockSimulationStepper()
        var now = 0.0
        let clock = SimulationClock(
            simulationStepper: stepper,
            tickInterval: 0.1,
            maximumFrameDelta: 5.0,
            nowProvider: { now }
        )

        clock.start()
        now = 1.0
        clock.advanceFrame(to: now)
        clock.pause()

        now = 8.0
        clock.advanceFrame(to: now)

        clock.resume()
        now = 9.0
        clock.advanceFrame(to: now)

        #expect(stepper.receivedDeltas.count == 2)
        #expect(stepper.receivedDeltas[0] == 1.0)
        #expect(stepper.receivedDeltas[1] == 1.0)
        #expect(clock.elapsedSeconds == 2.0)
    }

    @Test func simulationClockClampsLargeFrameDelta() {
        let stepper = MockSimulationStepper()
        var now = 10.0
        let clock = SimulationClock(
            simulationStepper: stepper,
            tickInterval: 0.1,
            maximumFrameDelta: 0.25,
            nowProvider: { now }
        )

        clock.start()
        now = 12.0
        clock.advanceFrame(to: now)

        #expect(stepper.receivedDeltas.count == 1)
        #expect(stepper.receivedDeltas[0] == 0.25)
        #expect(clock.elapsedSeconds == 0.25)
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
}

private final class MockSimulationStepper: SimulationStepping {
    private(set) var receivedDeltas: [CGFloat] = []

    func step(dt: CGFloat) {
        receivedDeltas.append(dt)
    }
}
