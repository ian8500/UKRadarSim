import Foundation
import CoreGraphics

struct SimConfig {
    struct LocalizerCapture {
        var maxDistancePixels: CGFloat
        var maxHeadingErrorDegrees: Double
    }

    struct Landing {
        var maxDistanceToThresholdPixels: CGFloat
        var maxTouchdownSpeedKnots: Int
    }

    var movementTickSeconds: TimeInterval
    var radarRefreshIntervalSeconds: TimeInterval
    var pixelsPerKnot: CGFloat

    var headingTurnRateDegreesPerSecond: Double
    var approachHeadingTurnRateDegreesPerSecond: Double

    var climbDescentRateFLPerSecond: Double

    var accelerationRateKnotsPerSecond: Double
    var decelerationRateKnotsPerSecond: Double

    var localizerCapture: LocalizerCapture

    var approachTargetGroundSpeedKnots: Int
    var approachDecelerationKnotsPerTick: Int
    var approachDescentFLPerTick: Int

    var landing: Landing

    static let `default` = SimConfig(
        movementTickSeconds: 0.1,
        radarRefreshIntervalSeconds: 6.0,
        pixelsPerKnot: 0.02,
        headingTurnRateDegreesPerSecond: 3.0,
        approachHeadingTurnRateDegreesPerSecond: 8.0,
        climbDescentRateFLPerSecond: 0.2,
        accelerationRateKnotsPerSecond: 8.0,
        decelerationRateKnotsPerSecond: 10.0,
        localizerCapture: .init(
            maxDistancePixels: 24,
            maxHeadingErrorDegrees: 35
        ),
        approachTargetGroundSpeedKnots: 145,
        approachDecelerationKnotsPerTick: 1,
        approachDescentFLPerTick: 1,
        landing: .init(
            maxDistanceToThresholdPixels: 26,
            maxTouchdownSpeedKnots: 150
        )
    )
}
