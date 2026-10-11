import Foundation

/// One day of observations, decoupled from persistence so the engine stays pure and testable.
struct DaySample: Equatable {
    var day: Date
    var dryFood: Double
    var wetFood: Double
    var water: Double
    var stool: Double
    var activity: Double
    var weight: Double?
}

enum Metric: String, CaseIterable, Identifiable {
    case dryFood, wetFood, water, stool, activity

    var id: String { rawValue }

    func value(in sample: DaySample) -> Double {
        switch self {
        case .dryFood: sample.dryFood
        case .wetFood: sample.wetFood
        case .water: sample.water
        case .stool: sample.stool
        case .activity: sample.activity
        }
    }

    /// Name used in "What changed?" rows.
    var changeTitle: String {
        switch self {
        case .dryFood: "Dry food intake"
        case .wetFood: "Wet food intake"
        case .water: "Water intake"
        case .stool: "Stool frequency"
        case .activity: "Activity level"
        }
    }

    /// Name used mid-sentence.
    var phrase: String {
        switch self {
        case .dryFood: "dry food intake"
        case .wetFood: "wet food intake"
        case .water: "water intake"
        case .stool: "stool frequency"
        case .activity: "activity"
        }
    }
}

/// A pet's usual pattern over a window of days.
struct Baseline {
    var days: Int
    var usual: [Metric: Double]
    var mean: [Metric: Double]
    var weight: Double?

    static let empty = Baseline(days: 0, usual: [:], mean: [:], weight: nil)
}

struct MetricChange: Identifiable {
    var metric: Metric
    var usual: Double
    var recent: Double
    /// Signed fraction, e.g. -0.4 for a 40% decrease.
    var fraction: Double
    /// Consecutive most-recent days the deviation has lasted.
    var days: Int

    var id: String { metric.rawValue }
    var isSignificant: Bool { abs(fraction) >= BaselineEngine.threshold - BaselineEngine.epsilon && days > 0 }
    var percent: Int { Int((abs(fraction) * 100).rounded()) }
    var isDecrease: Bool { fraction < 0 }
}

struct ChangeReport {
    /// False until there are enough days to know what "normal" is.
    var hasBaseline: Bool
    var changes: [MetricChange]
    var endDay: Date?

    static let learning = ChangeReport(hasBaseline: false, changes: [], endDay: nil)

    var significant: [MetricChange] {
        changes.filter(\.isSignificant).sorted { abs($0.fraction) > abs($1.fraction) }
    }
    var hasChange: Bool { !significant.isEmpty }
    var runDays: Int { significant.map(\.days).max() ?? 0 }
    var startDay: Date? {
        guard let endDay, runDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -(runDays - 1), to: endDay)
    }
    func change(for metric: Metric) -> MetricChange? { changes.first { $0.metric == metric } }
}

enum BaselineEngine {
    /// A metric must move at least this far from the pet's usual value to count.
    static let threshold = 0.20
    /// Tolerance so an exact 20% move (0.8 - 1 in floating point) still counts.
    static let epsilon = 1e-9
    /// Days of history needed before any change is reported.
    static let minBaselineDays = 5
    /// How far back "usual" looks.
    static let windowDays = 28

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    static func baseline(_ samples: [DaySample]) -> Baseline {
        guard !samples.isEmpty else { return .empty }
        var usual: [Metric: Double] = [:]
        var mean: [Metric: Double] = [:]
        for metric in Metric.allCases {
            let values = samples.map(metric.value(in:))
            usual[metric] = median(values)
            mean[metric] = values.reduce(0, +) / Double(values.count)
        }
        return Baseline(days: samples.count, usual: usual, mean: mean, weight: median(samples.compactMap(\.weight)))
    }

    /// Compares the most recent days with the pet's own usual pattern.
    ///
    /// "Usual" is the median of up to `windowDays` days before the latest one, so a short
    /// run of unusual days does not drag the reference with it. A change is the run of
    /// consecutive most-recent days that all deviate by `threshold` or more in the same direction.
    static func detect(_ samples: [DaySample]) -> ChangeReport {
        let sorted = samples.sorted { $0.day < $1.day }
        guard let latest = sorted.last, sorted.count > minBaselineDays else { return .learning }
        let prior = Array(sorted.dropLast().suffix(windowDays))

        let changes = Metric.allCases.compactMap { metric -> MetricChange? in
            guard let usual = median(prior.map(metric.value(in:))), usual > 0 else { return nil }
            let deviation = { (sample: DaySample) in metric.value(in: sample) / usual - 1 }
            let latestDeviation = deviation(latest)
            guard abs(latestDeviation) >= threshold - epsilon else {
                return MetricChange(metric: metric, usual: usual, recent: metric.value(in: latest), fraction: latestDeviation, days: 0)
            }
            let run = sorted.reversed().prefix(while: { sample -> Bool in
                let d = deviation(sample)
                return abs(d) >= threshold - epsilon && (d < 0) == (latestDeviation < 0)
            })
            let recent = run.map(metric.value(in:)).reduce(0, +) / Double(run.count)
            return MetricChange(metric: metric, usual: usual, recent: recent, fraction: recent / usual - 1, days: run.count)
        }
        return ChangeReport(hasBaseline: true, changes: changes, endDay: latest.day)
    }

    /// One-line label for a single day on the timeline.
    static func daySummary(_ sample: DaySample, usual: Baseline) -> String {
        let deviations = Metric.allCases.compactMap { metric -> (Metric, Double)? in
            guard let u = usual.usual[metric], u > 0 else { return nil }
            let value = metric.value(in: sample)
            // One stool more or less is ordinary day-to-day variation, not a deviation.
            if metric == .stool, abs(value - u) <= 1 { return nil }
            return (metric, value / u - 1)
        }
        guard let worst = deviations.max(by: { abs($0.1) < abs($1.1) }), abs(worst.1) >= 0.10 - epsilon else { return "Normal" }
        let direction = worst.1 < 0 ? "lower" : "higher"
        let prefix = abs(worst.1) < 0.25 ? "Slightly " : ""
        let text = "\(prefix)\(direction) \(worst.0.phrase)"
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
