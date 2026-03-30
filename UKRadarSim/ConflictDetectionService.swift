import Foundation
import CoreGraphics

struct ConflictDetectionConfig {
    let warningMaxLevelDelta: Int
    let warningMaxDistance: CGFloat
    let advisoryMaxLevelDelta: Int
    let advisoryMaxProjectedDistance: CGFloat
    let advisoryLookaheadSeconds: Double

    static let `default` = ConflictDetectionConfig(
        warningMaxLevelDelta: 10,
        warningMaxDistance: 40,
        advisoryMaxLevelDelta: 20,
        advisoryMaxProjectedDistance: 60,
        advisoryLookaheadSeconds: 90
    )
}

struct ConflictDetectionService {
    struct Conflict {
        let callsignPair: String
        let severity: SimulationEngine.SafetyAlert.Severity
        let message: String
    }

    let config: ConflictDetectionConfig

    init(config: ConflictDetectionConfig = .default) {
        self.config = config
    }

    func detectConflicts(aircraft: [Aircraft], predictor: (Aircraft, Double) -> CGPoint) -> [Conflict] {
        var conflicts: [Conflict] = []

        for firstIndex in aircraft.indices {
            for secondIndex in aircraft.indices where secondIndex > firstIndex {
                let first = aircraft[firstIndex]
                let second = aircraft[secondIndex]

                if first.isLanded || second.isLanded {
                    continue
                }

                let levelDelta = abs(first.currentLevel - second.currentLevel)
                let currentDistance = hypot(first.trueX - second.trueX, first.trueY - second.trueY)

                if levelDelta <= config.warningMaxLevelDelta && currentDistance < config.warningMaxDistance {
                    conflicts.append(
                        Conflict(
                            callsignPair: "\(first.callsign)/\(second.callsign)",
                            severity: .warning,
                            message: "Immediate separation risk"
                        )
                    )
                    continue
                }

                let projectedFirst = predictor(first, config.advisoryLookaheadSeconds)
                let projectedSecond = predictor(second, config.advisoryLookaheadSeconds)
                let projectedDistance = hypot(projectedFirst.x - projectedSecond.x, projectedFirst.y - projectedSecond.y)

                if levelDelta <= config.advisoryMaxLevelDelta && projectedDistance < config.advisoryMaxProjectedDistance {
                    conflicts.append(
                        Conflict(
                            callsignPair: "\(first.callsign)/\(second.callsign)",
                            severity: .advisory,
                            message: "Predicted loss of separation in 90s"
                        )
                    )
                }
            }
        }

        return conflicts
    }
}
