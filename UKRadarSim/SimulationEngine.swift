import Foundation
import CoreGraphics

class SimulationEngine: ObservableObject {
    @Published var aircraft: [Aircraft] = []
    @Published var strips: [EFPSStrip] = []

    private var movementTimer: Timer?
    private var radarTimer: Timer?

    init() {
        setupTestAircraft()
        start()
    }

    deinit {
        movementTimer?.invalidate()
        radarTimer?.invalidate()
    }

    private func setupTestAircraft() {
        aircraft = [
            Aircraft(
                callsign: "EZY15WY",
                trueX: 240,
                trueY: 310,
                displayX: 240,
                displayY: 310,
                heading: 45,
                groundSpeed: 360,
                currentLevel: 107,
                selectedLevel: 80,
                trend: .descend,
                destination: "KK",
                isInbound: true
            ),
            Aircraft(
                callsign: "BAW214",
                trueX: 530,
                trueY: 450,
                displayX: 530,
                displayY: 450,
                heading: 230,
                groundSpeed: 280,
                currentLevel: 40,
                selectedLevel: 50,
                trend: .climb,
                destination: "EGLL",
                isInbound: false
            )
        ]

        strips = aircraft.map { item in
            EFPSStrip(
                aircraftID: item.id,
                callsign: item.callsign,
                aircraftType: item.isInbound ? "A320" : "B738",
                destination: item.destination,
                isInbound: item.isInbound,
                bay: item.isInbound ? .inbound : .outbound,
                selectedLevel: item.selectedLevel,
                currentLevel: item.currentLevel,
                selectedHeading: Int(item.heading),
                selectedSpeed: item.groundSpeed,
                approachType: item.isInbound ? "ILS" : "SID",
                approachCleared: false,
                instructionLog: []
            )
        }
    }

    private func start() {
        movementTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAircraftTruth()
        }

        radarTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            self?.updateRadarDisplayedPositions()
        }
    }

    private func updateAircraftTruth() {
        let dt: CGFloat = 0.1

        for i in aircraft.indices {
            let headingRad = CGFloat(aircraft[i].heading * .pi / 180.0)

            // Temporary pixels-per-knot scale for prototype
            let speedScale: CGFloat = 0.02
            let distance = CGFloat(aircraft[i].groundSpeed) * speedScale * dt

            aircraft[i].trueX += cos(headingRad) * distance
            aircraft[i].trueY -= sin(headingRad) * distance

            wrapAircraftIfNeeded(index: i)
            syncStripFromAircraft(at: i)
        }
    }

    private func updateRadarDisplayedPositions() {
        for i in aircraft.indices {
            aircraft[i].displayX = aircraft[i].trueX
            aircraft[i].displayY = aircraft[i].trueY
        }
    }

    private func wrapAircraftIfNeeded(index: Int) {
        if aircraft[index].trueX > 1100 { aircraft[index].trueX = -100 }
        if aircraft[index].trueX < -100 { aircraft[index].trueX = 1100 }
        if aircraft[index].trueY > 900 { aircraft[index].trueY = -100 }
        if aircraft[index].trueY < -100 { aircraft[index].trueY = 900 }
    }

    private func syncStripFromAircraft(at index: Int) {
        let currentAircraft = aircraft[index]
        guard let stripIndex = strips.firstIndex(where: { $0.aircraftID == currentAircraft.id }) else {
            return
        }

        strips[stripIndex].currentLevel = currentAircraft.currentLevel
    }

    func sendInstruction(stripID: UUID) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        let strip = strips[stripIndex]
        let phraseology = VoiceReadbackService.shared.buildCAAReadback(for: strip)

        strips[stripIndex].instructionLog.insert(phraseology, at: 0)
        VoiceReadbackService.shared.speakReadback(for: strip)
    }

    func flitStrip(stripID: UUID, to bay: StripBay) {
        guard let stripIndex = strips.firstIndex(where: { $0.id == stripID }) else {
            return
        }

        strips[stripIndex].bay = bay
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
}
