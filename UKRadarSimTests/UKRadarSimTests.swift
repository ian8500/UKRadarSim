import CoreGraphics
import Testing
@testable import UKRadarSim

struct UKRadarSimTests {

    @Test func radarDisplayUpdatesOnlyOnRadarTick() {
        let engine = makeEngine()
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
        let engine = makeEngine()
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
        let engine = makeEngine()
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

    @Test func approachCaptureOccursWhenInterceptCriteriaMet() {
        let engine = makeEngine(with: SimulationScenario(id: "approach-capture", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY001",
                position: CGPoint(x: 790, y: 232),
                heading: 30,
                speed: 180,
                currentLevel: 10,
                selectedLevel: 10,
                isInbound: true
            )
        ]))

        engine.strips[0].approachCleared = true
        engine.step(dt: 0.1)

        #expect(engine.aircraft[0].approachCaptured)
        #expect(engine.strips[0].approachCaptured)
        #expect(engine.strips[0].instructionLog.first == "EZY001 | LOC CAPTURED")
    }

    @Test func approachCaptureDoesNotOccurWhenHeadingErrorTooLarge() {
        let engine = makeEngine(with: SimulationScenario(id: "approach-no-capture", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY002",
                position: CGPoint(x: 790, y: 232),
                heading: 100,
                speed: 180,
                currentLevel: 10,
                selectedLevel: 10,
                isInbound: true
            )
        ]))

        engine.strips[0].approachCleared = true
        engine.step(dt: 0.1)

        #expect(!engine.aircraft[0].approachCaptured)
        #expect(!engine.strips[0].approachCaptured)
        #expect(engine.strips[0].instructionLog.isEmpty)
    }

    @Test func landingOccursWhenCloseLevelZeroAndBelowTouchdownSpeed() {
        let runwayThreshold = RadarGeometry.default.runwayThreshold

        let engine = makeEngine(with: SimulationScenario(id: "landing-success", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY003",
                position: CGPoint(x: runwayThreshold.x - 5, y: runwayThreshold.y),
                heading: RadarGeometry.default.approachCourseHeading,
                speed: 160,
                currentLevel: 0,
                selectedLevel: 0,
                isInbound: true
            )
        ]))

        engine.strips[0].approachCleared = true
        engine.aircraft[0].approachCaptured = true
        engine.strips[0].approachCaptured = true

        engine.step(dt: 0.1)

        #expect(engine.aircraft[0].isLanded)
        #expect(engine.strips[0].isLanded)
        #expect(engine.landedCount == 1)
    }

    @Test func landingDoesNotOccurWhenNotCloseEnoughToThreshold() {
        let runwayThreshold = RadarGeometry.default.runwayThreshold

        let engine = makeEngine(with: SimulationScenario(id: "landing-too-far", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY004",
                position: CGPoint(x: runwayThreshold.x - 40, y: runwayThreshold.y),
                heading: RadarGeometry.default.approachCourseHeading,
                speed: 160,
                currentLevel: 0,
                selectedLevel: 0,
                isInbound: true
            )
        ]))

        engine.strips[0].approachCleared = true
        engine.aircraft[0].approachCaptured = true

        engine.step(dt: 0.1)

        #expect(!engine.aircraft[0].isLanded)
        #expect(engine.landedCount == 0)
    }

    @Test func landingDoesNotOccurWhenNotOnLevelZero() {
        let runwayThreshold = RadarGeometry.default.runwayThreshold

        let engine = makeEngine(with: SimulationScenario(id: "landing-high", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY005",
                position: CGPoint(x: runwayThreshold.x - 5, y: runwayThreshold.y),
                heading: RadarGeometry.default.approachCourseHeading,
                speed: 160,
                currentLevel: 1,
                selectedLevel: 1,
                isInbound: true
            )
        ]))

        engine.strips[0].approachCleared = true
        engine.aircraft[0].approachCaptured = true

        engine.step(dt: 0.1)

        #expect(!engine.aircraft[0].isLanded)
        #expect(engine.landedCount == 0)
    }

    @Test func landingDoesNotOccurWhenAboveTouchdownSpeed() {
        let runwayThreshold = RadarGeometry.default.runwayThreshold

        let engine = makeEngine(with: SimulationScenario(id: "landing-fast", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY006",
                position: CGPoint(x: runwayThreshold.x - 5, y: runwayThreshold.y),
                heading: RadarGeometry.default.approachCourseHeading,
                speed: 170,
                currentLevel: 0,
                selectedLevel: 0,
                isInbound: true
            )
        ]))

        engine.strips[0].approachCleared = true
        engine.aircraft[0].approachCaptured = true

        engine.step(dt: 0.1)

        #expect(!engine.aircraft[0].isLanded)
        #expect(engine.landedCount == 0)
    }

    @Test func conflictAlertsIncludeImmediateWarning() {
        let engine = makeEngine(with: SimulationScenario(id: "immediate-conflict", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY101",
                position: CGPoint(x: 200, y: 200),
                heading: 0,
                speed: 0,
                currentLevel: 50,
                selectedLevel: 50,
                isInbound: true
            ),
            makeScenarioAircraft(
                callsign: "BAW202",
                position: CGPoint(x: 220, y: 200),
                heading: 180,
                speed: 0,
                currentLevel: 55,
                selectedLevel: 55,
                isInbound: false
            )
        ]))

        engine.step(dt: 0.1)

        #expect(engine.activeAlerts.count == 1)
        #expect(engine.activeAlerts[0].severity == .warning)
        #expect(engine.activeAlerts[0].message == "Immediate separation risk")
        #expect(engine.score == 88)
    }

    @Test func conflictAlertsIncludeProjectedAdvisory() {
        let engine = makeEngine(with: SimulationScenario(id: "projected-conflict", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY303",
                position: CGPoint(x: 200, y: 200),
                heading: 0,
                speed: 20,
                currentLevel: 80,
                selectedLevel: 80,
                isInbound: true
            ),
            makeScenarioAircraft(
                callsign: "BAW404",
                position: CGPoint(x: 280, y: 200),
                heading: 180,
                speed: 20,
                currentLevel: 90,
                selectedLevel: 90,
                isInbound: false
            )
        ]))

        engine.step(dt: 0.1)

        #expect(engine.activeAlerts.count == 1)
        #expect(engine.activeAlerts[0].severity == .advisory)
        #expect(engine.activeAlerts[0].message == "Predicted loss of separation in 90s")
        #expect(engine.score == 95)
    }

    @Test func stripSyncUpdatesHeadingAndLevelFromAircraft() {
        let engine = makeEngine(with: SimulationScenario(id: "strip-sync", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY505",
                position: CGPoint(x: 300, y: 300),
                heading: 0,
                speed: 220,
                currentLevel: 70,
                selectedLevel: 70,
                isInbound: true
            )
        ]))

        engine.strips[0].selectedHeading = 90
        engine.strips[0].selectedLevel = 72

        engine.step(dt: 1.0)

        #expect(engine.aircraft[0].heading > 0)
        #expect(engine.aircraft[0].currentLevel == 72)
        #expect(engine.strips[0].currentHeading == Int(engine.aircraft[0].heading.rounded()))
        #expect(engine.strips[0].currentLevel == engine.aircraft[0].currentLevel)
    }

    @Test func resetScenarioRestoresStartupTrafficAndClearsOpsState() {
        let startupScenario = SimulationScenario(id: "reset-source", aircraft: [
            makeScenarioAircraft(
                callsign: "EZY777",
                position: CGPoint(x: 200, y: 200),
                heading: 0,
                speed: 0,
                currentLevel: 50,
                selectedLevel: 50,
                isInbound: true
            ),
            makeScenarioAircraft(
                callsign: "BAW888",
                position: CGPoint(x: 220, y: 200),
                heading: 180,
                speed: 0,
                currentLevel: 55,
                selectedLevel: 55,
                isInbound: false
            )
        ])

        let engine = makeEngine(with: startupScenario)

        engine.aircraft[0].isLanded = true
        engine.step(dt: 0.1)

        #expect(engine.landedCount == 1)
        #expect(!engine.activeAlerts.isEmpty)
        #expect(engine.score < 100)

        engine.aircraft.removeAll()
        engine.strips.removeAll()

        engine.resetScenario()

        #expect(engine.aircraft.map(\.callsign) == ["EZY777", "BAW888"])
        #expect(engine.strips.map(\.callsign) == ["EZY777", "BAW888"])
        #expect(engine.landedCount == 0)
        #expect(engine.activeAlerts.isEmpty)
        #expect(engine.score == 100)
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

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func makeEngine(with scenario: SimulationScenario = ScenarioLibrary.default) -> SimulationEngine {
        SimulationEngine(startupScenario: scenario)
    }

    private func makeScenarioAircraft(
        callsign: String,
        position: CGPoint,
        heading: Double,
        speed: Int,
        currentLevel: Int,
        selectedLevel: Int,
        isInbound: Bool
    ) -> ScenarioAircraftDefinition {
        ScenarioAircraftDefinition(
            callsign: callsign,
            aircraftType: "A320",
            position: position,
            heading: heading,
            groundSpeed: speed,
            currentLevel: currentLevel,
            selectedLevel: selectedLevel,
            trend: .level,
            destination: "EGKK",
            isInbound: isInbound
        )
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
