import Foundation

struct CognitiveClaim: Codable, Sendable, Identifiable {
    let id: UUID
    let text: String
    let epistemicStatus: EpistemicStatus
    let source: String
    let eventIDs: [UUID]

    init(text: String, epistemicStatus: EpistemicStatus, source: String, eventIDs: [UUID] = []) {
        self.id = UUID()
        self.text = text
        self.epistemicStatus = epistemicStatus
        self.source = source
        self.eventIDs = eventIDs
    }
}

struct EonCognitiveSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let sessionID: String
    let cycleID: Int
    let timestamp: Date
    let runtimeMode: String
    let measurements: [MeasurementDescriptor]
    let motorStates: [String: String]
    let claims: [CognitiveClaim]
    let qwenState: [String: String]

    static func empty(sessionID: String, cycleID: Int, timestamp: Date = Date()) -> EonCognitiveSnapshot {
        EonCognitiveSnapshot(
            schemaVersion: 1,
            sessionID: sessionID,
            cycleID: cycleID,
            timestamp: timestamp,
            runtimeMode: "initializing",
            measurements: [],
            motorStates: [:],
            claims: [CognitiveClaim(text: "Snapshot skapad; inga fenomenella slutsatser är tillåtna.", epistemicStatus: .observed, source: "CognitiveSnapshot")],
            qwenState: ["loaded": "false"]
        )
    }
}
