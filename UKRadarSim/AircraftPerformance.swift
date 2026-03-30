import Foundation

struct AircraftPerformanceProfile: Equatable {
    let maxTurnRateDegreesPerSecond: Double
    let climbRateFLPerSecond: Double
    let descentRateFLPerSecond: Double
    let accelerationRateKnotsPerSecond: Double
    let decelerationRateKnotsPerSecond: Double
    let typicalApproachSpeedKnots: Int

    static let genericJet = AircraftPerformanceProfile(
        maxTurnRateDegreesPerSecond: 3.0,
        climbRateFLPerSecond: 2.0,
        descentRateFLPerSecond: 2.4,
        accelerationRateKnotsPerSecond: 2.0,
        decelerationRateKnotsPerSecond: 2.2,
        typicalApproachSpeedKnots: 150
    )
}

protocol AircraftPerformanceProviding {
    func profile(for aircraftType: String) -> AircraftPerformanceProfile
}

struct AircraftPerformanceCatalog: AircraftPerformanceProviding {
    private let profilesByType: [String: AircraftPerformanceProfile]
    private let fallbackProfile: AircraftPerformanceProfile

    init(
        profilesByType: [String: AircraftPerformanceProfile] = AircraftPerformanceCatalog.starterProfiles,
        fallbackProfile: AircraftPerformanceProfile = .genericJet
    ) {
        self.profilesByType = profilesByType
        self.fallbackProfile = fallbackProfile
    }

    func profile(for aircraftType: String) -> AircraftPerformanceProfile {
        profilesByType[aircraftType.uppercased()] ?? fallbackProfile
    }

    static let starterProfiles: [String: AircraftPerformanceProfile] = [
        "A320": AircraftPerformanceProfile(
            maxTurnRateDegreesPerSecond: 3.0,
            climbRateFLPerSecond: 2.0,
            descentRateFLPerSecond: 2.5,
            accelerationRateKnotsPerSecond: 2.1,
            decelerationRateKnotsPerSecond: 2.4,
            typicalApproachSpeedKnots: 145
        ),
        "B738": AircraftPerformanceProfile(
            maxTurnRateDegreesPerSecond: 2.8,
            climbRateFLPerSecond: 1.9,
            descentRateFLPerSecond: 2.3,
            accelerationRateKnotsPerSecond: 2.0,
            decelerationRateKnotsPerSecond: 2.2,
            typicalApproachSpeedKnots: 150
        ),
        "E190": AircraftPerformanceProfile(
            maxTurnRateDegreesPerSecond: 3.4,
            climbRateFLPerSecond: 2.1,
            descentRateFLPerSecond: 2.6,
            accelerationRateKnotsPerSecond: 2.3,
            decelerationRateKnotsPerSecond: 2.6,
            typicalApproachSpeedKnots: 138
        ),
        "A321": AircraftPerformanceProfile(
            maxTurnRateDegreesPerSecond: 2.6,
            climbRateFLPerSecond: 1.8,
            descentRateFLPerSecond: 2.2,
            accelerationRateKnotsPerSecond: 1.8,
            decelerationRateKnotsPerSecond: 2.0,
            typicalApproachSpeedKnots: 150
        )
    ]
}
