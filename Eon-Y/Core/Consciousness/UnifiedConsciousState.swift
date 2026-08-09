import Foundation

struct ConsciousnessProxyMetrics: Codable, Equatable, Sendable {
    var integrationProxy: Double = 0
    var globalAvailability: Double = 0
    var recurrentDepth: Double = 0
    var selfModelCoupling: Double = 0
    var temporalContinuity: Double = 0
    var metacognitiveCalibration: Double = 0

    var mean: Double {
        let values = [integrationProxy, globalAvailability, recurrentDepth,
                      selfModelCoupling, temporalContinuity, metacognitiveCalibration]
        return values.reduce(0, +) / Double(values.count)
    }
}

struct UnifiedConsciousState: Codable, Equatable, Sendable {
    var cycleIndex: Int = 0
    var timestamp: Date = .distantPast
    var continuity: Double = 0
    var perceptualField: [String: Double] = [:]
    var predictionError: Double = 0
    var globalBroadcast: [String] = []
    var selfModel: SelfModelSnapshot = .init()
    var affectiveState: AffectiveSnapshot = .init()
    var memoryContext: MemorySnapshot = .init()
    var metacognitiveState: MetacognitiveSnapshot = .init()
    var metrics: ConsciousnessProxyMetrics = .init()

    mutating func apply(_ delta: ConsciousnessDelta) {
        cycleIndex = max(cycleIndex, delta.cycleIndex)
        if let timestamp = delta.timestamp { self.timestamp = timestamp }
        continuity = clamp(continuity + delta.continuityDelta)
        predictionError = clamp(delta.predictionError ?? predictionError)
        for (key, value) in delta.perceptualUpdates { perceptualField[key] = clamp(value) }
        if !delta.broadcast.isEmpty { globalBroadcast = Array(delta.broadcast.prefix(5)) }
        if let selfModel = delta.selfModel { self.selfModel = selfModel }
        if let affect = delta.affectiveState { self.affectiveState = affect }
        if let memory = delta.memoryContext { self.memoryContext = memory }
        if let metacognition = delta.metacognitiveState { self.metacognitiveState = metacognition }
        if let metrics = delta.metrics { self.metrics = metrics }
    }
}

struct SelfModelSnapshot: Codable, Equatable, Sendable {
    var identity: String = "Eon"
    var agency: Double = 0
    var uncertainty: Double = 1
    var bodyBudget: Double = 1
}

struct AffectiveSnapshot: Codable, Equatable, Sendable {
    var valence: Double = 0
    var arousal: Double = 0
    var curiosity: Double = 0
}

struct MemorySnapshot: Codable, Equatable, Sendable {
    var recalledIDs: [String] = []
    var consolidationSignal: Double = 0
}

struct MetacognitiveSnapshot: Codable, Equatable, Sendable {
    var confidence: Double = 0
    var introspectiveAccess: Double = 0
    var errorMonitoring: Double = 0
}

private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
