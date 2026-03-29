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
