import SwiftUI

struct MainRadarView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var sim = SimulationEngine()

    var body: some View {
        VStack(spacing: 0) {
            RadarCanvasView(
                aircraft: sim.aircraft,
                vectorSetting: appState.vectorSetting
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar

            stripArea
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            ToolbarButton(title: "Layers")
            vectorsMenu
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

    private var vectorsMenu: some View {
        Menu {
            ForEach(VectorSetting.allCases) { setting in
                Button {
                    appState.vectorSetting = setting
                } label: {
                    if appState.vectorSetting == setting {
                        Label(setting.menuLabel, systemImage: "checkmark")
                    } else {
                        Text(setting.menuLabel)
                    }
                }
            }
        } label: {
            Text(appState.vectorSetting.toolbarLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.25))
                .cornerRadius(8)
        }
    }

    private var stripArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(StripBay.allCases) { bay in
                    StripBayColumn(
                        bay: bay,
                        strips: $sim.strips,
                        sendInstruction: { stripID in
                            sim.sendInstruction(stripID: stripID)
                        },
                        clearForApproach: { stripID in
                            sim.clearForApproach(stripID: stripID)
                        },
                        flitStrip: { stripID, targetBay in
                            sim.flitStrip(stripID: stripID, to: targetBay)
                        }
                    )
                }
            }
            .padding()
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.16))
    }
}

#Preview {
    MainRadarView()
        .environmentObject(AppState())
}
