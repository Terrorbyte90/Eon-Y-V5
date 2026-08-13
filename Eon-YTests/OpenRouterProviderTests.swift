import XCTest
@testable import Eon_Y

final class OpenRouterProviderTests: XCTestCase {
    func testRequestTextIsBoundedToOneThousandCharacters() {
        let input = String(repeating: "å", count: 1_250)
        XCTAssertEqual(OpenRouterLimits.bounded(input).count, 1_000)
    }

    func testConfigurationUsesEnvironmentAndSafeDefaults() {
        let configuration = OpenRouterConfiguration(environment: [
            "OPENROUTER_API_KEY": "test-key",
            "OPENROUTER_MODEL": "deepseek/deepseek-v4-flash-0731"
        ])

        XCTAssertEqual(configuration.apiKey, "test-key")
        XCTAssertEqual(configuration.model, "deepseek/deepseek-v4-flash-0731")
        XCTAssertEqual(configuration.endpoint.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
    }

    func testTextNormalizerRemovesRecursiveNarrativeAndKeepsConcreteContent() {
        let raw = "Jag riktar uppmärksamheten mot ica. Jag riktar uppmärksamheten mot ica. Eon jämför ica med sin modell."

        let normalized = EonTextNormalizer.normalize(raw, maxLength: 1_000)

        XCTAssertFalse(normalized.lowercased().contains("jag riktar uppmärksamheten mot ica. jag riktar"))
        XCTAssertTrue(normalized.contains("Eon jämför ica med sin modell."))
    }
}
