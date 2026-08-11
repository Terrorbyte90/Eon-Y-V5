import Foundation

enum EonEpistemicKind: String, Codable, Sendable { case observed, inferred, remembered, predicted, counterfactual, linguistic }

struct EonEpistemicField: Codable, Equatable, Sendable {
    var externalWorld: [String: Double] = [:]
    var body: [String: Double] = [:]
    var currentSituation = ""
    var currentSelf = "Eon"
    var uncertainty: Double = 1
}

struct EonPredictionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let cycle: Int
    let createdAt: Date
    let prediction: String
    let predictedValue: Double
    let precision: Double
    let policy: String
    var actualValue: Double?
    var error: Double?
    var resolvedAt: Date?
}

struct EonPrecisionMap: Codable, Equatable, Sendable {
    var sensory = 0.5
    var memory = 0.5
    var selfModel = 0.5
    var social = 0.5
    var prediction = 0.5
    var interoceptive = 0.5
}

struct EonBodyState: Codable, Equatable, Sendable {
    var thermalPressure = 0.0
    var computePressure = 0.0
    var memoryPressure = 0.0
    var energyBudget = 1.0
    var processingAvailability = 1.0
    var wakeState = "awake"
    var sleepPressure = 0.0
    var cognitiveLoad = 0.0
    var recoveryNeed = 0.0
}

struct EonAffectiveState: Codable, Equatable, Sendable {
    var valence = 0.0
    var arousal = 0.2
    var curiosity = 0.3
    var frustration = 0.0
    var novelty = 0.0
    var controlEstimate = 0.5
}

struct EonPolicyCandidate: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let score: Double
    let epistemicValue: Double
    let resourceCost: Double
}

struct EonCausalEdge: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let from: String
    let to: String
    let contribution: Double
    let cycle: Int
}

struct EonCoreStateV2: Codable, Equatable, Sendable {
    var identity = "Eon"
    var cycle = 0
    var monotonicTimestamp = Date()
    var epistemicField = EonEpistemicField()
    var precision = EonPrecisionMap()
    var body = EonBodyState()
    var affect = EonAffectiveState()
    var attention = ""
    var attentionSchema = ""
    var globalBroadcast = ""
    var temporalContinuity = 0.0
    var selfModelConfidence = 0.3
    var agency = 0.0
    var memoryIDs: [String] = []
    var activePolicy = "observe"
    var policyCandidates: [EonPolicyCandidate] = []
    var predictions: [EonPredictionRecord] = []
    var causalTrace: [EonCausalEdge] = []
    var languageReporterAvailable = false

    mutating func appendPrediction(_ record: EonPredictionRecord) {
        predictions.append(record)
        if predictions.count > 128 { predictions.removeFirst(predictions.count - 128) }
    }

    mutating func appendCausalEdge(_ edge: EonCausalEdge) {
        causalTrace.append(edge)
        if causalTrace.count > 256 { causalTrace.removeFirst(causalTrace.count - 256) }
    }
}
