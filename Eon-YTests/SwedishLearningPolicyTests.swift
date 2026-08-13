import XCTest
@testable import Eon_Y

final class SwedishLearningPolicyTests: XCTestCase {
    func testValidSwedishCandidatePasses() {
        let candidate = SwedishLearningPolicy.candidate(word: "samsyn", definition: "gemensam förståelse", example: "Vi nådde samsyn.", domain: "Semantik", source: "openrouter")
        XCTAssertNotNil(candidate)
    }

    func testMalformedModelOutputIsRejected() {
        XCTAssertNil(SwedishLearningPolicy.candidate(word: "---", definition: "", example: nil, domain: "", source: "qwen"))
    }
}
