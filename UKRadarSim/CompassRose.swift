import SwiftUI

struct CompassRose: View {
    let baseHeadings: [Int]
    @Binding var selectedHeading: Int

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let center = CGPoint(x: radius, y: radius)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                Circle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)

                ForEach(baseHeadings, id: \.self) { heading in
                    HeadingTick(
                        heading: heading,
                        center: center,
                        radius: radius,
                        isSelected: selectedHeading == heading,
                        onSelect: { selectedHeading = heading }
                    )
                }
            }
            .frame(width: size, height: size)
        }
    }
}

private struct HeadingTick: View {
    let heading: Int
    let center: CGPoint
    let radius: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    private var angle: Angle {
        Angle.degrees(Double(heading - 90))
    }

    var body: some View {
        let tickStart = point(distanceFromCenter: radius - 20)
        let tickEnd = point(distanceFromCenter: radius - 8)
        let labelPoint = point(distanceFromCenter: radius - 34)

        return Group {
            Path { path in
                path.move(to: tickStart)
                path.addLine(to: tickEnd)
            }
            .stroke(Color.black.opacity(0.45), lineWidth: 1)

            Button(action: onSelect) {
                Text(String(format: "%03d", heading))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? .blue : .black)
            }
            .position(labelPoint)
            .buttonStyle(.plain)
        }
    }

    private func point(distanceFromCenter distance: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle.radians)) * distance,
            y: center.y + CGFloat(sin(angle.radians)) * distance
        )
    }
}
