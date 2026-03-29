import SwiftUI

struct StripBayColumn: View {
    let bay: StripBay
    @Binding var strips: [EFPSStrip]
    let sendInstruction: (UUID, Set<InstructionChange>) -> Void
    let armILSIntercept: (UUID) -> Void
    let clearForApproach: (UUID) -> Void
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
                        sendInstruction: { changedFields in
                            sendInstruction(strips[index].id, changedFields)
                        },
                        armILSIntercept: {
                            armILSIntercept(strips[index].id)
                        },
                        clearForApproach: {
                            clearForApproach(strips[index].id)
                        },
                        flitStrip: { targetBay in
                            flitStrip(strips[index].id, targetBay)
                        }
                    )
                }
            }
        }
        .padding()
        .frame(width: 490, alignment: .topLeading)
        .background(Color(red: 0.18, green: 0.20, blue: 0.23).opacity(0.65))
        .cornerRadius(10)
    }
}
