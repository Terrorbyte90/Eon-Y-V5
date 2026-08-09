import Foundation

struct ConsciousnessDelta: Sendable {
    var cycleIndex: Int = 0
    var timestamp: Date?
    var continuityDelta: Double = 0
    var perceptualUpdates: [String: Double] = [:]
    var predictionError: Double?
    var broadcast: [String] = []
    var selfModel: SelfModelSnapshot?
    var affectiveState: AffectiveSnapshot?
    var memoryContext: MemorySnapshot?
    var metacognitiveState: MetacognitiveSnapshot?
    var metrics: ConsciousnessProxyMetrics?

    init(cycleIndex: Int = 0, timestamp: Date? = nil) {
        self.cycleIndex = cycleIndex
        self.timestamp = timestamp
    }
}
