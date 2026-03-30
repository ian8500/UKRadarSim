import SwiftUI
import Foundation

struct RadarCanvasView: View {
    let aircraft: [Aircraft]
    let vectorSetting: VectorSetting
    let predictedVectorEndpoint: (Aircraft, Double) -> CGPoint
    let showsControlledAirspaceBase: Bool
    let showsTerrainMap: Bool
    let mapValidationMode: Bool
    let showsMapDebugLabels: Bool
    let visibleControlledAirspaceFloors: Set<String>
    let geometry: RadarGeometry

    @State private var zoomScale: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0

    private let minZoom: CGFloat = 0.6
    private let maxZoom: CGFloat = 3.0
    private let referenceRangeNM: CGFloat = 20
    private let mapPadding: CGFloat = 36
    var body: some View {
        GeometryReader { geo in
            let viewport = RadarViewport(
                geometry: geometry,
                viewSize: geo.size,
                zoomScale: effectiveZoom,
                panOffset: .zero
            )

            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RadarBackgroundLayer()
                    RadarMapLayer(
                        geometry: geometry,
                        size: geo.size,
                        zoomScale: effectiveZoom,
                        mapPadding: mapPadding,
                        showsControlledAirspaceBase: showsControlledAirspaceBase,
                        showsTerrainMap: showsTerrainMap,
                        showsDebugOverlays: showsMapDebugLabels,
                        visibleControlledAirspaceFloors: visibleControlledAirspaceFloors
                    )
                    RadarVectorLayer(aircraft: aircraft, vectorSetting: vectorSetting, viewport: viewport)
                    RadarTrackLayer(aircraft: aircraft, viewport: viewport)
                    RadarLabelLayer(aircraft: aircraft, viewport: viewport)
                }
                .gesture(
                    MagnificationGesture()
                        .updating($pinchScale) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            zoomScale = clampedZoom(zoomScale * value)
                        }
                )

                RadarScaleOverlay(
                    viewSize: geo.size,
                    effectiveZoom: effectiveZoom,
                    referenceRangeNM: referenceRangeNM,
                    zoomOutAction: { zoomScale = clampedZoom(zoomScale * 0.85) },
                    zoomInAction: { zoomScale = clampedZoom(zoomScale * 1.15) }
                )
                .padding(12)
            }
            .clipped()
        }
    }

    private var effectiveZoom: CGFloat {
        clampedZoom(zoomScale * pinchScale)
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, minZoom), maxZoom)
    }
}

private struct RadarViewport {
    let geometry: RadarGeometry
    let viewSize: CGSize
    let zoomScale: CGFloat
    let panOffset: CGSize

    func viewPoint(fromWorld worldPoint: CGPoint) -> CGPoint {
        let basePoint = geometry.point(inViewFromWorld: worldPoint, viewSize: viewSize)
        let viewCenter = CGPoint(
            x: (viewSize.width / 2) + panOffset.width,
            y: (viewSize.height / 2) + panOffset.height
        )
        return CGPoint(
            x: viewCenter.x + ((basePoint.x - (viewSize.width / 2)) * zoomScale),
            y: viewCenter.y + ((basePoint.y - (viewSize.height / 2)) * zoomScale)
        )
    }

    func viewPoint(fromFraction fraction: CGPoint) -> CGPoint {
        viewPoint(fromWorld: geometry.point(inWorldFromFraction: fraction))
    }
}

private struct RadarBackgroundLayer: View {
    var body: some View {
        Color(red: 0.02, green: 0.18, blue: 0.22)
    }
}

private struct RadarMapLayer: View {
    let geometry: RadarGeometry
    let size: CGSize
    let zoomScale: CGFloat
    let mapPadding: CGFloat
    let showsControlledAirspaceBase: Bool
    let showsTerrainMap: Bool
    let showsDebugOverlays: Bool
    let visibleControlledAirspaceFloors: Set<String>

    @State private var preRenderedMapImage: Image?
    @State private var cachedMapSize: CGSize = .zero

    var body: some View {
        Group {
            if let preRenderedMapImage, zoomScale == 1 {
                preRenderedMapImage
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
            } else {
                MapOverlayRenderer(
                    geometry: geometry,
                    size: size,
                    zoomScale: zoomScale,
                    mapPadding: mapPadding,
                    showsControlledAirspaceBase: showsControlledAirspaceBase,
                    showsTerrainMap: showsTerrainMap,
                    showsDebugOverlays: showsDebugOverlays,
                    visibleControlledAirspaceFloors: visibleControlledAirspaceFloors
                )
            }
        }
        .onAppear { updatePreRenderedMapIfNeeded() }
        .onChange(of: size) { _, _ in updatePreRenderedMapIfNeeded() }
        .onChange(of: showsTerrainMap) { _, _ in
            preRenderedMapImage = nil
            updatePreRenderedMapIfNeeded()
        }
        .onChange(of: showsControlledAirspaceBase) { _, _ in
            preRenderedMapImage = nil
            updatePreRenderedMapIfNeeded()
        }
        .onChange(of: visibleControlledAirspaceFloors) { _, _ in
            preRenderedMapImage = nil
            updatePreRenderedMapIfNeeded()
        }
    }

    private func updatePreRenderedMapIfNeeded() {
        guard size.width > 0, size.height > 0 else { return }
        guard cachedMapSize != size || preRenderedMapImage == nil else { return }

        let renderer = ImageRenderer(content: MapOverlayRenderer(
            geometry: geometry,
            size: size,
            zoomScale: 1,
            mapPadding: mapPadding,
            showsControlledAirspaceBase: showsControlledAirspaceBase,
            showsTerrainMap: showsTerrainMap,
            showsDebugOverlays: showsDebugOverlays,
            visibleControlledAirspaceFloors: visibleControlledAirspaceFloors
        ))
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        if let rendered = renderer.uiImage {
            preRenderedMapImage = Image(uiImage: rendered)
            cachedMapSize = size
        }
    }
}

private struct RadarVectorLayer: View {
    let aircraft: [Aircraft]
    let vectorSetting: VectorSetting
    let viewport: RadarViewport

    var body: some View {
        Canvas { context, _ in
            guard vectorSetting != .off else { return }

            for item in aircraft {
                let worldStart = CGPoint(x: item.displayX, y: item.displayY)
                let worldEnd = vectorEndpoint(for: item, lookaheadSeconds: vectorSetting.lookaheadSeconds)

                var path = Path()
                path.move(to: viewport.viewPoint(fromWorld: worldStart))
                path.addLine(to: viewport.viewPoint(fromWorld: worldEnd))
                context.stroke(path, with: .color(Color.cyan.opacity(0.55)), lineWidth: 1)
            }
        }
        .frame(width: viewport.viewSize.width, height: viewport.viewSize.height)
        .allowsHitTesting(false)
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

private struct RadarTrackLayer: View {
    let aircraft: [Aircraft]
    let viewport: RadarViewport

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(aircraft) { aircraft in
                RadarTrackSymbol(
                    displayPoint: viewport.viewPoint(fromWorld: CGPoint(x: aircraft.displayX, y: aircraft.displayY)),
                    historyPoints: aircraft.historyDots.map { viewport.viewPoint(fromWorld: $0) }
                )
            }
        }
        .frame(width: viewport.viewSize.width, height: viewport.viewSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

private struct RadarTrackSymbol: View {
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
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let baseOpacity = 0.6 - (Double(index) * 0.08)
        return max(0.15, baseOpacity)
    }
}

private struct RadarLabelLayer: View {
    let aircraft: [Aircraft]
    let viewport: RadarViewport

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(aircraft) { aircraft in
                let displayPoint = viewport.viewPoint(fromWorld: CGPoint(x: aircraft.displayX, y: aircraft.displayY))
                GatwickStyleLabel(aircraft: aircraft)
                    .position(x: displayPoint.x + 92, y: displayPoint.y - 42)
            }
        }
        .frame(width: viewport.viewSize.width, height: viewport.viewSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

private struct RadarScaleOverlay: View {
    let viewSize: CGSize
    let effectiveZoom: CGFloat
    let referenceRangeNM: CGFloat
    let zoomOutAction: () -> Void
    let zoomInAction: () -> Void

    var body: some View {
        let nmToPixels = (min(viewSize.width, viewSize.height) * 0.5 * effectiveZoom) / referenceRangeNM
        let distances: [CGFloat] = [20, 10, 3]

        VStack(alignment: .trailing, spacing: 8) {
            ForEach(distances, id: \.self) { distance in
                let width = max(20, distance * nmToPixels)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(distance))nm")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.95))

                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: width, height: 2)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 2, height: 8)
                        }
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 2, height: 8)
                        }
                }
            }

            HStack(spacing: 8) {
                Button {
                    zoomOutAction()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Text("\(Int((effectiveZoom * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(minWidth: 44)

                Button {
                    zoomInAction()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.bordered)
            }
            .tint(.white.opacity(0.9))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

}

private struct MapOverlayRenderer: View {
    let geometry: RadarGeometry
    let size: CGSize
    let zoomScale: CGFloat
    let mapPadding: CGFloat
    let showsControlledAirspaceBase: Bool
    let showsTerrainMap: Bool
    let showsDebugOverlays: Bool
    let visibleControlledAirspaceFloors: Set<String>

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

            let projectionTransform = geometry.fittedTransform(
                viewSize: size,
                worldPoints: coreProjectionWorldPoints,
                padding: mapPadding
            )

            if showsTerrainMap {
                for sector in geometry.terrainSectors {
                    var terrainPath = Path()
                    if let first = sector.polygonFractions.first {
                        terrainPath.move(to: zoomedPoint(inViewFromFraction: first, transform: projectionTransform))
                        for point in sector.polygonFractions.dropFirst() {
                            terrainPath.addLine(to: zoomedPoint(inViewFromFraction: point, transform: projectionTransform))
                        }
                        terrainPath.closeSubpath()
                    }
                    terrainPath.closeSubpath()
                    context.fill(terrainPath, with: .color(Color.brown.opacity(0.15)))
                    context.stroke(terrainPath, with: .color(Color.orange.opacity(0.30)), lineWidth: 0.8)
                    if !sector.polygonFractions.isEmpty {
                        let centroid = centroid(for: sector.polygonFractions)
                        let point = zoomedPoint(inViewFromFraction: centroid, transform: projectionTransform)
                        let text = Text(sector.minimumAltitudeLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.95))
                        context.draw(text, at: point)
                    }
                }
            }

            if showsControlledAirspaceBase {
                var ctr = Path()
                if let firstPoint = geometry.controlledAirspacePolygonFractions.first {
                    ctr.move(to: zoomedPoint(inViewFromFraction: firstPoint, transform: projectionTransform))
                    for point in geometry.controlledAirspacePolygonFractions.dropFirst() {
                        ctr.addLine(to: zoomedPoint(inViewFromFraction: point, transform: projectionTransform))
                    }
                    ctr.closeSubpath()
                }
                context.stroke(ctr, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
            }

            let visibleShelves = geometry.controlledAirspaceShelves.filter {
                visibleControlledAirspaceFloors.contains($0.floorLabel)
            }

            for shelf in visibleShelves {
                var shelfPath = Path()
                if let firstPoint = shelf.polygonFractions.first {
                    shelfPath.move(to: zoomedPoint(inViewFromFraction: firstPoint, transform: projectionTransform))
                    for point in shelf.polygonFractions.dropFirst() {
                        shelfPath.addLine(to: zoomedPoint(inViewFromFraction: point, transform: projectionTransform))
                    }
                    shelfPath.closeSubpath()
                }

                context.fill(shelfPath, with: .color(Color.cyan.opacity(0.08)))
                context.stroke(
                    shelfPath,
                    with: .color(.cyan.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 0.9, dash: [4, 4])
                )

            }

            for airway in geometry.surroundingAirways {
                guard let first = airway.waypoints.first else { continue }
                var airwayPath = Path()
                airwayPath.move(to: zoomedPoint(inViewFromFraction: first, transform: projectionTransform))
                for waypoint in airway.waypoints.dropFirst() {
                    airwayPath.addLine(to: zoomedPoint(inViewFromFraction: waypoint, transform: projectionTransform))
                }

                context.stroke(airwayPath, with: .color(.mint.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 6]))

            }

            let thresholdPoint = zoomedPoint(inViewFromWorld: geometry.runwayThreshold, transform: projectionTransform)
            let tenNmPoint = zoomedPoint(inViewFromWorld: geometry.centerlineStart, transform: projectionTransform)

            var centerline = Path()
            centerline.move(to: thresholdPoint)
            centerline.addLine(to: tenNmPoint)
            context.stroke(centerline, with: .color(.white.opacity(0.75)), lineWidth: 1.2)

            let markerOffsetsNm = stride(from: 0, through: 10, by: 2).map(CGFloat.init)
            for markerOffsetNm in markerOffsetsNm {
                let t = markerOffsetNm / 10.0
                let markerPoint = pointAlongLine(from: thresholdPoint, to: tenNmPoint, fraction: t)

                if markerOffsetNm == 0 {
                    let airportMarker = CGRect(
                        x: markerPoint.x - 4,
                        y: markerPoint.y - 4,
                        width: 8,
                        height: 8
                    )
                    context.stroke(Path(ellipseIn: airportMarker), with: .color(.white.opacity(0.95)), lineWidth: 1.4)
                } else {
                    let perpendicular = normalizedPerpendicular(from: thresholdPoint, to: tenNmPoint)
                    var tickPath = Path()
                    tickPath.move(to: CGPoint(
                        x: markerPoint.x - (perpendicular.x * 4),
                        y: markerPoint.y - (perpendicular.y * 4)
                    ))
                    tickPath.addLine(to: CGPoint(
                        x: markerPoint.x + (perpendicular.x * 4),
                        y: markerPoint.y + (perpendicular.y * 4)
                    ))
                    context.stroke(tickPath, with: .color(.white.opacity(0.9)), lineWidth: 1.1)
                }
            }

            if showsDebugOverlays {
                let boundsInView = zoomedRect(for: projectionTransform.sourceBounds, transform: projectionTransform)
                context.stroke(Path(boundsInView), with: .color(.yellow.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))

                let referencePoints: [(String, CGPoint)] = [
                    ("THR", geometry.runwayThreshold),
                    ("CLS", geometry.centerlineStart)
                ]

                for (label, worldPoint) in referencePoints {
                    let marker = zoomedPoint(inViewFromWorld: worldPoint, transform: projectionTransform)
                    let markerRect = CGRect(x: marker.x - 3, y: marker.y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: markerRect), with: .color(.yellow.opacity(0.9)))
                    let text = Text(label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow.opacity(0.95))
                    context.draw(text, at: CGPoint(x: marker.x + 12, y: marker.y - 8))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawValidationMarkers(context: inout GraphicsContext, projection: RadarMapValidationProjection) {
        drawCross(context: &context, at: projection.runwayThreshold, color: .green, radius: 6)
        drawCross(context: &context, at: projection.projectedOppositeRunwayThreshold, color: .green, radius: 5)
        drawCross(context: &context, at: projection.airportReferencePoint, color: .yellow, radius: 6)

        context.draw(Text("THR").font(.system(size: 10, design: .monospaced)), at: CGPoint(x: projection.runwayThreshold.x + 12, y: projection.runwayThreshold.y))
        context.draw(Text("THR(OPP)").font(.system(size: 10, design: .monospaced)), at: CGPoint(x: projection.projectedOppositeRunwayThreshold.x + 24, y: projection.projectedOppositeRunwayThreshold.y))
        context.draw(Text("ARP").font(.system(size: 10, design: .monospaced)), at: CGPoint(x: projection.airportReferencePoint.x + 12, y: projection.airportReferencePoint.y))

        for fix in projection.selectedFixes {
            drawCross(context: &context, at: fix.viewPoint, color: .cyan, radius: 4)
            context.draw(
                Text(fix.name).font(.system(size: 10, design: .monospaced)).foregroundColor(.cyan.opacity(0.95)),
                at: CGPoint(x: fix.viewPoint.x + 10, y: fix.viewPoint.y)
            )
        }

        guard showsDebugOverlays else { return }
        for (index, vertex) in projection.controlledAirspaceVertices.enumerated() {
            drawCross(context: &context, at: vertex, color: .red, radius: 3)
            context.draw(
                Text("V\(index)").font(.system(size: 9, design: .monospaced)).foregroundColor(.red.opacity(0.95)),
                at: CGPoint(x: vertex.x + 9, y: vertex.y)
            )
        }

        for point in projection.namedReferencePoints {
            context.draw(
                Text(point.name).font(.system(size: 9, design: .monospaced)).foregroundColor(.yellow.opacity(0.95)),
                at: CGPoint(x: point.viewPoint.x + 8, y: point.viewPoint.y - 10)
            )
        }
    }

    private func drawCross(context: inout GraphicsContext, at point: CGPoint, color: Color, radius: CGFloat) {
        var horizontal = Path()
        horizontal.move(to: CGPoint(x: point.x - radius, y: point.y))
        horizontal.addLine(to: CGPoint(x: point.x + radius, y: point.y))
        context.stroke(horizontal, with: .color(color.opacity(0.95)), lineWidth: 1.2)

        var vertical = Path()
        vertical.move(to: CGPoint(x: point.x, y: point.y - radius))
        vertical.addLine(to: CGPoint(x: point.x, y: point.y + radius))
        context.stroke(vertical, with: .color(color.opacity(0.95)), lineWidth: 1.2)
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.2f", value)
    }

    private func pointAlongLine(from start: CGPoint, to end: CGPoint, fraction: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + ((end.x - start.x) * fraction),
            y: start.y + ((end.y - start.y) * fraction)
        )
    }

    private func normalizedPerpendicular(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return CGPoint(x: 0, y: 1) }
        return CGPoint(x: -dy / length, y: dx / length)
    }

    private func centroid(for polygon: [CGPoint]) -> CGPoint {
        guard !polygon.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
        let sums = polygon.reduce((x: CGFloat.zero, y: CGFloat.zero)) { partial, point in
            (partial.x + point.x, partial.y + point.y)
        }
        return CGPoint(x: sums.x / CGFloat(polygon.count), y: sums.y / CGFloat(polygon.count))
    }

    private var coreProjectionWorldPoints: [CGPoint] {
        var points: [CGPoint] = [geometry.runwayThreshold, geometry.centerlineStart]
        points.append(contentsOf: geometry.controlledAirspacePolygonFractions.map { geometry.point(inWorldFromFraction: $0) })
        points.append(contentsOf: geometry.controlledAirspaceShelves.flatMap { shelf in
            shelf.polygonFractions.map { geometry.point(inWorldFromFraction: $0) }
        })
        points.append(contentsOf: geometry.surroundingAirways.flatMap { airway in
            airway.waypoints.map { geometry.point(inWorldFromFraction: $0) }
        })
        if showsTerrainMap {
            points.append(contentsOf: geometry.terrainSectors.flatMap { sector in
                sector.polygonFractions.map { geometry.point(inWorldFromFraction: $0) }
            })
        }
        return points
    }

    private func zoomedPoint(inViewFromWorld worldPoint: CGPoint, transform: RadarGeometry.FittedTransform) -> CGPoint {
        let basePoint = transform.pointInView(from: worldPoint)
        let viewCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(
            x: viewCenter.x + ((basePoint.x - viewCenter.x) * zoomScale),
            y: viewCenter.y + ((basePoint.y - viewCenter.y) * zoomScale)
        )
    }

    private func zoomedPoint(inViewFromFraction fraction: CGPoint, transform: RadarGeometry.FittedTransform) -> CGPoint {
        zoomedPoint(inViewFromWorld: geometry.point(inWorldFromFraction: fraction), transform: transform)
    }

    private func zoomedRect(for worldRect: CGRect, transform: RadarGeometry.FittedTransform) -> CGRect {
        let topLeft = zoomedPoint(inViewFromWorld: CGPoint(x: worldRect.minX, y: worldRect.minY), transform: transform)
        let bottomRight = zoomedPoint(inViewFromWorld: CGPoint(x: worldRect.maxX, y: worldRect.maxY), transform: transform)
        return CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
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
