import CoreGraphics
import Testing
@testable import UKRadarSim

struct UKRadarSimTests {

    @Test func radarDisplayUpdatesOnlyOnRadarTick() {
        let engine = SimulationEngine()
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
        let engine = SimulationEngine()
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
        let engine = SimulationEngine()
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

    @Test func aircraftTypesTurnAtDifferentRatesForSameInstruction() {
        let engine = SimulationEngine(startupScenario: makePerformanceComparisonScenario())
        #expect(engine.aircraft.count >= 2)

        for stripIndex in engine.strips.indices {
            engine.strips[stripIndex].selectedHeading = 180
        }

        engine.step(dt: 1.0)

        let fastTurnAircraft = engine.aircraft.first { $0.aircraftType == "E190" }
        let slowerTurnAircraft = engine.aircraft.first { $0.aircraftType == "A321" }

        #expect(fastTurnAircraft != nil)
        #expect(slowerTurnAircraft != nil)
        #expect(fastTurnAircraft!.heading > slowerTurnAircraft!.heading)
    }

    @Test func aircraftTypesChangeSpeedAndLevelDifferentlyForSameInstruction() {
        let engine = SimulationEngine(startupScenario: makePerformanceComparisonScenario())
        #expect(engine.aircraft.count >= 2)

        for stripIndex in engine.strips.indices {
            engine.strips[stripIndex].selectedSpeed = 230
            engine.strips[stripIndex].selectedLevel = 124
        }

        engine.step(dt: 1.0)

        let fasterAircraft = engine.aircraft.first { $0.aircraftType == "E190" }
        let slowerAircraft = engine.aircraft.first { $0.aircraftType == "A321" }

        #expect(fasterAircraft != nil)
        #expect(slowerAircraft != nil)
        #expect(fasterAircraft!.groundSpeed > slowerAircraft!.groundSpeed)
        #expect(fasterAircraft!.currentLevel > slowerAircraft!.currentLevel)
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

    private func makePerformanceComparisonScenario() -> SimulationScenario {
        SimulationScenario(
            id: "performance-comparison",
            aircraft: [
                ScenarioAircraftDefinition(
                    callsign: "TEST190",
                    aircraftType: "E190",
                    position: CGPoint(x: 100, y: 100),
                    heading: 0,
                    groundSpeed: 200,
                    currentLevel: 120,
                    selectedLevel: 120,
                    trend: .level,
                    destination: "EGKK",
                    isInbound: false
                ),
                ScenarioAircraftDefinition(
                    callsign: "TEST321",
                    aircraftType: "A321",
                    position: CGPoint(x: 140, y: 140),
                    heading: 0,
                    groundSpeed: 200,
                    currentLevel: 120,
                    selectedLevel: 120,
                    trend: .level,
                    destination: "EGKK",
                    isInbound: false
                )
            ]
        )
    }
}
