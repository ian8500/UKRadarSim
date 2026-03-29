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
        let instruction = buildIssuedInstruction(for: strip)
        guard !instruction.isEmpty else {
            return
        }

        let phraseology = buildCAAReadback(for: strip, instruction: instruction)
        let utterance = AVSpeechUtterance(string: phraseology)
        utterance.voice = voice(for: strip.callsign)
        utterance.rate = 0.44
        utterance.pitchMultiplier = 0.96
        utterance.volume = 0.95
        utterance.prefersAssistiveTechnologySettings = true

        synthesizer.speak(utterance)
    }

    func buildIssuedInstruction(for strip: EFPSStrip) -> [String] {
        var segments: [String] = []

        if strip.lastIssuedLevel != strip.selectedLevel {
            let selected = strip.selectedLevel
            let current = strip.currentLevel
            let levelValue: String = selected < 70
                ? "altitude \(digitWise(selected * 100)) feet"
                : "flight level \(digitWise(selected))"

            if selected > current {
                segments.append("climb \(levelValue)")
            } else if selected < current {
                segments.append("descend \(levelValue)")
            } else {
                segments.append("maintain \(levelValue)")
            }
        }

        if strip.lastIssuedHeading != strip.selectedHeading {
            segments.append("turn left heading \(digitWise(strip.selectedHeading, width: 3))")
        }

        if strip.lastIssuedSpeed != strip.selectedSpeed {
            segments.append("reduce speed \(digitWise(strip.selectedSpeed)) knots")
        }

        if strip.lastIssuedApproachType?.uppercased() != strip.approachType.uppercased() {
            segments.append(approachSegment(for: strip.approachType))
        }

        return segments
    }

    func buildCAAReadback(for strip: EFPSStrip, instruction: [String]) -> String {
        let callsign = spokenCallsign(from: strip.callsign)
        let instructionText = instruction.joined(separator: ", ")
        return "\(callsign), roger, \(instructionText)."
    }

    private func voice(for callsign: String) -> AVSpeechSynthesisVoice? {
        if let cached = cachedVoiceByCallsign[callsign] {
            return cached
        }

        let accent = accentForAirline(callsign: callsign)
        let available = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == accent.rawValue }
        let ranked = rankVoices(available)

        let selected = selectMixedVoice(from: ranked)
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

    private func approachSegment(for approachType: String) -> String {
        switch approachType.uppercased() {
        case "ILS":
            return "for ILS approach"
        case "RNAV":
            return "for RNAV approach"
        case "VISUAL":
            return "for visual approach"
        case "LOC":
            return "for localizer approach"
        default:
            return "for \(approachType)"
        }
    }

    private func spokenCallsign(from callsign: String) -> String {
        let prefix = String(callsign.prefix(3)).uppercased()
        let suffix = String(callsign.dropFirst(3))

        let spokenPrefix: String
        switch prefix {
        case "BAW":
            spokenPrefix = "Speedbird"
        case "EZY":
            spokenPrefix = "easyJet"
        default:
            spokenPrefix = prefix
        }

        let spokenSuffix = suffix.map { String($0) }.map(spokenToken(for:)).joined(separator: " ")
        if spokenSuffix.isEmpty {
            return spokenPrefix
        }
        return "\(spokenPrefix) \(spokenSuffix)"
    }

    private func digitWise(_ value: Int, width: Int? = nil) -> String {
        let stringValue = width.map { String(format: "%0\($0)d", value) } ?? String(value)
        return stringValue.map { spokenToken(for: String($0)) }.joined(separator: " ")
    }

    private func spokenToken(for token: String) -> String {
        switch token.uppercased() {
        case "0": return "zero"
        case "1": return "one"
        case "2": return "two"
        case "3": return "three"
        case "4": return "four"
        case "5": return "five"
        case "6": return "six"
        case "7": return "seven"
        case "8": return "eight"
        case "9": return "nine"
        case "A": return "alpha"
        case "B": return "bravo"
        case "C": return "charlie"
        case "D": return "delta"
        case "E": return "echo"
        case "F": return "foxtrot"
        case "G": return "golf"
        case "H": return "hotel"
        case "I": return "india"
        case "J": return "juliet"
        case "K": return "kilo"
        case "L": return "lima"
        case "M": return "mike"
        case "N": return "november"
        case "O": return "oscar"
        case "P": return "papa"
        case "Q": return "quebec"
        case "R": return "romeo"
        case "S": return "sierra"
        case "T": return "tango"
        case "U": return "uniform"
        case "V": return "victor"
        case "W": return "whiskey"
        case "X": return "x-ray"
        case "Y": return "yankee"
        case "Z": return "zulu"
        default:
            return token
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

    private func rankVoices(_ voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
        voices.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }
    }

    private func score(_ voice: AVSpeechSynthesisVoice) -> Int {
        let qualityScore: Int
        switch voice.quality {
        case .premium:
            qualityScore = 300
        case .enhanced:
            qualityScore = 200
        default:
            qualityScore = 100
        }

        let name = voice.name.lowercased()
        let identifier = voice.identifier.lowercased()

        var realismBoost = 0
        if name.contains("siri") || identifier.contains("siri") {
            realismBoost += 25
        }
        if identifier.contains("premium") {
            realismBoost += 15
        }
        if identifier.contains("enhanced") {
            realismBoost += 10
        }

        return qualityScore + realismBoost
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
