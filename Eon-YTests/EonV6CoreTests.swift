import XCTest
@testable import Eon_Y

final class EonV6CoreTests: XCTestCase {
    func testPredictionAndTraceHistoriesAreBounded() {
        var state = EonCoreStateV2()
        for index in 0..<140 {
            state.appendPrediction(EonPredictionRecord(id: UUID(), cycle: index, createdAt: Date(), prediction: "p", predictedValue: 0.5, precision: 0.5, policy: "observe", actualValue: nil, error: nil, resolvedAt: nil))
        }
        XCTAssertEqual(state.predictions.count, 128)
    }

    func testBodyPressureChangesPolicyChoice() {
        let core = PolicySelectionCore()
        let candidates = [EonPolicyCandidate(id: "deep", name: "Djup analys", score: 0.8, epistemicValue: 0.7, resourceCost: 0.9), EonPolicyCandidate(id: "observe", name: "Observera", score: 0.5, epistemicValue: 0.4, resourceCost: 0.1)]
        let low = core.choose(candidates: candidates, body: InteroceptiveBodyCore().state(thermal: 0, cpu: 0, memory: 0), affect: EonAffectiveState())
        let high = core.choose(candidates: candidates, body: InteroceptiveBodyCore().state(thermal: 0.9, cpu: 0.9, memory: 0.8), affect: EonAffectiveState())
        XCTAssertEqual(low?.id, "deep")
        XCTAssertEqual(high?.id, "observe")
    }

    func testLanguageReporterDoesNotMutateState() async {
        var state = EonCoreStateV2()
        state.cycle = 8
        let proposal = await EonLanguageReporter.shared.proposal(for: state)
        XCTAssertEqual(proposal.stateCycle, 8)
        XCTAssertEqual(proposal.epistemicKind, .linguistic)
    }
}
