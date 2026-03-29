import Foundation

enum VectorSetting: Int, CaseIterable, Identifiable {
    case off = 0
    case sec60 = 60
    case sec120 = 120
    case sec180 = 180

    var id: Int { rawValue }

    var toolbarLabel: String {
        switch self {
        case .off: return "Vectors: Off"
        case .sec60: return "Vectors: 60 sec"
        case .sec120: return "Vectors: 120 sec"
        case .sec180: return "Vectors: 180 sec"
        }
    }

    var menuLabel: String {
        switch self {
        case .off: return "Off"
        case .sec60: return "60 sec"
        case .sec120: return "120 sec"
        case .sec180: return "180 sec"
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
    @Published var activeScreen: AppScreen = .home
    @Published var selectedDifficulty: DifficultyLevel = .standard
    @Published var selectedAirportICAO: String = "EGKK"

    @Published var featureAccess = FeatureAccess()

    // Seed content; premium flags are optional by design.
    @Published var airports: [AirportConfig] = [
        AirportConfig(icao: "EGKK", name: "London Gatwick", isPremium: nil),
        AirportConfig(icao: "EGLL", name: "London Heathrow", isPremium: true),
        AirportConfig(icao: "EGCC", name: "Manchester", isPremium: true)
    ]

    @Published var weatherPacks: [WeatherPack] = [
        WeatherPack(id: "standard-uk", name: "UK Standard", isPremium: nil),
        WeatherPack(id: "winter-fronts", name: "Winter Fronts", isPremium: true)
    ]

    var selectedAirport: AirportConfig? {
        airports.first { $0.icao == selectedAirportICAO }
    }

    func canAccess(airport: AirportConfig) -> Bool {
        // Future StoreKit hook:
        // Replace tier check with a full entitlement resolver
        // (e.g. product-level unlocks, grace period, family sharing).
        guard airport.isPremium == true else { return true }
        return featureAccess.hasPremiumEntitlements
    }

    func canAccess(weatherPack: WeatherPack) -> Bool {
        guard weatherPack.isPremium == true else { return true }
        return featureAccess.hasPremiumEntitlements
    }
}
