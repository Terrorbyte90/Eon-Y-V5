import Foundation

struct KnowledgeRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let language: String
    let domain: String
    let title: String
    let text: String
    let source: String?

    enum CodingKeys: String, CodingKey { case id, language, domain, title, text, content, source }

    init(id: String, language: String, domain: String, title: String, text: String, source: String?) {
        self.id = id
        self.language = language
        self.domain = domain
        self.title = title
        self.text = text
        self.source = source
    }

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

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(language, forKey: .language)
        try values.encode(domain, forKey: .domain)
        try values.encode(title, forKey: .title)
        try values.encode(text, forKey: .text)
        try values.encodeIfPresent(source, forKey: .source)
    }
}

struct KnowledgeManifest: Codable, Sendable {
    let version: Int
    let recordCount: Int
    let sha256: String?
}
