import Foundation
import CoreGraphics

enum MotionProjection {
    static let speedScale: CGFloat = 0.02

    static func displacement(headingDegrees: Double, groundSpeed: Int, elapsedSeconds: CGFloat) -> CGVector {
        let headingRad = CGFloat(headingDegrees * .pi / 180.0)
        let distance = CGFloat(groundSpeed) * speedScale * elapsedSeconds

        return CGVector(
            dx: cos(headingRad) * distance,
            dy: -sin(headingRad) * distance
        )
    }

    static func project(from start: CGPoint, headingDegrees: Double, groundSpeed: Int, elapsedSeconds: CGFloat) -> CGPoint {
        let delta = displacement(
            headingDegrees: headingDegrees,
            groundSpeed: groundSpeed,
            elapsedSeconds: elapsedSeconds
        )

        return CGPoint(x: start.x + delta.dx, y: start.y + delta.dy)
    }
}
