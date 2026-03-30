import CoreGraphics

struct RadarNamedPoint: Equatable {
    let name: String
    let fraction: CGPoint
}

struct RadarProjectedNamedPoint: Equatable {
    let name: String
    let viewPoint: CGPoint
}

struct RadarMapTransform: Equatable {
    let origin: CGPoint
    let scale: CGSize
    let bounds: CGRect
}

struct RadarMapValidationProjection: Equatable {
    let runwayThreshold: CGPoint
    let projectedOppositeRunwayThreshold: CGPoint
    let airportReferencePoint: CGPoint
    let selectedFixes: [RadarProjectedNamedPoint]
    let controlledAirspaceVertices: [CGPoint]
    let namedReferencePoints: [RadarProjectedNamedPoint]
}

extension RadarGeometry {
    var airportReferencePointFraction: CGPoint {
        CGPoint(
            x: (runwayThresholdFraction.x * 0.88) + (centerlineStartFraction.x * 0.12),
            y: (runwayThresholdFraction.y * 0.88) + (centerlineStartFraction.y * 0.12)
        )
    }

    var namedReferencePoints: [RadarNamedPoint] {
        [
            RadarNamedPoint(name: "THR", fraction: runwayThresholdFraction),
            RadarNamedPoint(name: "ARP", fraction: airportReferencePointFraction),
            RadarNamedPoint(name: "LOC10", fraction: centerlineStartFraction)
        ]
    }

    var selectedFixes: [RadarNamedPoint] {
        surroundingAirways.prefix(3).compactMap { airway in
            guard let midpoint = airway.waypoints.dropFirst().first else { return nil }
            return RadarNamedPoint(name: airway.identifier, fraction: midpoint)
        }
    }

    func mapTransform(in viewSize: CGSize, zoomScale: CGFloat) -> RadarMapTransform {
        let xScale = viewSize.width / worldSize.width
        let yScale = viewSize.height / worldSize.height
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let scaledWorldWidth = worldSize.width * xScale * zoomScale
        let scaledWorldHeight = worldSize.height * yScale * zoomScale
        let origin = CGPoint(
            x: center.x - (scaledWorldWidth / 2),
            y: center.y - (scaledWorldHeight / 2)
        )
        let bounds = CGRect(origin: origin, size: CGSize(width: scaledWorldWidth, height: scaledWorldHeight))
        return RadarMapTransform(origin: origin, scale: CGSize(width: xScale * zoomScale, height: yScale * zoomScale), bounds: bounds)
    }

    func mapValidationProjection(in viewSize: CGSize, zoomScale: CGFloat) -> RadarMapValidationProjection {
        let threshold = zoomedValidationPoint(inViewFromWorld: runwayThreshold, viewSize: viewSize, zoomScale: zoomScale)
        let centerlineStartPoint = zoomedValidationPoint(inViewFromWorld: centerlineStart, viewSize: viewSize, zoomScale: zoomScale)
        let oppositeThreshold = CGPoint(
            x: threshold.x + (threshold.x - centerlineStartPoint.x),
            y: threshold.y + (threshold.y - centerlineStartPoint.y)
        )

        return RadarMapValidationProjection(
            runwayThreshold: threshold,
            projectedOppositeRunwayThreshold: oppositeThreshold,
            airportReferencePoint: zoomedValidationPoint(inViewFromFraction: airportReferencePointFraction, viewSize: viewSize, zoomScale: zoomScale),
            selectedFixes: selectedFixes.map {
                RadarProjectedNamedPoint(name: $0.name, viewPoint: zoomedValidationPoint(inViewFromFraction: $0.fraction, viewSize: viewSize, zoomScale: zoomScale))
            },
            controlledAirspaceVertices: controlledAirspacePolygonFractions.map {
                zoomedValidationPoint(inViewFromFraction: $0, viewSize: viewSize, zoomScale: zoomScale)
            },
            namedReferencePoints: namedReferencePoints.map {
                RadarProjectedNamedPoint(name: $0.name, viewPoint: zoomedValidationPoint(inViewFromFraction: $0.fraction, viewSize: viewSize, zoomScale: zoomScale))
            }
        )
    }

    private func zoomedValidationPoint(inViewFromWorld worldPoint: CGPoint, viewSize: CGSize, zoomScale: CGFloat) -> CGPoint {
        let basePoint = point(inViewFromWorld: worldPoint, viewSize: viewSize)
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        return CGPoint(
            x: viewCenter.x + ((basePoint.x - viewCenter.x) * zoomScale),
            y: viewCenter.y + ((basePoint.y - viewCenter.y) * zoomScale)
        )
    }

    private func zoomedValidationPoint(inViewFromFraction fraction: CGPoint, viewSize: CGSize, zoomScale: CGFloat) -> CGPoint {
        zoomedValidationPoint(inViewFromWorld: point(inWorldFromFraction: fraction), viewSize: viewSize, zoomScale: zoomScale)
    }
}
