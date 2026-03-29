import SwiftUI
import Foundation

struct MainRadarView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var sim: SimulationEngine
    @StateObject private var clock: SimulationClock

    private let geometry = RadarGeometry.default
    private let speedOptions: [Double] = [0.5, 1.0, 2.0, 4.0]

    init() {
        let radarGeometry = RadarGeometry.default
        let simulationEngine = SimulationEngine(
            geometry: radarGeometry,
            startupScenario: ScenarioLibrary.default
        )
        _sim = StateObject(wrappedValue: simulationEngine)
        _clock = StateObject(wrappedValue: SimulationClock(simulationEngine: simulationEngine))
    }
    var body: some View {
        VStack(spacing: 0) {
            RadarCanvasView(
                aircraft: sim.aircraft,
                vectorSetting: appState.vectorSetting,
                geometry: geometry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar

            opsStatusPanel

            stripArea
        }
        .onAppear {
            clock.start()
        }
        .onDisappear {
            clock.pause()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            ToolbarButton(title: "Layers")
            vectorsMenu
            ToolbarButton(title: "Wake")
            speedMenu
            Button {
                clock.isRunning ? clock.pause() : clock.resume()
            } label: {
                Text(clock.isRunning ? "Pause" : "Resume")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.25))
                    .cornerRadius(8)
            }
            Button {
                sim.resetScenario()
                clock.reset()
            } label: {
                Text("Reset")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Score: \(sim.score)")
                    .foregroundColor(.white)
                    .font(.headline)
                Text("Landed: \(sim.landedCount)")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption.monospacedDigit())
            }
        }
        .padding()
        .background(Color(red: 0.08, green: 0.10, blue: 0.12))
    }

    private var speedMenu: some View {
        Menu {
            ForEach(speedOptions, id: \.self) { speed in
                Button {
                    clock.speedMultiplier = speed
                } label: {
                    if clock.speedMultiplier == speed {
                        Label("\(speed.formatted())x", systemImage: "checkmark")
                    } else {
                        Text("\(speed.formatted())x")
                    }
                }
            }
        } label: {
            Text("Speed \(clock.speedMultiplier.formatted())x")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.25))
                .cornerRadius(8)
        }
    }

    private var opsStatusPanel: some View {
        HStack(spacing: 16) {
            Text("Session \(formatClock(clock.elapsedSeconds))")
                .foregroundColor(.white.opacity(0.9))
                .font(.caption.monospacedDigit())

            Text("Alerts: \(sim.activeAlerts.count)")
                .foregroundColor(sim.activeAlerts.isEmpty ? .green : .orange)
                .font(.caption.weight(.semibold))

            if let topAlert = sim.activeAlerts.first {
                Text("\(topAlert.callsignPair) • \(topAlert.message)")
                    .foregroundColor(topAlert.severity == .warning ? .red : .yellow)
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Text("No active conflict predictions")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(red: 0.06, green: 0.08, blue: 0.10))
    }

    private func formatClock(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
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
                        sendInstruction: { stripID, changedFields in
                            sim.sendInstruction(stripID: stripID, changedFields: changedFields)
                        },
                        armILSIntercept: { stripID in
                            sim.armILSIntercept(stripID: stripID)
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
