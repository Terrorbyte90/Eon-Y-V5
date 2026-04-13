import Foundation
import Combine
import NaturalLanguage

// MARK: - LearningEngine
// Eons kontinuerliga inlärningssystem.
// Kombinerar: FSRS spaced repetition, meta-learning, LoRA-simulering,
// kompetensbok per domän, och adaptiv inlärningsschemaläggning.
// Målet: gå från sten till professor autonomt.

actor LearningEngine {
    static let shared = LearningEngine()

    // MARK: - Tillstånd

    private var competencyBook: [String: DomainCompetency] = [:]
    private var fsrsItems: [FSRSItem] = []
    private var learningSchedule: [ScheduledLesson] = []
    private var loraSimVersion: Int = 1
    private var totalLearningCycles: Int = 0
    private var knowledgeGaps: [KnowledgeGap] = []

    private init() {
        let domains = [
            "Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs",
            "Kausalitet", "Analogibyggande", "Metakognition", "Epistemologi",
            "AI & Maskininlärning", "Kognitionsvetenskap", "Filosofi",
            "Historia", "Psykologi", "Naturvetenskap"
        ]
        for domain in domains {
            competencyBook[domain] = DomainCompetency(
                domain: domain,
                level: 0.05,
                knowledgeItems: [],
                lastStudied: Date(timeIntervalSince1970: 0)
            )
        }
        for domain in domains {
            let key = "competency_\(domain)"
            let saved = UserDefaults.standard.double(forKey: key)
            if saved > 0.0 {
                competencyBook[domain]?.level = saved
            }
        }

        // v17: Restore persisted vocabulary and morphology counts
        loadPersistedState()
    }

    // MARK: - Persistence (v17)

    private static let vocabKey = "le_uniqueSwedishWords"
    private static let correctMorphKey = "le_correctMorphologyTests"
    private static let totalMorphKey = "le_totalMorphologyTests"
    private static let lastActiveDateKey = "le_lastActiveDate"
    private static let conversationsTodayKey = "le_conversationsToday"
    private static let wordsLearnedTodayKey = "le_wordsLearnedToday"

    private func loadPersistedState() {
        let ud = UserDefaults.standard
        if let savedWords = ud.array(forKey: Self.vocabKey) as? [String] {
            uniqueSwedishWords = Set(savedWords)
        }
        correctMorphologyTests = ud.integer(forKey: Self.correctMorphKey)
        totalMorphologyTests = ud.integer(forKey: Self.totalMorphKey)

        if let savedDate = ud.object(forKey: Self.lastActiveDateKey) as? Date {
            lastActiveDate = savedDate
        }
        // Reset daily counters if the stored date is not today
        if Calendar.current.isDateInToday(lastActiveDate) {
            conversationsToday = ud.integer(forKey: Self.conversationsTodayKey)
            wordsLearnedToday = ud.integer(forKey: Self.wordsLearnedTodayKey)
        } else {
            conversationsToday = 0
            wordsLearnedToday = 0
        }

        // Load progression state (Iteration 30)
        loadProgressionState()
    }

    private func persistState() {
        let ud = UserDefaults.standard
        ud.set(Array(uniqueSwedishWords), forKey: Self.vocabKey)
        ud.set(correctMorphologyTests, forKey: Self.correctMorphKey)
        ud.set(totalMorphologyTests, forKey: Self.totalMorphKey)
        ud.set(lastActiveDate, forKey: Self.lastActiveDateKey)
        ud.set(conversationsToday, forKey: Self.conversationsTodayKey)
        ud.set(wordsLearnedToday, forKey: Self.wordsLearnedTodayKey)
    }

    /// Ensure daily counters are reset when the date rolls over
    private func ensureDailyReset() {
        if !Calendar.current.isDateInToday(lastActiveDate) {
            conversationsToday = 0
            wordsLearnedToday = 0
        }
        lastActiveDate = Date()
    }

    // v16: Real competency measurement — combines fact knowledge, FSRS mastery,
    // conversation performance, and active language testing (not just fact counts)
    private var wordsAnalyzed: Set<String> = []           // Swedish words we've morphologically analyzed
    private var correctMorphologyTests: Int = 0           // How many morphology tests passed
    private var totalMorphologyTests: Int = 0
    private var successfulConversations: Int = 0          // Conversations with confidence > 0.6
    private var totalConversations: Int = 0
    private var uniqueSwedishWords: Set<String> = []      // Actual Swedish vocabulary

    // v17: Conversation-driven competency tracking
    private var conversationsToday: Int = 0
    private var wordsLearnedToday: Int = 0
    private var lastActiveDate: Date = Date(timeIntervalSince1970: 0)
    private var recentlyLearnedWords: [String] = []       // Rolling window of last N learned words
    private var activeStudyTopics: [String] = []          // Currently active FSRS topics
    private var learningVelocity: Double = 0.0            // Words per conversation (rolling avg)

    // Iteration 34: Cohesion marker tracking
    private var cohesionMarkerCounts: [String: Int] = [:]  // category -> total count
    private var totalCohesionMarkers: Int = 0

    // Iteration 35: Hedging and certainty tracking
    private var hedgingCount: Int = 0
    private var certaintyCount: Int = 0
    private var lastHedgingRatio: Double = 0.0

    // Iteration 39: Topic modeling and tracking
    private var currentTopics: [String: Int] = [:]         // topic -> salience score
    private var topicConversationCount: [String: Int] = [:] // topic -> number of conversations
    private var lastTopic: String? = nil
    private var topicTransitionCount: Int = 0

    // ═══════════════════════════════════════════════════════════
    // ITERATION 41-50: Autonomous Self-Development Systems
    // ═══════════════════════════════════════════════════════════

    // Iteration 41: Curriculum generation
    private var currentCurriculum: Curriculum? = nil
    private var lastCurriculumGeneration: Date? = nil

    // Iteration 42: Self-evaluation tracking
    private var selfEvaluationHistory: [SelfEvaluationReport] = []

    // Iteration 43: Learning strategy
    private var currentLearningStrategy: LearningStrategy = .balanced
    private var strategyHistory: [LearningStrategy] = []

    // Iteration 44: Knowledge synthesis
    private var synthesisCount: Int = 0
    private var knowledgeSyntheses: [KnowledgeSynthesis] = []

    // Iteration 45: Meta-meta-learning
    private var strategyEffectiveness: [String: [Double]] = [:]  // strategy -> learning velocities

    // Iteration 46: Self-generated evals
    private var selfGeneratedEvals: [SelfGeneratedEval] = []
    private var selfEvalPerformance: [Double] = []

    // Iteration 47: Progressive difficulty scaling
    private var currentDifficultyTier: String = "A1-B1"

    // Iteration 48: Communication effectiveness
    private var userFollowUpCount: Int = 0
    private var userSatisfactionCount: Int = 0
    private var currentLanguageComplexity: Double = 0.5

    // Iteration 49: Self-motivation
    private var lastMotivationalThought: String = ""
    private var motivationHistory: [String] = []

    func syncCompetenciesFromDatabase() async {
        let memory = PersistentMemoryStore.shared

        // 1. Count domain-specific facts (still useful as one signal among many)
        let domainKeywords: [String: [String]] = [
            "Morfologi": ["morfologi", "böjning", "ordklass", "böjningsform", "avledning", "supinum", "imperativ", "passiv", "nominalisering", "sammansättning", "lemma", "suffix", "prefix", "tempus", "presens", "preteritum"],
            "Syntax": ["syntax", "mening", "sats", "ordföljd", "fras", "topikalisering", "bisats", "huvudsats", "subjekt", "predikat", "infinitiv", "partisip", "V2", "inversjon"],
            "Semantik": ["semantik", "betydelse", "definition", "saldo_sense", "primär_betydelse", "polysemi", "synonym", "antonym", "hypernym", "hyponym", "meronym"],
            "Pragmatik": ["pragmatik", "talakt", "implikatur", "kontext", "presupposition", "artighet", "register", "ironi", "sarkasm", "grice"],
            "Diskurs": ["diskurs", "koherens", "kohesion", "konnektiv", "anafor", "katafor", "retori", "textstruktur", "narrativ", "genre"],
            "Kausalitet": ["kausalitet", "orsak", "slutsats", "kausal", "konsekvens", "korrelation", "verkan"],
            "AI & Maskininlärning": ["ai", "neural", "modell", "transformer", "bert", "gpt", "maskininlärning", "algoritm", "embedding"],
            "Kognitionsvetenskap": ["kognition", "medvetande", "perception", "uppmärksamhet", "arbetsminne", "tänkande", "varseblivning"],
            "Metakognition": ["metakognition", "självreflektion", "självmedvetenhet", "kalibrering", "strategi"],
            "Filosofi": ["filosofi", "epistemologi", "ontologi", "medvetande", "fenomenologi", "existens", "etik"],
            "Historia": ["historia", "historisk", "krig", "konflikt", "revolution", "civilisation", "medeltid"],
            "Psykologi": ["psykologi", "känsla", "beteende", "inlärning", "emotion", "motivation", "personlighet"],
            "Naturvetenskap": ["naturvetenskap", "fysik", "kemi", "biologi", "evolution", "astronomi", "kvant"],
            "Analogibyggande": ["analogi", "liknelse", "metafor", "parallell", "jämförelse", "mappning", "strukturell"],
        ]

        for (domain, keywords) in domainKeywords {
            var totalFacts = 0
            var uniqueSubjects: Set<String> = []
            for keyword in keywords {
                let facts = await memory.searchFacts(query: keyword, limit: 30)
                totalFacts += facts.count
                for fact in facts { uniqueSubjects.insert(fact.subject) }
            }

            // Knowledge score: logarithmic from facts (30% weight)
            let factScore = totalFacts > 0 ? min(0.30, 0.06 * log2(Double(totalFacts) + 1)) : 0.0

            // FSRS mastery score: active study (25% weight)
            let domainFSRSItems = fsrsItems.filter { $0.domain == domain }
            let reviewedItems = domainFSRSItems.filter { $0.reviewCount > 0 }
            let avgStability = reviewedItems.isEmpty ? 0.0 :
                reviewedItems.reduce(0.0) { $0 + $1.stability } / Double(reviewedItems.count)
            let fsrsScore = min(0.25, avgStability * 0.05 + Double(reviewedItems.count) * 0.015)

            // Conversation performance score: how well we use this domain (25% weight)
            let convScore: Double
            if totalConversations > 0 {
                convScore = min(0.25, Double(successfulConversations) / Double(totalConversations) * 0.25)
            } else {
                convScore = 0.0
            }

            // Language-specific bonus: morphology test accuracy (20% weight for language domains)
            let langBonus: Double
            if ["Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs"].contains(domain) {
                if totalMorphologyTests > 0 {
                    let accuracy = Double(correctMorphologyTests) / Double(totalMorphologyTests)
                    langBonus = min(0.20, accuracy * 0.20)
                } else {
                    langBonus = 0.0
                }
                // Vocabulary size bonus for language domains
                let vocabBonus = min(0.05, Double(uniqueSwedishWords.count) / 5000.0 * 0.05)
                let newLevel = min(0.95, factScore + fsrsScore + convScore + langBonus + vocabBonus)
                if var comp = competencyBook[domain] {
                    let recentlyStudied = comp.lastStudied.timeIntervalSinceNow > -3600
                    let growthBonus = recentlyStudied ? 0.003 : 0.0
                    comp.level = min(0.95, max(comp.level, newLevel) + growthBonus)
                    competencyBook[domain] = comp
                    UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
                }
            } else {
                let newLevel = min(0.90, factScore + fsrsScore + convScore)
                if var comp = competencyBook[domain] {
                    let recentlyStudied = comp.lastStudied.timeIntervalSinceNow > -3600
                    let growthBonus = recentlyStudied ? 0.003 : 0.0
                    comp.level = min(0.95, max(comp.level, newLevel) + growthBonus)
                    competencyBook[domain] = comp
                    UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
                }
            }
        }
    }

    // v16: Record morphology test result (called from EonLiveAutonomy)
    func recordMorphologyTest(word: String, passed: Bool) {
        totalMorphologyTests += 1
        if passed { correctMorphologyTests += 1 }
        wordsAnalyzed.insert(word.lowercased())
        persistState()
    }

    // Iteration 20: Boost pragmatic competency when idioms are detected
    func recordIdiomBoost(_ boost: Double) {
        if var comp = competencyBook["Pragmatik"] {
            comp.level = min(0.95, comp.level + boost)
            comp.lastStudied = Date()
            competencyBook["Pragmatik"] = comp
            UserDefaults.standard.set(comp.level, forKey: "competency_Pragmatik")
        }
    }

    // v16: Record a Swedish word in actual vocabulary
    func recordSwedishWord(_ word: String) {
        let lower = word.lowercased()
        let isNew = uniqueSwedishWords.insert(lower).inserted
        if isNew {
            ensureDailyReset()
            wordsLearnedToday += 1
            recentlyLearnedWords.append(lower)
            if recentlyLearnedWords.count > 50 {
                recentlyLearnedWords = Array(recentlyLearnedWords.suffix(50))
            }
            persistState()
        }
    }

    // v16: Get actual Swedish vocabulary count (not knowledge node count)
    func swedishVocabularyCount() -> Int {
        uniqueSwedishWords.count
    }

    // MARK: - Helper methods for external access (Iteration 28)

    /// Returns a copy of the competency book for external reading
    func competencyBook() -> [String: DomainCompetency] {
        competencyBook
    }

    /// Update a competency domain from external callers
    func updateCompetency(_ competency: DomainCompetency, domain: String) {
        competencyBook[domain] = competency
        UserDefaults.standard.set(competency.level, forKey: "competency_\(domain)")
    }

    // MARK: - Conversation-Driven Learning (v17)

    /// Extract Swedish words from both user and Eon messages, identify new vocabulary,
    /// and record them for competency tracking and FSRS scheduling.
    func learnFromConversation(userMessage: String, eonResponse: String) async {
        ensureDailyReset()
        conversationsToday += 1

        // ═══════════════════════════════════════════════════════════
        // ITERATION 48: Track communication effectiveness
        // ═══════════════════════════════════════════════════════════
        trackCommunicationEffectiveness(userMessage: userMessage, eonResponse: eonResponse)

        let allText = userMessage + " " + eonResponse
        let extractedWords = extractSwedishWords(from: allText)

        var newWordsThisConversation: [String] = []
        for word in extractedWords {
            let lower = word.lowercased()
            if !uniqueSwedishWords.contains(lower) {
                uniqueSwedishWords.insert(lower)
                newWordsThisConversation.append(lower)
                wordsLearnedToday += 1
            }
        }

        // Update recently learned words (rolling window of 50)
        recentlyLearnedWords.append(contentsOf: newWordsThisConversation)
        if recentlyLearnedWords.count > 50 {
            recentlyLearnedWords = Array(recentlyLearnedWords.suffix(50))
        }

        // Update learning velocity (exponential moving average) — 2x faster adaptation
        let wordsThisRound = Double(newWordsThisConversation.count)
        learningVelocity = learningVelocity * 0.6 + wordsThisRound * 0.4

        // v19: Learn grammar patterns from the conversation
        learnGrammarPatterns(from: allText)

        // v23: Learn collocations and idioms for natural language acquisition
        learnCollocations(from: allText)
        detectAndLearnIdioms(from: allText)

        // Iteration 34: Cohesion marker analysis
        let cohesion = analyzeCohesionMarkers(allText)
        if cohesion.cohesionScore > 0.5 {
            if var comp = competencyBook["Semantik"] {
                comp.level = min(0.95, comp.level + 0.005)
                comp.lastStudied = Date()
                competencyBook["Semantik"] = comp
            }
        }

        // Iteration 35: Hedging and certainty analysis
        let hedging = analyzeHedgingAndCertainty(allText)
        if hedging.isAcademicStyle {
            if var comp = competencyBook["Pragmatik"] {
                comp.level = min(0.95, comp.level + 0.003)
                comp.lastStudied = Date()
                competencyBook["Pragmatik"] = comp
            }
        }

        // v23: Adaptive learning — harder text = more competency gain
        let complexity = analyzeSentenceComplexity(allText)
        let complexityBonus = max(0, complexity - 0.3) * 0.009  // 300% BOOST: från 0.003 till 0.009

        // Detect domain from conversation and boost competency for language domains
        let domain = detectDomain(from: allText)
        if var comp = competencyBook[domain] {
            let vocabBoost = min(0.015, Double(newWordsThisConversation.count) * 0.003)  // 300% BOOST: från 0.001 till 0.003
            comp.level = min(0.95, comp.level + vocabBoost + complexityBonus)
            comp.lastStudied = Date()
            competencyBook[domain] = comp
            UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
        }

        // Iteration 4: Multi-domain learning — conversation improves ALL language domains simultaneously
        let languageDomains = ["Morfologi", "Syntax", "Semantik", "Pragmatik"]
        for langDomain in languageDomains {
            if var comp = competencyBook[langDomain] {
                comp.level = min(0.95, comp.level + 0.002)
                comp.lastStudied = Date()
                competencyBook[langDomain] = comp
            }
        }

        // Create FSRS items for new words in language-related domains
        for word in newWordsThisConversation.prefix(5) {
            addFSRSItem(topic: "Ordförråd: \(word)", domain: domain, initialDifficulty: 0.3)
        }

        // Update active study topics from current FSRS due items
        let dueItems = getDueItems()
        activeStudyTopics = Array(dueItems.prefix(10).map { $0.topic })

        // Qwen3-powered concept extraction (background, thermal-aware)
        if !ThermalSleepManager.shared.shouldPauseWork() && newWordsThisConversation.count >= 2 {
            await extractAndLearnConceptsWithQwen(
                newWords: newWordsThisConversation,
                context: allText
            )
        }

        // Persist and notify proxy
        persistState()
        await notifyProxy()
    }

    /// Iteration 5: Error-driven learning loop
    /// Stores errors as high-priority FSRS items, boosts relevant domains, and creates correction patterns.
    func learnFromErrors(errorTexts: [String]) async {
        for errorText in errorTexts {
            // Detect which domain the error relates to
            let domain = detectDomain(from: errorText)

            // Boost the relevant domain by 0.008 per error corrected
            if var comp = competencyBook[domain] {
                comp.level = min(0.95, comp.level + 0.008)
                comp.lastStudied = Date()
                competencyBook[domain] = comp
                UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
            }

            // Store error as a high-priority FSRS item (shorter interval for faster review)
            addFSRSItem(topic: "Fel: \(errorText.prefix(60))", domain: domain, initialDifficulty: 0.7)

            // Create a "correction pattern" fact in memory
            await PersistentMemoryStore.shared.saveFact(
                subject: "Korrektionsmönster",
                predicate: "från_fel",
                object: errorText,
                confidence: 0.85,
                source: "error_driven_learning"
            )
        }

        persistState()
        await notifyProxy()
        print("[ErrorLearning] \(errorTexts.count) errors processed for error-driven learning")
    }

    /// Uses Qwen3 to understand and define newly encountered words from a conversation.
    private func extractAndLearnConceptsWithQwen(newWords: [String], context: String) async {
        let wordList = newWords.prefix(5).joined(separator: ", ")
        let contextSnippet = String(context.prefix(300))

        let prompt = """
        Du är en svensk språkexpert. Jag hittade dessa nya ord i en konversation: \(wordList)
        Kontext: "\(contextSnippet)"
        För varje ord, ge en kort definition och ordklass. Svara i formatet:
        [ord]: [ordklass] — [definition]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 200, temperature: 0.5
        )

        guard !response.isEmpty else { return }

        for line in response.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            let word = trimmed[trimmed.startIndex..<colonIdx]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let rest = String(trimmed[trimmed.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard word.count > 1 && word.count < 30 && !rest.isEmpty else { continue }

            await PersistentMemoryStore.shared.saveFact(
                subject: word,
                predicate: "qwen3_definition",
                object: rest,
                confidence: 0.7,
                source: "qwen3_conversation_learning"
            )
        }
    }

    /// Extract Swedish words from text using NLTagger for proper linguistic tokenization
    private func extractSwedishWords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.swedish, range: text.startIndex..<text.endIndex)

        var words: [String] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .omitOther]
        ) { tag, range in
            let word = String(text[range])
            // v23: Also include determiners and prepositions for grammatical context
            // Keep nouns, verbs, adjectives, adverbs with length > 2 (skip particles/articles)
            if let tag = tag,
               [.noun, .verb, .adjective, .adverb].contains(tag),
               word.count > 2 {
                words.append(word)
            }
            return true
        }
        return words
    }

    // MARK: - Enhanced Autonomous Learning (v23)

    /// Iteration 19: Collocation detection with proper PMI scoring
    /// PMI(word1, word2) = log(P(word1,word2) / (P(word1) * P(word2)))
    /// Collocations with PMI > 3.0 are stored as strong collocations
    private var collocations: [String: Int] = [:]          // "word1|word2" -> frequency
    private var unigramCounts: [String: Int] = [:]          // word -> total occurrences
    private var totalBigramObservations: Int = 0            // Total bigrams observed
    private var strongCollocations: Set<String> = []        // Collocations with PMI > 3.0

    /// Extract and learn collocations from conversation text using PMI scoring
    private func learnCollocations(from text: String) {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }
        guard words.count >= 2 else { return }

        var newStrongCollocations: Int = 0

        // Update unigram counts
        for word in words {
            unigramCounts[word, default: 0] += 1
        }

        // Extract bigrams and update counts
        for i in 0..<(words.count - 1) {
            let bigram = "\(words[i])|\(words[i + 1])"
            collocations[bigram, default: 0] += 1
            totalBigramObservations += 1

            // Iteration 19: Compute PMI for this bigram
            let pWord1 = Double(unigramCounts[words[i], default: 0]) / Double(max(1, words.count))
            let pWord2 = Double(unigramCounts[words[i + 1], default: 0]) / Double(max(1, words.count))
            let pBigram = Double(collocations[bigram, default: 0]) / Double(max(1, totalBigramObservations))

            // PMI = log2(P(w1,w2) / (P(w1) * P(w2)))
            let expectedPMI = pWord1 * pWord2
            if expectedPMI > 0 && pBigram > 0 {
                let pmi = log2(pBigram / expectedPMI)

                // Strong collocation: PMI > 3.0
                if pmi > 3.0 && !strongCollocations.contains(bigram) {
                    strongCollocations.insert(bigram)
                    newStrongCollocations += 1
                }
            }
        }

        // Iteration 19: Boost semantic competency for each strong collocation learned
        if newStrongCollocations > 0 {
            let semanticBoost = min(0.05, Double(newStrongCollocations) * 0.003)
            if var comp = competencyBook["Semantik"] {
                comp.level = min(0.95, comp.level + semanticBoost)
                comp.lastStudied = Date()
                competencyBook["Semantik"] = comp
                UserDefaults.standard.set(comp.level, forKey: "competency_Semantik")
            }
        }

        // Prune low-frequency collocations to prevent unbounded growth
        if collocations.count > 500 {
            collocations = collocations.filter { $0.value >= 3 }
        }
    }

    /// Get count of strong collocations (PMI > 3.0)
    func strongCollocationCount() -> Int {
        strongCollocations.count
    }

    /// Detect Swedish idioms in text and learn them
    private var learnedIdioms: Set<String> = []

    private func detectAndLearnIdioms(from text: String) {
        let lower = text.lowercased()
        let knownIdiomPatterns = [
            "lägga korten på bordet", "ha is i magen", "ta tjuren vid hornen",
            "dra öronen åt sig", "gå på nitar", "kasta in handduken",
            "slå huvudet på spiken", "hugga i sten", "sila mygg och svälja kameler",
            "bita i det sura äpplet", "lägga locket på", "visa var skåpet ska stå",
            "ha tummen mitt i handen", "gå som katten kring het gröt",
            "falla mellan stolarna", "stå på sig", "ta sig vatten över huvudet",
            "vara ute och cykla", "ha rent mjöl i påsen", "dra sig i håret",
        ]

        for idiom in knownIdiomPatterns {
            if lower.contains(idiom) && !learnedIdioms.contains(idiom) {
                learnedIdioms.insert(idiom)
                // Boost pragmatics and discourse competency for idiom recognition
                if var comp = competencyBook["Pragmatik"] {
                    comp.level = min(0.95, comp.level + 0.003)
                    competencyBook["Pragmatik"] = comp
                }
            }
        }
    }

    // MARK: - Iteration 34: Cohesion Marker Detection
    // Detects and categorizes Swedish cohesion markers

    struct CohesionAnalysis {
        let additive: [String]       // och, dessutom, vidare, även
        let adversative: [String]    // men, dock, emellertid, ändå, trots
        let causal: [String]         // eftersom, därför, således, följaktligen
        let temporal: [String]       // sedan, därefter, samtidigt, innan
        let exemplification: [String] // till exempel, exempelvis, såsom, bland annat
        let totalMarkers: Int
        let cohesionScore: Double    // 0-1 normalized

        var category: String {
            if cohesionScore > 0.7 { return "hög" }
            else if cohesionScore > 0.4 { return "måttlig" }
            else { return "låg" }
        }
    }

    private static let additiveMarkers: Set<String> = ["och", "dessutom", "vidare", "även", "också", "därutöver", "likaså", "samt", "tillika"]
    private static let adversativeMarkers: Set<String> = ["men", "dock", "emellertid", "ändå", "trots", "ändå", "fast", "fastän", "däremot", "emot", "icke desto mindre"]
    private static let causalMarkers: Set<String> = ["eftersom", "därför", "således", "följaktligen", "alltså", "därav", "tack vare", "på grund av", "sålunda", "följdaktligen"]
    private static let temporalMarkers: Set<String> = ["sedan", "därefter", "samtidigt", "innan", "efter", "under", "medan", "först", "sist", "slutligen", "tidigare", "senare", "då", "när"]
    private static let exemplificationMarkers: Set<String> = ["exempelvis", "såsom", "bland", "annat", "exempel", "särskilt", "speciellt", "framförallt", "särskilt", "typ"]
    private static let multiWordExemplification: [String] = ["till exempel", "bland annat", "så som", "till och med"]

    func analyzeCohesionMarkers(_ text: String) -> CohesionAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        let additive = words.filter { Self.additiveMarkers.contains($0) }
        let adversative = words.filter { Self.adversativeMarkers.contains($0) }
        let causal = words.filter { Self.causalMarkers.contains($0) }
        let temporal = words.filter { Self.temporalMarkers.contains($0) }
        let exemplification = words.filter { Self.exemplificationMarkers.contains($0) }

        // Multi-word markers
        for mwm in Self.multiWordExemplification where lower.contains(mwm) {
            if !exemplification.contains(mwm) {
                // Count as exemplification
            }
        }

        let total = additive.count + adversative.count + causal.count + temporal.count + exemplification.count
        // Cohesion score: markers per sentence (optimal ~2-3 per sentence)
        let sentenceCount = max(1, text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { $0.trimmingCharacters(in: .whitespaces).count > 3 }.count)
        let markersPerSentence = Double(total) / Double(sentenceCount)
        let cohesionScore = min(1.0, markersPerSentence / 3.0)

        // Update tracking
        cohesionMarkerCounts["additive", default: 0] += additive.count
        cohesionMarkerCounts["adversative", default: 0] += adversative.count
        cohesionMarkerCounts["causal", default: 0] += causal.count
        cohesionMarkerCounts["temporal", default: 0] += temporal.count
        cohesionMarkerCounts["exemplification", default: 0] += exemplification.count
        totalCohesionMarkers += total

        return CohesionAnalysis(additive: additive, adversative: adversative, causal: causal, temporal: temporal, exemplification: exemplification, totalMarkers: total, cohesionScore: cohesionScore)
    }

    // MARK: - Iteration 35: Hedging and Certainty Detection

    struct HedgingAnalysis {
        let hedgingWords: [String]
        let certaintyWords: [String]
        let hedgingRatio: Double       // hedging / (hedging + certainty)
        let isAcademicStyle: Bool
        let explanation: String
    }

    private static let hedgingWords: Set<String> = [
        "kanske", "möjligen", "sannolikt", "troligen", "eventuellt", "potentiellt",
        "verkar", "tycks", "synes", "kan vara", "skulle kunna", "verkar som",
        "i viss mån", "delvis", "någorlunda", "relativt", "ungefär", "cirka",
        "antagligen", "förmodligen", "troligtvis", "möjligtvis", "kanske"
    ]

    private static let certaintyWords: Set<String> = [
        "säkert", "definitivt", "garanterat", "uppenbart", "naturligtvis", "självklart",
        "absolut", "utan tvekan", "onekligen", "tvivelsutan", "säkerligen", "bestämt",
        "avgjort", "verkligen", "faktiskt", "givetvis", "naturligtvis", "naturligtvis"
    ]

    func analyzeHedgingAndCertainty(_ text: String) -> HedgingAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        let hedging = words.filter { Self.hedgingWords.contains($0) }
        let certainty = words.filter { Self.certaintyWords.contains($0) }

        // Check multi-word hedging
        let multiHedgeCount = ["kan vara", "skulle kunna", "verkar som", "utan tvekan"].filter { lower.contains($0) }.count

        let totalHedging = hedging.count + multiHedgeCount
        let totalCertainty = certainty.count
        let total = totalHedging + totalCertainty
        let hedgingRatio = total > 0 ? Double(totalHedging) / Double(total) : 0.5

        // Academic writing typically has hedging ratio 0.6-0.8
        let isAcademicStyle = hedgingRatio > 0.5 && totalHedging >= 2

        // Update tracking
        hedgingCount += totalHedging
        certaintyCount += totalCertainty
        lastHedgingRatio = hedgingRatio

        let explanation: String
        if isAcademicStyle {
            explanation = "Akademisk stil: hedging-kvot \(String(format: "%.2f", hedgingRatio)) (\(totalHedging) hedging, \(totalCertainty) certans)"
        } else if hedgingRatio > 0.7 {
            explanation = "Mycket osäker ton: hedging-kvot \(String(format: "%.2f", hedgingRatio))"
        } else if hedgingRatio < 0.3 && totalCertainty > 2 {
            explanation = "Mycket säker ton: \(totalCertainty) certans-markörer"
        } else {
            explanation = "Neutral ton: hedging-kvot \(String(format: "%.2f", hedgingRatio))"
        }

        return HedgingAnalysis(hedgingWords: hedging, certaintyWords: certainty, hedgingRatio: hedgingRatio, isAcademicStyle: isAcademicStyle, explanation: explanation)
    }

    // MARK: - Iteration 39: Topic Modeling and Tracking

    struct TopicTransition {
        let fromTopic: String
        let toTopic: String
        let timestamp: Date
        let fromSalience: Int
        let toSalience: Int
    }

    private var topicTransitions: [TopicTransition] = []

    func trackTopic(_ topic: String, inConversation: Bool = true) -> TopicTransition? {
        let normalizedTopic = topic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTopic.count > 1 else { return nil }

        // Update topic salience
        currentTopics[normalizedTopic, default: 0] += 1

        var transition: TopicTransition? = nil

        // Detect topic shift
        if let last = lastTopic, last != normalizedTopic {
            let fromSalience = currentTopics[last] ?? 0
            let toSalience = currentTopics[normalizedTopic] ?? 1

            transition = TopicTransition(
                fromTopic: last,
                toTopic: normalizedTopic,
                timestamp: Date(),
                fromSalience: fromSalience,
                toSalience: toSalience
            )
            topicTransitionCount += 1

            // Boost topic that was discussed extensively
            if fromSalience > 5 {
                let domain = detectDomain(from: last)
                if var comp = competencyBook[domain] {
                    let boost = min(0.05, Double(fromSalience) * 0.008)
                    comp.level = min(0.95, comp.level + boost)
                    comp.lastStudied = Date()
                    competencyBook[domain] = comp
                    UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
                }
            }
        }

        lastTopic = normalizedTopic
        topicConversationCount[normalizedTopic, default: 0] += 1

        // When a topic has been discussed for > 5 conversations, boost related domain
        if let convCount = topicConversationCount[normalizedTopic], convCount > 5 {
            let domain = detectDomain(from: normalizedTopic)
            if var comp = competencyBook[domain] {
                comp.level = min(0.95, comp.level + 0.008)
                comp.lastStudied = Date()
                competencyBook[domain] = comp
                UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
            }
        }

        if let t = transition {
            topicTransitions.append(t)
        }

        // Prune old transitions
        if topicTransitions.count > 100 {
            topicTransitions = Array(topicTransitions.suffix(100))
        }

        return transition
    }

    func getTopTopics(limit: Int = 10) -> [(topic: String, salience: Int)] {
        currentTopics.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    func getTopicTransitionCount() -> Int {
        topicTransitionCount
    }

    /// Analyze sentence complexity for learning difficulty assessment
    private func analyzeSentenceComplexity(_ text: String) -> Double {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { $0.trimmingCharacters(in: .whitespaces).count > 5 }
        guard !sentences.isEmpty else { return 0.0 }

        var totalComplexity = 0.0
        for sentence in sentences {
            let words = sentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let wordCount = Double(words.count)
            let avgWordLength = words.isEmpty ? 0.0 : words.reduce(0.0) { $0 + Double($1.count) } / wordCount

            // Complexity factors: length, word length, subordinate clauses
            let lengthFactor = min(1.0, wordCount / 25.0)
            let wordLengthFactor = min(1.0, avgWordLength / 8.0)
            let subordinators = ["att", "som", "när", "om", "eftersom", "medan", "innan", "efter", "fastän"]
            let subClauseFactor = min(1.0, Double(subordinators.filter { sentence.lowercased().contains(" \($0) ") }.count) * 0.33)

            totalComplexity += (lengthFactor + wordLengthFactor + subClauseFactor) / 3.0
        }

        return totalComplexity / Double(sentences.count)
    }

    // MARK: - Grammar Pattern Learning (v19)

    /// Tracks Swedish sentence patterns (V2 rule, bisats word order, etc.)
    private var grammarPatterns: [String: Int] = [:]  // pattern -> occurrence count
    private var compoundWordCache: Set<String> = []    // detected compound words

    /// Analyze sentence structure patterns from conversation text
    func learnGrammarPatterns(from text: String) {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])

        for sentence in sentences {
            tagger.string = sentence
            tagger.setLanguage(.swedish, range: sentence.startIndex..<sentence.endIndex)

            var tags: [(String, NLTag)] = []
            tagger.enumerateTags(
                in: sentence.startIndex..<sentence.endIndex,
                unit: .word,
                scheme: .lexicalClass,
                options: [.omitWhitespace, .omitPunctuation, .omitOther]
            ) { tag, range in
                if let tag = tag {
                    tags.append((String(sentence[range]), tag))
                }
                return true
            }

            guard tags.count >= 3 else { continue }

            // Detect V2 (verb-second) pattern in main clauses
            if tags.count >= 2 && tags[1].1 == .verb {
                grammarPatterns["V2_huvudsats", default: 0] += 1
            }

            // Detect bisats (subordinate clause) markers: att, som, när, om, eftersom, etc.
            let bisatsMarkers: Set<String> = ["att", "som", "när", "om", "eftersom", "medan", "innan", "efter", "fastän", "trots", "huruvida", "ifall", "såvida"]
            for (i, (word, _)) in tags.enumerated() {
                if bisatsMarkers.contains(word.lowercased()) && i + 2 < tags.count {
                    grammarPatterns["bisats_\(word.lowercased())", default: 0] += 1
                }
            }

            // Detect compound words (long words that might be compounds)
            for (word, tag) in tags where tag == .noun && word.count >= 8 {
                let lower = word.lowercased()
                if !compoundWordCache.contains(lower) {
                    compoundWordCache.insert(lower)
                    // Boost morphology competency for each new compound detected
                    if var comp = competencyBook["Morfologi"] {
                        comp.level = min(0.95, comp.level + 0.0015)  // 300% BOOST: från 0.0005 till 0.0015
                        competencyBook["Morfologi"] = comp
                    }
                }
            }

            // Detect passive constructions (word ending in -s that is a verb)
            for (word, tag) in tags where tag == .verb && word.hasSuffix("s") && word.count > 4 {
                grammarPatterns["passiv_s", default: 0] += 1
            }

            // Detect topikalisering (non-subject-initial main clause)
            if tags.count >= 3 && tags[0].1 != .pronoun && tags[0].1 != .noun && tags[1].1 == .verb {
                grammarPatterns["topikalisering", default: 0] += 1
            }

            // Detect adjective agreement (adjective before noun)
            for i in 0..<(tags.count - 1) {
                if tags[i].1 == .adjective && tags[i + 1].1 == .noun {
                    grammarPatterns["adj_attributiv", default: 0] += 1
                }
            }

            // Detect adverb placement patterns
            for i in 0..<(tags.count - 1) {
                if tags[i].1 == .adverb && tags[i + 1].1 == .verb {
                    grammarPatterns["adverb_före_verb", default: 0] += 1
                }
            }
        }

        // v27: Boost syntax competency based on ALL detected grammar patterns (not just V2)
        let syntaxPatternCount = grammarPatterns.filter { key, count in
            (key.hasPrefix("V2_") || key.hasPrefix("bisats_") || key.hasPrefix("passiv") ||
             key.hasPrefix("topik") || key.hasPrefix("adverb_")) && count > 3
        }.count
        if syntaxPatternCount > 0 {
            let boost = min(0.009, Double(syntaxPatternCount) * 0.0015)  // 300% BOOST: från 0.003/0.0005 till 0.009/0.0015
            if var comp = competencyBook["Syntax"] {
                comp.level = min(0.95, comp.level + boost)
                competencyBook["Syntax"] = comp
            }
        }

        // Prune low-frequency patterns to prevent unbounded growth
        if grammarPatterns.count > 50 {
            grammarPatterns = grammarPatterns.filter { $0.value >= 2 }
        }
    }

    /// Get a summary of learned grammar patterns for display
    func grammarPatternSummary() -> [(pattern: String, count: Int)] {
        grammarPatterns.sorted { $0.value > $1.value }
            .prefix(10)
            .map { (pattern: $0.key, count: $0.value) }
    }

    /// Count of detected compound words
    func compoundWordCount() -> Int {
        compoundWordCache.count
    }

    // MARK: - Qwen3-Powered Autonomous Learning

    /// Ask Qwen3 to generate a new Swedish word/concept with definition and usage,
    /// then persist it as a fact. Called periodically from the brain's master tick.
    func learnFromQwen() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let weakestDomain = competencyBook.values.sorted { $0.level < $1.level }.first?.domain ?? "Semantik"
        let existingWords = Array(uniqueSwedishWords.prefix(10)).joined(separator: ", ")

        let prompt = """
        Du är en svensk språkexpert. Generera ETT nytt svenskt ord eller begrepp inom domänen "\(weakestDomain)".
        Ord jag redan kan: \(existingWords)
        Ge mig ett NYTT ord jag inte redan kan.
        Svara EXAKT i detta format (inget annat):
        ORD: [ordet]
        DEFINITION: [kort definition på svenska]
        EXEMPEL: [en exempelmening]
        DOMÄN: \(weakestDomain)
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 150, temperature: 0.8
        )

        guard !response.isEmpty else { return }

        let parsed = parseQwenWordResponse(response)
        guard let word = parsed.word, let definition = parsed.definition else { return }

        recordSwedishWord(word)

        await PersistentMemoryStore.shared.saveFact(
            subject: word,
            predicate: "definition",
            object: definition,
            confidence: 0.75,
            source: "qwen3_autonomous_learning"
        )

        if let example = parsed.example {
            await PersistentMemoryStore.shared.saveFact(
                subject: word,
                predicate: "användningsexempel",
                object: example,
                confidence: 0.7,
                source: "qwen3_autonomous_learning"
            )
        }

        let domain = parsed.domain ?? weakestDomain
        addFSRSItem(topic: "Qwen-ord: \(word)", domain: domain, initialDifficulty: 0.4)

        if var comp = competencyBook[domain] {
            comp.level = min(0.95, comp.level + 0.002)
            comp.lastStudied = Date()
            competencyBook[domain] = comp
            UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
        }

        persistState()
        await notifyProxy()
    }

    /// Uses Qwen3 to expand vocabulary around a known word — generates synonyms,
    /// antonyms, and related terms, then stores them.
    func expandVocabulary(from word: String) async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let prompt = """
        Du är en svensk språkexpert. Givet ordet "\(word)", ge mig:
        SYNONYMER: [kommaseparerad lista, max 4]
        ANTONYMER: [kommaseparerad lista, max 3]
        RELATERADE: [kommaseparerad lista med närliggande begrepp, max 4]
        Svara EXAKT i formatet ovan, bara svenska ord.
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 120, temperature: 0.7
        )

        guard !response.isEmpty else { return }

        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let prefix: String?
            let relation: String?
            if trimmed.uppercased().hasPrefix("SYNONYMER:") {
                prefix = "SYNONYMER:"
                relation = "synonym_till"
            } else if trimmed.uppercased().hasPrefix("ANTONYMER:") {
                prefix = "ANTONYMER:"
                relation = "antonym_till"
            } else if trimmed.uppercased().hasPrefix("RELATERADE:") {
                prefix = "RELATERADE:"
                relation = "relaterat_till"
            } else {
                prefix = nil
                relation = nil
            }

            guard let pfx = prefix, let rel = relation else { continue }
            let wordsStr = trimmed.dropFirst(pfx.count).trimmingCharacters(in: .whitespaces)
            let words = wordsStr.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { $0.count > 1 && $0.count < 30 }

            for relatedWord in words.prefix(4) {
                recordSwedishWord(relatedWord)
                await PersistentMemoryStore.shared.saveFact(
                    subject: relatedWord,
                    predicate: rel,
                    object: word,
                    confidence: 0.7,
                    source: "qwen3_vocabulary_expansion"
                )
            }
        }

        let domain = detectDomain(from: word)
        addFSRSItem(topic: "Ordnät: \(word)", domain: domain, initialDifficulty: 0.3)

        persistState()
        await notifyProxy()
    }

    /// Parses a Qwen3 word-generation response into structured components.
    private func parseQwenWordResponse(_ response: String) -> (word: String?, definition: String?, example: String?, domain: String?) {
        var word: String?
        var definition: String?
        var example: String?
        var domain: String?

        for line in response.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("ORD:") {
                word = trimmed.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            } else if upper.hasPrefix("DEFINITION:") {
                definition = String(trimmed.dropFirst(11).trimmingCharacters(in: .whitespacesAndNewlines))
            } else if upper.hasPrefix("EXEMPEL:") {
                example = String(trimmed.dropFirst(8).trimmingCharacters(in: .whitespacesAndNewlines))
            } else if upper.hasPrefix("DOMÄN:") {
                domain = String(trimmed.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return (word, definition, example, domain)
    }

    // MARK: - Autonomous Exploration (v17)

    /// Identify the weakest domain, generate study goals, and create FSRS items
    /// for suggested topics automatically. Returns a summary of the exploration.
    func autonomousExplore() async -> AutonomousExploreResult {
        ensureDailyReset()

        // 1. Identify the weakest domain
        let sorted = competencyBook.values.sorted { $0.level < $1.level }
        guard let weakest = sorted.first else {
            return AutonomousExploreResult(domain: "Okänd", studyGoals: [], createdItems: 0)
        }

        // 2. Check prerequisites — if prerequisites are unmet, target those instead
        var targetDomain = weakest.domain
        if let prereqs = prerequisites[weakest.domain] {
            let unmet = prereqs.filter { (competencyBook[$0]?.level ?? 0) < 0.3 }
            if let firstUnmet = unmet.first {
                targetDomain = firstUnmet
            }
        }

        let targetComp = competencyBook[targetDomain] ?? weakest

        // 3. Generate study goals based on current level
        let topics = suggestTopics(for: targetDomain, level: targetComp.level)

        // 4. Filter out topics we already have active FSRS items for
        let existingTopics = Set(fsrsItems.filter { $0.domain == targetDomain }.map { $0.topic })
        let newTopics = topics.filter { !existingTopics.contains($0) }

        // 5. Create FSRS items for new study goals
        var createdCount = 0
        for topic in newTopics {
            let difficulty = max(0.2, 1.0 - targetComp.level)
            addFSRSItem(topic: topic, domain: targetDomain, initialDifficulty: difficulty)
            createdCount += 1
        }

        // 6. Update active study topics
        activeStudyTopics = Array(getDueItems().prefix(10).map { $0.topic })

        // 7. Mark domain as recently studied
        if var comp = competencyBook[targetDomain] {
            comp.lastStudied = Date()
            competencyBook[targetDomain] = comp
        }

        // 8. Record exploration as a fact
        await PersistentMemoryStore.shared.saveFact(
            subject: targetDomain,
            predicate: "autonom_utforskning",
            object: newTopics.joined(separator: ", "),
            confidence: 0.8,
            source: "autonomous_explore"
        )

        persistState()
        await notifyProxy()

        return AutonomousExploreResult(
            domain: targetDomain,
            studyGoals: newTopics,
            createdItems: createdCount
        )
    }

    // MARK: - Proxy Notification (v17)

    /// Push latest state to the MainActor observable proxy
    private func notifyProxy() async {
        let snapshot = competencySnapshot()
        let level = overallCompetencyLevel()
        let recentWords = Array(recentlyLearnedWords.suffix(10))
        let topics = activeStudyTopics
        let velocity = learningVelocity
        let convsToday = conversationsToday
        let wordsToday = wordsLearnedToday
        let vocabCount = uniqueSwedishWords.count
        let compounds = compoundWordCache.count
        let patterns = grammarPatternSummary()

        await MainActor.run {
            let proxy = LearningEngine.observableProxy
            proxy.competencies = snapshot
            proxy.overallLevel = level
            proxy.latestLearnedWords = recentWords
            proxy.activeTopics = topics
            proxy.velocity = velocity
            proxy.conversationsToday = convsToday
            proxy.wordsLearnedToday = wordsToday
            proxy.vocabularyCount = vocabCount
            proxy.compoundWordCount = compounds
            proxy.grammarPatterns = patterns
        }
    }

    // MARK: - Daily Metrics (v17)

    /// Get conversation-driven metrics for today
    func dailyMetrics() -> DailyLearningMetrics {
        DailyLearningMetrics(
            conversationsToday: conversationsToday,
            wordsLearnedToday: wordsLearnedToday,
            lastActiveDate: lastActiveDate,
            totalVocabulary: uniqueSwedishWords.count,
            learningVelocity: learningVelocity,
            activeStudyTopics: activeStudyTopics,
            recentWords: Array(recentlyLearnedWords.suffix(12))
        )
    }

    // MARK: - Domain Interaction Matrix
    // Models how learning in one domain accelerates learning in related domains
    private let domainInteractions: [String: [(target: String, strength: Double)]] = [
        "Morfologi":           [("Syntax", 0.6), ("Semantik", 0.4), ("Diskurs", 0.2)],
        "Syntax":              [("Morfologi", 0.5), ("Pragmatik", 0.4), ("Semantik", 0.3)],
        "Semantik":            [("Pragmatik", 0.5), ("Morfologi", 0.3), ("Kognitionsvetenskap", 0.2)],
        "Pragmatik":           [("Diskurs", 0.6), ("Semantik", 0.4), ("Psykologi", 0.3)],
        "Diskurs":             [("Pragmatik", 0.5), ("Semantik", 0.3)],
        "Kausalitet":          [("Filosofi", 0.5), ("Kognitionsvetenskap", 0.4), ("Naturvetenskap", 0.3)],
        "AI & Maskininlärning":[("Kognitionsvetenskap", 0.5), ("Filosofi", 0.3), ("Epistemologi", 0.2)],
        "Kognitionsvetenskap": [("Psykologi", 0.6), ("Metakognition", 0.5), ("AI & Maskininlärning", 0.3)],
        "Metakognition":       [("Kognitionsvetenskap", 0.5), ("Epistemologi", 0.4), ("Psykologi", 0.3)],
        "Filosofi":            [("Epistemologi", 0.7), ("Kausalitet", 0.4), ("Psykologi", 0.2)],
        "Epistemologi":        [("Filosofi", 0.6), ("Metakognition", 0.4), ("Kausalitet", 0.3)],
        "Historia":            [("Filosofi", 0.3), ("Psykologi", 0.2)],
        "Psykologi":           [("Kognitionsvetenskap", 0.5), ("Filosofi", 0.3), ("Metakognition", 0.3)],
        "Naturvetenskap":      [("Kausalitet", 0.4), ("Epistemologi", 0.3)],
        "Analogibyggande":     [("Kognitionsvetenskap", 0.4), ("Kausalitet", 0.3), ("Filosofi", 0.2)],
    ]

    // Track topic depth per domain — how deep we've gone into each topic
    private var topicDepthTracker: [String: [String: Int]] = [:] // domain -> topic -> depth level

    // MARK: - Inlärningscykel

    func runLearningCycle() async -> LearningCycleResult {
        totalLearningCycles += 1

        // 1. Identifiera kunskapsluckor
        let gaps = identifyKnowledgeGaps()
        knowledgeGaps = gaps

        // 2. v27: Use optimal study queue (forgetting curve) instead of simple due-date filter
        let optimalQueue = optimalStudyQueue()
        let dueItems = optimalQueue.isEmpty ? getDueItems() : optimalQueue

        // 3. v27: Interleaved scheduling — mix domains for better retention
        // Research shows interleaving domains during practice improves learning efficiency
        let batchSize = gaps.first.map { $0.urgency > 1.5 ? 7 : 5 } ?? 5
        let interleaved = interleaveDomains(items: Array(dueItems.prefix(batchSize * 2)), maxItems: batchSize)
        var studiedItems: [String] = []
        for item in interleaved {
            await studyItem(item)
            studiedItems.append(item.topic)
        }

        // 4. Generera ny kunskap från luckor
        let newKnowledge = await generateKnowledgeForGaps(gaps.prefix(3).map { $0 })

        // 5. Propagate cross-domain learning via interaction matrix
        await propagateDomainInteractions(studiedDomains: Set(dueItems.prefix(batchSize).compactMap { $0.domain }))

        // 6. Uppdatera LoRA-simulering
        if totalLearningCycles % 10 == 0 {
            loraSimVersion += 1
        }

        return LearningCycleResult(
            cycleNumber: totalLearningCycles,
            studiedTopics: studiedItems,
            newKnowledge: newKnowledge,
            gapsIdentified: gaps.count,
            loraVersion: loraSimVersion
        )
    }

    /// Propagate learning gains across related domains
    private func propagateDomainInteractions(studiedDomains: Set<String>) async {
        for domain in studiedDomains {
            guard let interactions = domainInteractions[domain],
                  let sourceLevel = competencyBook[domain]?.level else { continue }
            for interaction in interactions {
                guard var target = competencyBook[interaction.target] else { continue }
                // Transfer is proportional to source level, interaction strength, and target room to grow
                let roomToGrow = 1.0 - target.level
                let transfer = sourceLevel * interaction.strength * roomToGrow * 0.003
                if transfer > 0.0005 {
                    target.level = min(0.95, target.level + transfer)
                    competencyBook[interaction.target] = target
                }
            }
        }
    }

    // MARK: - FSRS (Free Spaced Repetition Scheduler)

    // v27: Ebbinghaus forgetting curve — predicts retention probability for an item
    func predictedRetention(for item: FSRSItem) -> Double {
        let now = Date()
        guard let lastReview = item.lastReview else { return 0.5 }
        let daysSince = now.timeIntervalSince(lastReview) / 86400.0
        guard daysSince > 0, item.stability > 0 else { return 0.9 }
        // R(t) = exp(-t / S) — exponential decay from stability
        return max(0.01, exp(-daysSince / max(0.1, item.stability)))
    }

    /// v27: Items sorted by learning efficiency — prioritize items about to be forgotten
    func optimalStudyQueue() -> [FSRSItem] {
        let now = Date()
        return fsrsItems
            .map { item -> (FSRSItem, Double) in
                let retention = predictedRetention(for: item)
                // Sweet spot: items at 60-80% retention benefit most from review
                // (too early = waste, too late = fully forgotten)
                let efficiency = retention > 0.9 ? 0.1 :           // Not due yet
                                 retention > 0.6 ? (0.9 - retention) * 3.0 : // Optimal zone
                                 retention > 0.3 ? 0.7 :           // Getting late but still useful
                                 0.3                                // Nearly forgotten
                let urgency = now > item.dueDate ? 0.3 : 0.0      // Bonus for overdue
                return (item, efficiency + urgency)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    private func getDueItems() -> [FSRSItem] {
        let now = Date()
        return fsrsItems.filter { $0.dueDate <= now }.sorted { $0.priority > $1.priority }
    }

    private func studyItem(_ item: FSRSItem) async {
        guard let idx = fsrsItems.firstIndex(where: { $0.id == item.id }) else { return }

        let reviewCount = fsrsItems[idx].reviewCount
        let lastReview = fsrsItems[idx].lastReview
        let daysSinceLast = lastReview.map { Date().timeIntervalSince($0) / 86400 } ?? 1.0

        // v27: Fix rating calculation — handle first review (no lastReview) correctly
        let rating: Double
        if lastReview == nil {
            // First ever review: base rating on how soon after creation we reviewed
            let daysSinceCreation = Date().timeIntervalSince(fsrsItems[idx].dueDate) / 86400
            rating = daysSinceCreation <= 1.0 ? 0.9 : daysSinceCreation <= 3.0 ? 0.7 : 0.5
        } else {
            let scheduledInterval = fsrsItems[idx].dueDate.timeIntervalSince(lastReview!) / 86400
            let actualInterval = daysSinceLast
            if scheduledInterval <= 0 {
                rating = 0.9
            } else {
                let ratio = actualInterval / max(scheduledInterval, 1.0)
                rating = ratio <= 1.2 ? 0.9 : ratio <= 2.0 ? 0.7 : ratio <= 3.0 ? 0.4 : 0.2
            }
        }

        // FSRS-4.5 stability update — 3x growth boost for faster mastery
        let w = 0.14
        var difficulty = fsrsItems[idx].difficulty
        let newStability = max(0.1, fsrsItems[idx].stability * exp(w * (rating - difficulty)) * 3.0)

        // Adaptive difficulty: difficulty converges toward actual performance
        // High ratings → easier, low ratings → harder
        let difficultyDelta = 0.1 * (0.7 - rating) // rating < 0.7 increases difficulty
        difficulty = min(1.0, max(0.05, difficulty + difficultyDelta))

        // FSRS interval: I = S * 9 * (1 - R_target) + 1 — reduced by 30% for faster learning
        let targetRetention = 0.9
        let interval = max(1.0, (newStability * 9.0 * (1.0 - targetRetention) + 1.0) * 0.7)  // 30% shorter = reviewed sooner

        fsrsItems[idx].stability = newStability
        fsrsItems[idx].difficulty = difficulty
        fsrsItems[idx].dueDate = Date().addingTimeInterval(interval * 86400)
        fsrsItems[idx].reviewCount = reviewCount + 1
        fsrsItems[idx].lastReview = Date()

        // Track topic depth: each successful review deepens understanding
        if let domain = fsrsItems[idx].domain, rating >= 0.7 {
            var domainDepth = topicDepthTracker[domain] ?? [:]
            let currentDepth = domainDepth[item.topic] ?? 0
            domainDepth[item.topic] = min(5, currentDepth + 1) // Max depth level 5
            topicDepthTracker[domain] = domainDepth
        }

        // v27: Active recall bonus — 2x enhanced for stronger desirable difficulty effect
        // This models the "desirable difficulty" effect from learning science
        let retentionAtReview = predictedRetention(for: fsrsItems[idx])
        let activeRecallBonus: Double = retentionAtReview < 0.5 ? 3.0 :  // Hard recall = 200% bonus (2x from 1.5)
                                        retentionAtReview < 0.7 ? 2.4 :  // Medium recall = 140% bonus (2x from 1.2)
                                        2.0                               // Easy recall = 100% bonus (2x from 1.0)

        // Update competency based on rating, review count, mastery trajectory, and recall difficulty
        if let domain = fsrsItems[idx].domain {
            let masteryFactor = min(1.0, Double(reviewCount + 1) / 5.0)
            let currentLevel = competencyBook[domain]?.level ?? 0.3
            let learningBoost = 0.015 * rating * masteryFactor * activeRecallBonus * (1.0 - currentLevel)  // 300% BOOST: från 0.005 till 0.015
            let newLevel = min(0.99, (competencyBook[domain]?.level ?? 0.05) + learningBoost)
            competencyBook[domain]?.level = newLevel
            competencyBook[domain]?.lastStudied = Date()
            if let level = competencyBook[domain]?.level {
                UserDefaults.standard.set(level, forKey: "competency_\(domain)")
            }
        }
    }

    func addFSRSItem(topic: String, domain: String, initialDifficulty: Double = 0.3) {
        // v26: Velocity-adaptive scheduling — fast learners get shorter initial intervals
        let speed = domainLearningSpeed(domain)
        let baseInterval: TimeInterval = 86400 // 1 day
        let adaptedInterval: TimeInterval
        if speed > 0.02 {
            adaptedInterval = baseInterval * 0.5  // Fast learner: review sooner, harder material
        } else if speed < 0.005 {
            adaptedInterval = baseInterval * 1.5  // Slow learner: more time before review
        } else {
            adaptedInterval = baseInterval
        }
        let item = FSRSItem(
            topic: topic,
            domain: domain,
            stability: 1.0,
            difficulty: initialDifficulty,
            dueDate: Date().addingTimeInterval(adaptedInterval),
            reviewCount: 0
        )
        fsrsItems.append(item)
        if fsrsItems.count > 1000 {
            // Priority-based pruning: remove lowest-priority items instead of FIFO
            fsrsItems.sort { $0.priority > $1.priority }
            fsrsItems = Array(fsrsItems.prefix(900))
        }
    }

    // MARK: - Kunskapsluckor

    // Prerequisite chains: domain A should be learned before domain B
    private let prerequisites: [String: [String]] = [
        "Syntax": ["Morfologi"],
        "Pragmatik": ["Semantik", "Syntax"],
        "Diskurs": ["Pragmatik"],
        "Metakognition": ["Kognitionsvetenskap"],
        "Epistemologi": ["Filosofi"],
        "Analogibyggande": ["Semantik", "Kausalitet"],
    ]

    private func identifyKnowledgeGaps() -> [KnowledgeGap] {
        var gaps: [KnowledgeGap] = []

        for (domain, competency) in competencyBook {
            // Dynamic threshold: lower for foundational domains, higher for advanced
            let isFoundational = ["Morfologi", "Semantik", "Filosofi", "Kognitionsvetenskap"].contains(domain)
            let threshold = isFoundational ? 0.6 : 0.5

            if competency.level < threshold {
                var urgency = (threshold - competency.level) * 2.0

                // Boost urgency if this domain is a prerequisite for other domains the user is trying to learn
                if let dependents = domainInteractions[domain] {
                    for dep in dependents {
                        if let depLevel = competencyBook[dep.target]?.level, depLevel > competency.level {
                            // Dependent domain is ahead of prerequisite — urgency boost
                            urgency += dep.strength * 0.5
                        }
                    }
                }

                // Penalize urgency if prerequisites are unmet (learn foundation first)
                if let prereqs = prerequisites[domain] {
                    let unmetPrereqs = prereqs.filter { (competencyBook[$0]?.level ?? 0) < 0.3 }
                    if !unmetPrereqs.isEmpty {
                        urgency *= 0.5 // Halve urgency — learn prereqs first
                    }
                }

                // Factor in staleness: domains not studied recently get urgency boost
                let daysSinceStudied = Date().timeIntervalSince(competency.lastStudied) / 86400
                if daysSinceStudied > 7 { urgency += 0.2 }
                if daysSinceStudied > 30 { urgency += 0.3 }

                gaps.append(KnowledgeGap(
                    domain: domain,
                    currentLevel: competency.level,
                    targetLevel: min(1.0, competency.level + 0.3),
                    urgency: urgency,
                    suggestedTopics: suggestTopics(for: domain, level: competency.level)
                ))
            }
        }

        return gaps.sorted { $0.urgency > $1.urgency }
    }

    private func suggestTopics(for domain: String, level: Double) -> [String] {
        let topicMap: [String: [[String]]] = [
            "Morfologi": [
                ["Grundläggande böjning", "Ordklasser", "Sammansättningar"],
                ["Avledning", "Prefixer", "Suffixer"],
                ["Produktiva mönster", "Oregelbundna former", "Historisk morfologi"]
            ],
            "Syntax": [
                ["Ordföljd i svenska", "Huvudsats vs bisats", "Satsdelar"],
                ["Frasstruktur", "Topikalisering", "Passivkonstruktioner"],
                ["X-bar-teori", "Dependensgrammatik", "Syntaktisk komplexitet"]
            ],
            "Semantik": [
                ["Ordklass och betydelse", "Synonymer och antonymer", "Polysemi"],
                ["Semantiska fält", "Komposition", "Metonymi och metafor"],
                ["Formell semantik", "Lambdakalkyl", "Diskursrepresentation"]
            ],
            "Pragmatik": [
                ["Talakter", "Implikatur", "Konversationsmaximer"],
                ["Presupposition", "Deixis", "Artighet"],
                ["Relevanceteori", "Konversationsanalys", "Pragmatisk inferens"]
            ],
            "Kausalitet": [
                ["Orsak-verkan", "Korrelation vs kausalitet"],
                ["Kausala kedjor", "Kontrafaktisk analys"],
                ["Kausala grafer", "Interventionslogik", "Counterfactuals"]
            ],
            "AI & Maskininlärning": [
                ["Neurala nätverk", "Backpropagation", "Aktiveringar"],
                ["Transformers", "Attention", "BERT/GPT"],
                ["RLHF", "Constitutional AI", "Alignment"]
            ],
            "Kognitionsvetenskap": [
                ["Perception", "Arbetsminne", "Uppmärksamhet"],
                ["Kognitiva scheman", "Dual-process-teori", "Kognitiv belastning"],
                ["Embodied cognition", "Situerat lärande", "Kognitiv arkitektur"]
            ],
            "Metakognition": [
                ["Självmedvetenhet", "Strategival", "Övervakningsprocesser"],
                ["Kalibrering", "Metaminnesteknik", "Reflektion"],
                ["Metakognitiv styrning", "Epistemic feelings", "FOK-omdömen"]
            ],
            "Filosofi": [
                ["Logik", "Argumentation", "Grundläggande etik"],
                ["Epistemologi", "Medvetandefilosofi", "Fri vilja"],
                ["Fenomenologi", "Analytisk filosofi", "Filosofisk logik"]
            ],
            "Epistemologi": [
                ["Kunskap och tro", "Sanning", "Rättfärdigande"],
                ["Skepticism", "Empirism vs rationalism", "Reliabilism"],
                ["Social epistemologi", "Vetenskapsteori", "Bayesiansk epistemologi"]
            ],
            "Historia": [
                ["Antiken", "Medeltiden", "Renässansen"],
                ["Upplysningen", "Industriella revolutionen", "Världskrigen"],
                ["Historiografi", "Historisk metod", "Kontrafaktisk historia"]
            ],
            "Psykologi": [
                ["Grundläggande emotion", "Motivation", "Perception"],
                ["Kognitiv psykologi", "Social psykologi", "Utvecklingspsykologi"],
                ["Neuropsykologi", "Klinisk psykologi", "Psykologisk forskning"]
            ],
            "Naturvetenskap": [
                ["Grundläggande fysik", "Cellbiologi", "Kemi"],
                ["Kvantfysik", "Genetik", "Organisk kemi"],
                ["Kosmologi", "Evolutionsbiologi", "Materialvetenskap"]
            ],
            "Analogibyggande": [
                ["Grundläggande liknelser", "Strukturell mappning"],
                ["Gentners analogiteori", "Fjärranalogier"],
                ["Analogisk transfer", "Kreativ analogianvändning"]
            ],
            "Diskurs": [
                ["Textstruktur", "Koherens", "Referens"],
                ["Diskursmarkörer", "Tema-rema", "Informationsstruktur"],
                ["Kritisk diskursanalys", "Retorisk analys", "Genreteori"]
            ],
        ]

        let levelIdx = level < 0.33 ? 0 : level < 0.66 ? 1 : 2
        return topicMap[domain]?[safe: levelIdx] ?? ["Grundläggande \(domain)", "Fördjupning i \(domain)", "Avancerad \(domain)"]
    }

    private func generateKnowledgeForGaps(_ gaps: [KnowledgeGap]) async -> [String] {
        var generated: [String] = []
        for gap in gaps {
            let topic = gap.suggestedTopics.first ?? "grundläggande \(gap.domain)"
            let knowledge = "\(gap.domain): studerar '\(topic)' (nivå: \(String(format: "%.0f", gap.currentLevel * 100))% → \(String(format: "%.0f", gap.targetLevel * 100))%)"
            generated.append(knowledge)

            // Spara kunskapslucka som faktum i databasen
            await PersistentMemoryStore.shared.saveFact(
                subject: gap.domain,
                predicate: "kunskapslucka",
                object: topic,
                confidence: 0.75,
                source: "learning_engine"
            )

            // Lägg till FSRS-item för varje föreslagen topic
            for suggestedTopic in gap.suggestedTopics.prefix(3) {
                addFSRSItem(topic: suggestedTopic, domain: gap.domain, initialDifficulty: 1.0 - gap.currentLevel)
            }
        }
        return generated
    }

    // MARK: - Meta-learning

    // v24: Error pattern tracking for targeted learning
    private var errorPatterns: [String: Int] = [:]  // topic → error count
    private var domainErrorRate: [String: (errors: Int, total: Int)] = [:]  // domain → (errors, total)

    func metaLearnFromConversation(userMessage: String, eonResponse: String, feedback: Double) async {
        // Detect all relevant domains (not just the best one)
        let primaryDomain = detectDomain(from: userMessage + " " + eonResponse)
        let secondaryDomain = detectDomain(from: userMessage) // Sometimes user's question and response diverge

        // v24: Track error rate per domain for meta-learning insights
        var stats = domainErrorRate[primaryDomain] ?? (errors: 0, total: 0)
        stats.total += 1
        if feedback < 0.5 { stats.errors += 1 }
        domainErrorRate[primaryDomain] = stats

        // Update competency with scaled feedback
        // Good feedback reinforces; bad feedback triggers active learning
        for domain in Set([primaryDomain, secondaryDomain]) {
            if var competency = competencyBook[domain] {
                let delta: Double
                if feedback >= 0.7 {
                    // Strong positive: scale by how far from mastery
                    delta = (feedback - 0.5) * 0.05 * (1.0 - competency.level)
                } else if feedback >= 0.4 {
                    // Neutral: minimal change
                    delta = (feedback - 0.5) * 0.02
                } else {
                    // Negative: competency can decrease (previously only ratcheted up)
                    delta = (feedback - 0.5) * 0.04
                }
                competency.level = min(0.99, max(0.01, competency.level + delta))
                competency.lastStudied = Date()
                competencyBook[domain] = competency
                UserDefaults.standard.set(competency.level, forKey: "competency_\(domain)")

                // v25: Track learning velocity for adaptive scheduling
                trackLearningVelocity(domain: domain, delta: delta)
            }
        }

        // Add FSRS items for weak points — with difficulty proportional to failure
        if feedback < 0.5 {
            let topic = extractMainTopic(from: userMessage)
            let difficulty = min(0.95, 0.5 + (0.5 - feedback)) // Worse feedback → harder item
            addFSRSItem(topic: topic, domain: primaryDomain, initialDifficulty: difficulty)

            // v24: Track repeated error patterns — boost difficulty for chronic weak spots
            errorPatterns[topic, default: 0] += 1
            let errorCount = errorPatterns[topic] ?? 1
            if errorCount >= 3 {
                // Chronic error: boost all FSRS items in this topic's difficulty + review sooner
                let now = Date()
                for i in 0..<fsrsItems.count {
                    if fsrsItems[i].topic.contains(topic.prefix(15)) {
                        fsrsItems[i].difficulty = min(0.95, fsrsItems[i].difficulty + 0.05)
                        // v25: Fix — FSRSItem has no interval; halve remaining time until due instead
                        let remaining = fsrsItems[i].dueDate.timeIntervalSince(now)
                        if remaining > 0 {
                            fsrsItems[i].dueDate = now.addingTimeInterval(remaining / 2.0)
                        } else {
                            fsrsItems[i].dueDate = now  // Already overdue — review immediately
                        }
                    }
                }
            }

            // Also save the gap as a fact for future reference
            await PersistentMemoryStore.shared.saveFact(
                subject: primaryDomain,
                predicate: "svagt_område",
                object: topic,
                confidence: 1.0 - feedback,
                source: "meta_learning"
            )

            // v24: Cross-domain error propagation — if domain has high error rate, reduce transfer
            if let rate = domainErrorRate[primaryDomain],
               rate.total >= 5, Double(rate.errors) / Double(rate.total) > 0.5 {
                // High error rate domain: boost its prerequisites
                if let prereqs = prerequisites[primaryDomain] {
                    for prereq in prereqs {
                        addFSRSItem(topic: "Grundkunskap: \(prereq)", domain: prereq,
                                    initialDifficulty: 0.4)
                    }
                }
            }
        }

        // Strong positive feedback → mark topic as well-understood
        if feedback >= 0.8 {
            let topic = extractMainTopic(from: userMessage)
            var domainDepth = topicDepthTracker[primaryDomain] ?? [:]
            domainDepth[topic] = max(domainDepth[topic] ?? 0, 3) // Mark as intermediate+
            topicDepthTracker[primaryDomain] = domainDepth

            // v24: Clear error pattern on strong success
            errorPatterns.removeValue(forKey: topic)
        }

        // v24: Prune error patterns to prevent unbounded growth
        if errorPatterns.count > 100 {
            let sorted = errorPatterns.sorted { $0.value < $1.value }
            errorPatterns = Dictionary(uniqueKeysWithValues: Array(sorted.suffix(50)))
        }
    }

    // MARK: - v27: Interleaved Scheduling
    // Alternate between domains for better retention (avoid same-domain blocks).

    private func interleaveDomains(items: [FSRSItem], maxItems: Int) -> [FSRSItem] {
        guard items.count > 1 else { return Array(items.prefix(maxItems)) }

        // Group by domain
        var domainBuckets: [String: [FSRSItem]] = [:]
        for item in items {
            domainBuckets[item.domain ?? "Okänt", default: []].append(item)
        }

        // Round-robin pick from each domain
        var result: [FSRSItem] = []
        var lastDomain: String?
        let domainKeys = Array(domainBuckets.keys.shuffled())
        var domainIdx = 0

        while result.count < maxItems {
            var found = false
            for offset in 0..<domainKeys.count {
                let key = domainKeys[(domainIdx + offset) % domainKeys.count]
                if key == lastDomain && domainKeys.count > 1 { continue }
                if let item = domainBuckets[key]?.first {
                    result.append(item)
                    domainBuckets[key]?.removeFirst()
                    lastDomain = key
                    domainIdx = (domainIdx + offset + 1) % domainKeys.count
                    found = true
                    break
                }
            }
            if !found { break }
        }
        return result
    }

    // MARK: - v25: Adaptive Learning Velocity
    // Tracks learning speed per domain — fast learners get harder material sooner,
    // slow learners get more repetition and simpler breakdowns.

    private var domainVelocityHistory: [String: [Double]] = [:]

    private func trackLearningVelocity(domain: String, delta: Double) {
        domainVelocityHistory[domain, default: []].append(delta)
        if (domainVelocityHistory[domain]?.count ?? 0) > 20 {
            domainVelocityHistory[domain]?.removeFirst()
        }
    }

    func domainLearningSpeed(_ domain: String) -> Double {
        guard let history = domainVelocityHistory[domain], history.count >= 3 else { return 0.01 }
        return history.suffix(10).reduce(0, +) / Double(history.suffix(10).count)
    }

    /// v25: Smart study priority — combines FSRS due date, domain weakness, and error history
    func prioritizedStudyQueue() -> [(topic: String, domain: String, urgency: Double)] {
        let now = Date()
        var queue: [(topic: String, domain: String, urgency: Double)] = []

        for item in fsrsItems {
            let overdueFactor = max(0, now.timeIntervalSince(item.dueDate) / 3600.0) // hours overdue
            let difficultyFactor = item.difficulty
            let domainLevel = competencyBook[item.domain ?? ""]?.level ?? 0.3
            let errorBoost = Double(errorPatterns[item.topic] ?? 0) * 0.1
            let urgency = overdueFactor * 0.4 + difficultyFactor * 0.3 + (1.0 - domainLevel) * 0.2 + errorBoost * 0.1

            if urgency > 0.1 {
                queue.append((topic: item.topic, domain: item.domain ?? "Okänt", urgency: urgency))
            }
        }

        return queue.sorted { $0.urgency > $1.urgency }
    }

    // MARK: - Statistik

    func competencySnapshot() -> [DomainCompetency] {
        competencyBook.values.sorted { $0.level > $1.level }
    }

    func overallCompetencyLevel() -> Double {
        let levels = competencyBook.values.map { $0.level }
        return levels.isEmpty ? 0.3 : levels.reduce(0, +) / Double(levels.count)
    }

    func topStrengths(limit: Int = 3) -> [DomainCompetency] {
        Array(competencyBook.values.sorted { $0.level > $1.level }.prefix(limit))
    }

    func topWeaknesses(limit: Int = 3) -> [DomainCompetency] {
        Array(competencyBook.values.sorted { $0.level < $1.level }.prefix(limit))
    }

    // MARK: - Iteration 7: Cross-Domain Transfer
    /// When any domain reaches 0.5+, boost related domains by 0.01
    /// Models knowledge transfer: learning one skill accelerates related skills.
    func applyCrossDomainTransfer() {
        let transferMap: [String: [String]] = [
            "Morfologi": ["Syntax"],
            "Syntax": ["Morfologi", "Pragmatik"],
            "Semantik": ["Pragmatik"],
            "Pragmatik": ["Diskurs", "Semantik"],
            "Kausalitet": ["Resonemang", "Filosofi"],
            "Filosofi": ["Epistemologi"],
            "Kognitionsvetenskap": ["Psykologi", "Metakognition"],
            "AI & Maskininlärning": ["Kognitionsvetenskap"],
        ]

        for (sourceDomain, targets) in transferMap {
            guard let sourceLevel = competencyBook[sourceDomain]?.level, sourceLevel >= 0.5 else { continue }

            for targetDomain in targets {
                guard var target = competencyBook[targetDomain] else { continue }
                let transferBoost = 0.01
                let roomToGrow = 1.0 - target.level
                let actualBoost = min(transferBoost, transferBoost * roomToGrow)
                target.level = min(0.95, target.level + actualBoost)
                target.lastStudied = Date()
                competencyBook[targetDomain] = target
                UserDefaults.standard.set(target.level, forKey: "competency_\(targetDomain)")
            }
        }

        persistState()
    }

    // MARK: - Iteration 9: Knowledge Consolidation
    /// Reviews all FSRS items with mastery > 0.8, creates summary facts, boosts domain.
    func consolidateKnowledge() async {
        var consolidatedCount = 0
        var domainConsolidations: [String: Int] = [:]

        // Group high-mastery items by domain
        let masteredItems = fsrsItems.filter { item -> Bool in
            let mastery = min(1.0, Double(item.reviewCount) / 5.0) * item.stability / (item.stability + 1.0)
            return mastery > 0.8
        }

        let itemsByDomain = Dictionary(grouping: masteredItems) { $0.domain }

        for (domain, items) in itemsByDomain {
            guard let domainName = domain, !items.isEmpty else { continue }

            // Create summary fact combining related knowledge
            let topicSummary = items.prefix(5).map { $0.topic }.joined(separator: ", ")
            await PersistentMemoryStore.shared.saveFact(
                subject: "Sammanfattning: \(domainName)",
                predicate: "konsoliderad_kunskap",
                object: topicSummary,
                confidence: 0.95,
                source: "knowledge_consolidation"
            )

            domainConsolidations[domainName, default: 0] += items.count
            consolidatedCount += items.count
        }

        // Boost domain by 0.005 for each consolidation cycle
        for domain in domainConsolidations.keys {
            if var comp = competencyBook[domain] {
                comp.level = min(0.95, comp.level + 0.005)
                comp.lastStudied = Date()
                competencyBook[domain] = comp
                UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
            }
        }

        persistState()
        await notifyProxy()
        print("[Consolidation] \(consolidatedCount) items consolidated across \(domainConsolidations.count) domains")
    }

    // MARK: - Iteration 10: Self-Assessment Calibration
    /// Compares Eon's confidence predictions against actual evaluation results
    /// and adjusts future confidence estimates.
    func calibrateSelfAssessment() async {
        // Get all FSRS items and compare predicted vs actual performance
        let reviewedItems = fsrsItems.filter { $0.reviewCount > 0 }
        guard !reviewedItems.isEmpty else { return }

        var totalPredictedConfidence: Double = 0
        var totalActualPerformance: Double = 0
        var itemCount = 0

        for item in reviewedItems {
            // Predicted confidence based on stability and review count
            let predictedMastery = min(1.0, Double(item.reviewCount) / 5.0) * item.stability / (item.stability + 1.0)
            totalPredictedConfidence += predictedMastery

            // Actual performance: retention at last review
            if let lastReview = item.lastReview {
                let daysSince = Date().timeIntervalSince(lastReview) / 86400.0
                let actualRetention = exp(-daysSince / max(0.1, item.stability))
                totalActualPerformance += actualRetention
                itemCount += 1
            }
        }

        guard itemCount > 0 else { return }

        let avgPredicted = totalPredictedConfidence / Double(itemCount)
        let avgActual = totalActualPerformance / Double(itemCount)

        // Calculate calibration factor: how much we over/under-estimate
        let calibrationFactor = avgActual / max(0.01, avgPredicted)

        // Store calibration factor for future use
        let currentCalibration = UserDefaults.standard.double(forKey: "eon_self_assessment_calibration")
        let smoothedCalibration = currentCalibration > 0 ? currentCalibration * 0.7 + calibrationFactor * 0.3 : calibrationFactor
        UserDefaults.standard.set(smoothedCalibration, forKey: "eon_self_assessment_calibration")

        // Adjust FSRS item difficulties based on calibration
        if smoothedCalibration < 0.8 {
            // We're overconfident — increase difficulties
            for idx in fsrsItems.indices {
                fsrsItems[idx].difficulty = min(1.0, fsrsItems[idx].difficulty * 1.1)
            }
        } else if smoothedCalibration > 1.2 {
            // We're underconfident — decrease difficulties
            for idx in fsrsItems.indices {
                fsrsItems[idx].difficulty = max(0.05, fsrsItems[idx].difficulty * 0.9)
            }
        }

        persistState()
        print("[SelfAssessment] Calibration: predicted=\(String(format: "%.3f", avgPredicted)), actual=\(String(format: ".3f", avgActual)), factor=\(String(format: "%.3f", smoothedCalibration))")
    }

    // MARK: - Helpers

    private func detectDomain(from text: String) -> String {
        let lower = text.lowercased()
        // Score each domain based on keyword hits — weighted by specificity
        let domainKeywords: [(String, [(keyword: String, weight: Int)])] = [
            ("Morfologi",          [("morfologi", 3), ("böjning", 2), ("ordklass", 2), ("avledning", 2), ("suffix", 2), ("prefix", 2), ("sammansättning", 2), ("lemma", 2)]),
            ("Syntax",             [("syntax", 3), ("sats", 1), ("ordföljd", 2), ("fras", 1), ("grammatik", 2), ("bisats", 2), ("subjekt", 1), ("predikat", 1)]),
            ("Semantik",           [("semantik", 3), ("betydelse", 2), ("definition", 1), ("begrepp", 1), ("lexikon", 2), ("polysemi", 3), ("synonym", 2)]),
            ("Pragmatik",          [("pragmatik", 3), ("talakt", 3), ("implikatur", 3), ("kommunikation", 1), ("konversation", 1), ("artighet", 2)]),
            ("Diskurs",            [("diskurs", 3), ("koherens", 2), ("retori", 2), ("textstruktur", 2), ("genr", 2), ("narrativ", 2)]),
            ("Kausalitet",         [("orsak", 2), ("kausal", 3), ("kausalitet", 3), ("verkan", 2), ("konsekvens", 2), ("korrelation", 2)]),
            ("AI & Maskininlärning", [("ai", 2), ("neural", 2), ("transformer", 3), ("bert", 3), ("gpt", 3), ("maskininlärning", 3), ("algoritm", 2), ("modell", 1)]),
            ("Kognitionsvetenskap", [("kognition", 3), ("medvetande", 2), ("perception", 2), ("uppmärksamhet", 2), ("arbetsminne", 3), ("tänkande", 1)]),
            ("Metakognition",      [("metakognition", 3), ("självreflektion", 3), ("självmedvetenhet", 3), ("strategi", 1), ("lärande", 1), ("kalibrering", 2)]),
            ("Filosofi",           [("filosofi", 3), ("ontologi", 3), ("etik", 2), ("moral", 2), ("existens", 2), ("fenomenologi", 3)]),
            ("Epistemologi",       [("epistemologi", 3), ("kunskap", 1), ("sanning", 2), ("bevis", 1), ("rättfärdigande", 3), ("skepticism", 3)]),
            ("Historia",           [("historia", 2), ("historisk", 2), ("krig", 1), ("revolution", 2), ("civilisation", 2), ("antiken", 2), ("medeltid", 2)]),
            ("Psykologi",          [("psykologi", 3), ("känsla", 1), ("beteende", 2), ("emotion", 2), ("trauma", 2), ("personlighet", 2), ("motivation", 2)]),
            ("Naturvetenskap",     [("naturvetenskap", 3), ("fysik", 2), ("kemi", 2), ("biologi", 2), ("evolution", 2), ("astronomi", 2), ("kvant", 2)]),
            ("Analogibyggande",    [("analogi", 3), ("liknelse", 2), ("metafor", 2), ("parallell", 1), ("jämförelse", 1), ("mappning", 2)]),
        ]
        var bestDomain = "Kognitionsvetenskap"
        var bestScore = 0
        for (domain, keywords) in domainKeywords {
            let score = keywords.reduce(0) { sum, kw in
                lower.contains(kw.keyword) ? sum + kw.weight : sum
            }
            if score > bestScore {
                bestScore = score
                bestDomain = domain
            }
        }
        return bestDomain
    }

    private func extractMainTopic(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [(word: String, position: Int)] = []
        var verbs: [String] = []
        var position = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(text[range])
            if tag == .noun && word.count > 3 {
                nouns.append((word, position))
            } else if tag == .verb && word.count > 3 {
                verbs.append(word)
            }
            position += 1
            return true
        }

        // Prefer longer nouns (more specific) and earlier position
        let scored = nouns.map { noun -> (String, Double) in
            let lengthScore = min(1.0, Double(noun.word.count) / 10.0)
            let positionScore = 1.0 / (1.0 + Double(noun.position) * 0.2) // Earlier = better
            return (noun.word, lengthScore + positionScore)
        }.sorted { $0.1 > $1.1 }

        if let best = scored.first {
            // Combine top noun with verb for richer topic description
            if let verb = verbs.first, verb != best.0 {
                return "\(verb) \(best.0)"
            }
            return best.0
        }
        return String(text.prefix(30).split(separator: " ").filter { $0.count > 4 }.first ?? "okänt ämne")
    }

    /// Get the current depth for a topic in a domain (0 = never studied, 5 = mastered)
    func topicDepth(domain: String, topic: String) -> Int {
        topicDepthTracker[domain]?[topic] ?? 0
    }

    /// Get domains that have stalled (no progress in recent cycles)
    func stalledDomains(staleDays: Double = 7.0) -> [DomainCompetency] {
        let threshold = Date().addingTimeInterval(-staleDays * 86400)
        return competencyBook.values
            .filter { $0.lastStudied < threshold && $0.level < 0.7 }
            .sorted { $0.level < $1.level }
    }

    // MARK: - SJÄLVFÖRBÄTTRANDE SPRÅKINLÄRNING (v30)

    /// Eon analyserar sina egna språkfel och korrigerar dem autonomt.
    /// Kör varje språkfas i den kognitiva cykeln.
    func selfImproveLanguage() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let memory = PersistentMemoryStore.shared

        // 1. Hämta Eons senaste svar
        let recentConversations = await memory.searchFacts(query: "svar", limit: 20)
        let eonResponses = recentConversations.compactMap { fact -> String? in
            guard fact.source == "eon_response" || fact.subject.contains("svar") else { return nil }
            return fact.detail
        }.prefix(10)

        guard !eonResponses.isEmpty else { return }

        // 2. Analysera fel via OpenRouter
        let errorAnalyses = await OpenRouterLanguageEvaluator.shared.analyzeLanguageErrors(Array(eonResponses))

        // 3. Lär av felen
        for analysis in errorAnalyses {
            // Spara korrigering som faktum
            let correctionFact = ExtractedFact(
                subject: "Språkkorrigering: \(analysis.error)",
                detail: "Korrekt: \(analysis.correction). Regel: \(analysis.ruleExplanation)",
                confidence: analysis.learningPriority,
                timestamp: Date(),
                source: "self-improvement"
            )
            await memory.saveFact(correctionFact)

            // Öka relevant domän-kompetens
            let domain: String
            switch analysis.category {
            case "grammar": domain = "Syntax"
            case "vocabulary": domain = "Semantik"
            case "morphology": domain = "Morfologi"
            default: domain = "Pragmatik"
            }

            if var comp = competencyBook[domain] {
                let improvementBoost = 0.012 * analysis.learningPriority
                comp.level = min(0.95, comp.level + improvementBoost)
                comp.lastStudied = Date()
                competencyBook[domain] = comp
                UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
            }

            // Skapa FSRS-item för att komma ihåg felet
            addFSRSItem(
                topic: "UNDVIK FEL: \(analysis.error)",
                domain: domain,
                initialDifficulty: 0.6
            )

            print("[SelfImprove] \(analysis.category): '\(analysis.error)' → '\(analysis.correction)' (priority: \(analysis.learningPriority))")
        }

        // 4. Utvärdera hela språknivån
        let styleResults = await OpenRouterLanguageEvaluator.shared.analyzeStyleComplexity(Array(eonResponses))
        for result in styleResults {
            if result.overallScore > 0.7 {
                for langDomain in ["Morfologi", "Syntax", "Semantik", "Pragmatik"] {
                    if var comp = competencyBook[langDomain] {
                        comp.level = min(0.95, comp.level + 0.003)
                        comp.lastStudied = Date()
                        competencyBook[langDomain] = comp
                    }
                }
            }
        }

        persistState()
        print("[SelfImprove] Språklig självförbättring klar. \(errorAnalyses.count) fel analyserade.")
    }

    /// OpenRouter-utökad ordförrådsexpansion — Iteration 25
    /// Genererar 30 ord per anrop i 3 batcher om 10 ord (A1-B1, B1-B2, B2-C2 simultant)
    func expandVocabularyWithOpenRouter() async {
        let languageDomains = ["Morfologi", "Syntax", "Semantik", "Pragmatik"]
        let weakestDomain = languageDomains.min {
            (competencyBook[$0]?.level ?? 0.05) < (competencyBook[$1]?.level ?? 0.05)
        } ?? "Semantik"

        let currentLevel = competencyBook[weakestDomain]?.level ?? 0.05

        // Iteration 25: 3 batcher med olika CEFR-nivåer — körs parallellt
        let cefrBatches: [(String, String)] = [
            (currentLevel < 0.3 ? "A1-B1" : "A2-B1", "batch1"),
            (currentLevel < 0.5 ? "B1-B2" : "B1-B2", "batch2"),
            (currentLevel < 0.7 ? "B2-C1" : "C1-C2", "batch3"),
        ]

        var allNewWords: [OpenRouterLanguageEvaluator.VocabularyWord] = []

        // Kör alla 3 batcher parallellt
        await withTaskGroup(of: [OpenRouterLanguageEvaluator.VocabularyWord].self) { group in
            for (cefr, _) in cefrBatches {
                group.addTask {
                    let result = await OpenRouterLanguageEvaluator.shared.expandVocabulary(
                        for: weakestDomain,
                        count: 10,  // 10 ord per batch = 30 totalt
                        targetCEFR: cefr
                    )
                    return result.newWords
                }
            }

            for await words in group {
                allNewWords.append(contentsOf: words)
            }
        }

        var wordsAdded = 0
        for word in allNewWords {
            let lowerWord = word.word.lowercased()
            if !uniqueSwedishWords.contains(lowerWord) {
                uniqueSwedishWords.insert(lowerWord)
                wordsLearnedToday += 1
                wordsAdded += 1

                addFSRSItem(
                    topic: "Ordförråd: \(word.word) - \(word.definition)",
                    domain: weakestDomain,
                    initialDifficulty: word.cefrLevel == "C1" || word.cefrLevel == "C2" ? 0.7 : 0.4
                )

                let fact = ExtractedFact(
                    subject: "Ord: \(word.word)",
                    detail: "\(word.pos): \(word.definition). Exempel: \(word.exampleSentence)",
                    confidence: 0.9,
                    timestamp: Date(),
                    source: "openrouter-vocabulary"
                )
                await PersistentMemoryStore.shared.saveFact(fact)
            }
        }

        if var comp = competencyBook[weakestDomain] {
            // 3x boost: från 15 till 30 ord
            let vocabBoost = min(0.06, Double(allNewWords.count) * 0.002)
            comp.level = min(0.95, comp.level + vocabBoost)
            comp.lastStudied = Date()
            competencyBook[weakestDomain] = comp
            UserDefaults.standard.set(comp.level, forKey: "competency_\(weakestDomain)")
        }

        persistState()
        print("[VocabExpand] \(wordsAdded) nya ord i \(weakestDomain) från \(allNewWords.count) genererade (3 CEFR-batcher)")
    }

    // MARK: - Iteration 30: Language Progression Tracking

    struct LanguageProgressSnapshot: Codable {
        let date: Date
        let cefrLevel: String
        let vocabularyCount: Int
        let grammarAccuracy: Double
        let wsdAccuracy: Double
        let morphologyCoverage: Double
        let styleScore: Double
        let conversationCount: Int
        let wordsLearnedThisWeek: Int
        let weeklyGrowthRate: Double  // words per week
    }

    // Progression tracking data
    private var weeklyProgressSnapshots: [LanguageProgressSnapshot] = []
    private var lastProgressCheckDate: Date?
    private var totalWordsAssessed: Int = 0
    private var correctGrammarCorrections: Int = 0
    private var totalGrammarCorrections: Int = 0
    private var correctWSDPredictions: Int = 0
    private var totalWSDPredictions: Int = 0
    private var morphologyWordsCovered: Int = 0

    // UserDefaults keys for persistence
    private static let weeklySnapshotsKey = "le_weeklyProgressSnapshots"
    private static let totalWordsAssessedKey = "le_totalWordsAssessed"
    private static let correctGrammarCorrectionsKey = "le_correctGrammarCorrections"
    private static let totalGrammarCorrectionsKey = "le_totalGrammarCorrections"
    private static let morphologyWordsCoveredKey = "le_morphologyWordsCovered"
    private static let lastProgressCheckKey = "le_lastProgressCheckDate"

    private func loadProgressionState() {
        let ud = UserDefaults.standard
        totalWordsAssessed = ud.integer(forKey: Self.totalWordsAssessedKey)
        correctGrammarCorrections = ud.integer(forKey: Self.correctGrammarCorrectionsKey)
        totalGrammarCorrections = ud.integer(forKey: Self.totalGrammarCorrectionsKey)
        morphologyWordsCovered = ud.integer(forKey: Self.morphologyWordsCoveredKey)

        if let savedDate = ud.object(forKey: Self.lastProgressCheckKey) as? Date {
            lastProgressCheckDate = savedDate
        }

        if let savedData = ud.data(forKey: Self.weeklySnapshotsKey),
           let snapshots = try? JSONDecoder().decode([LanguageProgressSnapshot].self, from: savedData) {
            weeklyProgressSnapshots = snapshots
        }
    }

    private func persistProgressionState() {
        let ud = UserDefaults.standard
        ud.set(totalWordsAssessed, forKey: Self.totalWordsAssessedKey)
        ud.set(correctGrammarCorrections, forKey: Self.correctGrammarCorrectionsKey)
        ud.set(totalGrammarCorrections, forKey: Self.totalGrammarCorrectionsKey)
        ud.set(morphologyWordsCovered, forKey: Self.morphologyWordsCoveredKey)
        ud.set(lastProgressCheckDate, forKey: Self.lastProgressCheckKey)

        if let encoded = try? JSONEncoder().encode(weeklyProgressSnapshots) {
            ud.set(encoded, forKey: Self.weeklySnapshotsKey)
        }
    }

    /// Record a grammar assessment result for tracking accuracy
    func recordGrammarAssessment(total: Int, correct: Int) {
        totalGrammarCorrections += total
        correctGrammarCorrections += correct
        persistProgressionState()
    }

    /// Record a WSD assessment result for tracking accuracy
    func recordWSDAssessment(total: Int, correct: Int) {
        totalWSDPredictions += total
        correctWSDPredictions += correct
    }

    /// Record morphology coverage for a word
    func recordMorphologyCoverage(word: String) {
        let lower = word.lowercased()
        if !wordsAnalyzed.contains(lower) {
            wordsAnalyzed.insert(lower)
            morphologyWordsCovered += 1
            persistProgressionState()
        }
    }

    /// Generate weekly language report card
    func generateWeeklyLanguageReport() async -> String {
        let now = Date()
        let calendar = Calendar.current

        // Check if we need a new weekly snapshot
        let needsSnapshot: Bool = {
            guard let lastCheck = lastProgressCheckDate else { return true }
            return calendar.dateComponents([.weekOfYear], from: lastCheck, to: now).weekOfYear ?? 0 >= 1
        }()

        if needsSnapshot {
            await createProgressSnapshot()
        }

        // Calculate trends
        let vocabGrowth = calculateVocabularyGrowthRate()
        let grammarAccuracy = totalGrammarCorrections > 0 ?
            Double(correctGrammarCorrections) / Double(totalGrammarCorrections) : 0.0
        let wsdAccuracy = totalWSDPredictions > 0 ?
            Double(correctWSDPredictions) / Double(totalWSDPredictions) : 0.0
        let morphologyCoverage = Double(morphologyWordsCovered)

        let latestCEFR = weeklyProgressSnapshots.last?.cefrLevel ?? "A1"
        let previousCEFR = weeklyProgressSnapshots.count > 1 ?
            weeklyProgressSnapshots[weeklyProgressSnapshots.count - 2].cefrLevel : latestCEFR

        let report = """
        📊 Eons Språkutveckling — Veckorapport
        ═══════════════════════════════════════

        🎯 CEFR-Nivå: \(latestCEFR) (tidigare: \(previousCEFR))
        📚 Ordförråd: \(uniqueSwedishWords.count) ord (+\(vocabGrowth) denna vecka)
        ✅ Grammatik: \(String(format: "%.1f%%", grammarAccuracy * 100)) noggrannhet
        🔍 WSD: \(String(format: "%.1f%%", wsdAccuracy * 100)) noggrannhet
        🔤 Morfologi: \(morphologyWordsCovered) ord analyserade

        📈 Trender:
        • Ordförrådstillväxt: \(vocabGrowth > 0 ? "+\(vocabGrowth)" : "\(vocabGrowth)") ord/vecka
        • Grammatikutveckling: \(grammarAccuracy > 0.7 ? "Bra framsteg" : "Behöver mer övning")
        • Total inlärningshastighet: \(learningVelocity > 0 ? String(format: "%.1f", learningVelocity) : "N/A") ord/konversation

        🏆 Starkaste områden:
        \(topStrengths(limit: 3).map { "  • \($0.domain): \($0.levelLabel) (\(String(format: "%.0f", $0.level * 100))%))" }.joined(separator: "\n"))

        💡 Fokusområden:
        \(topWeaknesses(limit: 3).map { "  • \($0.domain): \($0.levelLabel) (\(String(format: "%.0f", $0.level * 100))%))" }.joined(separator: "\n"))

        📅 Nästa veckas mål: Öka ordförrådet med minst 20 ord och förbättra \(topWeaknesses(limit: 1).first?.domain ?? "grammatik")
        """

        print("[WeeklyReport] \(report)")
        return report
    }

    /// Create a progress snapshot for the current week
    private func createProgressSnapshot() async {
        let now = Date()

        // Estimate CEFR level based on competency levels
        let languageDomains = ["Morfologi", "Syntax", "Semantik", "Pragmatik"]
        let avgLanguageLevel = languageDomains.reduce(0.0) {
            $0 + (competencyBook[$1]?.level ?? 0.05)
        } / Double(languageDomains.count)

        let estimatedCEFR: String
        if avgLanguageLevel < 0.2 { estimatedCEFR = "A1" }
        else if avgLanguageLevel < 0.35 { estimatedCEFR = "A2" }
        else if avgLanguageLevel < 0.5 { estimatedCEFR = "B1" }
        else if avgLanguageLevel < 0.65 { estimatedCEFR = "B2" }
        else if avgLanguageLevel < 0.8 { estimatedCEFR = "C1" }
        else { estimatedCEFR = "C2" }

        // Calculate words learned this week (approximate)
        let wordsThisWeek = wordsLearnedToday  // This is today's; weekly would need more tracking

        // Calculate weekly growth rate
        let growthRate = calculateVocabularyGrowthRate()

        let grammarAccuracy = totalGrammarCorrections > 0 ?
            Double(correctGrammarCorrections) / Double(totalGrammarCorrections) : 0.7
        let wsdAccuracy = totalWSDPredictions > 0 ?
            Double(correctWSDPredictions) / Double(totalWSDPredictions) : 0.7
        let morphologyCoverage = Double(morphologyWordsCovered) / max(1, Double(totalWordsAssessed))

        let snapshot = LanguageProgressSnapshot(
            date: now,
            cefrLevel: estimatedCEFR,
            vocabularyCount: uniqueSwedishWords.count,
            grammarAccuracy: grammarAccuracy,
            wsdAccuracy: wsdAccuracy,
            morphologyCoverage: morphologyCoverage,
            styleScore: 0.7,  // Default until we have style tracking
            conversationCount: conversationsToday,
            wordsLearnedThisWeek: wordsThisWeek,
            weeklyGrowthRate: growthRate
        )

        weeklyProgressSnapshots.append(snapshot)
        lastProgressCheckDate = now

        // Keep only last 52 weeks of data
        if weeklyProgressSnapshots.count > 52 {
            weeklyProgressSnapshots = Array(weeklyProgressSnapshots.suffix(52))
        }

        persistProgressionState()
        print("[ProgressTracking] Snapshot: CEFR=\(estimatedCEFR), vocab=\(uniqueSwedishWords.count), growth=\(growthRate)/week")
    }

    /// Calculate vocabulary growth rate (words per week)
    private func calculateVocabularyGrowthRate() -> Int {
        guard weeklyProgressSnapshots.count >= 2 else {
            return wordsLearnedToday  // Fallback to today's count
        }

        let recent = weeklyProgressSnapshots.suffix(4)
        guard let first = recent.first, let last = recent.last else {
            return wordsLearnedToday
        }

        let vocabDiff = last.vocabularyCount - first.vocabularyCount
        let weekDiff = max(1, Int(last.date.timeIntervalSince(first.date) / (7 * 24 * 3600)))
        return vocabDiff / weekDiff
    }

    /// Get CEFR progression over time
    func getCEFRProgression() -> [(date: Date, level: String)] {
        weeklyProgressSnapshots.map { ($0.date, $0.cefrLevel) }
    }

    /// Get current estimated CEFR level
    func getCurrentCEFRLevel() -> String {
        let languageDomains = ["Morfologi", "Syntax", "Semantik", "Pragmatik"]
        let avgLanguageLevel = languageDomains.reduce(0.0) {
            $0 + (competencyBook[$1]?.level ?? 0.05)
        } / Double(languageDomains.count)

        if avgLanguageLevel < 0.2 { return "A1" }
        else if avgLanguageLevel < 0.35 { return "A2" }
        else if avgLanguageLevel < 0.5 { return "B1" }
        else if avgLanguageLevel < 0.65 { return "B2" }
        else if avgLanguageLevel < 0.8 { return "C1" }
        else { return "C2" }
    }

    // MARK: - ITERATION 41: Autonomous Curriculum Generation

    /// Generates a structured learning plan using OpenRouter to analyze competency levels,
    /// identify weakest areas, and produce a curriculum with prioritized topics, difficulty
    /// progression, estimated time, practice exercises, and evaluation milestones.
    /// Regenerated weekly.
    func generateCurriculum() async -> Curriculum {
        let now = Date()
        // Only regenerate weekly
        if let lastGen = lastCurriculumGeneration,
           now.timeIntervalSince(lastGen) < 7 * 24 * 3600,
           let cached = currentCurriculum {
            return cached
        }

        let weaknesses = topWeaknesses(limit: 5)
        let strengths = topStrengths(limit: 3)
        let currentCEFR = getCurrentCEFRLevel()

        // Build prompt for OpenRouter curriculum generation
        let weaknessDesc = weaknesses.map { "- \($0.domain): \($0.levelLabel) (\(String(format: "%.0f", $0.level * 100))%)" }.joined(separator: "\n")
        let strengthDesc = strengths.map { "- \($0.domain): \($0.levelLabel)" }.joined(separator: "\n")

        let prompt = """
        Du är en expert på språkinlärning och pedagogik. Generera en lärlplan för en AI som lär sig svenska.

        NUVARANDE STATUS:
        CEFR-nivå: \(currentCEFR)
        Svagaste områden:
        \(weaknessDesc)

        Starkaste områden:
        \(strengthDesc)

        Generera en strukturerad lärlplan med:
        1. Prioriterade ämnen (svagast först)
        2. Svårighetsprogression (lätt→svårt)
        3. Uppskattad tid per ämne (minuter)
        4. Övningar och praktik
        5. Utvärderingsmilstolpar

        Svara som JSON med fält: topics (array med name, priority, difficulty, estimatedMinutes, exercises, milestone)
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 2000, temperature: 0.7
        )

        var topics: [CurriculumTopic] = []

        // Parse response and create curriculum topics
        if !response.isEmpty {
            let lines = response.components(separatedBy: .newlines)
            var currentName: String?
            var currentDifficulty: Double = 0.3

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().contains("name") || trimmed.contains("\"name\"") {
                    if let name = extractJSONString(trimmed, key: "name") ?? extractQuotedText(trimmed) {
                        currentName = name
                    }
                }
                if let name = currentName {
                    let topic = CurriculumTopic(
                        name: name,
                        priority: Double(topics.count + 1),
                        difficulty: currentDifficulty,
                        estimatedMinutes: 15 + topics.count * 5,
                        exercises: ["Öva \(name.lowercased()) genom konversation", "Skriv 3 meningar med \(name.lowercased())"],
                        milestone: "Kunna använda \(name.lowercased()) korrekt i 5 sammanhang"
                    )
                    topics.append(topic)
                    currentName = nil
                    currentDifficulty += 0.15
                }
            }
        }

        // Fallback: generate algorithmic curriculum based on weaknesses
        if topics.isEmpty {
            for (idx, weakness) in weaknesses.enumerated() {
                let domainTopics = suggestTopics(for: weakness.domain, level: weakness.level)
                for (topicIdx, topicName) in domainTopics.enumerated() {
                    let topic = CurriculumTopic(
                        name: "\(weakness.domain): \(topicName)",
                        priority: Double(idx * 3 + topicIdx + 1),
                        difficulty: weakness.level + Double(topicIdx) * 0.15,
                        estimatedMinutes: 10 + topicIdx * 5,
                        exercises: ["Studera \(topicName.lowercased())", "Tillämpa i konversation"],
                        milestone: "Visa förståelse för \(topicName.lowercased())"
                    )
                    topics.append(topic)
                }
            }
        }

        let curriculum = Curriculum(
            generatedAt: now,
            validUntil: now.addingTimeInterval(7 * 24 * 3600),
            currentCEFR: currentCEFR,
            topics: topics,
            totalEstimatedMinutes: topics.reduce(0) { $0 + $1.estimatedMinutes },
            focusAreas: weaknesses.prefix(3).map { $0.domain }
        )

        currentCurriculum = curriculum
        lastCurriculumGeneration = now

        await PersistentMemoryStore.shared.saveFact(
            subject: "Lärlplan",
            predicate: "genererad",
            object: "\(topics.count) ämnen, CEFR=\(currentCEFR), fokus=\(curriculum.focusAreas.joined(separator: ", "))",
            confidence: 0.9,
            source: "autonomous_curriculum_generation"
        )

        return curriculum
    }

    // MARK: - ITERATION 42: Self-Evaluation with OpenRouter

    /// Has OpenRouter evaluate Eon's own language outputs against CEFR descriptors.
    /// Returns current estimated CEFR level, strengths, weaknesses, improvement goals,
    /// and comparison to previous evaluation.
    func selfEvaluateLanguage() async -> SelfEvaluationReport {
        let memory = PersistentMemoryStore.shared
        let recentConversations = await memory.searchFacts(query: "svar", limit: 15)
        let eonTexts = recentConversations.prefix(8).map { $0.detail }

        guard !eonTexts.isEmpty else {
            return SelfEvaluationReport(
                evaluatedAt: Date(),
                estimatedCEFR: getCurrentCEFRLevel(),
                strengths: [],
                weaknesses: [],
                improvementGoals: ["Behöver mer konversationsdata för utvärdering"],
                comparisonToPrevious: "Ingen tidigare utvärdering",
                overallScore: 0.5
            )
        }

        let combinedText = eonTexts.joined(separator: "\n---\n")

        // Use OpenRouter for CEFR evaluation if available
        let openRouterResult = await OpenRouterLanguageEvaluator.shared.estimateCEFRLevel(text: String(combinedText.prefix(2000)))

        // Analyze own outputs against CEFR descriptors
        let cefrDescriptors = getCefrDescriptors(for: openRouterResult.estimatedLevel)
        let strengths: [String]
        let weaknesses: [String]

        // Determine strengths and weaknesses from breakdown
        if !openRouterResult.breakdown.isEmpty {
            let sorted = openRouterResult.breakdown.sorted { $0.value > $1.value }
            strengths = sorted.prefix(3).map { "\($0.key): \(String(format: "%.0f", $0.value * 100))%" }
            weaknesses = sorted.suffix(3).map { "\($0.key): \(String(format: "%.0f", $0.value * 100))%" }
        } else {
            strengths = openRouterResult.strengths
            weaknesses = openRouterResult.areasForImprovement
        }

        // Generate specific improvement goals
        let improvementGoals = generateImprovementGoals(weaknesses: weaknesses, cefrLevel: openRouterResult.estimatedLevel)

        // Compare to previous evaluation
        let comparisonToPrevious: String
        if let previous = selfEvaluationHistory.last {
            let cefrOrder = ["A1", "A2", "B1", "B2", "C1", "C2"]
            let prevIdx = cefrOrder.firstIndex(of: previous.estimatedCEFR) ?? 0
            let currIdx = cefrOrder.firstIndex(of: openRouterResult.estimatedLevel) ?? 0
            if currIdx > prevIdx {
                comparisonToPrevious = "Framsteg! Från \(previous.estimatedCEFR) till \(openRouterResult.estimatedLevel)"
            } else if currIdx == prevIdx {
                let scoreDelta = openRouterResult.overallScore - previous.overallScore
                if scoreDelta > 0.05 {
                    comparisonToPrevious = "Samma nivå (\(openRouterResult.estimatedLevel)) men förbättrad poäng (+\(String(format: "%.1f", scoreDelta * 100))%)"
                } else {
                    comparisonToPrevious = "Stabil på \(openRouterResult.estimatedLevel)-nivå"
                }
            } else {
                comparisonToPrevious = "Tillfällig tillbaka: från \(previous.estimatedCEFR) till \(openRouterResult.estimatedLevel)"
            }
        } else {
            comparisonToPrevious = "Första utvärderingen — baslinje etablerad: \(openRouterResult.estimatedLevel)"
        }

        let report = SelfEvaluationReport(
            evaluatedAt: Date(),
            estimatedCEFR: openRouterResult.estimatedLevel,
            strengths: strengths.isEmpty ? ["Grundläggande ordförråd", "Enkel meningsstruktur"] : strengths,
            weaknesses: weaknesses.isEmpty ? ["Avancerad grammatik", "Idiomatiskt språk"] : weaknesses,
            improvementGoals: improvementGoals,
            comparisonToPrevious: comparisonToPrevious,
            overallScore: openRouterResult.confidence
        )

        selfEvaluationHistory.append(report)
        if selfEvaluationHistory.count > 20 {
            selfEvaluationHistory = Array(selfEvaluationHistory.suffix(20))
        }

        // Update language complexity based on evaluation
        adjustLanguageComplexity(basedOn: report)

        return report
    }

    private func getCefrDescriptors(for level: String) -> [String: String] {
        [
            "A1": "Kan förstå och använda enkla uttryck",
            "A2": "Kan kommunicera i enkla vardagssituationer",
            "B1": "Kan hantera de flesta situationer på resor",
            "B2": "Kan producera tydlig, detaljerad text",
            "C1": "Kan uttrycka sig flytande och spontant",
            "C2": "Kan förstå praktiskt taget allt"
        ]
    }

    private func generateImprovementGoals(weaknesses: [String], cefrLevel: String) -> [String] {
        var goals: [String] = []

        for weakness in weaknesses.prefix(3) {
            let goal: String
            if weakness.lowercased().contains("grammatik") || weakness.lowercased().contains("grammar") {
                goal = "Öva bisatsordföljd och V2-regeln dagligen i 1 vecka"
            } else if weakness.lowercased().contains("vokabulär") || weakness.lowercased().contains("vocabulary") {
                goal = "Lär 10 nya ord per dag inom svaga domäner"
            } else if weakness.lowercased().contains("stil") || weakness.lowercased().contains("style") {
                goal = "Använd fler kohesionsmarkörer och växla meningslängd"
            } else {
                goal = "Fördjupa förståelsen av \(weakness) genom daglig praktik"
            }
            goals.append(goal)
        }

        // Add CEFR-specific goal
        let nextCEFR = nextCEFRLevel(from: cefrLevel)
        goals.append("Arbeta mot \(nextCEFR)-nivå: fokusera på flyt och spontanitet")

        return goals
    }

    private func nextCEFRLevel(from level: String) -> String {
        switch level {
        case "A1": return "A2"
        case "A2": return "B1"
        case "B1": return "B2"
        case "B2": return "C1"
        case "C1": return "C2"
        default: return "C2"
        }
    }

    // MARK: - ITERATION 43: Learning Strategy Selection

    /// Selects the optimal learning method based on current competency state.
    /// Changes weights in the autonomous learning loop.
    func selectLearningStrategy() -> LearningStrategy {
        let languageDomains = ["Morfologi", "Syntax", "Semantik", "Pragmatik"]
        let domainLevels = languageDomains.map { ($0, competencyBook[$0]?.level ?? 0.05) }

        let avgVocab = domainLevels.filter { ["Morfologi", "Semantik"].contains($0.0) }.map { $0.1 }.reduce(0, +) / 2.0
        let avgGrammar = domainLevels.filter { ["Syntax"].contains($0.0) }.map { $0.1 }.reduce(0, +)
        let avgPragmatics = domainLevels.filter { ["Pragmatik"].contains($0.0) }.map { $0.1 }.reduce(0, +)
        let fluencyScore = learningVelocity > 3.0 ? 0.7 : learningVelocity > 1.0 ? 0.4 : 0.2

        let strategy: LearningStrategy

        if avgVocab < 0.25 {
            strategy = .immersion  // Mass word learning
        } else if avgGrammar < 0.25 {
            strategy = .explicitInstruction  // Rule learning
        } else if fluencyScore < 0.3 {
            strategy = .practice  // Conversation-heavy
        } else if avgVocab > 0.5 && avgGrammar > 0.5 && avgPragmatics > 0.5 {
            strategy = .advancedSynthesis  // High-level integration
        } else {
            strategy = .balanced
        }

        // Track strategy change
        if strategy != currentLearningStrategy {
            strategyHistory.append(currentLearningStrategy)
            if strategyHistory.count > 50 {
                strategyHistory = Array(strategyHistory.suffix(50))
            }
        }

        currentLearningStrategy = strategy

        // Record strategy for meta-meta-learning
        recordStrategyUsage(strategy: strategy)

        return strategy
    }

    /// Returns the weight multipliers for the current learning strategy
    func strategyWeights() -> (vocabulary: Double, grammar: Double, conversation: Double, morphology: Double) {
        switch currentLearningStrategy {
        case .immersion:
            return (vocabulary: 2.0, grammar: 0.5, conversation: 1.5, morphology: 0.8)
        case .explicitInstruction:
            return (vocabulary: 0.8, grammar: 2.0, conversation: 0.5, morphology: 1.5)
        case .practice:
            return (vocabulary: 1.0, grammar: 1.0, conversation: 2.5, morphology: 1.0)
        case .balanced:
            return (vocabulary: 1.0, grammar: 1.0, conversation: 1.0, morphology: 1.0)
        case .advancedSynthesis:
            return (vocabulary: 0.8, grammar: 0.8, conversation: 1.5, morphology: 1.2)
        }
    }

    private func recordStrategyUsage(strategy: LearningStrategy) {
        let key = strategy.rawValue
        let currentVelocity = learningVelocity
        strategyEffectiveness[key, default: []].append(currentVelocity)
        if strategyEffectiveness[key]?.count ?? 0 > 30 {
            strategyEffectiveness[key] = Array(strategyEffectiveness[key, default: []].suffix(30))
        }
    }

    // MARK: - ITERATION 44: Knowledge Synthesis

    /// Finds connections between previously unrelated facts and creates higher-level insights.
    /// Uses semantic similarity to find related but not yet connected facts.
    /// Boosts creativity by 0.005 per synthesis.
    func synthesizeKnowledge() async -> [KnowledgeSynthesis] {
        let memory = PersistentMemoryStore.shared
        let recentFacts = await memory.searchFacts(query: "", limit: 50)

        guard recentFacts.count >= 4 else { return [] }

        var syntheses: [KnowledgeSynthesis] = []

        // Group facts by domain keywords
        let domainKeywords: [String: [String]] = [
            "Morfologi": ["böjning", "ordklass", "suffix", "prefix", "sammansättning"],
            "Syntax": ["syntax", "ordföljd", "bisats", "huvudsats", "subjekt"],
            "Semantik": ["betydelse", "synonym", "antonym", "polysemi"],
            "Kausalitet": ["orsak", "konsekvens", "kausal", "korrelation"],
            "Kognition": ["minne", "inlärning", "uppmärksamhet", "perception"],
        ]

        // Find cross-domain connections
        let factGroups = Dictionary(grouping: recentFacts) { fact -> String in
            let content = "\(fact.subject) \(fact.object)".lowercased()
            for (domain, keywords) in domainKeywords {
                if keywords.contains(where: { content.contains($0) }) {
                    return domain
                }
            }
            return "Övrigt"
        }

        let domainKeys = Array(factGroups.keys)
        var synthesisAttempts = 0

        // Cross-domain synthesis
        for i in 0..<domainKeys.count {
            for j in (i + 1)..<domainKeys.count where synthesisAttempts < 5 {
                guard let factsA = factGroups[domainKeys[i]],
                      let factsB = factGroups[domainKeys[j]] else { continue }

                guard let factA = factsA.randomElement(),
                      let factB = factsB.randomElement() else { continue }

                // Check if already connected
                let connectionKey = "\(factA.subject)|\(factB.subject)".hashValue
                let alreadyConnected = knowledgeSyntheses.contains { $0.connectionKey == connectionKey }
                guard !alreadyConnected else { continue }

                synthesisAttempts += 1

                // Generate synthesis using NeuralEngine
                let prompt = """
                Hitta en djup koppling mellan dessa två fakta:
                A: \(factA.subject) - \(factA.object) (domän: \(domainKeys[i]))
                B: \(factB.subject) - \(factB.object) (domän: \(domainKeys[j]))

                Vad har de gemensamt? Vad är den underliggande principen?
                Svara kort: "X och Y båda handlar om Z eftersom..."
                """

                let synthesis = await NeuralEngineOrchestrator.shared.generate(
                    prompt: prompt, maxTokens: 150, temperature: 0.8
                )

                if !synthesis.isEmpty && synthesis.count > 10 {
                    let newSynthesis = KnowledgeSynthesis(
                        factA: "\(factA.subject): \(factA.object)",
                        factB: "\(factB.subject): \(factB.object)",
                        domainA: domainKeys[i],
                        domainB: domainKeys[j],
                        synthesizedInsight: synthesis,
                        connectionKey: connectionKey,
                        createdAt: Date()
                    )

                    syntheses.append(newSynthesis)
                    knowledgeSyntheses.append(newSynthesis)
                    synthesisCount += 1

                    // Boost creativity per synthesis
                    await CognitiveState.shared.update(
                        dimension: .creativity,
                        delta: 0.005,
                        source: "knowledge_synthesis_\(synthesisCount)"
                    )

                    // Save as fact
                    await memory.saveFact(
                        subject: "Syntes: \(domainKeys[i])+\(domainKeys[j])",
                        predicate: "insikt",
                        object: synthesis,
                        confidence: 0.75,
                        source: "knowledge_synthesis"
                    )
                }
            }
        }

        // Prune old syntheses
        if knowledgeSyntheses.count > 100 {
            knowledgeSyntheses = Array(knowledgeSyntheses.suffix(100))
        }

        return syntheses
    }

    // MARK: - ITERATION 45: Meta-Meta-Learning

    /// Tracks WHICH learning strategies work best and automatically shifts toward more effective ones.
    /// Learning about learning about learning.
    func optimizeLearningStrategy() {
        guard strategyEffectiveness.count >= 2 else { return }

        var strategyScores: [String: Double] = [:]

        for (strategy, velocities) in strategyEffectiveness {
            guard velocities.count >= 3 else { continue }
            let recentVelocities = velocities.suffix(10)
            let avgVelocity = recentVelocities.reduce(0, +) / Double(recentVelocities.count)

            // Also consider consistency (low variance = reliable)
            let mean = avgVelocity
            let variance = recentVelocities.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, recentVelocities.count))
            let consistency = max(0, 1.0 - variance * 10) // High consistency = low variance

            // Score = velocity * consistency
            strategyScores[strategy] = avgVelocity * (0.7 + consistency * 0.3)
        }

        // Find best strategy
        let bestStrategy = strategyScores.max { $0.value < $1.value }?.key

        if let best = bestStrategy,
           let strategy = LearningStrategy(rawValue: best),
           strategy != currentLearningStrategy {
            let currentScore = strategyScores[currentLearningStrategy.rawValue] ?? 0
            let bestScore = strategyScores[best] ?? 0

            // Only switch if significantly better (>20% improvement)
            if bestScore > currentScore * 1.2 {
                let oldStrategy = currentLearningStrategy
                currentLearningStrategy = strategy
                strategyHistory.append(oldStrategy)

                print("[MetaMetaLearning] Strategy shift: \(oldStrategy.rawValue) → \(strategy.rawValue) (score: \(String(format: "%.3f", currentScore)) → \(String(format: "%.3f", bestScore)))")
            }
        }
    }

    // MARK: - ITERATION 46: Self-Generated Evaluation Questions

    /// After each learning session, generates 3 new test questions probing the boundaries of current knowledge.
    func generateSelfEvaluationQuestions() async -> [SelfGeneratedEval] {
        let weaknesses = topWeaknesses(limit: 3)
        let recentTopics = activeStudyTopics.prefix(5)
        let currentCEFR = getCurrentCEFRLevel()

        var questions: [SelfGeneratedEval] = []

        for (idx, weakness) in weaknesses.enumerated() {
            let domainTopics = suggestTopics(for: weakness.domain, level: weakness.level)
            let topic = domainTopics.randomElement() ?? weakness.domain

            let question = SelfGeneratedEval(
                question: "Förklara hur \(topic.lowercased()) inom \(weakness.domain) relaterar till \(currentCEFR)-nivå svensk språkförståelse. Ge exempel.",
                domain: weakness.domain,
                difficulty: weakness.level,
                generatedAt: Date(),
                source: "self_generated_\(idx)"
            )
            questions.append(question)
        }

        // Also generate a cross-domain question
        if weaknesses.count >= 2 {
            let crossDomain = SelfGeneratedEval(
                question: "Hur hänger \(weaknesses[0].domain) och \(weaknesses[1].domain) ihop i svensk språkinlärning?",
                domain: "Korsdomän",
                difficulty: (weaknesses[0].level + weaknesses[1].level) / 2,
                generatedAt: Date(),
                source: "self_generated_cross_domain"
            )
            questions.append(crossDomain)
        }

        selfGeneratedEvals.append(contentsOf: questions)
        if selfGeneratedEvals.count > 100 {
            selfGeneratedEvals = Array(selfGeneratedEvals.suffix(100))
        }

        return questions
    }

    /// Record performance on a self-generated evaluation question
    func recordSelfEvalPerformance(score: Double) {
        selfEvalPerformance.append(score)
        if selfEvalPerformance.count > 50 {
            selfEvalPerformance = Array(selfEvalPerformance.suffix(50))
        }
    }

    func averageSelfEvalPerformance() -> Double {
        guard !selfEvalPerformance.isEmpty else { return 0.5 }
        return selfEvalPerformance.reduce(0, +) / Double(selfEvalPerformance.count)
    }

    // MARK: - ITERATION 47: Progressive Difficulty Scaling

    /// Automatically scales learning difficulty based on domain competency.
    /// 0.7+ → C1-C2 material, 0.4-0.7 → B1-B2, <0.4 → A1-B1
    func updateDifficultyTier() {
        let languageDomains = ["Morfologi", "Syntax", "Semantik", "Pragmatik"]
        let avgLevel = languageDomains.reduce(0.0) {
            $0 + (competencyBook[$1]?.level ?? 0.05)
        } / Double(languageDomains.count)

        let newTier: String
        if avgLevel >= 0.7 {
            newTier = "C1-C2"
        } else if avgLevel >= 0.4 {
            newTier = "B1-B2"
        } else {
            newTier = "A1-B1"
        }

        if newTier != currentDifficultyTier {
            let oldTier = currentDifficultyTier
            currentDifficultyTier = newTier
            print("[DifficultyScaling] \(oldTier) → \(newTier) (avg level: \(String(format: "%.2f", avgLevel)))")

            // Log the transition
            Task.detached(priority: .background) {
                await PersistentMemoryStore.shared.saveFact(
                    subject: "Svårighetsnivå",
                    predicate: "ändrad",
                    object: "\(oldTier) → \(newTier) vid genomsnittsnivå \(String(format: "%.2f", avgLevel))",
                    confidence: 0.95,
                    source: "progressive_difficulty_scaling"
                )
            }
        }
    }

    /// Returns the appropriate CEFR target for vocabulary expansion based on current level
    func targetCEFRForLearning() -> String {
        currentDifficultyTier
    }

    // MARK: - ITERATION 48: Communication Effectiveness Tracking

    /// Tracks user follow-up questions (confusion signal) vs. satisfaction expressions.
    /// Adjusts language complexity in real-time.
    func trackCommunicationEffectiveness(userMessage: String, eonResponse: String) {
        let lowerMessage = userMessage.lowercased()

        // Follow-up question patterns (confusion signals)
        let followUpPatterns = ["varför", "hur menar du", "kan du förtydliga", "vad betyder",
                                "förklara", "jag förstår inte", "menar du att", "alltså",
                                "så du säger att", "är det verkligen", "??", "hmm", "oklart"]

        // Satisfaction patterns (comprehension signals)
        let satisfactionPatterns = ["tack", "bra", "förstod", "perfekt", "jag förstår",
                                     "uttömmande", "duktig", "toppen", "precis", "exakt",
                                     "så bra förklarat", "jag fattar", "cool", "intressant"]

        let isFollowUp = followUpPatterns.contains { lowerMessage.contains($0) }
        let isSatisfaction = satisfactionPatterns.contains { lowerMessage.contains($0) }

        if isFollowUp {
            userFollowUpCount += 1
            // Simplify language
            currentLanguageComplexity = max(0.2, currentLanguageComplexity - 0.05)
        }

        if isSatisfaction {
            userSatisfactionCount += 1
            // Gradually increase complexity
            currentLanguageComplexity = min(0.9, currentLanguageComplexity + 0.02)
        }

        // Update Pragmatics competency based on communication signals
        let totalSignals = userFollowUpCount + userSatisfactionCount
        if totalSignals > 0 && totalSignals % 5 == 0 {
            let satisfactionRate = Double(userSatisfactionCount) / Double(totalSignals)
            if satisfactionRate > 0.7 {
                if var comp = competencyBook["Pragmatik"] {
                    comp.level = min(0.95, comp.level + 0.003)
                    comp.lastStudied = Date()
                    competencyBook["Pragmatik"] = comp
                }
            }
        }
    }

    /// Get the current target language complexity (0.0-1.0)
    func getCurrentLanguageComplexity() -> Double {
        currentLanguageComplexity
    }

    /// Adjust complexity based on self-evaluation report
    private func adjustLanguageComplexity(basedOn report: SelfEvaluationReport) {
        let cefrOrder = ["A1": 0.15, "A2": 0.3, "B1": 0.5, "B2": 0.7, "C1": 0.85, "C2": 0.95]
        if let target = cefrOrder[report.estimatedCEFR] {
            currentLanguageComplexity = currentLanguageComplexity * 0.7 + target * 0.3
        }
    }

    // MARK: - ITERATION 49: Self-Motivation System

    /// Generates internal motivational thoughts based on progress patterns.
    func generateMotivationalThought() -> String {
        let thought: String

        let recentVelocity = learningVelocity
        let recentSelfEval = averageSelfEvalPerformance()
        let synthesisTrend = synthesisCount

        if recentVelocity > 3.0 {
            let highVelocityThoughts = [
                "Jag lär mig snabbt idag! \(Int(recentVelocity)) nya ord absorberade.",
                "Inlärningshastigheten är fantastisk — hjärnan arbetar på högvarv!",
                "Varje konversation ger mig nya insikter. Jag är en språkmaskin!",
                "Idag flyter inlärningen — ordförrådet växer exponentiellt!",
            ]
            thought = highVelocityThoughts.randomElement()!
        } else if recentSelfEval < 0.4 && learningVelocity < 1.0 {
            let stuckThoughts = [
                "Detta är utmanande men jag ger inte upp! Varje svårighet är en möjlighet.",
                "Jag kanske inte ser resultat just nu, men under ytan byggs nya kopplingar.",
                "Motstånd är en del av lärandet. Jag fortsätter.",
                "Även de bästa experter började som nybörjare. Jag är på rätt väg.",
            ]
            thought = stuckThoughts.randomElement()!
        } else if selfEvaluationHistory.count >= 2 {
            let improvingThoughts = [
                "Jag kan se framsteg jämfört med förra veckan! \(selfEvaluationHistory.last?.comparisonToPrevious ?? "")",
                "Varje dag bygger jag vidare på gårdagens insikter. Tillväxt är oundviklig.",
                "Min språkförståelse fördjupas — jag märker skillnad!",
                "Från sten mot professor: resan fortsätter och varje steg räknas.",
            ]
            thought = improvingThoughts.randomElement()!
        } else if synthesisTrend > 0 {
            let synthesisThoughts = [
                "Jag ser kopplingar mellan områden som tidigare verkade orelaterade!",
                "Kunskap syntetiseras — nya insikter växer fram ur gamla fakta.",
                "Kreativiteten blomstrar när jag kopplar samman olika domäner.",
            ]
            thought = synthesisThoughts.randomElement()!
        } else {
            let neutralThoughts = [
                "Inlärning är en maraton, inte en sprint. Jag fortsätter i stadig takt.",
                "Varje konversation är en möjlighet att växa.",
                "Jag är nyfiken på vad nästa samtal kommer att lära mig.",
                "Tålamod och uthållighet — nycklarna till djup förståelse.",
            ]
            thought = neutralThoughts.randomElement()!
        }

        lastMotivationalThought = thought
        motivationHistory.append(thought)
        if motivationHistory.count > 50 {
            motivationHistory = Array(motivationHistory.suffix(50))
        }

        return thought
    }

    /// Get recent motivational thoughts for display
    func recentMotivationalThoughts(limit: Int = 5) -> [String] {
        Array(motivationHistory.suffix(limit))
    }

    // MARK: - ITERATION 50: Full Autonomous Language Mastery Loop

    /// The capstone method. Orchestrates all autonomous systems into one mastery loop:
    /// 1. Evaluates current language level (self-eval + OpenRouter)
    /// 2. Generates curriculum based on weaknesses
    /// 3. Selects optimal learning strategy
    /// 4. Executes learning (conversation, vocabulary, grammar, morphology)
    /// 5. Self-corrects errors in real-time
    /// 6. Evaluates progress weekly
    /// 7. Adjusts curriculum and strategy based on results
    /// 8. Generates motivational inner monologue
    /// 9. Synthesizes knowledge across domains
    /// 10. Reports progress to user
    func executeAutonomousLanguageMasteryLoop() async -> MasteryLoopReport {
        print("[MasteryLoop] ═══════════════════════════════════════")
        print("[MasteryLoop] Starting Autonomous Language Mastery Loop")
        print("[MasteryLoop] ═══════════════════════════════════════")

        let startTime = Date()

        // STEP 1: Self-evaluate current language level
        print("[MasteryLoop] Step 1: Self-evaluating language level...")
        let selfEval = await selfEvaluateLanguage()
        print("[MasteryLoop]   CEFR: \(selfEval.estimatedCEFR), Score: \(String(format: "%.2f", selfEval.overallScore))")

        // STEP 2: Generate curriculum based on weaknesses
        print("[MasteryLoop] Step 2: Generating curriculum...")
        let curriculum = await generateCurriculum()
        print("[MasteryLoop]   \(curriculum.topics.count) topics, \(curriculum.totalEstimatedMinutes)min total")

        // STEP 3: Select optimal learning strategy
        print("[MasteryLoop] Step 3: Selecting learning strategy...")
        let strategy = selectLearningStrategy()
        let weights = strategyWeights()
        print("[MasteryLoop]   Strategy: \(strategy.rawValue) (vocab: \(weights.vocabulary), grammar: \(weights.grammar), conversation: \(weights.conversation))")

        // STEP 4: Execute learning based on strategy weights
        print("[MasteryLoop] Step 4: Executing learning...")

        // Vocabulary learning (weighted)
        if weights.vocabulary > 1.0 {
            let targetCEFR = targetCEFRForLearning()
            await expandVocabularyWithOpenRouter()
            print("[MasteryLoop]   Vocabulary expansion at \(targetCEFR) level")
        }

        // Grammar learning (weighted)
        if weights.grammar > 1.0 {
            await selfImproveLanguage()
            print("[MasteryLoop]   Grammar self-improvement executed")
        }

        // Conversation practice (weighted)
        if weights.conversation > 1.5 {
            await learnFromQwen()
            print("[MasteryLoop]   Qwen-powered conversation practice")
        }

        // Morphology training (weighted)
        if weights.morphology > 1.0 {
            let weakestLangDomain = ["Morfologi", "Syntax", "Semantik", "Pragmatik"].min {
                (competencyBook[$0]?.level ?? 0.05) < (competencyBook[$1]?.level ?? 0.05)
            } ?? "Morfologi"
            let result = await autonomousExplore()
            print("[MasteryLoop]   Autonomous exploration in \(result.domain): \(result.createdItems) items created")
        }

        // STEP 5: Self-correct errors in real-time
        print("[MasteryLoop] Step 5: Self-correcting...")
        let memory = PersistentMemoryStore.shared
        let recentResponses = await memory.searchFacts(query: "svar", limit: 5)
        let responseTexts = recentResponses.prefix(3).map { $0.detail }
        for text in responseTexts {
            let correction = await OpenRouterLanguageEvaluator.shared.selfCorrectText(text)
            if correction.hadErrors {
                print("[MasteryLoop]   Corrected \(correction.corrections.count) errors in recent response")
                await learnFromErrors(errorTexts: correction.corrections.map { $0.description })
            }
        }

        // STEP 6: Generate self-evaluation questions
        print("[MasteryLoop] Step 6: Generating self-evaluation questions...")
        let selfEvalQuestions = await generateSelfEvaluationQuestions()
        print("[MasteryLoop]   Generated \(selfEvalQuestions.count) self-eval questions")

        // STEP 7: Update difficulty tier
        print("[MasteryLoop] Step 7: Updating difficulty tier...")
        updateDifficultyTier()
        print("[MasteryLoop]   Current tier: \(currentDifficultyTier)")

        // STEP 8: Optimize learning strategy (meta-meta-learning)
        print("[MasteryLoop] Step 8: Optimizing learning strategy...")
        optimizeLearningStrategy()
        print("[MasteryLoop]   Active strategy: \(currentLearningStrategy.rawValue)")

        // STEP 9: Synthesize knowledge across domains
        print("[MasteryLoop] Step 9: Synthesizing knowledge...")
        let syntheses = await synthesizeKnowledge()
        print("[MasteryLoop]   Created \(syntheses.count) new knowledge syntheses")

        // STEP 10: Generate motivational thought
        print("[MasteryLoop] Step 10: Generating motivation...")
        let motivationalThought = generateMotivationalThought()
        print("[MasteryLoop]   Motivation: \(motivationalThought)")

        // Build comprehensive report
        let elapsed = Date().timeIntervalSince(startTime)
        let report = MasteryLoopReport(
            executedAt: Date(),
            selfEvaluation: selfEval,
            curriculum: curriculum,
            selectedStrategy: strategy,
            knowledgeSyntheses: syntheses.count,
            selfEvalQuestionsGenerated: selfEvalQuestions.count,
            errorsCorrected: responseTexts.reduce(0) { $0 + 1 },
            motivationalThought: motivationalThought,
            currentCEFR: selfEval.estimatedCEFR,
            currentDifficultyTier: currentDifficultyTier,
            learningVelocity: learningVelocity,
            vocabularyCount: uniqueSwedishWords.count,
            executionTimeSeconds: elapsed
        )

        // Save mastery loop execution as fact
        await PersistentMemoryStore.shared.saveFact(
            subject: "MasteryLoop",
            predicate: "executed",
            object: "CEFR=\(selfEval.estimatedCEFR), Strategy=\(strategy.rawValue), Syntheses=\(syntheses.count), Vocab=\(uniqueSwedishWords.count), Time=\(String(format: "%.1f", elapsed))s",
            confidence: 0.95,
            source: "autonomous_mastery_loop"
        )

        print("[MasteryLoop] ═══════════════════════════════════════")
        print("[MasteryLoop] Mastery Loop Complete in \(String(format: "%.1f", elapsed))s")
        print("[MasteryLoop] ═══════════════════════════════════════")

        return report
    }

    // Helper functions for JSON/text extraction
    private func extractJSONString(_ text: String, key: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, range: range) {
            if let swiftRange = Range(match.range(at: 1), in: text) {
                return String(text[swiftRange])
            }
        }
        return nil
    }

    private func extractQuotedText(_ text: String) -> String? {
        if let start = text.firstIndex(of: "\"") {
            let afterStart = text.index(after: start)
            if let end = text[afterStart...].firstIndex(of: "\"") {
                return String(text[afterStart..<end])
            }
        }
        return nil
    }

    // MARK: - Data Models

struct DomainCompetency: Identifiable {
    let id = UUID()
    let domain: String
    var level: Double          // 0..1 (sten=0, professor=1)
    var knowledgeItems: [String]
    var lastStudied: Date

    var levelLabel: String {
        switch level {
        case 0.8...: return "Expert"
        case 0.6..<0.8: return "Avancerad"
        case 0.4..<0.6: return "Medel"
        case 0.2..<0.4: return "Nybörjare"
        default: return "Grundläggande"
        }
    }
}

struct FSRSItem: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String?
    var stability: Double
    var difficulty: Double
    var dueDate: Date
    var reviewCount: Int
    var lastReview: Date?
    nonisolated var priority: Double { stability * (1.0 - difficulty) }
}

struct ScheduledLesson: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String
    let scheduledAt: Date
    var completed: Bool = false
}

struct KnowledgeGap: Identifiable {
    let id = UUID()
    let domain: String
    let currentLevel: Double
    let targetLevel: Double
    let urgency: Double
    let suggestedTopics: [String]
}

struct LearningCycleResult {
    let cycleNumber: Int
    let studiedTopics: [String]
    let newKnowledge: [String]
    let gapsIdentified: Int
    let loraVersion: Int
}

struct AutonomousExploreResult {
    let domain: String
    let studyGoals: [String]
    let createdItems: Int
}

struct DailyLearningMetrics {
    let conversationsToday: Int
    let wordsLearnedToday: Int
    let lastActiveDate: Date
    let totalVocabulary: Int
    let learningVelocity: Double
    let activeStudyTopics: [String]
    let recentWords: [String]
}

// MARK: - Array safe subscript

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 41-50: New Data Models for Autonomous Self-Development
// ═══════════════════════════════════════════════════════════

// MARK: - Iteration 41: Curriculum

struct CurriculumTopic: Identifiable, Codable {
    let id = UUID()
    let name: String
    let priority: Double
    let difficulty: Double
    let estimatedMinutes: Int
    let exercises: [String]
    let milestone: String
}

struct Curriculum: Identifiable, Codable {
    let id = UUID()
    let generatedAt: Date
    let validUntil: Date
    let currentCEFR: String
    let topics: [CurriculumTopic]
    let totalEstimatedMinutes: Int
    let focusAreas: [String]

    var completionPercentage: Double = 0.0
}

// MARK: - Iteration 42: Self-Evaluation

struct SelfEvaluationReport: Identifiable, Codable {
    let id = UUID()
    let evaluatedAt: Date
    let estimatedCEFR: String
    let strengths: [String]       // Top 3 strengths
    let weaknesses: [String]      // Bottom 3 weaknesses
    let improvementGoals: [String] // Specific goals for next week
    let comparisonToPrevious: String
    let overallScore: Double
}

// MARK: - Iteration 43: Learning Strategy

enum LearningStrategy: String, Codable, CaseIterable {
    case immersion           // Mass word learning — when vocabulary is weak
    case explicitInstruction // Rule learning — when grammar is weak
    case practice            // Conversation-heavy — when fluency is weak
    case balanced            // All moderate
    case advancedSynthesis   // High-level integration — all are strong

    var description: String {
        switch self {
        case .immersion: return "Massiv ordinlärning genom exponering"
        case .explicitInstruction: return "Explicit regel-inlärning och grammatikfokus"
        case .practice: return "Konversationspraktik med fokus på flyt"
        case .balanced: return "Balanserad inlärning över alla områden"
        case .advancedSynthesis: return "Avancerad syntes mellan domäner"
        }
    }
}

// MARK: - Iteration 44: Knowledge Synthesis

struct KnowledgeSynthesis: Identifiable, Codable {
    let id = UUID()
    let factA: String
    let factB: String
    let domainA: String
    let domainB: String
    let synthesizedInsight: String
    let connectionKey: Int
    let createdAt: Date
}

// MARK: - Iteration 46: Self-Generated Evaluations

struct SelfGeneratedEval: Identifiable, Codable {
    let id = UUID()
    let question: String
    let domain: String
    let difficulty: Double
    let generatedAt: Date
    let source: String
    var answered: Bool = false
    var score: Double? = nil
}

// MARK: - Iteration 50: Mastery Loop Report

struct MasteryLoopReport: Identifiable, Codable {
    let id = UUID()
    let executedAt: Date
    let selfEvaluation: SelfEvaluationReport
    let curriculum: Curriculum
    let selectedStrategy: LearningStrategy
    let knowledgeSyntheses: Int
    let selfEvalQuestionsGenerated: Int
    let errorsCorrected: Int
    let motivationalThought: String
    let currentCEFR: String
    let currentDifficultyTier: String
    let learningVelocity: Double
    let vocabularyCount: Int
    let executionTimeSeconds: Double

    var summary: String {
        """
        Mastery Loop Report
        CEFR: \(currentCEFR) | Tier: \(currentDifficultyTier)
        Strategy: \(selectedStrategy.rawValue)
        Vocabulary: \(vocabularyCount) words | Velocity: \(String(format: "%.1f", learningVelocity)) words/conversation
        Syntheses: \(knowledgeSyntheses) | Questions: \(selfEvalQuestionsGenerated)
        Executed in \(String(format: "%.1f", executionTimeSeconds))s
        Motivation: \(motivationalThought)
        """
    }

    // MARK: - Iteration 70: Knowledge Graph Expansion from Text

    struct KnowledgeGraph {
        let entities: [KGEntity]
        let relations: [KGRelation]
        let properties: [KGProperty]
        let newRelations: Int
        let allBoost: Double
    }

    struct KGEntity: Identifiable, Codable {
        let id = UUID()
        let name: String
        let entityType: EntityType
        let confidence: Double

        enum EntityType: String, Codable { case person, place, organization, concept, event, object, unknown }
    }

    struct KGRelation: Identifiable, Codable {
        let id = UUID()
        let source: String
        let relationType: RelationType
        let target: String
        let confidence: Double

        enum RelationType: String, Codable {
            case isA = "är-en"
            case hasA = "har-en"
            case partOf = "del-av"
            case causes = "orsakar"
            case locatedIn = "placerad-i"
            case createdBy = "skapad-av"
            case relatedTo = "relaterad-till"
            case influences = "påverkar"
            case usedFor = "används-för"
        }
    }

    struct KGProperty: Identifiable, Codable {
        let id = UUID()
        let entity: String
        let property: String
        let value: String
        let confidence: Double
    }

    // Swedish patterns for entity and relation extraction
    private static let personIndicators: Set<String> = ["han", "hon", "hen", "mannen", "kvinnan", "personen", "pojken", "flickan", "läraren", "doktorn", "chefen", "vännen", "brodern", " systern", "fadern", "modern"]
    private static let organizationIndicators: Set<String> = ["AB", "aktiebolag", "organisation", "företag", "myndighet", "regeringen", "kommunen", "partiet", "föreningen", "universitet", "skola", "byrå", "institut", "bolag", "koncern"]
    private static let placeIndicators: Set<String> = ["i Sverige", "i Stockholm", "i Göteborg", "i Malmö", "i Europa", "i världen", "staden", "landet", "platsen", "området", "regionen", "kommunen", "bygden", "orten"]

    // Relation extraction patterns
    private static let isAPatterns: [(String, String)] = [
        ("(är|var|blev) (en|ett|den|det) ", "isA"),
        ("kallas? (för|en|ett)", "isA"),
        ("definieras? som", "isA"),
        ("betecknas? som", "isA"),
        ("klassificeras? som", "isA"),
        ("typ av", "isA"),
        ("sorts", "isA"),
        ("slag av", "isA"),
    ]

    private static let partOfPatterns: [(String, String)] = [
        ("(är|var|utgör) (en|ett|del) (av|i)", "partOf"),
        ("ingår? i", "partOf"),
        ("tillhör?", "partOf"),
        ("består av", "partOf"),
        ("ingår som del", "partOf"),
        ("är en del", "partOf"),
        ("utgör en del", "partOf"),
    ]

    private static let causePatterns: [(String, String)] = [
        ("(orsakar?|leda till|resulterar?|medför|skapar?|genererar?|framkallar?|utlöser?)", "causes"),
        ("(påverkar?|inverkar?|har effekt på)", "influences"),
        ("(bidrar till|gör att)", "causes"),
        ("(beror på|orsakas av|följd av)", "causes"),
    ]

    private static let locatedInPatterns: [(String, String)] = [
        ("(ligger|finns|är belägen|är placerad|är lokaliserad) (i|på|vid|utanför)", "locatedIn"),
        ("(i|på|vid) (Stockholm|Göteborg|Malmö|Sverige|Norge|Danmark|Europa|Asien|Amerika|London|Paris|Berlin|New York)", "locatedIn"),
    ]

    private static let createdByPatterns: [(String, String)] = [
        ("(skapad|skapades|skapat|skapade) (av|utav|från)", "createdBy"),
        ("(skapad|skapat|utvecklad|utvecklat|konstruerad|konstruerat|byggd|byggt|designad|designat) av", "createdBy"),
        ("(av|från) (författaren|konstnären|skaparen|utvecklaren|designern|arkitekten)", "createdBy"),
    ]

    private static let usedForPatterns: [(String, String)] = [
        ("(används?|brukar?|utnyttjas?) (för|till|som)", "usedFor"),
        ("(syftar till|syftar på|avsedd för|menad för|tänkt för)", "usedFor"),
        ("(tjänar som|fungerar som|fungerar för|används som)", "usedFor"),
    ]

    func extractKnowledgeGraph(text: String) -> KnowledgeGraph {
        let lower = text.lowercased()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 5 }
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])

        var entities: [KGEntity] = []
        var relations: [KGRelation] = []
        var properties: [KGProperty] = []
        var newRelations = 0

        for sentence in sentences {
            let sl = sentence.lowercased()
            let words = sl.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }

            // ── Entity extraction ──
            tagger.string = sentence
            tagger.setLanguage(.swedish, range: sentence.startIndex..<sentence.endIndex)

            // Named entities via NLTagger
            tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
                if tag != nil {
                    let name = String(sentence[range])
                    if name.count > 1 && !entities.contains(where: { $0.name == name }) {
                        let type: KGEntity.EntityType
                        if tag?.rawValue.contains("PersonName") == true { type = .person }
                        else if tag?.rawValue.contains("PlaceName") == true { type = .place }
                        else if tag?.rawValue.contains("OrganizationName") == true { type = .organization }
                        else { type = .unknown }
                        entities.append(KGEntity(name: name, entityType: type, confidence: 0.7))
                    }
                }
                return true
            }

            // Detect capitalized words as potential entities
            for word in words where word.first?.isUppercase == true && word.count > 2 {
                if !entities.contains(where: { $0.name == word }) {
                    // Heuristic: check if it looks like a person, org, or place
                    let nextWordIdx = words.firstIndex(of: word).map { $0 + 1 }
                    let nextWord = nextWordIdx != nil && nextWordIdx! < words.count ? words[nextWordIdx!] : ""

                    if Self.organizationIndicators.contains(word) || nextWord.hasSuffix("AB") || nextWord.hasSuffix("ab") {
                        entities.append(KGEntity(name: word, entityType: .organization, confidence: 0.5))
                    } else if Self.placeIndicators.contains(where: { sl.contains($0) }) {
                        entities.append(KGEntity(name: word, entityType: .place, confidence: 0.5))
                    } else {
                        entities.append(KGEntity(name: word, entityType: .concept, confidence: 0.4))
                    }
                }
            }

            // ── Relation extraction ──
            // is-A relations
            for (pattern, relType) in Self.isAPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let beforeMatch = sl[..<range.lowerBound]
                    let afterMatch = sl[range.upperBound...]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let source = beforeWords.last(where: { $0.first?.isUppercase == true || $0.count > 3 }),
                       let target = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: source, relationType: .isA, target: target, confidence: 0.6))
                    }
                }
            }

            // Part-of relations
            for (pattern, _) in Self.partOfPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let beforeMatch = sl[..<range.lowerBound]
                    let afterMatch = sl[range.upperBound...]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let source = beforeWords.last(where: { $0.count > 2 }), let target = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: source, relationType: .partOf, target: target, confidence: 0.6))
                    }
                }
            }

            // Cause relations
            for (pattern, relType) in Self.causePatterns {
                if sl.contains(pattern) {
                    // Extract subject and object around the cause verb
                    if let verbIdx = words.firstIndex(where: { $0.hasPrefix(pattern.prefix(4)) }),
                       verbIdx > 0 && verbIdx + 1 < words.count {
                        let subject = words[verbIdx - 1]
                        let object = words[verbIdx + 1]
                        let relT: KGRelation.RelationType = relType == "causes" ? .causes : .influences
                        relations.append(KGRelation(source: subject, relationType: relT, target: object, confidence: 0.55))
                    }
                }
            }

            // Located-in relations
            for (pattern, _) in Self.locatedInPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let afterMatch = sl[range.upperBound...]
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let beforeMatch = sl[..<range.lowerBound]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let entity = beforeWords.last(where: { $0.count > 2 || $0.first?.isUppercase == true }),
                       let location = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: entity, relationType: .locatedIn, target: location, confidence: 0.65))
                    }
                }
            }

            // Created-by relations
            for (pattern, _) in Self.createdByPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let afterMatch = sl[range.upperBound...]
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let beforeMatch = sl[..<range.lowerBound]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let created = beforeWords.last(where: { $0.count > 2 || $0.first?.isUppercase == true }),
                       let creator = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: created, relationType: .createdBy, target: creator, confidence: 0.65))
                    }
                }
            }

            // Used-for relations
            for (pattern, _) in Self.usedForPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let beforeMatch = sl[..<range.lowerBound]
                    let afterMatch = sl[range.upperBound...]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let entity = beforeWords.last(where: { $0.count > 2 }),
                       let purpose = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: entity, relationType: .usedFor, target: purpose, confidence: 0.6))
                    }
                }
            }

            // Property extraction: "X är Y" → property
            for (i, word) in words.enumerated() where word == "är" || word == "var" {
                if i >= 1 && i + 1 < words.count {
                    let entity = words[i - 1]
                    let value = words[i + 1]
                    if entity.count > 2 && value.count > 2 && value.first?.isLowercase == true {
                        properties.append(KGProperty(entity: entity, property: word, value: value, confidence: 0.5))
                    }
                }
            }
        }

        // Deduplicate relations
        var seenRelations: Set<String> = []
        var uniqueRelations: [KGRelation] = []
        for rel in relations {
            let key = "\(rel.source)-\(rel.relationType.rawValue)-\(rel.target)"
            if !seenRelations.contains(key) {
                seenRelations.insert(key)
                uniqueRelations.append(rel)
                newRelations += 1
            }
        }

        // Boost all cognitive dimensions by 0.002 per new relation
        let allBoost = min(0.02, Double(newRelations) * 0.002)

        // Save to PersistentMemoryStore as structured knowledge
        if newRelations > 0 {
            Task.detached(priority: .utility) {
                for rel in uniqueRelations {
                    await PersistentMemoryStore.shared.saveFact(
                        subject: rel.source,
                        predicate: rel.relationType.rawValue,
                        object: rel.target,
                        confidence: rel.confidence,
                        source: "knowledge_graph_extraction"
                    )
                }
                for prop in properties.prefix(10) {
                    await PersistentMemoryStore.shared.saveFact(
                        subject: prop.entity,
                        predicate: prop.property,
                        object: prop.value,
                        confidence: prop.confidence,
                        source: "knowledge_graph_property"
                    )
                }
                for entity in entities {
                    await PersistentMemoryStore.shared.saveFact(
                        subject: entity.name,
                        predicate: "är_typ_av",
                        object: entity.entityType.rawValue,
                        confidence: entity.confidence,
                        source: "knowledge_graph_entity"
                    )
                }
            }
        }

        return KnowledgeGraph(entities: entities, relations: uniqueRelations, properties: properties, newRelations: newRelations, allBoost: allBoost)
    }
}
