import SwiftUI

struct WakeTurbulenceGuide {
    static let sourceTitle = "UK CAA CAP 493 (MATS Part 1), Edition 12"
    static let sourceEffectiveDate = "Effective 31 October 2025"

    static let finalApproachRows: [WakeTurbulenceMinimaRow] = [
        .init(leading: "SUPER", following: "HEAVY", minima: "5 NM"),
        .init(leading: "SUPER", following: "UPPER/LOWER MEDIUM", minima: "7 NM"),
        .init(leading: "SUPER", following: "SMALL", minima: "7 NM"),
        .init(leading: "SUPER", following: "LIGHT", minima: "8 NM"),
        .init(leading: "HEAVY", following: "HEAVY", minima: "4 NM"),
        .init(leading: "HEAVY", following: "UPPER/LOWER MEDIUM", minima: "5 NM"),
        .init(leading: "HEAVY", following: "SMALL", minima: "6 NM"),
        .init(leading: "HEAVY", following: "LIGHT", minima: "7 NM"),
        .init(leading: "UPPER MEDIUM", following: "UPPER MEDIUM", minima: "3 NM"),
        .init(leading: "UPPER MEDIUM", following: "LOWER MEDIUM", minima: "4 NM"),
        .init(leading: "UPPER MEDIUM", following: "SMALL", minima: "4 NM"),
        .init(leading: "UPPER MEDIUM", following: "LIGHT", minima: "6 NM"),
        .init(leading: "LOWER MEDIUM", following: "SMALL", minima: "3 NM"),
        .init(leading: "LOWER MEDIUM", following: "LIGHT", minima: "5 NM"),
        .init(leading: "SMALL", following: "SMALL", minima: "3 NM"),
        .init(leading: "SMALL", following: "LIGHT", minima: "4 NM")
    ]

}

struct WakeTurbulenceMinimaRow: Identifiable {
    let id = UUID()
    let leading: String
    let following: String
    let minima: String
}

struct WakeTurbulencePopup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wake Turbulence Minima")
                .font(.headline)

            Text("\(WakeTurbulenceGuide.sourceTitle) • \(WakeTurbulenceGuide.sourceEffectiveDate)")
                .font(.caption)
                .foregroundStyle(.secondary)

            wakeSection(title: "Arrival minima (final approach, Table 3)", rows: WakeTurbulenceGuide.finalApproachRows)

            Text("No wake minima is required where CAP 493 marks the pairing with #.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func wakeSection(title: String, rows: [WakeTurbulenceMinimaRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                GridRow {
                    Text("Leading")
                        .font(.caption.weight(.semibold))
                    Text("Following")
                        .font(.caption.weight(.semibold))
                    Text("Min")
                        .font(.caption.weight(.semibold))
                }

                ForEach(rows) { row in
                    GridRow {
                        Text(row.leading)
                            .font(.caption)
                        Text(row.following)
                            .font(.caption)
                        Text(row.minima)
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }
}
