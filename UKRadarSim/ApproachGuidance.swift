import Foundation
import CoreGraphics

struct ApproachGuidance {
    struct Configuration {
        let courseHeading: Double
        let centerlineStart: CGPoint
        let runwayThreshold: CGPoint
        let localizerCaptureDistance: CGFloat
        let maxCaptureHeadingError: Double
        let headingConvergenceRate: Double
        let approachSpeedFloor: Int
        let landingDistance: CGFloat
        let maxLandingSpeed: Int
        let descentRateFLPerSecond: Double

        static let manchesterILS = Configuration(
            courseHeading: 34.5,
            centerlineStart: CGPoint(x: 180, y: 576),
            runwayThreshold: CGPoint(x: 790, y: 232),
            localizerCaptureDistance: 24,
            maxCaptureHeadingError: 35,
            headingConvergenceRate: 8,
            approachSpeedFloor: 145,
            landingDistance: 26,
            maxLandingSpeed: 150,
            descentRateFLPerSecond: 10
        )
    }

    private let config: Configuration
    private var descentProgressByAircraft: [UUID: Double] = [:]

    init(config: Configuration = .manchesterILS) {
        self.config = config
    }

    mutating func applyIfNeeded(aircraft: inout Aircraft, strip: inout EFPSStrip, dt: CGFloat) {
        guard aircraft.isInbound, strip.approachCleared, !aircraft.isLanded else {
            return
        }

        let position = CGPoint(x: aircraft.trueX, y: aircraft.trueY)
        handleLocalizerCapture(for: &aircraft, strip: &strip, position: position)

        guard aircraft.approachCaptured else {
            return
        }

        convergeHeadingOnLocalizer(for: &aircraft, dt: dt)
        manageApproachSpeed(for: &aircraft)
        updateDescentProfile(for: &aircraft, dt: dt)
        detectLandingIfNeeded(for: &aircraft, strip: &strip, position: position)
    }

    private mutating func handleLocalizerCapture(for aircraft: inout Aircraft, strip: inout EFPSStrip, position: CGPoint) {
        let distanceToLocalizer = distanceFromPoint(position, toSegmentFrom: config.centerlineStart, to: config.runwayThreshold)
        let headingError = angularDifference(aircraft.heading, config.courseHeading)

        guard !aircraft.approachCaptured,
              distanceToLocalizer < config.localizerCaptureDistance,
              headingError < config.maxCaptureHeadingError
        else {
            return
        }

        aircraft.approachCaptured = true
        strip.instructionLog.insert("\(aircraft.callsign) | LOC CAPTURED", at: 0)
    }

    private func convergeHeadingOnLocalizer(for aircraft: inout Aircraft, dt: CGFloat) {
        aircraft.heading = moveAngle(
            aircraft.heading,
            toward: config.courseHeading,
            maxDelta: Double(dt) * config.headingConvergenceRate
        )
    }

    private func manageApproachSpeed(for aircraft: inout Aircraft) {
        if aircraft.groundSpeed > config.approachSpeedFloor {
            aircraft.groundSpeed = max(config.approachSpeedFloor, aircraft.groundSpeed - 1)
        }
    }

    private mutating func updateDescentProfile(for aircraft: inout Aircraft, dt: CGFloat) {
        guard aircraft.currentLevel > 0 else {
            descentProgressByAircraft[aircraft.id] = 0
            aircraft.trend = .level
            return
        }

        descentProgressByAircraft[aircraft.id, default: 0] += config.descentRateFLPerSecond * Double(dt)

        while descentProgressByAircraft[aircraft.id, default: 0] >= 1.0, aircraft.currentLevel > 0 {
            aircraft.currentLevel -= 1
            descentProgressByAircraft[aircraft.id, default: 0] -= 1.0
        }

        aircraft.trend = aircraft.currentLevel == 0 ? .level : .descend
    }

    private func detectLandingIfNeeded(for aircraft: inout Aircraft, strip: inout EFPSStrip, position: CGPoint) {
        let distanceToThreshold = hypot(position.x - config.runwayThreshold.x, position.y - config.runwayThreshold.y)
        guard distanceToThreshold < config.landingDistance,
              aircraft.currentLevel == 0,
              aircraft.groundSpeed <= config.maxLandingSpeed
        else {
            return
        }

        aircraft.isLanded = true
        aircraft.groundSpeed = 0
        aircraft.trend = .level
        aircraft.trueX = config.runwayThreshold.x
        aircraft.trueY = config.runwayThreshold.y
        aircraft.displayX = config.runwayThreshold.x
        aircraft.displayY = config.runwayThreshold.y
        strip.instructionLog.insert("\(aircraft.callsign) | LANDED", at: 0)
    }

    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private func moveAngle(_ current: Double, toward target: Double, maxDelta: Double) -> Double {
        let delta = ((current - target + 540).truncatingRemainder(dividingBy: 360)) - 180
        let clamped = min(max(delta, -maxDelta), maxDelta)
        var adjusted = current + clamped
        if adjusted < 0 { adjusted += 360 }
        if adjusted >= 360 { adjusted -= 360 }
        return adjusted
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}
