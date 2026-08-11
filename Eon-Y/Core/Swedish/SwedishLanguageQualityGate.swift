import Foundation

enum SwedishLanguageQualityGate {
    static func needsRepair(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 24 else { return true }
        if clean.contains("(context.") || clean.contains("TODO") { return true }
        let sentences = clean.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(sentences).count * 2 < sentences.count || clean.contains("Eon: Eon:")
    }

    static func repair(_ text: String, question: String) async -> String {
        guard needsRepair(text) else { return text }
        let prompt = """
        Förbättra följande svenska svar utan att ändra betydelsen.
        Skriv naturlig, tydlig och grammatiskt korrekt svenska.
        Behåll osäkerhet och fakta; hitta inte på nya uppgifter.
        Svara endast med den förbättrade texten.
        Fråga: (question)
        Text: (text)
        """
        let repaired = await NeuralEngineOrchestrator.shared.generate(prompt: prompt, maxTokens: 220, temperature: 0.38)
        let result = repaired.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? text : result
    }
}
