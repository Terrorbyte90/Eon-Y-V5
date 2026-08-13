import Foundation

enum SelfNarrativeKind: String, Codable, Sendable { case observation, memory, prediction, hypothesis, plan, uncertainty, reflection }
enum SelfNarrativeSource: String, Codable, Sendable { case openRouter, fallback }

struct SelfNarrativeContext: Codable, Sendable {
    let focus: String
    let observation: String
    let prediction: String?
    let actual: String?
    let uncertainty: Double
    let activeGoal: String
    let recentMemory: String?
}

struct SelfNarrativeEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let text: String
    let kind: SelfNarrativeKind
    let source: SelfNarrativeSource
    let confidence: Double
    let context: SelfNarrativeContext
}

struct SelfNarrativeMemory: Sendable {
    private(set) var entries: [SelfNarrativeEntry] = []
    mutating func append(_ entry: SelfNarrativeEntry) {
        entries.append(entry)
        if entries.count > 24 { entries.removeFirst(entries.count - 24) }
    }
}

enum SelfNarrativeEngine {
    static func generate(context: SelfNarrativeContext, recent: [String]) async -> SelfNarrativeEntry {
        let prompt = """
        Formulera en konkret svensk status för Eon i högst två korta meningar.
        Säg vad som faktiskt observeras eller bearbetas. Använd inte upprepade fraser,
        vaga påståenden om upplevelse eller nya mätvärden. Svara med endast text.
        UNDERLAG: \(String(data: (try? JSONEncoder().encode(context)) ?? Data(), encoding: .utf8) ?? "{}")
        """
        let generated = await NeuralEngineOrchestrator.shared.generate(prompt: prompt, maxTokens: 120, temperature: 0.68, enableThinking: false)
        let cleaned = EonTextNormalizer.normalize(generated, maxLength: OpenRouterLimits.maxCharacters)
        guard !cleaned.isEmpty, cleaned.count < 1200,
              !cleaned.contains("Formulera en konkret svensk status"),
              !hasNestedSelfReference(cleaned) else { return fallback(context: context, recent: recent) }
        let source: SelfNarrativeSource = await OpenRouterProvider.shared.isConfigured ? .openRouter : .fallback
        return SelfNarrativeEntry(id: UUID(), timestamp: Date(), text: cleaned, kind: .reflection, source: source, confidence: max(0, min(1, 1 - context.uncertainty)), context: context)
    }

    static func fallback(context: SelfNarrativeContext, recent: [String]) -> SelfNarrativeEntry {
        let recentUnique = Array(NSOrderedSet(array: recent).compactMap { $0 as? String }.suffix(8))
        let variant = recentUnique.contains(where: { $0 == baseText(context) })
            ? "Samma signal återkommer: \(context.observation). Jag jämför den med den befintliga modellen och behåller osäkerheten."
            : baseText(context)
        return SelfNarrativeEntry(id: UUID(), timestamp: Date(), text: EonTextNormalizer.normalize(variant, maxLength: OpenRouterLimits.maxCharacters), kind: .reflection, source: .fallback, confidence: max(0, min(1, 1 - context.uncertainty)), context: context)
    }

    private static func baseText(_ context: SelfNarrativeContext) -> String {
        let focus = EonTextSanitizer.clean(context.focus, maxLength: 120)
        let observation = EonTextSanitizer.clean(context.observation, maxLength: 260)
        var text = "Aktuell signal: \(focus.isEmpty ? "ej specificerad" : focus). \(observation)."
        if let prediction = context.prediction, let actual = context.actual {
            text += " Jag förutsåg \(prediction), men observerade \(actual). Det gör min tidigare modell osäker."
        }
        if let memory = context.recentMemory {
            let cleanMemory = memory.replacingOccurrences(of: "Jag riktar uppmärksamheten mot ", with: "")
            text += " Närliggande minne: \(String(cleanMemory.prefix(180)))."
        }
        text += " Mitt aktuella mål är \(context.activeGoal)."
        return text
    }

    private static func hasNestedSelfReference(_ text: String) -> Bool {
        let marker = "jag riktar uppmärksamheten mot"
        return text.lowercased().components(separatedBy: marker).count > 2
    }
}
