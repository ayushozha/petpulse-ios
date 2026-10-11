import Charts
import SwiftData
import SwiftUI

struct BaselineView: View {
    var pet: Pet

    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]
    @State private var range = Span.month

    enum Span: String, CaseIterable {
        case week = "1W", month = "1M", quarter = "3M", all = "All"

        var days: Int? {
            switch self {
            case .week: 7
            case .month: 28
            case .quarter: 84
            case .all: nil
            }
        }
    }

    private var samples: [DaySample] {
        let all = checkIns.map(\.sample)
        guard let days = range.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: .now))
        else { return all }
        return all.filter { $0.day >= cutoff }
    }

    var body: some View {
        let samples = self.samples
        let baseline = BaselineEngine.baseline(samples)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                rangePicker
                Text("\(pet.name)'s usual patterns (learned from \(Narrative.dayCount(baseline.days)))")
                    .font(.pp(13))
                    .foregroundStyle(PP.subtext)
                    .padding(.top, 4)

                if samples.isEmpty {
                    Text("No check-ins in this period yet.").font(.pp(14)).foregroundStyle(PP.subtext).card()
                } else {
                    metricCard(.dryFood, "Food Intake", approx(baseline.usual[.dryFood], "g/day"), samples)
                    metricCard(.water, "Water Intake", approx(baseline.usual[.water], "ml/day"), samples)
                    metricCard(.stool, "Stool Frequency", stoolLabel(baseline.mean[.stool]), samples)
                    metricCard(.activity, "Activity Level", activityLabel(baseline.usual[.activity]), samples)
                    weightCard(baseline.weight, samples)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill").font(.system(size: 20)).foregroundStyle(PP.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Still learning").font(.pp(15, .semibold)).foregroundStyle(PP.blue)
                        Text("The more check-ins you add, the more accurate \(pet.name)'s baseline will be!")
                            .font(.pp(13))
                            .foregroundStyle(PP.text)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PP.blueSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .screen("\(pet.name)'s Baseline")
    }

    // MARK: Labels

    private func approx(_ value: Double?, _ unit: String) -> String {
        value.map { "~ \(Int($0.rounded())) \(unit)" } ?? "–"
    }

    private func stoolLabel(_ mean: Double?) -> String {
        guard let mean else { return "–" }
        let low = Int(mean.rounded(.down)), high = Int(mean.rounded(.up))
        return low == high ? "~ \(low) times/day" : "~ \(low)–\(high) times/day"
    }

    private func activityLabel(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value >= 6.5 ? "Usually active" : value >= 4 ? "Moderately active" : "Usually calm"
    }

    // MARK: Pieces

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(Span.allCases, id: \.self) { option in
                Button { range = option } label: {
                    Text(option.rawValue)
                        .font(.pp(13, option == range ? .semibold : .regular))
                        .foregroundStyle(option == range ? .white : PP.subtext)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(option == range ? PP.teal : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(hex: 0xE9EFF1), in: Capsule())
    }

    private func metricCard(_ metric: Metric, _ title: String, _ value: String, _ samples: [DaySample]) -> some View {
        let values = Array(samples.suffix(9).map(metric.value(in:)).enumerated())
        return HStack(spacing: 12) {
            IconBadge(kind: .metric(metric), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.pp(14, .semibold)).foregroundStyle(PP.navy)
                Text(value).font(.pp(14)).foregroundStyle(PP.text)
            }
            Spacer()
            Chart(values, id: \.offset) { item in
                BarMark(x: .value("Day", item.offset), y: .value(title, item.element), width: .fixed(5))
                    .foregroundStyle(metric.tint.opacity(0.75))
                    .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: 96, height: 36)
            .accessibilityHidden(true)
        }
        .card(padding: 12)
    }

    private func weightCard(_ usual: Double?, _ samples: [DaySample]) -> some View {
        let points = samples.suffix(14).compactMap { sample in sample.weight.map { (day: sample.day, kg: $0) } }
        let low = (points.map(\.kg).min() ?? 0) - 0.1
        let high = (points.map(\.kg).max() ?? 1) + 0.1
        return HStack(spacing: 12) {
            IconBadge(kind: .weight, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                (Text("Weight ").font(.pp(14, .semibold)).foregroundColor(PP.navy)
                    + Text("(optional)").font(.pp(12)).foregroundColor(PP.subtext))
                Text(usual.map { "~ " + String(format: "%.1f", $0) + " kg" } ?? "–").font(.pp(14)).foregroundStyle(PP.text)
            }
            Spacer()
            Chart(points, id: \.day) { point in
                AreaMark(x: .value("Day", point.day), yStart: .value("Low", low), yEnd: .value("Weight", point.kg))
                    .foregroundStyle(PP.blue.opacity(0.12))
                LineMark(x: .value("Day", point.day), y: .value("Weight", point.kg))
                    .foregroundStyle(PP.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYScale(domain: low...high)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: 96, height: 36)
            .accessibilityHidden(true)
        }
        .card(padding: 12)
    }
}
