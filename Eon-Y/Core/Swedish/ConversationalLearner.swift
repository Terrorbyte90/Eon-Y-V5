import Foundation
import NaturalLanguage

actor ConversationalLearner {
    static let shared = ConversationalLearner()
    private var learnedConstructions: [LearnedConstruction] = []
    private let db = PersistentMemoryStore.shared

    struct LearnedConstruction: Codable {
        let phrase: String, context: String, source: String
        let pos: String, confidence: Double
        let learnedAt: Date
        var reinforcementCount: Int
    }

    func learnFromUserInput(_ text: String) async {
        let analysis = await SwedishLanguageCore.shared.analyze(text)
        for morpheme in analysis.morphemes {
            if morpheme.pos == "unknown" {
                await registerNewWord(word: morpheme.word, baseForm: morpheme.baseForm,
                    context: text, source: "user_input", pos: guessPOS(morpheme.word, in: text))
            }
        }
        await extractCollocations(from: analysis)
        await detectNewPatterns(text: text, analysis: analysis)
    }

    func learnFromOwnOutput(_ text: String, userFeedback: UserFeedback? = nil) async {
        let analysis = await SwedishLanguageCore.shared.analyze(text)
        if let feedback = userFeedback, feedback.isCorrection {
            await db.insertCorrection(wrong: feedback.originalPhrase, correct: feedback.correctedPhrase, context: text)
        }
        let quality = assessOutputQuality(text: text, analysis: analysis)
        let delta = (quality - 0.5) * 0.01
        await LearningEngine.shared.adjustCompetency("Morfologi", delta: delta * 0.3)
        await LearningEngine.shared.adjustCompetency("Syntax", delta: delta * 0.3)
        await LearningEngine.shared.adjustCompetency("Semantik", delta: delta * 0.25)
        await LearningEngine.shared.adjustCompetency("Pragmatik", delta: delta * 0.15)
    }

    func learnFromArticle(_ text: String) async {
        let sentences = text.components(separatedBy: ". ")
        for sentence in sentences.prefix(20) {
            let analysis = await SwedishLanguageCore.shared.analyze(sentence)
            for morpheme in analysis.morphemes where morpheme.pos == "unknown" {
                await registerNewWord(word: morpheme.word, baseForm: morpheme.baseForm,
                    context: sentence, source: "article", pos: guessPOS(morpheme.word, in: sentence))
            }
        }
    }

    private func registerNewWord(word: String, baseForm: String, context: String, source: String, pos: String) async {
        await db.insertLearnedWord(word: baseForm, pos: pos, context: context, source: source, confidence: 0.3)
        await LearningEngine.shared.registerNewVocabulary(word: baseForm, context: context)
        await SwedishLanguageCore.shared.morphologyEngine.addDynamicEntry(word: baseForm, pos: pos)
    }

    private func extractCollocations(from analysis: SwedishAnalysis) async {
        let words = analysis.morphemes.map { $0.baseForm }
        for i in 0..<(words.count - 1) {
            let bigram = "\(words[i]) \(words[i+1])"
            await db.registerCollocation(bigram)
        }
    }

    private func detectNewPatterns(text: String, analysis: SwedishAnalysis) async {
        for clause in analysis.clauses {
            let pattern = clause.text.lowercased().hasPrefix("att ") || clause.text.lowercased().hasPrefix("som ") ? "bisats" : "huvudsats"
            await db.registerGrammarPattern(pattern)
        }
    }

    private func guessPOS(_ word: String, in context: String) -> String {
        let tagger = NLTaggerPool.shared.lexicalTagger(for: context)
        let range = context.range(of: word) ?? context.startIndex..<context.endIndex
        if let (tag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass) {
            switch tag {
            case .noun: return "noun"
            case .verb: return "verb"
            case .adjective: return "adjective"
            case .adverb: return "adverb"
            default: return "unknown"
            }
        }
        return "unknown"
    }

    private func assessOutputQuality(text: String, analysis: SwedishAnalysis) -> Double {
        var score = 0.5
        let unknownRatio = Double(analysis.morphemes.filter { $0.pos == "unknown" }.count) / max(1.0, Double(analysis.morphemes.count))
        score -= unknownRatio * 0.3
        if !analysis.detectedIdioms.isEmpty { score += 0.1 }
        return min(1.0, max(0.0, score))
    }
}

struct UserFeedback {
    let isCorrection: Bool
    let originalPhrase: String
    let correctedPhrase: String
}
