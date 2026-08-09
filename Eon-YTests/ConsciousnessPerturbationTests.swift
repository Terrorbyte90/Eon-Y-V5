import Foundation
import Testing
@testable import Eon_Y

struct ConsciousnessPerturbationTests {
    @Test func removingGlobalBroadcastChangesMeasuredAccess() {
        let suite = ConsciousnessPerturbationSuite()
        let results = suite.run(orchestrator: ConsciousnessOrchestrator(), input: ConsciousnessCycleInput(candidateBroadcasts: ["perception"]))
        let result = results.first { $0.perturbation == .noBroadcast }
        #expect(result != nil)
        #expect((result?.causalSensitivity ?? 0) > 0)
    }
}
