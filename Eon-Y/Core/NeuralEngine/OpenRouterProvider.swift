import Foundation

enum OpenRouterLimits {
    static let maxCharacters = 1_000

    static func bounded(_ text: String, maxLength: Int = maxCharacters) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
    }
}

struct OpenRouterConfiguration: Sendable {
    let apiKey: String?
    let model: String
    let endpoint: URL
    let appTitle: String

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let key = environment["OPENROUTER_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = key?.isEmpty == false ? key : nil
        model = environment["OPENROUTER_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "~deepseek/deepseek-v4-flash-latest"
        endpoint = URL(string: environment["OPENROUTER_ENDPOINT"] ?? "https://openrouter.ai/api/v1/chat/completions")!
        appTitle = environment["OPENROUTER_APP_TITLE"]?.nonEmpty ?? "Eon"
    }

    var isConfigured: Bool { apiKey != nil }
}

actor OpenRouterProvider {
    static let shared = OpenRouterProvider()

    private let configuration: OpenRouterConfiguration
    private let session: URLSession

    init(configuration: OpenRouterConfiguration = OpenRouterConfiguration(), session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    var isConfigured: Bool { configuration.isConfigured }
    var model: String { configuration.model }

    func generate(prompt: String, maxTokens: Int = 180, temperature: Float = 0.45) async -> String? {
        guard let apiKey = configuration.apiKey else { return nil }

        let boundedPrompt = OpenRouterLimits.bounded(prompt)
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.appTitle, forHTTPHeaderField: "X-Title")
        request.httpBody = try? JSONEncoder().encode(Request(
            model: configuration.model,
            messages: [Message(role: "user", content: boundedPrompt)],
            maxTokens: min(maxTokens, 220),
            temperature: temperature,
            reasoning: .init(enabled: false)
        ))

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard let content = decoded.choices.first?.message.content else { return nil }
            return EonTextNormalizer.normalize(content, maxLength: OpenRouterLimits.maxCharacters)
        } catch {
            return nil
        }
    }

    private struct Request: Encodable {
        let model: String
        let messages: [Message]
        let maxTokens: Int
        let temperature: Float
        let reasoning: Reasoning

        enum CodingKeys: String, CodingKey {
            case model, messages, maxTokens = "max_tokens", temperature, reasoning
        }

        struct Reasoning: Encodable { let enabled: Bool }
    }

    private struct Message: Codable {
        let role: String
        let content: String
    }

    private struct Response: Decodable {
        let choices: [Choice]
    }

    private struct Choice: Decodable {
        let message: Message
    }
}

enum EonTextNormalizer {
    static func normalize(_ text: String, maxLength: Int = OpenRouterLimits.maxCharacters) -> String {
        var value = text
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove exact repeated sentences before handling recursive prefixes.
        // This preserves the concrete sentence that follows a repeated prefix.
        value = removeDuplicateSentences(value)

        let recursiveMarkers = [
            "Jag riktar uppmärksamheten mot ",
            "Jag fokuserar reflexmässigt på ",
            "Jag fokuserar reflexmässigt och intensivt på "
        ]
        for marker in recursiveMarkers {
            let lower = value.lowercased()
            let markerLower = marker.lowercased()
            var searchStart = lower.startIndex
            var seen = 0
            while let range = lower.range(of: markerLower, range: searchStart..<lower.endIndex) {
                seen += 1
                if seen > 1 {
                    let end = value.index(value.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
                    value.removeSubrange(end..<value.endIndex)
                    break
                }
                searchStart = range.upperBound
            }
        }

        value = removeDuplicateSentences(value)
        return OpenRouterLimits.bounded(value, maxLength: maxLength)
    }

    private static func removeDuplicateSentences(_ text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var seen = Set<String>()
        var result: [String] = []
        for sentence in sentences {
            let clean = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = clean.lowercased()
            guard !clean.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(clean)
        }
        guard !result.isEmpty else { return text }
        return result.joined(separator: ". ") + "."
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
