import Foundation

/// Theory-neutral perturbations. A self-report alone is not sufficient; the
/// system must change coherently when a causal component is removed.
struct ConsciousnessPerturbationSuite: Sendable {
    enum Perturbation: String, CaseIterable, Codable, Sendable {
        case noBroadcast
        case noRecurrence
        case bodySignalMismatch
        case memoryDiscontinuity
    }

    struct Result: Codable, Equatable, Sendable {
        let perturbation: Perturbation
        let baseline: ConsciousnessProxyMetrics
        let perturbed: ConsciousnessProxyMetrics
        let causalSensitivity: Double
    }

    func run(orchestrator: ConsciousnessOrchestrator, input: ConsciousnessCycleInput) -> [Result] {
        let baselineState = orchestrator.advance(state: UnifiedConsciousState(), input: input).state
        return Perturbation.allCases.map { perturbation in
            var alteredInput = input
            switch perturbation {
            case .noBroadcast: alteredInput.candidateBroadcasts = []
            case .noRecurrence: alteredInput.signals["recurrence"] = 0
            case .bodySignalMismatch: alteredInput.thermalLoad = 1 - input.thermalLoad
            case .memoryDiscontinuity: alteredInput.signals["memoryContinuity"] = 0
            }
            let altered = orchestrator.advance(state: UnifiedConsciousState(), input: alteredInput).state
            return Result(perturbation: perturbation, baseline: baselineState.metrics,
                          perturbed: altered.metrics,
                          causalSensitivity: abs(baselineState.metrics.mean - altered.metrics.mean))
        }
    }
}
