import Foundation

enum QwenTaskKind: String, Codable, CaseIterable, Sendable {
    case languageExpansion
    case measurementReview
    case optimizationProposal
}

struct QwenTask: Codable, Identifiable, Sendable {
    let id: UUID
    let kind: QwenTaskKind
    let createdAt: Date
    let reason: String
    let inputDigest: String
}

struct QwenProposal: Codable, Identifiable, Sendable {
    let id: UUID
    let taskID: UUID
    let createdAt: Date
    let summary: String
    let evidence: [String]
    let requiresHumanApproval: Bool
    let canMutateProduction: Bool
    let canContactHermes: Bool
}

/// Qwen may analyse and propose. It never receives a tool handle, write handle,
/// network command, or direct reference to Eon's production state.
actor QwenAutonomyQueue {
    static let shared = QwenAutonomyQueue()

    private var pending: [QwenTask] = []
    private var proposals: [QwenProposal] = []

    func enqueue(_ task: QwenTask) {
        guard pending.count < 32 else { return }
        pending.append(task)
    }

    func next() -> QwenTask? {
        guard !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }

    func recordProposal(_ proposal: QwenProposal) {
        proposals.append(proposal)
        if proposals.count > 100 { proposals.removeFirst(proposals.count - 100) }
    }

    func recentProposals() -> [QwenProposal] { proposals }
}

extension QwenTask {
    static func make(kind: QwenTaskKind, reason: String, inputDigest: String = "") -> QwenTask {
        QwenTask(id: UUID(), kind: kind, createdAt: Date(), reason: reason, inputDigest: inputDigest)
    }
}
