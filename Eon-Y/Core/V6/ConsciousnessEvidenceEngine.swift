import Foundation

enum EonEvidenceFamily: String, Codable, CaseIterable, Sendable { case workspace, recurrence, predictive, metacognitive, embodied, integration, agency, temporal }

struct EonEvidenceProfile: Codable, Equatable, Sendable {
    var scores: [EonEvidenceFamily: Double] = [:]
    var heldOutPassed = false
    var languageOffPassed = false
    var restartPassed = false
    var ablationCount = 0
    var updatedAt = Date()

    var mean: Double { scores.values.isEmpty ? 0 : scores.values.reduce(0, +) / Double(scores.count) }
}

struct ConsciousnessEvidenceEngine: Sendable {
    func profile(state: EonCoreStateV2, ablationCount: Int = 0, heldOut: Bool = false, languageOff: Bool = false, restart: Bool = false) -> EonEvidenceProfile {
        let scores: [EonEvidenceFamily: Double] = [
            .workspace: state.globalBroadcast.isEmpty ? 0 : 1,
            .recurrence: state.temporalContinuity,
            .predictive: state.precision.prediction,
            .metacognitive: state.selfModelConfidence,
            .embodied: state.body.processingAvailability,
            .integration: state.temporalContinuity * 0.6 + (state.globalBroadcast.isEmpty ? 0 : 0.4),
            .agency: state.agency,
            .temporal: state.temporalContinuity
        ]
        return EonEvidenceProfile(scores: scores, heldOutPassed: heldOut, languageOffPassed: languageOff, restartPassed: restart, ablationCount: ablationCount)
    }
}
