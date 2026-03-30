import Foundation

enum VectorSetting: Int, CaseIterable, Identifiable {
    case off = 0
    case sec60 = 60

    var id: Int { rawValue }

    var toolbarLabel: String {
        switch self {
        case .off: return "Vectors: Off"
        case .sec60: return "Vectors: 60 sec"
        }
    }

    var menuLabel: String {
        switch self {
        case .off: return "Off"
        case .sec60: return "60 sec"
        }
    }

    var lookaheadSeconds: Double {
        Double(rawValue)
    }
}

enum DifficultyLevel: String, CaseIterable, Identifiable {
    case beginner
    case standard
    case expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .standard: return "Standard"
        case .expert: return "Expert"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Calmer traffic for practice"
        case .standard: return "Balanced traffic flow"
        case .expert: return "Busy sectors and tighter pace"
        }
    }
}

enum AppScreen {
    case home
    case simulator
}

final class AppState: ObservableObject {
    @Published var vectorSetting: VectorSetting = .off
    @Published var showsControlledAirspaceBase = true
    @Published var showsTerrainMap = true
    @Published var mapValidationMode = false
    @Published var showsMapDebugLabels = false
    @Published var activeScreen: AppScreen = .home
    @Published var selectedDifficulty: DifficultyLevel = .standard
    @Published var selectedAirportICAO: String = "EGKK"
    @Published var selectedWeatherPackID: String = "standard-uk"
    @Published private(set) var hasPremiumEntitlements = false

    // Seed content; premium flags are optional by design.
    @Published var airports: [AirportConfig] = [
        AirportConfig(icao: "EGKK", name: "London Gatwick", isPremium: nil),
        AirportConfig(icao: "EGLL", name: "London Heathrow", isPremium: nil),
        AirportConfig(icao: "EGPF", name: "Glasgow", isPremium: nil),
        AirportConfig(icao: "EGPH", name: "Edinburgh", isPremium: true)
    ]

    @Published var weatherPacks: [WeatherPack] = [
        WeatherPack(id: "standard-uk", name: "UK Standard", isPremium: nil),
        WeatherPack(id: "winter-fronts", name: "Winter Fronts", isPremium: true)
    ]

    private let entitlementService: EntitlementService

    init(entitlementService: EntitlementService = LocalPreviewEntitlementService()) {
        self.entitlementService = entitlementService
        refreshEntitlements()
    }

    var canPreviewPremiumEntitlements: Bool {
        entitlementService.supportsPreviewToggle
    }

    var selectedAirport: AirportConfig? {
        airports.first { $0.icao == selectedAirportICAO }
    }

    var selectedWeatherPack: WeatherPack? {
        weatherPacks.first { $0.id == selectedWeatherPackID }
    }

    func setPreviewPremiumEntitlementsEnabled(_ isEnabled: Bool) {
        entitlementService.setPreviewPremiumEnabled(isEnabled)
        refreshEntitlements()
    }

    func canAccess(airport: AirportConfig) -> Bool {
        guard airport.isPremium == true else { return true }
        return hasPremiumEntitlements
    }

    func canAccess(weatherPack: WeatherPack) -> Bool {
        guard weatherPack.isPremium == true else { return true }
        return hasPremiumEntitlements
    }

    private func refreshEntitlements() {
        hasPremiumEntitlements = entitlementService.hasPremiumEntitlements
    }
}
