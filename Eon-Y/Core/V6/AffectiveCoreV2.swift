import Foundation

struct AffectiveCoreV2: Sendable {
    func update(previous: EonAffectiveState, predictionError: Double, body: EonBodyState, outcomeImprovement: Double) -> EonAffectiveState {
        let control = min(1, max(0, 0.5 + outcomeImprovement * 0.5 - predictionError * 0.3))
        return EonAffectiveState(valence: min(1, max(-1, previous.valence * 0.9 + outcomeImprovement * 0.2 - body.recoveryNeed * 0.12)), arousal: min(1, max(0, previous.arousal * 0.8 + predictionError * 0.35 + body.computePressure * 0.15)), curiosity: min(1, max(0, previous.curiosity * 0.9 + predictionError * 0.15)), frustration: min(1, max(0, previous.frustration * 0.85 + max(0, predictionError - outcomeImprovement) * 0.2)), novelty: min(1, predictionError), controlEstimate: control)
    }
}
