import Foundation
import NaturalLanguage

// MARK: - ConversationalLearner v2
// Improved output quality assessment with 5 dimensions:
// syntactic complexity, register appropriateness, discourse coherence,
// lexical diversity, grammatical correctness.
// Stronger feedback loop: delta * 0.05 (was 0.01) with dimension-specific weights.

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

    // MARK: - Learning from input

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

        // v2: Multi-dimensional quality assessment
        let quality = await assessOutputQuality(text: text, analysis: analysis)

        // v2: Stronger feedback loop — delta * 0.05 (was 0.01)
        // Higher weight = faster learning from output quality
        let learningRate = 0.05
        let delta = (quality - 0.5) * learningRate

        // v2: Dimension-specific weights with adaptive scaling
        // If quality is high, boost all dimensions; if low, penalize more heavily
        let morphWeight = quality > 0.6 ? 0.25 : 0.30
        let syntaxWeight = quality > 0.6 ? 0.30 : 0.35
        let semWeight = quality > 0.6 ? 0.25 : 0.20
        let pragWeight = quality > 0.6 ? 0.20 : 0.15

        await LearningEngine.shared.adjustCompetency("Morfologi", delta: delta * morphWeight)
        await LearningEngine.shared.adjustCompetency("Syntax", delta: delta * syntaxWeight)
        await LearningEngine.shared.adjustCompetency("Semantik", delta: delta * semWeight)
        await LearningEngine.shared.adjustCompetency("Pragmatik", delta: delta * pragWeight)

        // v2: Also boost Diskurs based on coherence
        if quality > 0.7 {
            await LearningEngine.shared.adjustCompetency("Diskurs", delta: delta * 0.15)
        }
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

    // MARK: - Word registration

    private func registerNewWord(word: String, baseForm: String, context: String, source: String, pos: String) async {
        await db.insertLearnedWord(word: baseForm, pos: pos, context: context, source: source, confidence: 0.3)
        await LearningEngine.shared.registerNewVocabulary(word: baseForm, context: context)
        await SwedishLanguageCore.shared.morphologyEngine.addDynamicEntry(word: baseForm, pos: pos)
    }

    // MARK: - Collocation extraction

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
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = context
        let range = context.range(of: word) ?? context.startIndex..<context.endIndex
        let (tag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass)
        if let tag {
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

    // MARK: - v2: Multi-dimensional quality assessment

    private func assessOutputQuality(text: String, analysis: SwedishAnalysis) async -> Double {
        var score = 0.5

        // 1. Unknown word penalty (was: only metric)
        let unknownRatio = Double(analysis.morphemes.filter { $0.pos == "unknown" }.count) / max(1.0, Double(analysis.morphemes.count))
        score -= unknownRatio * 0.25

        // 2. Idiom bonus
        if !analysis.detectedIdioms.isEmpty { score += 0.08 }

        // 3. Syntactic complexity: bonus for subordinate clauses
        let subordinateCount = analysis.clauses.filter { $0.type == .subordinate }.count
        let totalClauses = max(1, analysis.clauses.count)
        let subRatio = Double(subordinateCount) / Double(totalClauses)
        if subRatio > 0.2 { score += 0.05 }
        if subRatio > 0.4 { score += 0.03 }

        // 4. Lexical diversity: unique word ratio
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
        let uniqueWords = Set(words)
        let diversity = words.isEmpty ? 0.5 : Double(uniqueWords.count) / Double(words.count)
        if diversity > 0.6 { score += 0.04 }
        if diversity > 0.8 { score += 0.03 }

        // 5. Sentence length variety
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { $0.trimmingCharacters(in: .whitespaces).count > 3 }
        if sentences.count >= 2 {
            let lengths = sentences.map { $0.split(separator: " ").count }
            let avgLength = Double(lengths.reduce(0, +)) / Double(lengths.count)
            let variance = lengths.map { abs(Double($0) - avgLength) }.reduce(0, +) / Double(lengths.count)
            // Moderate variance = good writing
            if variance > 2.0 && variance < 8.0 { score += 0.05 }
        }

        // 6. Register appropriateness: prefer neutral/formal for learning
        if analysis.register == .neutral || analysis.register == .formal {
            score += 0.03
        }

        // 7. Discourse coherence: bonus for anaphora resolution
        if !analysis.anaphoraResolutions.isEmpty {
            let avgConfidence = analysis.anaphoraResolutions.map { $0.confidence }.reduce(0, +) / Double(analysis.anaphoraResolutions.count)
            if avgConfidence > 0.6 { score += 0.03 }
        }

        // 8. Modal particle usage (advanced pragmatic skill)
        if !analysis.modalParticles.isEmpty { score += 0.02 }

        return min(1.0, max(0.0, score))
    }
}

struct UserFeedback {
    let isCorrection: Bool
    let originalPhrase: String
    let correctedPhrase: String
}
