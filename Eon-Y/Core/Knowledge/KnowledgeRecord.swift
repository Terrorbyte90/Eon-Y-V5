import Foundation

struct KnowledgeRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let language: String
    let domain: String
    let title: String
    let text: String
    let source: String?

    enum CodingKeys: String, CodingKey { case id, language, domain, title, text, content, source }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        language = try values.decode(String.self, forKey: .language)
        domain = try values.decode(String.self, forKey: .domain)
        title = try values.decode(String.self, forKey: .title)
        if let modernText = try values.decodeIfPresent(String.self, forKey: .text) {
            text = modernText
        } else {
            text = try values.decode(String.self, forKey: .content)
        }
        source = try values.decodeIfPresent(String.self, forKey: .source)
    }
}

struct KnowledgeManifest: Codable, Sendable {
    let version: Int
    let recordCount: Int
    let sha256: String?
}
