import Foundation
import CoreGraphics

struct ScenarioAircraftDefinition {
    let callsign: String
    let aircraftType: String
    let position: CGPoint
    let heading: Double
    let groundSpeed: Int
    let currentLevel: Int
    let selectedLevel: Int
    let trend: VerticalTrend
    let destination: String
    let isInbound: Bool

    func makeAircraft() -> Aircraft {
        Aircraft(
            callsign: callsign,
            trueX: position.x,
            trueY: position.y,
            displayX: position.x,
            displayY: position.y,
            heading: heading,
            groundSpeed: groundSpeed,
            currentLevel: currentLevel,
            selectedLevel: selectedLevel,
            trend: trend,
            aircraftType: aircraftType,
            destination: destination,
            isInbound: isInbound
        )
    }
}

struct SimulationScenario {
    let id: String
    let aircraft: [ScenarioAircraftDefinition]
}

enum ScenarioLibrary {
    static let `default` = SimulationScenario(
        id: "default",
        aircraft: [
            ScenarioAircraftDefinition(
                callsign: "EZY15WY",
                aircraftType: "A320",
                position: CGPoint(x: 240, y: 310),
                heading: 45,
                groundSpeed: 360,
                currentLevel: 107,
                selectedLevel: 80,
                trend: .descend,
                destination: "KK",
                isInbound: true
            ),
            ScenarioAircraftDefinition(
                callsign: "BAW214",
                aircraftType: "B738",
                position: CGPoint(x: 530, y: 450),
                heading: 230,
                groundSpeed: 280,
                currentLevel: 40,
                selectedLevel: 50,
                trend: .climb,
                destination: "EGLL",
                isInbound: false
            )
        ]
    )
}

enum ScenarioLoader {
    static func loadAircraft(from scenario: SimulationScenario) -> [Aircraft] {
        scenario.aircraft.map { $0.makeAircraft() }
    }
}
