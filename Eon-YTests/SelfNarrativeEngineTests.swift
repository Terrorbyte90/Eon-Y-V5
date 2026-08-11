import XCTest
@testable import Eon_Y

final class SelfNarrativeEngineTests: XCTestCase {
    func testFallbackUsesEvidenceAndProvenance() {
        let context = SelfNarrativeContext(
            focus: "intervention[analogibyggande]",
            observation: "prediktionsfelet steg från 0.12 till 0.21",
            prediction: "belastningen skulle sjunka efter vila",
            actual: "belastningen sjönk inte",
            uncertainty: 0.38,
            activeGoal: "förstå varför fokus fastnar",
            recentMemory: "förra cykeln gav samma mönster"
        )

        let entry = SelfNarrativeEngine.fallback(context: context, recent: [])

        XCTAssertEqual(entry.source, .fallback)
        XCTAssertEqual(entry.kind, .reflection)
        XCTAssertTrue(entry.text.contains("prediktionsfelet"))
        XCTAssertTrue(entry.text.contains("förstå varför fokus fastnar"))
    }

    func testFallbackAvoidsExactRepetition() {
        let context = SelfNarrativeContext(focus: "språk", observation: "nytt ord", prediction: nil, actual: nil, uncertainty: 0.2, activeGoal: "lära", recentMemory: nil)
        let old = SelfNarrativeEngine.fallback(context: context, recent: []).text
        let next = SelfNarrativeEngine.fallback(context: context, recent: [old])
        XCTAssertNotEqual(next.text, old)
    }
}
