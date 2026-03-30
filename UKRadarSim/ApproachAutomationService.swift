import Foundation
import CoreGraphics

struct ApproachAutomationConfig {
    struct LocalizerCapture {
        let maxDistancePixels: CGFloat
        let maxHeadingErrorDegrees: Double
    }

    struct Landing {
        let maxDistanceToThresholdPixels: CGFloat
        let maxTouchdownSpeedKnots: Int
    }

    let approachTargetGroundSpeedKnots: Int
    let approachDecelerationKnotsPerTick: Int
    let approachDescentFLPerTick: Int
    let headingTurnRateDegreesPerSecond: Double
    let localizerCapture: LocalizerCapture
    let landing: Landing

    static let `default` = ApproachAutomationConfig(
        approachTargetGroundSpeedKnots: 160,
        approachDecelerationKnotsPerTick: 2,
        approachDescentFLPerTick: 1,
        headingTurnRateDegreesPerSecond: 8,
        localizerCapture: .init(maxDistancePixels: 24, maxHeadingErrorDegrees: 35),
        landing: .init(maxDistanceToThresholdPixels: 18, maxTouchdownSpeedKnots: 165)
    )
}

struct ApproachAutomationService {
    struct Outcome {
        let didCaptureLocalizer: Bool
        let didLand: Bool
    }

    let config: ApproachAutomationConfig

    init(config: ApproachAutomationConfig = .default) {
        self.config = config
    }

    func apply(
        to aircraft: inout Aircraft,
        strip: EFPSStrip,
        geometry: RadarGeometry,
        dt: CGFloat
    ) -> Outcome {
        guard aircraft.isInbound, strip.approachCleared else {
            return Outcome(didCaptureLocalizer: false, didLand: false)
        }

        let position = CGPoint(x: aircraft.trueX, y: aircraft.trueY)

        let distanceToLocalizer = distanceFromPoint(
            position,
            toSegmentFrom: geometry.centerlineStart,
            to: geometry.runwayThreshold
        )

        let headingError = angularDifference(aircraft.heading, geometry.approachCourseHeading)
        var didCaptureLocalizer = false

        if !aircraft.approachCaptured,
           distanceToLocalizer < config.localizerCapture.maxDistancePixels,
           headingError < config.localizerCapture.maxHeadingErrorDegrees {
            aircraft.approachCaptured = true
            didCaptureLocalizer = true
        }

        guard aircraft.approachCaptured else {
            return Outcome(didCaptureLocalizer: didCaptureLocalizer, didLand: false)
        }

        aircraft.heading = moveAngle(
            aircraft.heading,
            toward: geometry.approachCourseHeading,
            maxDelta: Double(dt) * config.headingTurnRateDegreesPerSecond
        )

        if aircraft.groundSpeed > config.approachTargetGroundSpeedKnots {
            aircraft.groundSpeed = max(
                config.approachTargetGroundSpeedKnots,
                aircraft.groundSpeed - config.approachDecelerationKnotsPerTick
            )
        }

        if aircraft.currentLevel > 0 {
            aircraft.currentLevel = max(0, aircraft.currentLevel - config.approachDescentFLPerTick)
            aircraft.trend = aircraft.currentLevel == 0 ? .level : .descend
        }

        let runwayThreshold = geometry.runwayThreshold
        let distanceToThreshold = hypot(position.x - runwayThreshold.x, position.y - runwayThreshold.y)

        if distanceToThreshold < config.landing.maxDistanceToThresholdPixels,
           aircraft.currentLevel == 0,
           aircraft.groundSpeed <= config.landing.maxTouchdownSpeedKnots {
            aircraft.isLanded = true
            aircraft.groundSpeed = 0
            aircraft.trend = .level
            aircraft.trueX = runwayThreshold.x
            aircraft.trueY = runwayThreshold.y
            aircraft.displayX = runwayThreshold.x
            aircraft.displayY = runwayThreshold.y
            return Outcome(didCaptureLocalizer: didCaptureLocalizer, didLand: true)
        }

        return Outcome(didCaptureLocalizer: didCaptureLocalizer, didLand: false)
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y

        guard dx != 0 || dy != 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func moveAngle(_ current: Double, toward target: Double, maxDelta: Double) -> Double {
        let delta = ((target - current + 540).truncatingRemainder(dividingBy: 360)) - 180
        let clamped = min(max(delta, -maxDelta), maxDelta)
        var adjusted = current + clamped

        if adjusted < 0 { adjusted += 360 }
        if adjusted >= 360 { adjusted -= 360 }

        return adjusted
    }
}
