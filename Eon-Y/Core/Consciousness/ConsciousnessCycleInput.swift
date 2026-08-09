import Foundation

struct ConsciousnessCycleInput: Sendable {
    var timestamp: Date
    var signals: [String: Double]
    var thermalLoad: Double
    var candidateBroadcasts: [String]

    init(timestamp: Date = Date(), signals: [String: Double] = [:], thermalLoad: Double = 0, candidateBroadcasts: [String] = []) {
        self.timestamp = timestamp
        self.signals = signals
        self.thermalLoad = min(1, max(0, thermalLoad))
        self.candidateBroadcasts = candidateBroadcasts
    }
}
