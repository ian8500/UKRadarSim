import SwiftUI

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
