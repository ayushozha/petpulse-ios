import Foundation
import SwiftData

/// Hackathon demo data: four weeks of healthy history, and an optional three-day dip.
enum DemoSeeder {
    /// When true, saving the first pet profile also loads the healthy demo history.
    static let seedOnFirstProfile = true

    // Weekly patterns: food and water offsets are zero-sum and zero-median, and activity stays
    // within 10% of its median of 7, so every seeded day reads as "Normal" on the timeline.
    private static let foodOffsets: [Double] = [-5, 3, 0, 4, -3, 0, 1]
    private static let stoolCounts = [1, 2, 1, 2, 2, 1, 2]
    private static let activityLevels: [Double] = [7, 7.5, 6.5, 7, 7, 7.5, 6.5]
    private static let weightOffsets: [Double] = [-0.05, 0, 0.03, -0.02, 0.04, 0.02, -0.02]

    private static func day(_ offset: Int, from today: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: today)) ?? today
    }

    /// Inserts `days` of normal check-ins ending yesterday, so today's check-in is still to do.
    static func seedHealthyHistory(in context: ModelContext, weight: Double = 4.2, days: Int = 28, today: Date = .now) {
        for offset in 1...days {
            let i = (days - offset) % 7
            let checkIn = DailyCheckIn(
                day: day(offset, from: today),
                dryFoodGrams: 60 + foodOffsets[i],
                wetFoodGrams: 80 + foodOffsets[(i + 3) % 7],
                waterMl: 120 + foodOffsets[(i + 5) % 7] * 2,
                stoolCount: stoolCounts[i],
                activity: activityLevels[i],
                weightKg: ((weight + weightOffsets[i]) * 100).rounded() / 100
            )
            if offset == 2 { checkIn.demoPhotoNames = ["cat_face", "cat_sleep", "cat_stretch"] }
            if offset == 7 { checkIn.demoPhotoNames = ["cat_walk", "cat_table"] }
            context.insert(checkIn)
        }
        context.insert(TimelineEvent(day: day(4, from: today), title: "Vet summary exported",
                                     subtitle: "Shared with your veterinarian"))
    }

    /// Rewrites today and the two days before it as a 40% dry-food and 30% activity drop.
    static func simulateChange(in context: ModelContext, existing: [DailyCheckIn], today: Date = .now) {
        let runStart = day(2, from: today)
        let usual = BaselineEngine.baseline(existing.filter { $0.day < runStart }.map(\.sample))
        let dry = usual.usual[.dryFood] ?? 60
        let wet = usual.usual[.wetFood] ?? 80
        let water = usual.usual[.water] ?? 120
        let activity = usual.usual[.activity] ?? 7

        for offset in 0...2 {
            let date = day(offset, from: today)
            let checkIn = existing.first { $0.day == date } ?? {
                let new = DailyCheckIn(day: date, dryFoodGrams: dry, wetFoodGrams: wet, waterMl: water,
                                       stoolCount: 2, activity: activity, weightKg: usual.weight)
                context.insert(new)
                return new
            }()
            checkIn.dryFoodGrams = dry * 0.6
            checkIn.activity = activity * 0.7
            checkIn.wetFoodGrams = wet
            checkIn.mood = "Calm"
        }
    }

    static func deleteHistory(in context: ModelContext) {
        // Per-object deletes, so unsaved inserts and live @Query results are handled too.
        for checkIn in (try? context.fetch(FetchDescriptor<DailyCheckIn>())) ?? [] { context.delete(checkIn) }
        for event in (try? context.fetch(FetchDescriptor<TimelineEvent>())) ?? [] { context.delete(event) }
    }
}
