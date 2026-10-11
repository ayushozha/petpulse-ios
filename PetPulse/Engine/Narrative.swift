import Foundation

/// Plain-language wording for a change report. Rule-based: it describes and triages, it never diagnoses.
enum Narrative {
    static func joined(_ parts: [String]) -> String {
        switch parts.count {
        case 0: ""
        case 1: parts[0]
        default: parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }

    private static func verb(_ change: MetricChange) -> String { change.isDecrease ? "decreased" : "increased" }

    static func headline(_ report: ChangeReport, name: String, possessive: String) -> String {
        guard let top = report.significant.first else {
            return "\(name)'s recent check-ins match \(possessive) usual pattern."
        }
        return "\(name)'s \(top.metric.phrase) has \(verb(top)) compared to \(possessive) usual pattern."
    }

    static func meaning(_ report: ChangeReport) -> String {
        let flagged = Set(report.significant.map(\.metric))
        let down = Set(report.significant.filter(\.isDecrease).map(\.metric))
        if flagged.isEmpty {
            return "No meaningful deviation from the usual pattern. Keep logging daily so the baseline stays accurate."
        }
        if !down.isDisjoint(with: [.dryFood, .wetFood, .activity]) {
            return "A decrease in appetite or activity can sometimes indicate early signs of illness, such as dental discomfort, digestive issues, or other underlying conditions."
        }
        if flagged.contains(.water) {
            return "A sustained change in drinking can sometimes be linked to diet changes, temperature, or kidney and urinary conditions."
        }
        if flagged.contains(.stool) {
            return "A change in stool frequency can sometimes follow diet changes or stress, or point to digestive upset."
        }
        return "A sustained change from the usual pattern can be worth watching, even when your pet otherwise seems fine."
    }

    static func recommendation(_ report: ChangeReport) -> String {
        guard let top = report.significant.first else { return "Keep up the daily check-ins." }
        if report.runDays >= 5 || abs(top.fraction) >= 0.6 {
            return "This change is large or has lasted several days. Consider contacting your veterinarian and sharing the vet summary."
        }
        return "Continue monitoring for 1–2 days.\nIf the change persists or worsens, consider a veterinary visit."
    }

    static func ownerConcern(_ report: ChangeReport) -> String {
        let phrases = report.significant.map { change -> String in
            switch (change.metric, change.isDecrease) {
            case (.dryFood, true): "eating less dry food"
            case (.wetFood, true): "eating less wet food"
            case (.activity, true): "less active than usual"
            case (.activity, false): "more restless than usual"
            case (.water, true): "drinking less"
            case (.water, false): "drinking more"
            default: "\(change.isDecrease ? "lower" : "higher") \(change.metric.phrase)"
            }
        }
        guard !phrases.isEmpty else { return "No specific concern. Routine summary of recent check-ins." }
        let text = joined(phrases)
        return text.prefix(1).uppercased() + text.dropFirst() + " for the past \(dayCount(report.runDays))."
    }

    static func timelineSummary(_ report: ChangeReport) -> String {
        guard report.hasChange else { return "No meaningful change from the usual pattern." }
        let down = report.significant.filter(\.isDecrease).map(\.metric.phrase)
        let up = report.significant.filter { !$0.isDecrease }.map(\.metric.phrase)
        var parts: [String] = []
        if !down.isEmpty { parts.append("decreased \(joined(down))") }
        if !up.isEmpty { parts.append("increased \(joined(up))") }
        return "\(dayCount(report.runDays)) of \(joined(parts))."
    }

    static func dayCount(_ days: Int) -> String { days == 1 ? "1 day" : "\(days) days" }
}
