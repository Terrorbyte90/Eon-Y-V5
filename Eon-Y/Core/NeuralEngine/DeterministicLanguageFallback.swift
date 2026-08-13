import Foundation

/// Small offline fallback used when OpenRouter is unavailable.
struct NLResponseEngine {
    static func generate(for prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("varför") || lower.contains("hur") {
            return "Jag saknar tillräckligt underlag för ett säkert svar. Jag kan jämföra frågan med registrerad information när mer kontext finns."
        }
        return "Eon har registrerat signalen och håller tolkningen öppen tills mer underlag finns."
    }

    static func generateAsync(for prompt: String) async -> String {
        generate(for: prompt)
    }
}
