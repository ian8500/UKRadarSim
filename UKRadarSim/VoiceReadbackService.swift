import AVFoundation
import Foundation

enum PilotAccent: String {
    case british = "en-GB"
    case dutch = "nl-NL"
    case american = "en-US"
}

final class VoiceReadbackService {
    static let shared = VoiceReadbackService()

    private let synthesizer = AVSpeechSynthesizer()
    private var cachedVoiceByCallsign: [String: AVSpeechSynthesisVoice] = [:]
    private var femaleToggle = false

    private init() {}

    func speakReadback(for strip: EFPSStrip) {
        let phraseology = buildCAAReadback(for: strip)
        let utterance = AVSpeechUtterance(string: phraseology)
        utterance.voice = voice(for: strip.callsign)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    func buildCAAReadback(for strip: EFPSStrip) -> String {
        let callsign = strip.callsign
        let levelSegment: String
        let selected = strip.selectedLevel
        let current = strip.currentLevel

        let levelValue: String = selected < 70
            ? "altitude \(selected * 100) feet"
            : "flight level \(selected)"

        if selected > current {
            levelSegment = "climb \(levelValue)"
        } else if selected < current {
            levelSegment = "descend \(levelValue)"
        } else {
            levelSegment = "maintain \(levelValue)"
        }

        let headingSegment = "turn left heading \(String(format: "%03d", strip.selectedHeading))"
        let speedSegment = "reduce speed \(strip.selectedSpeed) knots"

        let approachSegment: String
        switch strip.approachType.uppercased() {
        case "ILS":
            approachSegment = "for ILS approach"
        case "RNAV":
            approachSegment = "for RNAV approach"
        case "VISUAL":
            approachSegment = "for visual approach"
        case "LOC":
            approachSegment = "for localizer approach"
        default:
            approachSegment = "for \(strip.approachType)"
        }

        return "\(callsign), roger, \(levelSegment), \(headingSegment), \(speedSegment), \(approachSegment)."
    }

    private func voice(for callsign: String) -> AVSpeechSynthesisVoice? {
        if let cached = cachedVoiceByCallsign[callsign] {
            return cached
        }

        let accent = accentForAirline(callsign: callsign)
        let available = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == accent.rawValue }

        let selected = selectMixedVoice(from: available)
            ?? AVSpeechSynthesisVoice(language: accent.rawValue)
            ?? AVSpeechSynthesisVoice(language: PilotAccent.american.rawValue)

        if let selected {
            cachedVoiceByCallsign[callsign] = selected
        }

        return selected
    }

    private func accentForAirline(callsign: String) -> PilotAccent {
        let prefix = String(callsign.prefix(3)).uppercased()

        switch prefix {
        case "EZY", "BAW", "SHT", "VIR", "LOG", "RYR":
            return .british
        case "KLM", "TRA":
            return .dutch
        default:
            return .american
        }
    }

    private func selectMixedVoice(from voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        guard !voices.isEmpty else {
            return nil
        }

        let femaleCandidates = voices.filter { looksFemale($0.name) }
        let maleCandidates = voices.filter { looksMale($0.name) }

        femaleToggle.toggle()

        if femaleToggle, let female = femaleCandidates.randomElement() {
            return female
        }

        if !femaleToggle, let male = maleCandidates.randomElement() {
            return male
        }

        return voices.randomElement()
    }

    private func looksFemale(_ voiceName: String) -> Bool {
        let lower = voiceName.lowercased()
        return ["fem", "samantha", "karen", "moira", "serena", "ava", "allison", "susan", "victoria", "fiona", "veena", "joana", "sofia", "anna", "emma"].contains { lower.contains($0) }
    }

    private func looksMale(_ voiceName: String) -> Bool {
        let lower = voiceName.lowercased()
        return ["male", "daniel", "alex", "fred", "jorge", "thomas", "arthur", "xander", "diego", "liam", "oliver", "nicky", "rishi", "reed"].contains { lower.contains($0) }
    }
}
