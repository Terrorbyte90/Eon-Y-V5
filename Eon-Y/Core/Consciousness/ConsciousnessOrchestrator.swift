import Foundation

struct ConsciousnessOrchestrator {
    enum Stage: String, CaseIterable, Sendable {
        case signal, prediction, attention, workspace, recurrence
        case selfModel, memory, action, metrics
    }

    typealias StageHandler = @Sendable (_ state: UnifiedConsciousState, _ input: ConsciousnessCycleInput) -> ConsciousnessDelta

    private let handlers: [Stage: StageHandler]

    init(handlers: [Stage: StageHandler] = [:]) {
        self.handlers = handlers
    }

    func advance(state: UnifiedConsciousState, input: ConsciousnessCycleInput) -> (state: UnifiedConsciousState, stages: [Stage]) {
        var next = state
        next.cycleIndex += 1
        next.timestamp = input.timestamp
        var completed: [Stage] = []

        for stage in Stage.allCases {
            let delta = handlers[stage]?(next, input) ?? defaultDelta(for: stage, state: next, input: input)
            next.apply(delta)
            completed.append(stage)
        }
        return (next, completed)
    }

    private func defaultDelta(for stage: Stage, state: UnifiedConsciousState, input: ConsciousnessCycleInput) -> ConsciousnessDelta {
        var delta = ConsciousnessDelta(cycleIndex: state.cycleIndex, timestamp: input.timestamp)
        switch stage {
        case .signal:
            delta.perceptualUpdates = input.signals
        case .prediction:
            delta.predictionError = input.signals.values.reduce(0, +) / Double(max(1, input.signals.count))
        case .attention:
            delta.broadcast = input.candidateBroadcasts.sorted().prefix(5).map { $0 }
        case .workspace:
            delta.continuityDelta = state.globalBroadcast.isEmpty ? 0 : 0.02
        case .recurrence:
            delta.continuityDelta = 0.03
        case .selfModel:
            let bodilyCoupling = 1 - abs(input.thermalLoad - state.selfModel.bodyBudget)
            delta.selfModel = SelfModelSnapshot(currentPerspective: input.signals.isEmpty ? state.selfModel.currentPerspective : "sensoriskt nu",
                                                agency: state.selfModel.agency + 0.01,
                                                uncertainty: state.selfModel.uncertainty * 0.99,
                                                bodyBudget: 1 - input.thermalLoad,
                                                autobiographicalContinuity: min(1, state.selfModel.autobiographicalContinuity + 0.01),
                                                interoceptiveCoupling: min(1, max(0, bodilyCoupling)),
                                                counterfactualDepth: min(1, state.selfModel.counterfactualDepth + (state.predictionError > 0.2 ? 0.01 : 0)))
        case .memory:
            delta.memoryContext = state.memoryContext
        case .action:
            delta.affectiveState = AffectiveSnapshot(valence: state.affectiveState.valence,
                                                     arousal: state.affectiveState.arousal,
                                                     curiosity: min(1, state.affectiveState.curiosity + state.predictionError * 0.1))
        case .metrics:
            let broadcast = state.globalBroadcast.isEmpty ? 0.0 : 1.0
            delta.metrics = ConsciousnessProxyMetrics(
                integrationProxy: min(1, state.continuity * 0.6 + broadcast * 0.4),
                globalAvailability: broadcast,
                recurrentDepth: min(1, state.continuity),
                selfModelCoupling: state.selfModel.agency * (1 - state.selfModel.uncertainty) * state.selfModel.interoceptiveCoupling,
                temporalContinuity: state.continuity,
                metacognitiveCalibration: state.metacognitiveState.confidence)
        }
        return delta
    }
}
