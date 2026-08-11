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
            // Prediction error is a magnitude. The old signed average could
            // cancel out contradictory signals and falsely report certainty.
            delta.predictionError = input.signals.values
                .map { abs($0) }
                .reduce(0, +) / Double(max(1, input.signals.count))
        case .attention:
            delta.broadcast = input.candidateBroadcasts.sorted().prefix(5).map { $0 }
        case .workspace:
            delta.continuityDelta = state.globalBroadcast.isEmpty ? 0 : 0.02
        case .recurrence:
            delta.continuityDelta = 0.03
        case .selfModel:
            let bodilyCoupling = 1 - abs(input.thermalLoad - state.selfModel.bodyBudget)
            let prediction = state.predictionError
            let actionSuccess = input.signals["action_success"] ?? 0
            let dominantSignal = input.signals
                .filter { $0.key != "action_success" }
                .max(by: { abs($0.value) < abs($1.value) })?.key
            delta.selfModel = SelfModelSnapshot(currentPerspective: input.signals.isEmpty ? state.selfModel.currentPerspective : "sensoriskt nu",
                                                agency: min(1, max(0, state.selfModel.agency + (actionSuccess - 0.5) * 0.04)),
                                                uncertainty: min(1, max(0, prediction * 0.7 + (1 - bodilyCoupling) * 0.3)),
                                                bodyBudget: 1 - input.thermalLoad,
                                                autobiographicalContinuity: min(1, state.selfModel.autobiographicalContinuity + 0.01),
                                                interoceptiveCoupling: min(1, max(0, bodilyCoupling)),
                                                counterfactualDepth: min(1, state.selfModel.counterfactualDepth + (prediction > 0.2 ? 0.01 : 0)))
            if let dominantSignal {
                delta.selfModel?.currentPerspective = dominantSignal
            }
        case .memory:
            let recallSignal = input.signals["memoryRecall"] ?? 0
            if recallSignal > 0 {
                let recalledID = "trace-cycle-\(state.cycleIndex)"
                delta.memoryContext = MemorySnapshot(
                    recalledIDs: Array((state.memoryContext.recalledIDs + [recalledID]).suffix(12)),
                    consolidationSignal: min(1, state.memoryContext.consolidationSignal * 0.95 + recallSignal * 0.05)
                )
            } else {
                delta.memoryContext = state.memoryContext
            }
        case .action:
            let error = state.predictionError
            delta.affectiveState = AffectiveSnapshot(valence: state.affectiveState.valence,
                                                     arousal: min(1, error * 0.8 + input.thermalLoad * 0.2),
                                                     curiosity: min(1, max(0, state.affectiveState.curiosity * 0.96 + error * 0.12)))
            // Metacognition is updated from calibration and error monitoring,
            // so later verification levels depend on performance rather than
            // on generated self-descriptions.
            delta.metacognitiveState = MetacognitiveSnapshot(
                confidence: min(1, max(0, 1 - error)),
                introspectiveAccess: state.globalBroadcast.isEmpty ? 0.2 : 0.7,
                errorMonitoring: min(1, error)
            )
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
