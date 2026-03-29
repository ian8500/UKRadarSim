import SwiftUI

struct HeadingPicker: View {
    @Binding var selectedHeading: Int
    @Binding var ilsModeArmed: Bool
    let onSend: (Bool) -> Void

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

            if ilsModeArmed {
                Button("ILS") {
                    ilsModeArmed.toggle()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("ILS") {
                    ilsModeArmed.toggle()
                }
                .buttonStyle(.bordered)
            }

            Button("Send") {
                onSend(ilsModeArmed)
            }
            .buttonStyle(.borderedProminent)
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
