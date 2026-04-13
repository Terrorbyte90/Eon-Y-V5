import Foundation

actor LanguageProgressTracker {
    static let shared = LanguageProgressTracker()

    func takeDailySnapshot() async {
        let brain = await MainActor.run { EonBrain.shared }
        let db = PersistentMemoryStore.shared
        let vocabSize = await db.getLearnedVocabularySize()
        let morphM = await MainActor.run { brain.morphologyMastery }
        let syntaxM = await MainActor.run { brain.syntaxMastery }
        let semM = await MainActor.run { brain.semanticMastery }
        let pragM = await MainActor.run { brain.pragmaticMastery }
        let overall = await MainActor.run { brain.overallLanguageLevel }
        let dateStr = String(Date().description.prefix(10))
        await db.insertLanguageSnapshot(date: dateStr, vocabSize: vocabSize, morphMastery: morphM, syntaxMastery: syntaxM, semMastery: semM, pragMastery: pragM, overall: overall, unknownRatio: 0.15, avgComplexity: 0.3)
    }

    func calculateGrowthRate() async -> LanguageGrowth {
        return LanguageGrowth(vocabGrowth: 0, morphGrowth: 0, syntaxGrowth: 0, semGrowth: 0, pragGrowth: 0, overallGrowth: 0)
    }
}

struct LanguageGrowth {
    let vocabGrowth: Int
    let morphGrowth: Double
    let syntaxGrowth: Double
    let semGrowth: Double
    let pragGrowth: Double
    let overallGrowth: Double
}
