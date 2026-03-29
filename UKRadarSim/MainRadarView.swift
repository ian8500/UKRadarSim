import SwiftUI
import Foundation

struct MainRadarView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var sim: SimulationEngine
    @StateObject private var clock: SimulationClock
    @State private var selectedBayFilter: StripBay?
    @State private var showWakeGuide = false

    let selectedAirport: AirportConfig
    let difficulty: DifficultyLevel
    let onExit: () -> Void

    private let geometry: RadarGeometry
    private let speedOptions: [Double] = [0.5, 1.0, 2.0, 4.0]

    init(
        selectedAirport: AirportConfig,
        difficulty: DifficultyLevel,
        onExit: @escaping () -> Void = {}
    ) {
        self.selectedAirport = selectedAirport
        self.difficulty = difficulty
        self.onExit = onExit
        let radarGeometry = AirportMapCatalog.geometry(for: selectedAirport.icao)
        self.geometry = radarGeometry
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
                showsControlledAirspaceBase: appState.showsControlledAirspaceBase,
                showsTerrainMap: appState.showsTerrainMap,
                geometry: geometry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar
            opsStatusPanel
            stripArea
        }
        .onAppear { clock.start() }
        .onDisappear { clock.pause() }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Button("Home") { onExit() }
                .buttonStyle(.bordered)
                .tint(.white)

            layerControls
            vectorsMenu
            wakeButton
            speedMenu

            Button(clock.isRunning ? "Pause" : "Resume") {
                clock.isRunning ? clock.pause() : clock.resume()
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button {
                sim.resetScenario()
                clock.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.7))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(selectedAirport.icao) • \(difficulty.title)")
                    .foregroundColor(.white.opacity(0.85))
                    .font(.caption.weight(.semibold))
                Text("Score: \(sim.score)")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(red: 0.08, green: 0.10, blue: 0.12))
    }

    private var wakeButton: some View {
        Button(action: {}) {
            Text("Wake")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.25))
                .cornerRadius(8)
        }
        .onLongPressGesture(minimumDuration: 0.15, maximumDistance: 40, pressing: { pressing in
            showWakeGuide = pressing
        }, perform: {})
        .popover(isPresented: $showWakeGuide, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            WakeTurbulencePopup()
        }
    }

    private var layerControls: some View {
        HStack(spacing: 8) {
            layerToggleButton(
                title: "CAS Base",
                isOn: appState.showsControlledAirspaceBase
            ) {
                appState.showsControlledAirspaceBase.toggle()
            }

            layerToggleButton(
                title: "Terrain",
                isOn: appState.showsTerrainMap
            ) {
                appState.showsTerrainMap.toggle()
            }
        }
    }

    private func layerToggleButton(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((isOn ? Color.blue : Color.gray).opacity(0.35))
                .cornerRadius(8)
        }
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
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                StatusPill(title: "Session", value: formatClock(clock.elapsedSeconds), tint: .cyan)
                StatusPill(title: "Score", value: "\(sim.score)", tint: .blue)
                StatusPill(title: "Landed", value: "\(sim.landedCount)", tint: .green)
                StatusPill(
                    title: "Alerts",
                    value: "\(sim.activeAlerts.count)",
                    tint: sim.activeAlerts.isEmpty ? .green : .orange
                )
                Spacer()
            }

            HStack(spacing: 8) {
                if let topAlert = sim.activeAlerts.first {
                    Label("\(topAlert.callsignPair) • \(topAlert.message)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(topAlert.severity == .warning ? .red : .yellow)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                } else {
                    Label("No active conflict predictions", systemImage: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.caption.weight(.semibold))
                }
                Spacer()
            }
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
        Button {
            appState.vectorSetting = (appState.vectorSetting == .off) ? .sec60 : .off
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
        VStack(spacing: 10) {
            bayFilterBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(visibleBays) { bay in
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
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.16))
    }

    private var bayFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("All Bays") {
                    selectedBayFilter = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedBayFilter == nil ? .blue : .gray)

                ForEach(StripBay.allCases) { bay in
                    Button(bay.rawValue) {
                        selectedBayFilter = bay
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(selectedBayFilter == bay ? .indigo : .gray)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }

    private var visibleBays: [StripBay] {
        if let selectedBayFilter {
            return [selectedBayFilter]
        }
        return StripBay.allCases
    }
}

private struct StatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        }
    }
}

#Preview {
    MainRadarView(
        selectedAirport: AirportConfig(icao: "EGKK", name: "London Gatwick", isPremium: nil),
        difficulty: .standard
    )
    .environmentObject(AppState())
}
