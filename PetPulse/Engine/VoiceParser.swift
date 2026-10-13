import Foundation

/// How a spoken observation compares with the pet's usual pattern.
enum VoiceLevel: Equatable {
    case lower, slightlyLower, normal, slightlyHigher, higher

    /// Multiplier applied to the pet's usual value. "Slightly" stays inside `BaselineEngine.threshold`.
    var factor: Double {
        switch self {
        case .lower: 0.7
        case .slightlyLower: 0.85
        case .normal: 1
        case .slightlyHigher: 1.15
        case .higher: 1.3
        }
    }

    var label: String {
        switch self {
        case .lower: "Less than usual"
        case .slightlyLower: "Slightly lower"
        case .normal: "Normal"
        case .slightlyHigher: "Slightly higher"
        case .higher: "More than usual"
        }
    }
}

enum VoiceReading: Equatable {
    /// Relative to the pet's usual value, as in "ate less".
    case level(VoiceLevel)
    /// An explicit quantity, as in "40 grams".
    case amount(Double)

    /// The value to put in the form, snapped to the field's step and range.
    func value(usual: Double, step: Double, in range: ClosedRange<Double>) -> Double {
        let raw: Double
        switch self {
        case .level(let level): raw = usual * level.factor
        case .amount(let amount): raw = amount
        }
        return min(max((raw / step).rounded() * step, range.lowerBound), range.upperBound)
    }
}

/// What a spoken check-in said. Anything not mentioned stays nil so the form keeps its value.
struct VoiceCheckIn: Equatable {
    var transcript = ""
    var readings: [Metric: VoiceReading] = [:]
    var stoolNormal: Bool?
    var urinationNormal: Bool?

    /// Text for the first of `metrics` that was mentioned.
    func label(_ metrics: [Metric], unit: String = "") -> String? {
        guard let reading = metrics.compactMap({ readings[$0] }).first else { return nil }
        switch reading {
        case .level(let level): return level.label
        case .amount(let amount): return "\(Int(amount)) \(unit)"
        }
    }

    var stoolLabel: String? {
        if stoolNormal == false || urinationNormal == false { return "Not normal" }
        return label([.stool], unit: "today") ?? (stoolNormal == true || urinationNormal == true ? "Normal" : nil)
    }
}

/// Turns a transcript into check-in values.
///
/// Clear wording is matched directly. Phrasing with no known keyword or cue ("bouncing off the
/// walls") is matched by meaning, using sentence-embedding similarity against example phrases.
enum VoiceParser {
    /// Cosine similarity of two phrases, or nil when no embedding is available.
    typealias Similarity = (String, String) -> Double?

    /// An embedding match below this is treated as "not about any topic".
    static let minSimilarity = 0.5

    enum Topic: CaseIterable {
        case food, water, stool, activity

        /// Word beginnings that name the topic outright.
        var stems: [String] {
            switch self {
            case .food: ["ate", "eat", "food", "fed", "feed", "kibble", "meal", "appetite", "breakfast", "dinner", "treat", "hungry"]
            case .water: ["water", "drank", "drink", "drunk", "thirst"]
            case .stool: VoiceParser.stoolStems + VoiceParser.urineStems + VoiceParser.abnormalStoolStems
            case .activity: ["activ", "energ", "play", "letharg", "sleep", "slept", "tired", "mood", "zoomies", "restless", "lazy"]
            }
        }

        /// Phrases an unfamiliar clause is compared with to find its topic.
        var examples: [String] {
            switch self {
            case .food: ["she ate her food", "her appetite at mealtime", "she finished what was in her bowl"]
            case .water: ["she drank water", "she kept going to the water bowl"]
            case .stool: ["she used the litter box", "her bowel movements and urination"]
            case .activity: ["she was playing and running around", "her energy and behavior", "she rested all day"]
            }
        }

        /// One phrase per direction, used when a clause names the topic but gives no clear cue.
        var levelExamples: [(VoiceLevel, String)] {
            switch self {
            case .food: [(.lower, "she ate much less than usual"), (.normal, "she ate a normal amount"), (.higher, "she ate much more than usual")]
            case .water: [(.lower, "she drank much less than usual"), (.normal, "she drank a normal amount"), (.higher, "she drank much more than usual")]
            case .stool: [(.lower, "she went to the litter box less than usual"), (.normal, "her litter box use was normal"), (.higher, "she went to the litter box more than usual")]
            case .activity: [(.lower, "she was lethargic and slept all day"), (.normal, "she was her usual self"), (.higher, "she was hyperactive and would not settle")]
            }
        }
    }

    static func parse(_ transcript: String, similarity: Similarity) -> VoiceCheckIn {
        var result = VoiceCheckIn(transcript: transcript.trimmingCharacters(in: .whitespacesAndNewlines))
        for sentence in transcript.split(separator: #/[.!?;]+(\s+|$)/#) {
            // Clauses that name a topic but say nothing about it yet, as in "food and water were normal".
            var pending: [(clause: Clause, topics: [Topic])] = []
            for part in sentence.split(separator: #/,|\b(and|but|while|though|then)\b/#.ignoresCase()) {
                let clause = Clause(String(part))
                guard !clause.words.isEmpty else { continue }
                let topics = topics(in: clause, similarity)
                let level = level(in: clause)
                let recorded = topics.filter { record($0, clause, level, into: &result) }
                if recorded.isEmpty, !topics.isEmpty {
                    pending.append((clause, topics))
                } else if let level {
                    // A bare mention takes the level of the clause that completes it.
                    for (earlier, topics) in pending where earlier.words.count <= 2 {
                        for topic in topics { _ = record(topic, earlier, level, into: &result) }
                    }
                    pending.removeAll { $0.clause.words.count <= 2 }
                }
            }
            for (clause, topics) in pending where clause.words.count > 2 {
                for topic in topics {
                    _ = record(topic, clause, nearestLevel(clause, topic, similarity), into: &result)
                }
            }
        }
        return result
    }

    // MARK: Vocabulary

    private static let stoolStems = ["stool", "poop", "litter", "bowel"]
    private static let urineStems = ["urin", "pee"]
    private static let abnormalStoolStems = ["diarrh", "constipat", "loose", "runny", "blood", "mucus", "strain", "abnormal"]
    private static let dryStems = ["dry", "kibble", "biscuit"]
    private static let wetStems = ["wet", "canned", "pouch", "tin"]

    private static let unchanged = ["no change", "no changes", "no problem", "no problems", "no issue", "no issues", "nothing unusual"]
    private static let slightly = ["a little", "a bit", "slightly", "somewhat", "a tad"]
    private static let lowerWords: Set = ["less", "lower", "fewer", "reduced", "decreased", "low", "down", "lethargic",
                                          "tired", "sleepy", "sluggish", "lazy", "weak", "withdrawn"]
    private static let higherWords: Set = ["more", "extra", "higher", "increased", "lots", "hyper", "restless", "excessive", "excessively"]
    private static let normalWords: Set = ["normal", "normally", "usual", "fine", "same", "regular", "okay", "ok", "typical", "well", "good", "healthy"]
    private static let negations: Set = ["not", "no", "never", "didnt", "wasnt", "isnt", "doesnt", "hasnt", "hadnt", "wont",
                                         "couldnt", "wouldnt", "barely", "hardly", "refused", "skipped", "stopped"]

    // MARK: Steps

    /// A lowercased clause with apostrophes removed, so "didn't" and "didn’t" both read "didnt".
    struct Clause {
        let text: String
        let words: [String]

        init(_ raw: String) {
            text = raw.lowercased().replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "'", with: "")
            words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        }

        func hasWord(in list: Set<String>) -> Bool { words.contains(where: list.contains) }
        func hasStem(_ stems: [String]) -> Bool { words.contains { word in stems.contains(where: word.hasPrefix) } }
        func hasPhrase(_ phrases: [String]) -> Bool {
            let padded = " " + words.joined(separator: " ") + " "
            return phrases.contains { padded.contains(" \($0) ") }
        }

        var isNegated: Bool { hasWord(in: VoiceParser.negations) }

        /// The first number followed by one of `units`, as in "40 grams".
        func amount(_ units: String) -> Double? {
            guard let regex = try? Regex("(\\d+(?:\\.\\d+)?)\\s*(?:\(units))\\b"),
                  let match = text.firstMatch(of: regex), let number = match.output[1].substring else { return nil }
            return Double(number)
        }
    }

    private static func topics(in clause: Clause, _ similarity: Similarity) -> [Topic] {
        let named = Topic.allCases.filter { clause.hasStem($0.stems) }
        guard named.isEmpty, clause.words.count > 2 else { return named }
        let scored = Topic.allCases.compactMap { topic -> (topic: Topic, score: Double)? in
            topic.examples.compactMap { similarity(clause.text, $0) }.max().map { (topic, $0) }
        }
        guard let best = scored.max(by: { $0.score < $1.score }), best.score >= minSimilarity else { return [] }
        return [best.topic]
    }

    /// Direction and size from explicit wording, or nil when the clause gives no cue.
    static func level(in clause: Clause) -> VoiceLevel? {
        if clause.hasPhrase(unchanged) { return .normal }
        let slight = clause.hasPhrase(slightly)
        let lower = clause.hasWord(in: lowerWords)
        let higher = clause.hasWord(in: higherWords) || clause.hasPhrase(["a lot"])
        // "didn't eat", "barely drank": a negation with no other direction means less.
        if lower || (clause.isNegated && !higher) { return slight ? .slightlyLower : .lower }
        if higher { return clause.isNegated ? .normal : slight ? .slightlyHigher : .higher }
        return clause.hasWord(in: normalWords) ? .normal : nil
    }

    private static func nearestLevel(_ clause: Clause, _ topic: Topic, _ similarity: Similarity) -> VoiceLevel? {
        topic.levelExamples
            .compactMap { level, phrase in similarity(clause.text, phrase).map { (level: level, score: $0) } }
            .max { $0.score < $1.score }?.level
    }

    /// Writes what `clause` says about `topic`. Returns false when it says nothing usable.
    private static func record(_ topic: Topic, _ clause: Clause, _ level: VoiceLevel?, into result: inout VoiceCheckIn) -> Bool {
        switch topic {
        case .stool:
            let abnormal = !clause.hasPhrase(unchanged)
                && (clause.hasStem(abnormalStoolStems) || (clause.isNegated && clause.hasWord(in: normalWords)))
            let count: Double? = clause.amount("times|stools?|poops?") ?? (clause.hasWord(in: ["once"]) ? 1 : clause.hasWord(in: ["twice"]) ? 2 : nil)
            guard abnormal || level != nil || count != nil else { return false }
            let aboutUrine = clause.hasStem(urineStems)
            let aboutStool = clause.hasStem(stoolStems) || !aboutUrine
            if abnormal || level == .normal {
                if aboutStool { result.stoolNormal = !abnormal }
                if aboutUrine { result.urinationNormal = !abnormal }
            }
            if let count {
                result.readings[.stool] = .amount(count)
            } else if let level, !abnormal, aboutStool {
                result.readings[.stool] = .level(level)
            }
            return true
        case .food:
            guard let reading = clause.amount("g|gm|grams?").map(VoiceReading.amount) ?? level.map(VoiceReading.level) else { return false }
            let dry = clause.hasStem(dryStems), wet = clause.hasStem(wetStems)
            // "Ate less" with no kind named applies to both bowls.
            if dry || !wet { result.readings[.dryFood] = reading }
            if wet || !dry { result.readings[.wetFood] = reading }
            return true
        case .water:
            guard let reading = clause.amount("ml|mls|millilit(?:er|re)s?").map(VoiceReading.amount) ?? level.map(VoiceReading.level) else { return false }
            result.readings[.water] = reading
            return true
        case .activity:
            guard let level else { return false }
            result.readings[.activity] = .level(level)
            return true
        }
    }
}
