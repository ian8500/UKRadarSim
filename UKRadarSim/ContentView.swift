import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Radar area
            ZStack {
                Color(red: 0.02, green: 0.18, blue: 0.22)
                    .ignoresSafeArea()

                Text("RADAR AREA")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Toolbar
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

            // Strip area
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    StripCard(callsign: "EZY15WY", level: "F107", selectedLevel: "080", destination: "KK")
                    StripCard(callsign: "BAW123", level: "F090", selectedLevel: "070", destination: "KK")
                    StripCard(callsign: "RYR82AB", level: "F120", selectedLevel: "100", destination: "KK")
                }
                .padding()
            }
            .background(Color(red: 0.12, green: 0.14, blue: 0.16))
        }
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
    let callsign: String
    let level: String
    let selectedLevel: String
    let destination: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(callsign)
                .font(.headline)
                .foregroundColor(.white)

            Text("Current: \(level)")
                .foregroundColor(.white.opacity(0.9))

            Text("Selected: \(selectedLevel)")
                .foregroundColor(.orange)

            Text("Dest: \(destination)")
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .frame(width: 180, alignment: .leading)
        .background(Color(red: 0.18, green: 0.20, blue: 0.23))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
