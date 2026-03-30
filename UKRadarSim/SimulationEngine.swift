import Foundation
import CoreGraphics

enum InstructionChange: Hashable {
    case level
    case heading
    case speed
    case approachType
    case ilsClearance
}

@MainActor
class SimulationEngine: ObservableObject {
    struct SafetyAlert: Identifiable {
        enum Severity {
            case advisory
            case warning
        }

        let id = UUID()
        let callsignPair: String
        let message: String
        let severity: Severity
    }

    @Published var aircraft: [Aircraft] = []
    @Published var strips: [EFPSStrip] = []
    @Published private(set) var isPaused = false
    @Published private(set) var score = 100
    @Published private(set) var activeAlerts: [SafetyAlert] = []
    @Published private(set) var landedCount = 0

    private let truthUpdateInterval: CGFloat = 0.1
    private let radarUpdateInterval: CGFloat = 6.0
    private var elapsedSinceRadarUpdate: CGFloat = 0
    private var verticalProgressByAircraft: [UUID: Double] = [:]

    private let geometry: RadarGeometry
    private let predictor = IntentAwareTrackPredictor()
    private let startupScenario: SimulationScenario
    private let motionService: AircraftMotionService
    private let conflictService: ConflictDetectionService
    private let approachService: ApproachAutomationService
    private let stripSyncService: StripSyncService
    private let scoringService: ScoringService

    init(
        geometry: RadarGeometry = .default,
        startupScenario: SimulationScenario = ScenarioLibrary.default,
        motionService: AircraftMotionService = .init(),
        conflictService: ConflictDetectionService = .init(),
        approachService: ApproachAutomationService = .init(),
        stripSyncService: StripSyncService = .init(),
        scoringService: ScoringService = .init()
    ) {
        self.geometry = geometry
        self.startupScenario = startupScenario
        self.motionService = motionService
        self.conflictService = conflictService
        self.approachService = approachService
        self.stripSyncService = stripSyncService
        self.scoringService = scoringService
        loadStartupTraffic()
        updateRadarDisplayedPositions()
    }

    private func loadStartupTraffic() {
        aircraft = ScenarioLoader.loadAircraft(from: startupScenario)

        strips = aircraft.map { item in
            EFPSStrip(
                aircraftID: item.id,
                callsign: item.callsign,
                aircraftType: item.aircraftType,
                destination: item.destination,
                isInbound: item.isInbound,
                bay: item.isInbound ? .inbound : .outbound,
                selectedLevel: item.selectedLevel,
                currentLevel: item.currentLevel,
                selectedHeading: Int(item.heading),
                currentHeading: Int(item.heading),
                selectedSpeed: item.groundSpeed,
                approachType: item.isInbound ? "ILS" : "SID",
                approachCleared: false,
                instructionLog: [],
                lastIssuedLevel: nil,
                lastIssuedHeading: nil,
                lastIssuedSpeed: nil,
                lastIssuedApproachType: nil
            )
        }
    }

    func step(dt: CGFloat) {
        guard dt > 0 else { return }
        var remainingStep = dt

        while remainingStep > 0 {
            let truthDelta = min(truthUpdateInterval, remainingStep)
            updateAircraftTruth(dt: truthDelta)
            elapsedSinceRadarUpdate += truthDelta

            while elapsedSinceRadarUpdate >= radarUpdateInterval {
                updateRadarDisplayedPositions()
                elapsedSinceRadarUpdate -= radarUpdateInterval
            }

            remainingStep -= truthDelta
        }

        recalculateOpsState()
        isPaused = false
    }

    func resetScenario() {
        verticalProgressByAircraft.removeAll()
        elapsedSinceRadarUpdate = 0
        score = 100
        activeAlerts.removeAll()
        landedCount = 0
        loadStartupTraffic()
        updateRadarDisplayedPositions()
    }

    private func updateAircraftTruth(dt: CGFloat) {
        for i in aircraft.indices {
            if aircraft[i].isLanded { continue }

            applyControllerTargetsIfNeeded(index: i, dt: dt)

            let updatedPosition = motionService.projectPosition(for: aircraft[i], dt: dt)
            aircraft[i].trueX = updatedPosition.x
            aircraft[i].trueY = updatedPosition.y

            applyApproachAutomationIfNeeded(index: i, dt: dt)
            motionService.wrapIfNeeded(aircraft: &aircraft[i], wrapBounds: geometry.wrapBounds)
            syncStripFromAircraft(at: i)
        }

        landedCount = aircraft.filter(\.isLanded).count
    }

    private func updateRadarDisplayedPositions() {
        for i in aircraft.indices {
            stripSyncService.appendRadarHistory(to: &aircraft[i])
        }
    }

    private func syncStripFromAircraft(at index: Int) {
        let currentAircraft = aircraft[index]

        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == currentAircraft.id }) else {
            return
        }

        stripSyncService.syncStrip(from: currentAircraft, strip: &strips[stripIndex])
    }

    private func applyControllerTargetsIfNeeded(index: Int, dt: CGFloat) {
        let aircraftID = aircraft[index].id

        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == aircraftID }) else {
            return
        }

        var verticalProgress = verticalProgressByAircraft[aircraftID, default: 0]
        motionService.applyControllerTargets(
            to: &aircraft[index],
            strip: strips[stripIndex],
            dt: dt,
            verticalProgress: &verticalProgress
        )
        verticalProgressByAircraft[aircraftID] = verticalProgress
    }

    func predictedPosition(for aircraftID: UUID, lookaheadSeconds: Double) -> CGPoint? {
        guard let track = aircraft.first(where: { $0.id == aircraftID }) else {
            return nil
        }

        let intentLookup = intentByAircraftID()
        let startPosition = CGPoint(x: track.trueX, y: track.trueY)
        return predictedState(
            for: track,
            intentLookup: intentLookup,
            lookaheadSeconds: lookaheadSeconds,
            startPosition: startPosition
        ).projectedPosition
    }

    func predictedDisplayPosition(for aircraftID: UUID, lookaheadSeconds: Double) -> CGPoint? {
        guard let track = aircraft.first(where: { $0.id == aircraftID }) else {
            return nil
        }

        let intentLookup = intentByAircraftID()
        let startPosition = CGPoint(x: track.displayX, y: track.displayY)
        return predictedState(
            for: track,
            intentLookup: intentLookup,
            lookaheadSeconds: lookaheadSeconds,
            startPosition: startPosition
        ).projectedPosition
    }

    func predictedStates(lookaheadSeconds: Double) -> [PredictedAircraftState] {
        predictor.predictedStates(
            for: aircraft,
            intentByAircraftID: intentByAircraftID(),
            lookaheadSeconds: lookaheadSeconds
        )
    }

    func sendInstruction(stripID: UUID, changedFields: Set<InstructionChange> = []) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        let instruction = VoiceReadbackService.shared.buildIssuedInstruction(
            for: strips[stripIndex],
            changedFields: changedFields
        )

        guard !instruction.isEmpty else {
            strips[stripIndex].instructionLog.insert("\(strips[stripIndex].callsign) | NO NEW INSTRUCTION", at: 0)
            return
        }

        let strip = strips[stripIndex]
        let phraseology = VoiceReadbackService.shared.buildCAAReadback(for: strip, instruction: instruction)

        strips[stripIndex].instructionLog.insert(phraseology, at: 0)
        strips[stripIndex].lastIssuedLevel = strip.selectedLevel
        strips[stripIndex].lastIssuedHeading = strip.selectedHeading
        strips[stripIndex].lastIssuedSpeed = strip.selectedSpeed
        strips[stripIndex].lastIssuedApproachType = strip.approachType

        Task { @MainActor in
            VoiceReadbackService.shared.speakReadback(
                phraseology: phraseology,
                callsign: strip.callsign
            )
        }
    }

    func flitStrip(stripID: UUID, to bay: StripBay) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].bay = bay
    }

    func armILSIntercept(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].approachType = "ILS"
        strips[stripIndex].approachCleared = true
    }

    func clearForApproach(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].approachCleared = true
        let strip = strips[stripIndex]
        let instruction = "\(strip.callsign) | CLEARED \(strip.approachType) APPROACH"
        strips[stripIndex].instructionLog.insert(instruction, at: 0)
    }

    private func applyApproachAutomationIfNeeded(index: Int, dt: CGFloat) {
        let aircraftID = aircraft[index].id

        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == aircraftID }) else {
            return
        }

        let outcome = approachService.apply(
            to: &aircraft[index],
            strip: strips[stripIndex],
            geometry: geometry,
            dt: dt
        )

        if outcome.didCaptureLocalizer {
            strips[stripIndex].instructionLog.insert("\(aircraft[index].callsign) | LOC CAPTURED", at: 0)
        }

        if outcome.didLand {
            strips[stripIndex].instructionLog.insert("\(aircraft[index].callsign) | LANDED", at: 0)
        }
    }

    private func recalculateOpsState() {
        let intentLookup = intentByAircraftID()
        let conflicts = conflictService.detectConflicts(aircraft: aircraft) { [predictor] track, lookaheadSeconds in
            predictor.predictedState(
                for: track,
                intent: intentLookup[track.id] ?? TrackIntent(
                    selectedHeading: track.heading,
                    selectedSpeed: track.groundSpeed,
                    selectedLevel: track.currentLevel
                ),
                lookaheadSeconds: lookaheadSeconds,
                startPosition: CGPoint(x: track.trueX, y: track.trueY)
            ).projectedPosition
        }

        score = scoringService.computeScore(landedCount: landedCount, conflicts: conflicts)
        activeAlerts = conflicts.map {
            SafetyAlert(callsignPair: $0.callsignPair, message: $0.message, severity: $0.severity)
        }
    }

    private func intentByAircraftID() -> [UUID: TrackIntent] {
        Dictionary(uniqueKeysWithValues: strips.map { strip in
            (
                strip.aircraftID,
                TrackIntent(
                    selectedHeading: Double(strip.selectedHeading),
                    selectedSpeed: strip.selectedSpeed,
                    selectedLevel: strip.selectedLevel
                )
            )
        })
    }

    private func predictedState(
        for track: Aircraft,
        intentLookup: [UUID: TrackIntent],
        lookaheadSeconds: Double,
        startPosition: CGPoint
    ) -> PredictedAircraftState {
        let intent = intentLookup[track.id] ?? TrackIntent(
            selectedHeading: track.heading,
            selectedSpeed: track.groundSpeed,
            selectedLevel: track.currentLevel
        )
        return predictor.predictedState(
            for: track,
            intent: intent,
            lookaheadSeconds: lookaheadSeconds,
            startPosition: startPosition
        )
    }
}
