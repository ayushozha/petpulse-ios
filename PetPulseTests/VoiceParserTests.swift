import XCTest
@testable import PetPulse

final class VoiceParserTests: XCTestCase {
    /// No embedding, so only explicit wording is understood. Keeps the tests deterministic.
    private func parse(_ text: String) -> VoiceCheckIn {
        VoiceParser.parse(text, similarity: { _, _ in nil })
    }

    func testMockupSentence() {
        let voice = parse("Mochi ate less dry food today, drank normal water, stool looked normal, and she was a little less active.")
        XCTAssertEqual(voice.readings[.dryFood], .level(.lower))
        XCTAssertNil(voice.readings[.wetFood])
        XCTAssertEqual(voice.readings[.water], .level(.normal))
        XCTAssertEqual(voice.readings[.stool], .level(.normal))
        XCTAssertEqual(voice.stoolNormal, true)
        XCTAssertEqual(voice.readings[.activity], .level(.slightlyLower))

        XCTAssertEqual(voice.label([.dryFood, .wetFood], unit: "g"), "Less than usual")
        XCTAssertEqual(voice.label([.water], unit: "ml"), "Normal")
        XCTAssertEqual(voice.stoolLabel, "Normal")
        XCTAssertEqual(voice.label([.activity]), "Slightly lower")
    }

    func testExplicitAmounts() {
        let voice = parse("She ate 40 grams of kibble and drank 100 ml. She pooped twice.")
        XCTAssertEqual(voice.readings[.dryFood], .amount(40))
        XCTAssertNil(voice.readings[.wetFood])
        XCTAssertEqual(voice.readings[.water], .amount(100))
        XCTAssertEqual(voice.readings[.stool], .amount(2))
    }

    func testUnspecifiedFoodAppliesToBothBowls() {
        let voice = parse("She ate more than usual")
        XCTAssertEqual(voice.readings[.dryFood], .level(.higher))
        XCTAssertEqual(voice.readings[.wetFood], .level(.higher))
    }

    func testBareMentionTakesTheFollowingLevel() {
        let voice = parse("Food and water were normal")
        XCTAssertEqual(voice.readings[.dryFood], .level(.normal))
        XCTAssertEqual(voice.readings[.water], .level(.normal))
    }

    func testNegationMeansLess() {
        XCTAssertEqual(parse("She didn’t drink much").readings[.water], .level(.lower))
        XCTAssertEqual(parse("She barely touched her food").readings[.dryFood], .level(.lower))
        XCTAssertEqual(parse("Not as much water as usual").readings[.water], .level(.lower))
    }

    func testAbnormalStool() {
        let loose = parse("She had diarrhea this morning")
        XCTAssertEqual(loose.stoolNormal, false)
        XCTAssertNil(loose.readings[.stool])
        XCTAssertEqual(loose.stoolLabel, "Not normal")

        XCTAssertEqual(parse("Her stool was not normal").stoolNormal, false)
        XCTAssertEqual(parse("No change in her stool").stoolNormal, true)
    }

    func testUnmentionedTopicsStayEmpty() {
        let voice = parse("Hello, this is a test.")
        XCTAssertTrue(voice.readings.isEmpty)
        XCTAssertNil(voice.stoolNormal)
        XCTAssertNil(voice.stoolLabel)
    }

    func testEmbeddingHandlesUnfamiliarPhrasing() {
        // Stand-in embedding that finds the clause close to one activity example and one direction.
        let topic = VoiceParser.Topic.activity.examples[0]
        let direction = VoiceParser.Topic.activity.levelExamples.first { $0.0 == .higher }!.1
        let voice = VoiceParser.parse("She was bouncing off the walls") { _, example in
            example == topic || example == direction ? 0.9 : 0.1
        }
        XCTAssertEqual(voice.readings[.activity], .level(.higher))
        XCTAssertNil(voice.readings[.water])
    }

    func testReadingValueSnapsToStepAndRange() {
        XCTAssertEqual(VoiceReading.level(.lower).value(usual: 60, step: 5, in: 0...150), 40)
        XCTAssertEqual(VoiceReading.level(.slightlyLower).value(usual: 7, step: 1, in: 0...10), 6)
        XCTAssertEqual(VoiceReading.level(.normal).value(usual: 120, step: 10, in: 0...300), 120)
        XCTAssertEqual(VoiceReading.amount(500).value(usual: 60, step: 5, in: 0...150), 150)
    }
}
