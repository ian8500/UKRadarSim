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

struct StripCard: View {
    @Binding var strip: EFPSStrip
    let sendInstruction: () -> Void
    let flitStrip: (StripBay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(strip.callsign)
                    .font(.headline)
                    .foregroundColor(.black)

                Spacer()

                Menu("Flit") {
                    ForEach(StripBay.allCases.filter { $0 != strip.bay }) { bay in
                        Button("To \(bay.rawValue)") {
                            flitStrip(bay)
                        }
                    }
                }
                .font(.caption.bold())
                .foregroundColor(.black.opacity(0.8))
            }

            Text("Current: F\(String(format: "%03d", strip.currentLevel))")
                .foregroundColor(.black.opacity(0.85))

            Text("Selected: \(String(format: "%03d", strip.selectedLevel))")
                .foregroundColor(.black.opacity(0.85))

            Text("Dest: \(strip.destination)")
                .foregroundColor(.black.opacity(0.8))

            Divider()

            HStack(spacing: 8) {
                TextField("Instruction", text: $strip.pendingInstruction)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                Button("Send", action: sendInstruction)
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
        .padding()
        .frame(width: 250, alignment: .leading)
        .background(
            strip.isInbound
            ? Color(red: 0.91, green: 0.81, blue: 0.62)
            : Color(red: 0.82, green: 0.89, blue: 1.0)
        )
        .cornerRadius(8)
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
        .frame(width: 280, alignment: .topLeading)
        .background(Color(red: 0.18, green: 0.20, blue: 0.23).opacity(0.65))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
