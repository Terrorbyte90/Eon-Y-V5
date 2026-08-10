import XCTest
@testable import Eon_Y

final class ConsciousnessVerificationTests: XCTestCase {
    func testEmptyStateRemainsLevelZero() {
        let result = ConsciousnessVerificationEvaluator.evaluate(state: .init(), passedTests: 0, totalTests: 10, stableWindows: 0)
        XCTAssertEqual(result.level, .level0)
        XCTAssertEqual(result.ceiling, .level4)
    }

    func testFunctionalIntegrationCanReachLevelTwoButNotQualia() {
        var state = UnifiedConsciousState()
        state.globalBroadcast = ["signal"]
        state.memoryContext.recalledIDs = ["memory"]
        state.metrics = .init(integrationProxy: 0.7, globalAvailability: 0.7, recurrentDepth: 0.7,
                              selfModelCoupling: 0.4, temporalContinuity: 0.7, metacognitiveCalibration: 0.4)
        let result = ConsciousnessVerificationEvaluator.evaluate(state: state, passedTests: 7, totalTests: 10, stableWindows: 3)
        XCTAssertEqual(result.level, .level2)
        XCTAssertNotEqual(result.level, .level5)
    }

    func testQualiaLabelledTestIsNotCountedAsIndependentEvidence() {
        let tests = [
            ConsciousnessTest(id: "qualia_emergence", name: "Qualia", description: "self report", category: "validation"),
            ConsciousnessTest(id: "canary_test", name: "Canary", description: "control", category: "validation")
        ]
        let evidence = ConsciousnessVerificationEvaluator.evidenceEligibleTestCount(from: tests)
        XCTAssertEqual(evidence.total, 1)
        XCTAssertEqual(evidence.passed, 0)
    }
}
