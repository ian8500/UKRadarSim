import Foundation

struct ScoringConfig {
    let startingScore: Int
    let landedBonus: Int
    let warningPenalty: Int
    let advisoryPenalty: Int

    static let `default` = ScoringConfig(
        startingScore: 100,
        landedBonus: 5,
        warningPenalty: 12,
        advisoryPenalty: 5
    )
}

struct ScoringService {
    let config: ScoringConfig

    init(config: ScoringConfig = .default) {
        self.config = config
    }

    func computeScore(landedCount: Int, conflicts: [ConflictDetectionService.Conflict]) -> Int {
        var score = config.startingScore + (landedCount * config.landedBonus)

        for conflict in conflicts {
            switch conflict.severity {
            case .warning:
                score -= config.warningPenalty
            case .advisory:
                score -= config.advisoryPenalty
            }
        }

        return max(0, score)
    }
}
