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

    @Test func speedReadbackUsesMaintainWhenNoLastIssuedSpeed() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(selectedSpeed: 210, lastIssuedSpeed: nil)

        let instruction = service.buildIssuedInstruction(for: strip, changedFields: [.speed])

        #expect(instruction == ["maintain speed two one zero knots"])
    }

    @Test func callsignExpansionUsesAirlineNamesAndPhonetics() {
        let service = VoiceReadbackService.shared
        let strip = makeStrip(callsign: "BAW12A")

        let readback = service.buildCAAReadback(for: strip, instruction: ["maintain speed two one zero knots"])

        #expect(readback == "maintain speed two one zero knots, Speedbird one two alpha.")
    }

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func makeStrip(
        callsign: String = "EZY123",
        selectedLevel: Int = 100,
        currentLevel: Int = 100,
        lastIssuedLevel: Int? = 100,
        selectedHeading: Int = 90,
        selectedSpeed: Int = 220,
        lastIssuedSpeed: Int? = 220
    ) -> EFPSStrip {
        EFPSStrip(
            aircraftID: UUID(),
            callsign: callsign,
            aircraftType: "A320",
            destination: "EGKK",
            isInbound: true,
            bay: .inbound,
            selectedLevel: selectedLevel,
            currentLevel: currentLevel,
            selectedHeading: selectedHeading,
            currentHeading: 0,
            selectedSpeed: selectedSpeed,
            approachType: "ILS",
            approachCleared: false,
            instructionLog: [],
            lastIssuedLevel: lastIssuedLevel,
            lastIssuedHeading: 0,
            lastIssuedSpeed: lastIssuedSpeed,
            lastIssuedApproachType: "ILS"
        )
    }
}
