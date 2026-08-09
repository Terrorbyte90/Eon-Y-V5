import Foundation
import Testing
@testable import Eon_Y

struct ConsciousnessArchitectureTests {
    @Test func stateAppliesDeltasWithoutExceedingWorkspaceCapacity() {
        var state = UnifiedConsciousState()
        var delta = ConsciousnessDelta(cycleIndex: 1)
        delta.broadcast = ["a", "b", "c", "d", "e", "f"]
        delta.continuityDelta = 2
        state.apply(delta)
        #expect(state.globalBroadcast.count == 5)
        #expect(state.continuity == 1)
    }

    @Test func orchestratorRunsStagesInTheoryOrder() {
        let orchestrator = ConsciousnessOrchestrator()
        let result = orchestrator.advance(
            state: UnifiedConsciousState(),
            input: ConsciousnessCycleInput(signals: ["sound": 0.4], candidateBroadcasts: ["sound"])
        )
        #expect(result.stages == ConsciousnessOrchestrator.Stage.allCases)
        #expect(result.state.cycleIndex == 1)
        #expect(result.state.metrics.globalAvailability == 1)
    }

    @Test func orchestratorIsDeterministicForSameInput() {
        let orchestrator = ConsciousnessOrchestrator()
        let date = Date(timeIntervalSince1970: 100)
        let input = ConsciousnessCycleInput(timestamp: date, signals: ["x": 0.25], candidateBroadcasts: ["x"])
        let first = orchestrator.advance(state: UnifiedConsciousState(), input: input).state
        let second = orchestrator.advance(state: UnifiedConsciousState(), input: input).state
        #expect(first == second)
    }
}
