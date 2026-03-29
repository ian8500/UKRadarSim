import SwiftUI

struct ContentView: View {
    var body: some View {
        MainRadarView()
    }
}

struct ToolbarButton: View {
    let title: String

    var body: some View {
        Button(action: {}) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.25))
                .cornerRadius(8)
        }
    }
}

private enum StripField: String, Identifiable {
    case callsign
    case aircraftType
    case level
    case heading
    case speed
    case approachType

    var id: String { rawValue }

    var title: String {
        switch self {
        case .callsign: return "Callsign"
        case .aircraftType: return "Aircraft Type"
        case .level: return "Level"
        case .heading: return "Heading"
        case .speed: return "Speed"
        case .approachType: return "Approach"
        }
    }
}

struct StripCard: View {
    @Binding var strip: EFPSStrip
    let sendInstruction: () -> Void
    let flitStrip: (StripBay) -> Void

    @State private var activeField: StripField?

    private let aircraftTypes = ["A319", "A320", "A321", "B738", "B739", "E190", "DH8D"]
    private let approachTypes = ["ILS", "RNAV", "VISUAL", "LOC", "SID"]
    private let callsignOptions = ["EZY15WY", "BAW214", "RYR82MP", "KLM1023", "SHT7AB", "DAL41"]
    private let levelOptions: [Int] = Array(stride(from: 10, through: 60, by: 10)) + Array(stride(from: 70, through: 160, by: 10))
    private let speedOptions: [Int] = [250, 230, 210, 190, 170, 160]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                fieldCell(title: "CALL", value: strip.callsign, field: .callsign)
                fieldCell(title: "TYPE", value: strip.aircraftType, field: .aircraftType)
                fieldCell(title: "APP", value: strip.approachType, field: .approachType)
            }

            HStack(spacing: 8) {
                fieldCell(title: "LVL", value: strip.levelDisplay, field: .level)
                fieldCell(title: "HDG", value: String(format: "%03d", strip.selectedHeading), field: .heading)
                fieldCell(title: "SPD", value: "\(strip.selectedSpeed)KT", field: .speed)
            }

            HStack {
                Menu("Flit") {
                    ForEach(StripBay.allCases.filter { $0 != strip.bay }) { bay in
                        Button("To \(bay.rawValue)") {
                            flitStrip(bay)
                        }
                    }
                }
                .font(.caption.bold())
                .foregroundColor(.black.opacity(0.8))

                Spacer()

                Button("Send") {
                    sendInstruction()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
            }

            if let lastInstruction = strip.instructionLog.first {
                Text("Last: \(lastInstruction)")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.75))
                    .lineLimit(2)
            } else {
                Text("Last: —")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.55))
            }
        }
        .padding(10)
        .frame(width: 380, alignment: .leading)
        .background(
            strip.isInbound
                ? Color(red: 0.91, green: 0.81, blue: 0.62)
                : Color(red: 0.82, green: 0.89, blue: 1.0)
        )
        .cornerRadius(6)
        .popover(item: $activeField) { field in
            popupContent(for: field)
                .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder
    private func popupContent(for field: StripField) -> some View {
        switch field {
        case .callsign:
            optionList(title: field.title, options: callsignOptions, label: { $0 }) { selected in
                strip.callsign = selected
            }
        case .aircraftType:
            optionList(title: field.title, options: aircraftTypes, label: { $0 }) { selected in
                strip.aircraftType = selected
            }
        case .level:
            optionList(title: field.title, options: levelOptions, label: { level in
                level < 70 ? "\(level * 100)FT" : "FL\(level)"
            }) { selected in
                strip.selectedLevel = selected
            }
        case .heading:
            HeadingPicker(selectedHeading: $strip.selectedHeading)
        case .speed:
            optionList(title: field.title, options: speedOptions, label: { "\($0)KT" }) { selected in
                strip.selectedSpeed = selected
            }
        case .approachType:
            optionList(title: field.title, options: approachTypes, label: { $0 }) { selected in
                strip.approachType = selected
            }
        }
    }

    private func fieldCell(title: String, value: String, field: StripField) -> some View {
        Button {
            activeField = field
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.black.opacity(0.7))
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.55))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func optionList<T>(
        title: String,
        options: [T],
        label: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void
    ) -> some View where T: Hashable {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button(label(option)) {
                            onSelect(option)
                            activeField = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .frame(width: 260, height: 320)
    }
}

private struct HeadingPicker: View {
    @Binding var selectedHeading: Int

    private let baseHeadings: [Int] = Array(stride(from: 0, through: 340, by: 20))

    var body: some View {
        VStack(spacing: 12) {
            Text("Heading")
                .font(.headline)

            Text(String(format: "%03d°", normalized(selectedHeading)))
                .font(.title2.monospacedDigit())

            CompassRose(baseHeadings: baseHeadings, selectedHeading: $selectedHeading)
                .frame(width: 220, height: 220)

            HStack(spacing: 10) {
                adjustButton("-10", by: -10)
                adjustButton("-5", by: -5)
                adjustButton("+5", by: 5)
                adjustButton("+10", by: 10)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func adjustButton(_ title: String, by delta: Int) -> some View {
        Button(title) {
            selectedHeading = normalized(selectedHeading + delta)
        }
        .buttonStyle(.borderedProminent)
        .font(.caption.weight(.bold))
    }

    private func normalized(_ value: Int) -> Int {
        ((value % 360) + 360) % 360
    }
}

private struct CompassRose: View {
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
                    let angle = Angle.degrees(Double(heading - 90))
                    let tickStart = CGPoint(
                        x: center.x + cos(angle.radians) * (radius - 20),
                        y: center.y + sin(angle.radians) * (radius - 20)
                    )
                    let tickEnd = CGPoint(
                        x: center.x + cos(angle.radians) * (radius - 8),
                        y: center.y + sin(angle.radians) * (radius - 8)
                    )

                    Path { path in
                        path.move(to: tickStart)
                        path.addLine(to: tickEnd)
                    }
                    .stroke(Color.black.opacity(0.45), lineWidth: 1)

                    Button {
                        selectedHeading = heading
                    } label: {
                        Text(String(format: "%03d", heading))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(selectedHeading == heading ? .blue : .black)
                    }
                    .position(
                        x: center.x + cos(angle.radians) * (radius - 34),
                        y: center.y + sin(angle.radians) * (radius - 34)
                    )
                    .buttonStyle(.plain)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

struct StripBayColumn: View {
    let bay: StripBay
    @Binding var strips: [EFPSStrip]
    let sendInstruction: (UUID) -> Void
    let flitStrip: (UUID, StripBay) -> Void

    private var stripIndexes: [Int] {
        strips.indices.filter { strips[$0].bay == bay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bay.rawValue.uppercased())
                .font(.headline)
                .foregroundColor(.white)

            if stripIndexes.isEmpty {
                Text("No strips")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
            } else {
                ForEach(stripIndexes, id: \.self) { index in
                    StripCard(
                        strip: $strips[index],
                        sendInstruction: {
                            sendInstruction(strips[index].id)
                        },
                        flitStrip: { targetBay in
                            flitStrip(strips[index].id, targetBay)
                        }
                    )
                }
            }
        }
        .padding()
        .frame(width: 410, alignment: .topLeading)
        .background(Color(red: 0.18, green: 0.20, blue: 0.23).opacity(0.65))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
