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

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func makeStrip(selectedHeading: Int) -> EFPSStrip {
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
            selectedSpeed: 220,
            approachType: "ILS",
            approachCleared: false,
            instructionLog: [],
            lastIssuedLevel: 100,
            lastIssuedHeading: 0,
            lastIssuedSpeed: 220,
            lastIssuedApproachType: "ILS"
        )
    }
}
