import Foundation

enum EpistemicStatus: String, Codable, Sendable {
    case observed
    case inferred
    case hypothesis
    case simulated
}

struct MeasurementDescriptor: Codable, Sendable, Identifiable {
    let id: String
    let label: String
    let definition: String
    let value: Double
    let unit: String
    let confidence: Double
    let provenance: String
    let temporalWindow: TimeInterval
    let epistemicStatus: EpistemicStatus

    init(id: String, label: String, definition: String, value: Double, unit: String,
         confidence: Double, provenance: String, temporalWindow: TimeInterval,
         epistemicStatus: EpistemicStatus) {
        self.id = id
        self.label = label
        self.definition = definition
        self.value = value
        self.unit = unit
        self.confidence = min(max(confidence, 0), 1)
        self.provenance = provenance
        self.temporalWindow = max(0, temporalWindow)
        self.epistemicStatus = epistemicStatus
    }
}
