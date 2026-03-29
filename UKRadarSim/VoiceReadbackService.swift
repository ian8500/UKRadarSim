import AVFoundation
import Foundation

enum PilotAccent: String {
    case british = "en-GB"
    case dutch = "nl-NL"
    case american = "en-US"
}

@MainActor
final class VoiceReadbackService {
    static let shared = VoiceReadbackService()

    private let synthesizer = AVSpeechSynthesizer()
    private var cachedVoiceByCallsign: [String: AVSpeechSynthesisVoice] = [:]
    private var femaleToggle = false

    private init() {}

    func speakReadback(phraseology: String, callsign: String) {
        guard !phraseology.isEmpty else {
            return
        }

        let utterance = AVSpeechUtterance(string: phraseology)
        utterance.voice = voice(for: callsign)
        utterance.rate = 0.44
        utterance.pitchMultiplier = 0.96
        utterance.volume = 0.95
        utterance.prefersAssistiveTechnologySettings = true

        synthesizer.speak(utterance)
    }

    nonisolated func buildIssuedInstruction(for strip: EFPSStrip, changedFields: Set<InstructionChange> = []) -> [String] {
        var segments: [String] = []
        let useExplicitChanges = !changedFields.isEmpty

        let includeLevel = useExplicitChanges
            ? changedFields.contains(.level)
            : strip.lastIssuedLevel != strip.selectedLevel
        if includeLevel && strip.lastIssuedLevel != strip.selectedLevel {
            let selected = strip.selectedLevel
            let current = strip.currentLevel
            let levelValue: String = selected < 70
                ? "altitude \(spokenAltitude(selected * 100)) feet"
                : "flight level \(digitWise(selected))"

            if selected > current {
                segments.append("climb \(levelValue)")
            } else if selected < current {
                segments.append("descend \(levelValue)")
            } else {
                segments.append("maintain \(levelValue)")
            }
        }

        let includeHeading = useExplicitChanges
            ? changedFields.contains(.heading)
            : strip.lastIssuedHeading != strip.selectedHeading
        if includeHeading && strip.lastIssuedHeading != strip.selectedHeading {
            let headingReadback = spokenHeading(strip.selectedHeading)
            if changedFields.contains(.ilsClearance) {
                segments.append("head \(headingReadback)")
            } else {
                let direction = turnDirection(from: strip.currentHeading, to: strip.selectedHeading)
                segments.append("turn \(direction) heading \(headingReadback)")
            }
        }

        let includeSpeed = useExplicitChanges
            ? changedFields.contains(.speed)
            : strip.lastIssuedSpeed != strip.selectedSpeed
        if includeSpeed && strip.lastIssuedSpeed != strip.selectedSpeed {
            let speedVerb: String
            if let lastIssuedSpeed = strip.lastIssuedSpeed {
                speedVerb = strip.selectedSpeed < lastIssuedSpeed ? "reduce" : "increase"
            } else {
                speedVerb = "maintain"
            }
            segments.append("\(speedVerb) speed \(digitWise(strip.selectedSpeed)) knots")
        }

        let selectedApproach = strip.approachType.uppercased()
        let lastIssuedApproach = strip.lastIssuedApproachType?.uppercased() ?? ""
        let approachChanged = lastIssuedApproach != selectedApproach

        let includeApproach = useExplicitChanges
            ? changedFields.contains(.approachType)
            : approachChanged
        if includeApproach && approachChanged {
            segments.append(approachSegment(for: strip.approachType))
        }


        if changedFields.contains(.ilsClearance) {
            segments.append("cleared I L S approach")
        }

        return segments
    }

    nonisolated func buildCAAReadback(for strip: EFPSStrip, instruction: [String]) -> String {
        let callsign = spokenCallsign(from: strip.callsign)
        let instructionText = instruction.joined(separator: ", ")
        return "\(instructionText), \(callsign)."
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

    nonisolated private func approachSegment(for approachType: String) -> String {
        switch approachType.uppercased() {
        case "ILS":
            return "for I L S approach"
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

    nonisolated private func spokenCallsign(from callsign: String) -> String {
        let prefix = String(callsign.prefix(3)).uppercased()
        let suffix = String(callsign.dropFirst(3))

        let spokenPrefix: String
        switch prefix {
        case "BAW":
            spokenPrefix = "Speedbird"
        case "EZY":
            spokenPrefix = "Easy"
        default:
            spokenPrefix = prefix
        }

        let spokenSuffix = suffix.map { String($0) }.map(spokenToken(for:)).joined(separator: " ")
        if spokenSuffix.isEmpty {
            return spokenPrefix
        }
        return "\(spokenPrefix) \(spokenSuffix)"
    }

    nonisolated private func turnDirection(from current: Int, to target: Int) -> String {
        let normalizedCurrent = normalizedHeading(current)
        let normalizedTarget = normalizedHeading(target)
        let clockwiseDelta = (normalizedTarget - normalizedCurrent + 360) % 360
        let counterclockwiseDelta = (normalizedCurrent - normalizedTarget + 360) % 360

        return clockwiseDelta <= counterclockwiseDelta ? "right" : "left"
    }

    nonisolated private func normalizedHeading(_ heading: Int) -> Int {
        (heading % 360 + 360) % 360
    }

    nonisolated private func digitWise(_ value: Int, width: Int? = nil) -> String {
        let stringValue = width.map { String(format: "%0\($0)d", value) } ?? String(value)
        return stringValue.map { spokenToken(for: String($0)) }.joined(separator: " ")
    }

    nonisolated private func spokenHeading(_ heading: Int) -> String {
        let normalized = normalizedHeading(heading)
        let headingDigits = digitWise(normalized, width: 3)

        if normalized % 10 == 0 {
            return "\(headingDigits) degrees"
        }

        return headingDigits
    }

    nonisolated private func spokenAltitude(_ feet: Int) -> String {
        if feet <= 0 {
            return "zero"
        }

        if feet % 1000 == 0 {
            let thousands = feet / 1000
            if thousands == 1 {
                return "one thousand"
            }
            return "\(spokenCardinal(thousands)) thousand"
        }

        if feet % 100 == 0 {
            let hundreds = feet / 100
            if hundreds == 1 {
                return "one hundred"
            }
            return "\(spokenCardinal(hundreds)) hundred"
        }

        return digitWise(feet)
    }

    nonisolated private func spokenCardinal(_ value: Int) -> String {
        switch value {
        case 0: return "zero"
        case 1: return "one"
        case 2: return "two"
        case 3: return "three"
        case 4: return "four"
        case 5: return "five"
        case 6: return "six"
        case 7: return "seven"
        case 8: return "eight"
        case 9: return "nine"
        case 10: return "ten"
        case 11: return "eleven"
        case 12: return "twelve"
        case 13: return "thirteen"
        case 14: return "fourteen"
        case 15: return "fifteen"
        case 16: return "sixteen"
        case 17: return "seventeen"
        case 18: return "eighteen"
        case 19: return "nineteen"
        case 20: return "twenty"
        case 30: return "thirty"
        case 40: return "forty"
        case 50: return "fifty"
        case 60: return "sixty"
        case 70: return "seventy"
        case 80: return "eighty"
        case 90: return "ninety"
        case 21...99:
            let tens = (value / 10) * 10
            let ones = value % 10
            return "\(spokenCardinal(tens)) \(spokenCardinal(ones))"
        default:
            return String(value)
        }
    }

    nonisolated private func spokenToken(for token: String) -> String {
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
