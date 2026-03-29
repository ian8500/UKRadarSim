import SwiftUI

private enum StripField: String, Identifiable {
    case level
    case heading
    case speed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .level: return "Level"
        case .heading: return "Heading"
        case .speed: return "Speed"
        }
    }
}

struct StripCard: View {
    @Binding var strip: EFPSStrip
    let sendInstruction: (Set<InstructionChange>) -> Void
    let armILSIntercept: () -> Void
    let clearForApproach: () -> Void
    let flitStrip: (StripBay) -> Void

    @State private var activeField: StripField?
    @State private var draftLevel: Int = 0
    @State private var draftHeading: Int = 0
    @State private var draftSpeed: Int = 0
    @State private var ilsModeArmed = false

    private let levelOptions: [Int] = Array(stride(from: 10, through: 60, by: 10)) + Array(stride(from: 70, through: 160, by: 10))
    private let speedOptions: [Int] = [250, 230, 210, 190, 170, 160]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                staticFieldCell(value: strip.callsign)
                staticFieldCell(value: strip.aircraftType)
                fieldCell(value: String(format: "%03d", strip.selectedHeading), field: .heading)
                fieldCell(value: strip.levelDisplay, field: .level)
                fieldCell(value: "\(strip.selectedSpeed)", field: .speed)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
            )

            HStack {
                Button {
                    clearForApproach()
                } label: {
                    Text("APP \(approachStatusText)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

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
            }

        }
        .padding(10)
        .frame(width: 460, alignment: .leading)
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
        .onAppear {
            syncDraftValues()
        }
        .onChange(of: strip.selectedLevel) { _, newValue in
            draftLevel = newValue
        }
        .onChange(of: strip.selectedHeading) { _, newValue in
            draftHeading = newValue
        }
        .onChange(of: strip.selectedSpeed) { _, newValue in
            draftSpeed = newValue
        }
    }

    @ViewBuilder
    private func popupContent(for field: StripField) -> some View {
        switch field {
        case .level:
            optionList(title: field.title, options: levelOptions, label: { level in
                level < 70 ? "\(level * 100)FT" : "FL\(level)"
            }, selected: draftLevel) { selected in
                draftLevel = selected
            } onSend: {
                strip.selectedLevel = draftLevel
                sendInstruction([.level])
            }
        case .heading:
            HeadingPicker(selectedHeading: $draftHeading, ilsModeArmed: $ilsModeArmed) { ilsRequested in
                strip.selectedHeading = draftHeading
                if ilsRequested {
                    armILSIntercept()
                    sendInstruction([.heading, .ilsClearance])
                    ilsModeArmed = false
                } else {
                    sendInstruction([.heading])
                }
                activeField = nil
            }
        case .speed:
            optionList(title: field.title, options: speedOptions, label: { "\($0)KT" }, selected: draftSpeed) { selected in
                draftSpeed = selected
            } onSend: {
                strip.selectedSpeed = draftSpeed
                sendInstruction([.speed])
            }
        }
    }

    private func staticFieldCell(value: String) -> some View {
        Text(value)
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundColor(.black)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .center)
            .background(Color.white.opacity(0.55))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 1)
            }
    }

    private func fieldCell(value: String, field: StripField) -> some View {
        Button {
            activeField = field
        } label: {
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .center)
                .background(Color.white.opacity(0.55))
                .overlay(alignment: .trailing) {
                    if field != .speed {
                        Rectangle()
                            .fill(Color.black.opacity(0.25))
                            .frame(width: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func optionList<T>(
        title: String,
        options: [T],
        label: @escaping (T) -> String,
        selected: T,
        onSelect: @escaping (T) -> Void,
        onSend: @escaping () -> Void
    ) -> some View where T: Hashable {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        if selected == option {
                            Button(label(option)) {
                                onSelect(option)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(label(option)) {
                                onSelect(option)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            Button("Send") {
                onSend()
                activeField = nil
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 260, height: 320)
    }

    private func syncDraftValues() {
        draftLevel = strip.selectedLevel
        draftHeading = strip.selectedHeading
        draftSpeed = strip.selectedSpeed
    }

    private var approachStatusText: String {
        if strip.isLanded { return "LANDED" }
        if strip.approachCaptured { return "CAPTURED" }
        return strip.approachCleared ? "CLEARED" : "CLEAR"
    }
}
