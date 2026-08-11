import Foundation

enum SelfNarrativeKind: String, Codable, Sendable { case observation, memory, prediction, hypothesis, plan, uncertainty, reflection }
enum SelfNarrativeSource: String, Codable, Sendable { case qwen, fallback }

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
        let wasLoaded = await NeuralEngineOrchestrator.shared.isLoaded
        let prompt = """
        Du är Eons interna självreflektionsmotor. Skriv en kort svensk reflektion i jag-form.
        Använd endast uppgifterna i JSON-underlaget. Hitta inte på mätvärden, minnen,
        upplevelser eller orsaker. Beskriv osäkerhet när den finns. Svara med endast text.
        UNDERLAG: \(String(data: (try? JSONEncoder().encode(context)) ?? Data(), encoding: .utf8) ?? "{}")
        """
        let generated = await NeuralEngineOrchestrator.shared.generate(prompt: prompt, maxTokens: 120, temperature: 0.68, enableThinking: false)
        let cleaned = generated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count < 1200,
              !cleaned.contains("Skriv en kort svensk reflektion"),
              !hasNestedSelfReference(cleaned) else { return fallback(context: context, recent: recent) }
        return SelfNarrativeEntry(id: UUID(), timestamp: Date(), text: cleaned, kind: .reflection, source: wasLoaded ? .qwen : .fallback, confidence: max(0, min(1, 1 - context.uncertainty)), context: context)
    }

    static func fallback(context: SelfNarrativeContext, recent: [String]) -> SelfNarrativeEntry {
        let recentUnique = Array(NSOrderedSet(array: recent).compactMap { $0 as? String }.suffix(8))
        let variant = recentUnique.contains(where: { $0 == baseText(context) })
            ? "Jag ser samma signal igen, men jag behandlar den inte som en ny upptäckt. \(context.observation). Jag håller därför min tolkning öppen medan jag arbetar mot \(context.activeGoal)."
            : baseText(context)
        return SelfNarrativeEntry(id: UUID(), timestamp: Date(), text: String(variant.prefix(900)), kind: .reflection, source: .fallback, confidence: max(0, min(1, 1 - context.uncertainty)), context: context)
    }

    private static func baseText(_ context: SelfNarrativeContext) -> String {
        var text = "Jag riktar uppmärksamheten mot \(context.focus). \(context.observation)."
        if let prediction = context.prediction, let actual = context.actual {
            text += " Jag förutsåg \(prediction), men observerade \(actual). Det gör min tidigare modell osäker."
        }
        if let memory = context.recentMemory {
            let cleanMemory = memory.replacingOccurrences(of: "Jag riktar uppmärksamheten mot ", with: "")
            text += " Ett närliggande observationstillstånd är: \(String(cleanMemory.prefix(180)))."
        }
        text += " Mitt aktuella mål är \(context.activeGoal)."
        return text
    }

    private static func hasNestedSelfReference(_ text: String) -> Bool {
        let marker = "jag riktar uppmärksamheten mot"
        return text.lowercased().components(separatedBy: marker).count > 2
    }
}
