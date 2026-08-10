import Foundation

struct SwedishKnowledgeCandidate: Codable, Identifiable, Sendable {
    let id: UUID
    let word: String
    let definition: String
    let example: String?
    let domain: String
    let source: String
    let confidence: Double
    let createdAt: Date
}

enum SwedishLearningPolicy {
    /// A small deterministic gate around model output. Qwen proposes; the
    /// learning engine is the only component allowed to persist a candidate.
    static func validate(word: String, definition: String, example: String?) -> Bool {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (2...40).contains(normalized.count),
              !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              normalized.range(of: "^[\\p{L}][\\p{L}-]*$", options: .regularExpression) != nil else { return false }
        if let example, example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    static func candidate(word: String, definition: String, example: String?, domain: String, source: String) -> SwedishKnowledgeCandidate? {
        guard validate(word: word, definition: definition, example: example) else { return nil }
        return SwedishKnowledgeCandidate(id: UUID(), word: word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                                        definition: definition.trimmingCharacters(in: .whitespacesAndNewlines),
                                        example: example?.trimmingCharacters(in: .whitespacesAndNewlines),
                                        domain: domain, source: source, confidence: 0.75, createdAt: Date())
    }
}
