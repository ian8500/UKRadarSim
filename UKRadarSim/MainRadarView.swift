import SwiftUI

struct MainRadarView: View {
    @State private var aircraft: [Aircraft] = [
        Aircraft(
            callsign: "EZY15WY",
            trueX: 240,
            trueY: 310,
            displayX: 240,
            displayY: 310,
            heading: 055,
            groundSpeed: 355,
            currentLevel: 107,
            selectedLevel: 80,
            trend: .descend,
            destination: "KK"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            RadarCanvasView(aircraft: aircraft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar

            stripArea
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            ToolbarButton(title: "Layers")
            ToolbarButton(title: "Vectors")
            ToolbarButton(title: "Wake")
            ToolbarButton(title: "Pause")

            Spacer()

            Text("Score: 0")
                .foregroundColor(.white)
                .font(.headline)
        }
        .padding()
        .background(Color(red: 0.08, green: 0.10, blue: 0.12))
    }

    private var stripArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(aircraft) { item in
                    StripCard(
                        callsign: item.callsign,
                        level: "F\(String(format: "%03d", item.currentLevel))",
                        selectedLevel: String(format: "%03d", item.selectedLevel),
                        destination: item.destination
                    )
                }
            }
            .padding()
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.16))
    }
}
