import Foundation

enum CognitiveEventKind: String, Codable, Sendable {
    case lifecycle, motor, workspace, memory, language, qwen, measurement, thermal, error, user
}

enum CognitiveEventSeverity: String, Codable, Sendable {
    case debug, info, notice, warning, error
}

struct EonObservableEvent: Codable, Sendable, Identifiable {
    let eventID: UUID
    let sessionID: String
    let cycleID: Int
    let sequence: Int
    let timestamp: Date
    let source: String
    let kind: CognitiveEventKind
    let severity: CognitiveEventSeverity
    let payload: [String: String]

    var id: UUID { eventID }

    init(
        eventID: UUID = UUID(),
        sessionID: String,
        cycleID: Int,
        sequence: Int,
        timestamp: Date = Date(),
        source: String,
        kind: CognitiveEventKind,
        severity: CognitiveEventSeverity,
        payload: [String: String] = [:]
    ) {
        self.eventID = eventID
        self.sessionID = sessionID
        self.cycleID = cycleID
        self.sequence = sequence
        self.timestamp = timestamp
        self.source = source
        self.kind = kind
        self.severity = severity
        self.payload = payload
    }
}
