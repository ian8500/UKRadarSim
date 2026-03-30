import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.activeScreen == .home {
            HomeView()
        } else if let selectedAirport = appState.selectedAirport {
            MainRadarView(
                selectedAirport: selectedAirport,
                difficulty: appState.selectedDifficulty,
                onExit: {
                    appState.activeScreen = .home
                }
            )
        } else {
            HomeView()
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.20),
                        Color.indigo.opacity(0.08),
                        Color.black.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroHeader
                        quickStatsCard
                        productHighlightsCard
                        sessionSetupCard
                        startButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
        }
    }

    private var quickStatsCard: some View {
        HStack(spacing: 12) {
            DashboardStat(title: "Airports", value: "\(appState.airports.count)", symbol: "airplane.departure")
            DashboardStat(title: "Weather", value: "\(appState.weatherPacks.count)", symbol: "cloud.sun")
            DashboardStat(title: "Difficulty", value: appState.selectedDifficulty.title, symbol: "speedometer")
            DashboardStat(
                title: "Access",
                value: appState.hasPremiumEntitlements ? "Premium" : "Standard",
                symbol: appState.hasPremiumEntitlements ? "star.circle.fill" : "star.circle"
            )
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("UK Radar Sim", systemImage: "dot.radiowaves.forward")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Professional radar training, redesigned.")
                .font(.largeTitle.weight(.bold))

            Text("Build realistic ATC workflows with guided scenarios, faster controls, and a cleaner command interface.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TagView(title: "Live Conflict Alerts", symbol: "exclamationmark.triangle")
                TagView(title: "Scenario Packs", symbol: "shippingbox")
                TagView(title: "Premium Ready", symbol: "star.fill")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
    }

    private var productHighlightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why users subscribe")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label("Premium airports unlock advanced traffic complexity.", systemImage: "airplane.circle")
                Label("Weather packs add variety for approach and sequencing practice.", systemImage: "cloud.rain")
                Label("Professional-style dashboard surfaces risk and landing performance.", systemImage: "gauge.with.dots.needle.67percent")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var sessionSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Setup")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("Difficulty")
                    .font(.subheadline.weight(.semibold))

                Picker("Difficulty", selection: $appState.selectedDifficulty) {
                    ForEach(DifficultyLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                Text(appState.selectedDifficulty.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Airport")
                    .font(.subheadline.weight(.semibold))

                Picker("Airport", selection: $appState.selectedAirportICAO) {
                    ForEach(appState.airports) { airport in
                        let locked = !appState.canAccess(airport: airport)
                        Text(locked ? "\(airport.name) (Premium)" : "\(airport.name) (\(airport.icao))")
                            .tag(airport.icao)
                    }
                }
                .pickerStyle(.menu)

                if let airport = appState.selectedAirport {
                    if appState.canAccess(airport: airport) {
                        Text("Selected: \(airport.name) (\(airport.icao))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(airport.name) is premium. Unlock premium to start there.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Weather Pack")
                    .font(.subheadline.weight(.semibold))

                Picker("Weather Pack", selection: $appState.selectedWeatherPackID) {
                    ForEach(appState.weatherPacks) { pack in
                        let locked = !appState.canAccess(weatherPack: pack)
                        Text(locked ? "\(pack.name) (Premium)" : pack.name)
                            .tag(pack.id)
                    }
                }
                .pickerStyle(.menu)

                if let pack = appState.selectedWeatherPack {
                    if appState.canAccess(weatherPack: pack) {
                        Text("Selected weather: \(pack.name)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(pack.name) is premium. Upgrade to enable this pack.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if appState.canPreviewPremiumEntitlements {
                Divider()

                Toggle(
                    "Preview Premium Experience",
                    isOn: Binding(
                        get: { appState.hasPremiumEntitlements },
                        set: { appState.setPreviewPremiumEntitlementsEnabled($0) }
                    )
                )
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
    }

    private var startButton: some View {
        Button {
            appState.activeScreen = .simulator
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Session")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(appState.selectedAirport.map { !appState.canAccess(airport: $0) } ?? true)
    }
}

private struct TagView: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.2), in: Capsule())
    }
}

private struct DashboardStat: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.indigo)

            Text(value)
                .font(.headline.weight(.bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
