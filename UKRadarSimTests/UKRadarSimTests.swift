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

    @Test func mapTransformProducesDeterministicOriginScaleAndBounds() {
        let geometry = AirportMapCatalog.geometry(for: "EGKK")
        let transform = geometry.mapTransform(in: CGSize(width: 1200, height: 900), zoomScale: 1.25)

        #expect(transform.origin.x == 0)
        #expect(transform.origin.y == 0)
        #expect(transform.scale.width == 1.5)
        #expect(transform.scale.height == 1.40625)
        #expect(transform.bounds == CGRect(x: 0, y: 0, width: 1200, height: 900))
    }

    @Test func validationProjectionContainsStableFixAndReferenceGeometry() {
        let geometry = AirportMapCatalog.geometry(for: "EGKK")
        let projection = geometry.mapValidationProjection(in: CGSize(width: 1000, height: 800), zoomScale: 1.0)

        #expect(projection.runwayThreshold == CGPoint(x: 760, y: 400))
        #expect(projection.projectedOppositeRunwayThreshold == CGPoint(x: 1420, y: 368))
        #expect(projection.airportReferencePoint == CGPoint(x: 680.8, y: 396.16))
        #expect(projection.selectedFixes.count == 3)
        #expect(projection.selectedFixes.map(\.name) == ["L9", "M23", "UL607"])
        #expect(projection.controlledAirspaceVertices.count == geometry.controlledAirspacePolygonFractions.count)
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
