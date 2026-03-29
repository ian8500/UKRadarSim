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
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to UK Radar Sim")
                        .font(.largeTitle.weight(.bold))

                    Text("Choose an airport and difficulty to begin your session.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Difficulty")
                        .font(.headline)

                    Picker("Difficulty", selection: $appState.selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases) { level in
                            VStack(alignment: .leading) {
                                Text(level.title)
                                Text(level.subtitle)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appState.selectedDifficulty.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Airport")
                        .font(.headline)

                    Picker("Airport", selection: $appState.selectedAirportICAO) {
                        ForEach(appState.airports) { airport in
                            let locked = !appState.canAccess(airport: airport)
                            Text(locked ? "\(airport.name) (Premium)" : airport.name)
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
                            Text("\(airport.name) is premium. Switch to an unlocked airport to start.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Button {
                    appState.activeScreen = .simulator
                } label: {
                    Text("Start Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.selectedAirport.map { !appState.canAccess(airport: $0) } ?? true)

                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
