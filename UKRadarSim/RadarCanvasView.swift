import SwiftUI

struct RadarCanvasView: View {
    let aircraft: [Aircraft]
    let vectorSetting: VectorSetting
    let geometry: RadarGeometry

    private let predictor = AircraftPredictor()
    @State private var preRenderedMapImage: Image?
    @State private var cachedMapSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                radarBackground
                radarMap(in: geo.size)
                vectorLayer(in: geo.size)
                aircraftLayer(in: geo.size)
            }
            .clipped()
            .onAppear { updatePreRenderedMapIfNeeded(size: geo.size) }
            .onChange(of: geo.size) { _, newSize in
                updatePreRenderedMapIfNeeded(size: newSize)
            }
        }
    }

    private var radarBackground: some View {
        Color(red: 0.02, green: 0.18, blue: 0.22)
    }

    @ViewBuilder
    private func radarMap(in size: CGSize) -> some View {
        if let preRenderedMapImage {
            preRenderedMapImage
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
        } else {
            MapOverlayRenderer(geometry: geometry, size: size)
        }
    }

    private func updatePreRenderedMapIfNeeded(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard cachedMapSize != size || preRenderedMapImage == nil else { return }

        let renderer = ImageRenderer(content: MapOverlayRenderer(geometry: geometry, size: size))
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        if let rendered = renderer.uiImage {
            preRenderedMapImage = Image(uiImage: rendered)
            cachedMapSize = size
        }
    }

    private func centroid(for polygon: [CGPoint]) -> CGPoint {
        guard !polygon.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
        let sums = polygon.reduce((x: CGFloat.zero, y: CGFloat.zero)) { partial, point in
            (partial.x + point.x, partial.y + point.y)
        }
        return CGPoint(x: sums.x / CGFloat(polygon.count), y: sums.y / CGFloat(polygon.count))
    }

    private func vectorLayer(in size: CGSize) -> some View {
        Canvas { context, _ in
            guard vectorSetting != .off else { return }

            for item in aircraft {
                let worldStart = CGPoint(x: item.displayX, y: item.displayY)
                let worldEnd = vectorEndpoint(for: item, lookaheadSeconds: vectorSetting.lookaheadSeconds)

                var path = Path()
                path.move(to: geometry.point(inViewFromWorld: worldStart, viewSize: size))
                path.addLine(to: geometry.point(inViewFromWorld: worldEnd, viewSize: size))
                context.stroke(path, with: .color(Color.cyan.opacity(0.55)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }

    private func aircraftLayer(in size: CGSize) -> some View {
        ForEach(aircraft) { aircraft in
            AircraftTrackView(
                aircraft: aircraft,
                displayPoint: geometry.point(
                    inViewFromWorld: CGPoint(x: aircraft.displayX, y: aircraft.displayY),
                    viewSize: size
                ),
                historyPoints: aircraft.historyDots.map { geometry.point(inViewFromWorld: $0, viewSize: size) }
            )
        }
    }

    private func vectorEndpoint(for aircraft: Aircraft, lookaheadSeconds: Double) -> CGPoint {
        MotionProjection.project(
            from: CGPoint(x: aircraft.displayX, y: aircraft.displayY),
            headingDegrees: aircraft.heading,
            groundSpeed: aircraft.groundSpeed,
            elapsedSeconds: CGFloat(lookaheadSeconds)
        )
    }
}

private struct MapOverlayRenderer: View {
    let geometry: RadarGeometry
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let center = CGPoint(x: w / 2, y: h / 2)

            let ringRadii: [CGFloat] = [120, 220, 320]
            for radius in ringRadii {
                var path = Path()
                path.addEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(path, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            }

            for sector in geometry.terrainSectors {
                var terrainPath = Path()
                if let first = sector.polygonFractions.first {
                    terrainPath.move(to: geometry.point(inViewFromFraction: first, viewSize: size))
                    for point in sector.polygonFractions.dropFirst() {
                        terrainPath.addLine(to: geometry.point(inViewFromFraction: point, viewSize: size))
                    }
                    terrainPath.closeSubpath()
                }
                context.fill(terrainPath, with: .color(Color.brown.opacity(0.15)))
                context.stroke(terrainPath, with: .color(Color.orange.opacity(0.30)), lineWidth: 0.8)
                if !sector.polygonFractions.isEmpty {
                    let centroid = centroid(for: sector.polygonFractions)
                    let point = geometry.point(inViewFromFraction: centroid, viewSize: size)
                    let text = Text(sector.minimumAltitudeLabel)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.95))
                    context.draw(text, at: point)
                }
            }

            var ctr = Path()
            if let firstPoint = geometry.controlledAirspacePolygonFractions.first {
                ctr.move(to: geometry.point(inViewFromFraction: firstPoint, viewSize: size))
                for point in geometry.controlledAirspacePolygonFractions.dropFirst() {
                    ctr.addLine(to: geometry.point(inViewFromFraction: point, viewSize: size))
                }
                ctr.closeSubpath()
            }
            context.stroke(ctr, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))

            for shelf in geometry.controlledAirspaceShelves {
                var shelfPath = Path()
                if let firstPoint = shelf.polygonFractions.first {
                    shelfPath.move(to: geometry.point(inViewFromFraction: firstPoint, viewSize: size))
                    for point in shelf.polygonFractions.dropFirst() {
                        shelfPath.addLine(to: geometry.point(inViewFromFraction: point, viewSize: size))
                    }
                    shelfPath.closeSubpath()
                }
                context.fill(shelfPath, with: .color(Color.cyan.opacity(0.08)))
                context.stroke(shelfPath, with: .color(.cyan.opacity(0.35)), style: StrokeStyle(lineWidth: 0.9, dash: [4, 4]))
                if !shelf.polygonFractions.isEmpty {
                    let centroid = centroid(for: shelf.polygonFractions)
                    let point = geometry.point(inViewFromFraction: centroid, viewSize: size)
                    let text = Text("\(shelf.floorLabel)-\(shelf.ceilingLabel)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.95))
                    context.draw(text, at: point)
                }
            }

            for airway in geometry.surroundingAirways {
                guard let first = airway.waypoints.first else { continue }
                var airwayPath = Path()
                airwayPath.move(to: geometry.point(inViewFromFraction: first, viewSize: size))
                for waypoint in airway.waypoints.dropFirst() {
                    airwayPath.addLine(to: geometry.point(inViewFromFraction: waypoint, viewSize: size))
                }

                context.stroke(airwayPath, with: .color(.mint.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 6]))

                let labelPointFraction = airway.waypoints[airway.waypoints.count / 2]
                let labelPoint = geometry.point(inViewFromFraction: labelPointFraction, viewSize: size)
                let text = Text(airway.identifier)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.mint.opacity(0.95))
                context.draw(text, at: CGPoint(x: labelPoint.x + 10, y: labelPoint.y - 8))
            }

            var centerline = Path()
            centerline.move(to: geometry.point(inViewFromWorld: geometry.centerlineStart, viewSize: size))
            centerline.addLine(to: geometry.point(inViewFromWorld: geometry.runwayThreshold, viewSize: size))
            context.stroke(centerline, with: .color(.white.opacity(0.75)), lineWidth: 1.2)
        }
        .frame(width: size.width, height: size.height)
    }

    private func centroid(for polygon: [CGPoint]) -> CGPoint {
        guard !polygon.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
        let sums = polygon.reduce((x: CGFloat.zero, y: CGFloat.zero)) { partial, point in
            (partial.x + point.x, partial.y + point.y)
        }
        return CGPoint(x: sums.x / CGFloat(polygon.count), y: sums.y / CGFloat(polygon.count))
    }
}

struct AircraftTrackView: View {
    let aircraft: Aircraft
    let displayPoint: CGPoint
    let historyPoints: [CGPoint]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(historyPoints.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(Color.white.opacity(dotOpacity(for: index)))
                    .frame(width: 4, height: 4)
                    .position(x: point.x, y: point.y)
            }

            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .position(x: displayPoint.x, y: displayPoint.y)

            Path { path in
                path.move(to: CGPoint(x: displayPoint.x + 4, y: displayPoint.y - 4))
                path.addLine(to: CGPoint(x: displayPoint.x + 26, y: displayPoint.y - 22))
            }
            .stroke(Color.white.opacity(0.85), lineWidth: 1)

            GatwickStyleLabel(aircraft: aircraft)
                .position(x: displayPoint.x + 92, y: displayPoint.y - 42)
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let baseOpacity = 0.6 - (Double(index) * 0.08)
        return max(0.15, baseOpacity)
    }
}

struct GatwickStyleLabel: View {
    let aircraft: Aircraft

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(aircraft.callsign)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            (
                Text("F\(formatLevel(displayLevel)) ")
                    .foregroundColor(.white)
                +
                Text("\(aircraft.trend.symbol) ")
                    .foregroundColor(.white)
                +
                Text(formatSelectedLevel(aircraft.selectedLevel))
                    .foregroundColor(.orange)
            )
            .font(.system(size: 13, weight: .medium, design: .monospaced))

            Text("G\(displaySpeed) \(aircraft.destination)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func formatLevel(_ level: Int) -> String {
        String(format: "%03d", level)
    }

    private func formatSelectedLevel(_ level: Int) -> String {
        String(format: "%03d", level)
    }

    private var displayLevel: Int {
        guard aircraft.trend != .level else { return aircraft.currentLevel }
        return roundedToNearestFive(aircraft.currentLevel)
    }

    private var displaySpeed: Int {
        guard aircraft.trend != .level else { return aircraft.groundSpeed }
        return roundedToNearestFive(aircraft.groundSpeed)
    }

    private func roundedToNearestFive(_ value: Int) -> Int {
        max(0, Int((Double(value) / 5.0).rounded() * 5.0))
    }
}
