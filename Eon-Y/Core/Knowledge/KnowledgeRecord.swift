import Foundation

struct KnowledgeRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let language: String
    let domain: String
    let title: String
    let text: String
    let source: String?
}

struct KnowledgeManifest: Codable, Sendable {
    let version: Int
    let recordCount: Int
    let sha256: String?
}
