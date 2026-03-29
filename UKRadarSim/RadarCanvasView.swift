import SwiftUI

struct RadarCanvasView: View {
    let aircraft: [Aircraft]
    let vectorSetting: VectorSetting
    let geometry: RadarGeometry

    private let predictor = AircraftPredictor()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                radarBackground
                radarMap(in: geo.size)
                vectorLayer(in: geo.size)
                aircraftLayer(in: geo.size)
            }
            .clipped()
        }
    }

    private var radarBackground: some View {
        Color(red: 0.02, green: 0.18, blue: 0.22)
    }

    @ViewBuilder
    private func radarMap(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let center = CGPoint(x: w / 2, y: h / 2)

            // Range rings
            let ringRadii: [CGFloat] = [120, 220, 320]
            for radius in ringRadii {
                var path = Path()
                path.addEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))

                context.stroke(
                    path,
                    with: .color(.white.opacity(0.18)),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                )
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

            var centerline = Path()
            centerline.move(to: geometry.point(inViewFromWorld: geometry.centerlineStart, viewSize: size))
            centerline.addLine(to: geometry.point(inViewFromWorld: geometry.runwayThreshold, viewSize: size))
            context.stroke(centerline, with: .color(.white.opacity(0.75)), lineWidth: 1.2)

            var runway = Path()
            runway.move(to: geometry.point(inViewFromFraction: CGPoint(x: 0.74, y: 0.34), viewSize: size))
            runway.addLine(to: geometry.point(inViewFromFraction: CGPoint(x: 0.79, y: 0.29), viewSize: size))
            context.stroke(runway, with: .color(.white.opacity(0.95)), lineWidth: 2)

            let tickPoints: [CGPoint] = [
                CGPoint(x: 0.30, y: 0.62),
                CGPoint(x: 0.42, y: 0.54),
                CGPoint(x: 0.54, y: 0.46),
                CGPoint(x: 0.66, y: 0.38)
            ]

            for point in tickPoints {
                let viewPoint = geometry.point(inViewFromFraction: point, viewSize: size)
                var tick = Path()
                tick.move(to: CGPoint(x: viewPoint.x - 6, y: viewPoint.y + 6))
                tick.addLine(to: CGPoint(x: viewPoint.x + 6, y: viewPoint.y - 6))
                context.stroke(tick, with: .color(.white.opacity(0.45)), lineWidth: 1)
            }

            var cas = Path()
            if let firstPoint = geometry.controlledAirspacePolygonFractions.first {
                cas.move(to: geometry.point(inViewFromFraction: firstPoint, viewSize: size))
                for point in geometry.controlledAirspacePolygonFractions.dropFirst() {
                    cas.addLine(to: geometry.point(inViewFromFraction: point, viewSize: size))
                }
                cas.closeSubpath()
            }

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
                context.stroke(
                    shelfPath,
                    with: .color(.cyan.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 0.9, dash: [4, 4])
                )

                if !shelf.polygonFractions.isEmpty {
                    let centroid = centroid(for: shelf.polygonFractions)
                    let point = geometry.point(inViewFromFraction: centroid, viewSize: size)
                    let text = Text("\(shelf.floorLabel)-\(shelf.ceilingLabel)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.95))
                    context.draw(text, at: point)
                }
            }

            context.stroke(
                cas,
                with: .color(.white.opacity(0.28)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
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
