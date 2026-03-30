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

    @Test func pointProjectionUsesReferenceOrigin() {
        let origin = GeoPoint(latitude: 51.0, longitude: -0.1)
        let point = GeoPoint(latitude: 51.01, longitude: -0.1)

        let projected = GeoProjection.project(point, relativeTo: origin)

        #expect(abs(projected.x) < 0.1)
        #expect(abs(projected.y - 1_111.95) < 5)
    }

    @Test func arcGenerationProducesExpectedSweepAndRadius() {
        let center = GeoPoint(latitude: 51.0, longitude: -0.1)
        let arc = ArcSegment(
            center: center,
            radiusMeters: 10 * 1_852,
            startBearingDegrees: 0,
            endBearingDegrees: 90,
            clockwise: false
        )

        let samples = arc.sample(stepDegrees: 30)

        #expect(samples.count == 4)
        let first = GeoProjection.project(samples[0], relativeTo: center)
        let last = GeoProjection.project(samples[samples.count - 1], relativeTo: center)
        let firstDistance = hypot(first.x, first.y)
        let lastDistance = hypot(last.x, last.y)

        #expect(abs(firstDistance - (10 * 1_852)) < 20)
        #expect(abs(lastDistance - (10 * 1_852)) < 20)
        #expect(abs(last.x - (10 * 1_852)) < 80)
        #expect(abs(last.y) < 80)
    }

    @Test func polygonIsClosedWhenRequested() throws {
        let segments = try AirspaceGeometryParser.parseSegments(from: [
            "LINE 510000N0000000W 510000N0001000W",
            "LINE 510000N0001000W 510600N0001000W",
            "LINE 510600N0001000W 510000N0000000W"
        ])
        let origin = GeoPoint(latitude: 51.0, longitude: 0.0)

        let polygon = BoundaryGeometryBuilder.toPlanarPolygon(
            segments: segments,
            origin: origin,
            closePolygon: true
        )

        #expect(polygon.first == polygon.last)
    }

    @Test func boundingBoxTracksExtents() {
        let bounds = BoundaryGeometryBuilder.boundingBox(
            for: [
                PlanarPoint(x: 100, y: -200),
                PlanarPoint(x: -50, y: 75),
                PlanarPoint(x: 80, y: 300)
            ]
        )

        #expect(bounds == PlanarBounds(minX: -50, maxX: 100, minY: -200, maxY: 300))
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
