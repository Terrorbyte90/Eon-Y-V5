import Foundation

actor MorphologyLearner {
    static let shared = MorphologyLearner()

    func learnMorphology(word: String, context: String) async -> LearnedMorphology? {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return nil }
        let prompt = "Du är en svensk grammatikexpert. Analysera ordet \"\(word)\" i kontexten: \"\(context)\"\nSvara EXAKT i JSON: {\"baseForm\":\"\",\"pos\":\"\",\"forms\":{\"plural\":\"\",\"bestämd\":\"\"}}"
        let response = await NeuralEngineOrchestrator.shared.generate(prompt: prompt, maxTokens: 150, temperature: 0.2)
        return parseResponse(response, originalWord: word)
    }

    func batchLearnUnknownWords() async {
        let words = await PersistentMemoryStore.shared.getRecentlyLearnedWords(limit: 50).filter { $0.confidence < 0.5 }
        for (word, _) in words.prefix(10) {
            guard !ThermalSleepManager.shared.shouldPauseWork() else { break }
            if let learned = await learnMorphology(word: word, context: "") {
                await SwedishLanguageCore.shared.morphologyEngine.addDynamicEntry(word: learned.baseForm, pos: learned.pos)
                for (k, v) in learned.forms { await SwedishLanguageCore.shared.morphologyEngine.addInflection(baseForm: learned.baseForm, formKey: k, formValue: v) }
                await PersistentMemoryStore.shared.reinforceLearnedWord(learned.baseForm)
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    private func parseResponse(_ response: String, originalWord: String) -> LearnedMorphology? {
        guard let s = response.firstIndex(of: "{"), let e = response.lastIndex(of: "}"),
              let data = String(response[s...e]).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return LearnedMorphology(baseForm: json["baseForm"] as? String ?? originalWord,
            pos: json["pos"] as? String ?? "unknown",
            forms: json["forms"] as? [String: String] ?? [:])
    }
}

struct LearnedMorphology { let baseForm: String; let pos: String; let forms: [String: String] }
