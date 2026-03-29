import SwiftUI

struct RadarCanvasView: View {
    let aircraft: [Aircraft]
    let vectorSetting: VectorSetting

    var body: some View {
        GeometryReader { geo in
            ZStack {
                radarBackground
                radarMap(in: geo.size)
                vectorLayer
                aircraftLayer
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

            // Simple Gatwick-style final approach centreline
            var centerline = Path()
            centerline.move(to: CGPoint(x: w * 0.18, y: h * 0.72))
            centerline.addLine(to: CGPoint(x: w * 0.82, y: h * 0.28))
            context.stroke(centerline, with: .color(.white.opacity(0.75)), lineWidth: 1.2)

            // Small runway marker near the end of the centreline
            var runway = Path()
            runway.move(to: CGPoint(x: w * 0.74, y: h * 0.34))
            runway.addLine(to: CGPoint(x: w * 0.79, y: h * 0.29))
            context.stroke(runway, with: .color(.white.opacity(0.95)), lineWidth: 2)

            // Tick marks on final
            let tickPoints: [CGPoint] = [
                CGPoint(x: w * 0.30, y: h * 0.62),
                CGPoint(x: w * 0.42, y: h * 0.54),
                CGPoint(x: w * 0.54, y: h * 0.46),
                CGPoint(x: w * 0.66, y: h * 0.38)
            ]

            for point in tickPoints {
                var tick = Path()
                tick.move(to: CGPoint(x: point.x - 6, y: point.y + 6))
                tick.addLine(to: CGPoint(x: point.x + 6, y: point.y - 6))
                context.stroke(tick, with: .color(.white.opacity(0.45)), lineWidth: 1)
            }

            // Example dashed controlled airspace polygon
            var cas = Path()
            cas.move(to: CGPoint(x: w * 0.15, y: h * 0.78))
            cas.addLine(to: CGPoint(x: w * 0.28, y: h * 0.18))
            cas.addLine(to: CGPoint(x: w * 0.72, y: h * 0.12))
            cas.addLine(to: CGPoint(x: w * 0.88, y: h * 0.48))
            cas.addLine(to: CGPoint(x: w * 0.70, y: h * 0.86))
            cas.addLine(to: CGPoint(x: w * 0.22, y: h * 0.88))
            cas.closeSubpath()

            context.stroke(
                cas,
                with: .color(.white.opacity(0.28)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
        }
    }

    private var vectorLayer: some View {
        Canvas { context, _ in
            guard vectorSetting != .off else { return }

            for item in aircraft {
                let endpoint = vectorEndpoint(for: item, lookaheadSeconds: vectorSetting.lookaheadSeconds)
                var path = Path()
                path.move(to: CGPoint(x: item.displayX, y: item.displayY))
                path.addLine(to: endpoint)
                context.stroke(path, with: .color(Color.cyan.opacity(0.55)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }

    private var aircraftLayer: some View {
        ForEach(aircraft) { aircraft in
            AircraftTrackView(aircraft: aircraft)
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(aircraft.historyDots.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(Color.white.opacity(dotOpacity(for: index)))
                    .frame(width: 4, height: 4)
                    .position(x: point.x, y: point.y)
            }

            // Aircraft symbol
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .position(x: aircraft.displayX, y: aircraft.displayY)

            // Leader line
            Path { path in
                path.move(to: CGPoint(x: aircraft.displayX + 4, y: aircraft.displayY - 4))
                path.addLine(to: CGPoint(x: aircraft.displayX + 26, y: aircraft.displayY - 22))
            }
            .stroke(Color.white.opacity(0.85), lineWidth: 1)

            // Label
            GatwickStyleLabel(aircraft: aircraft)
                .position(x: aircraft.displayX + 92, y: aircraft.displayY - 42)
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
                Text("F\(formatLevel(aircraft.currentLevel)) ")
                    .foregroundColor(.white)
                +
                Text("\(aircraft.trend.symbol) ")
                    .foregroundColor(.white)
                +
                Text(formatSelectedLevel(aircraft.selectedLevel))
                    .foregroundColor(.orange)
            )
            .font(.system(size: 13, weight: .medium, design: .monospaced))

            Text("G\(aircraft.groundSpeed) \(aircraft.destination)")
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
}
