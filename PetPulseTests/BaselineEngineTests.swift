import XCTest
@testable import PetPulse

final class BaselineEngineTests: XCTestCase {
    private let today = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_791_590_400))

    private func sample(_ daysAgo: Int, dry: Double = 60, wet: Double = 80, water: Double = 120,
                        stool: Double = 2, activity: Double = 7) -> DaySample {
        DaySample(day: Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!,
                  dryFood: dry, wetFood: wet, water: water, stool: stool, activity: activity, weight: 4.2)
    }

    private func history(_ days: Int, startingDaysAgo first: Int = 1) -> [DaySample] {
        (first..<(first + days)).map { sample($0) }
    }

    func testMedian() {
        XCTAssertNil(BaselineEngine.median([]))
        XCTAssertEqual(BaselineEngine.median([3, 1, 2]), 2)
        XCTAssertEqual(BaselineEngine.median([4, 1, 3, 2]), 2.5)
    }

    func testNeedsHistoryBeforeReporting() {
        let report = BaselineEngine.detect(history(BaselineEngine.minBaselineDays))
        XCTAssertFalse(report.hasBaseline)
        XCTAssertFalse(report.hasChange)
    }

    func testStableHistoryHasNoChange() {
        let report = BaselineEngine.detect(history(28) + [sample(0)])
        XCTAssertTrue(report.hasBaseline)
        XCTAssertFalse(report.hasChange)
    }

    func testSmallDipBelowThresholdIsIgnored() {
        let report = BaselineEngine.detect(history(28) + [sample(0, dry: 51)])
        XCTAssertFalse(report.hasChange)
    }

    func testThreeDayDropIsReportedWithSizeAndDuration() throws {
        let low = (0...2).map { sample($0, dry: 36, activity: 4.9) }
        let report = BaselineEngine.detect(history(26, startingDaysAgo: 3) + low)

        XCTAssertEqual(report.significant.map(\.metric), [.dryFood, .activity])
        let dry = try XCTUnwrap(report.change(for: .dryFood))
        XCTAssertEqual(dry.percent, 40)
        XCTAssertTrue(dry.isDecrease)
        XCTAssertEqual(dry.days, 3)
        XCTAssertEqual(report.change(for: .activity)?.percent, 30)
        XCTAssertEqual(report.change(for: .wetFood)?.isSignificant, false)
        XCTAssertEqual(report.runDays, 3)
        XCTAssertEqual(report.startDay, sample(2).day)
    }

    func testExactThresholdChangeIsReported() {
        let report = BaselineEngine.detect(history(28) + [sample(0, dry: 48)])
        XCTAssertEqual(report.change(for: .dryFood)?.isSignificant, true)
        XCTAssertEqual(report.change(for: .dryFood)?.percent, 20)
    }

    func testOneStoolDifferenceIsNormal() {
        let usual = BaselineEngine.baseline(history(28))
        XCTAssertEqual(BaselineEngine.daySummary(sample(0, stool: 1), usual: usual), "Normal")
    }

    func testSingleDayDropCountsOneDay() {
        let report = BaselineEngine.detect(history(28) + [sample(0, dry: 30)])
        XCTAssertEqual(report.change(for: .dryFood)?.days, 1)
        XCTAssertEqual(report.change(for: .dryFood)?.percent, 50)
    }

    func testIncreaseIsReportedAsIncrease() {
        let report = BaselineEngine.detect(history(28) + [sample(0, water: 180)])
        XCTAssertEqual(report.change(for: .water)?.isDecrease, false)
        XCTAssertEqual(report.change(for: .water)?.percent, 50)
    }

    func testDaySummary() {
        let usual = BaselineEngine.baseline(history(28))
        XCTAssertEqual(BaselineEngine.daySummary(sample(0), usual: usual), "Normal")
        XCTAssertEqual(BaselineEngine.daySummary(sample(0, dry: 50), usual: usual), "Slightly lower dry food intake")
        XCTAssertEqual(BaselineEngine.daySummary(sample(0, dry: 30), usual: usual), "Lower dry food intake")
    }

    func testNarrativeMatchesTheDemoStory() {
        let low = (0...2).map { sample($0, dry: 36, activity: 4.9) }
        let report = BaselineEngine.detect(history(26, startingDaysAgo: 3) + low)
        XCTAssertEqual(Narrative.headline(report, name: "Mochi", possessive: "her"),
                       "Mochi's dry food intake has decreased compared to her usual pattern.")
        XCTAssertEqual(Narrative.ownerConcern(report), "Eating less dry food and less active than usual for the past 3 days.")
        XCTAssertEqual(Narrative.timelineSummary(report), "3 days of decreased dry food intake and activity.")
    }
}
