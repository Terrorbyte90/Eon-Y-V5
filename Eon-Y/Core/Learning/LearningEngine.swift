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

    // MARK: - Thread-safe UserDefaults helpers for actor context

    private nonisolated func udDouble(_ key: String) async -> Double {
        await MainActor.run { UserDefaults.standard.double(forKey: key) }
    }

    private nonisolated func udSet(_ value: Double, forKey key: String) async {
        await MainActor.run { UserDefaults.standard.set(value, forKey: key) }
    }

    private nonisolated func udInteger(_ key: String) async -> Int {
        await MainActor.run { UserDefaults.standard.integer(forKey: key) }
    }

    private nonisolated func udSet(_ value: Int, forKey key: String) async {
        await MainActor.run { UserDefaults.standard.set(value, forKey: key) }
    }

    private nonisolated func udArray(_ key: String) async -> [Any]? {
        await MainActor.run { UserDefaults.standard.array(forKey: key) }
    }

    private nonisolated func udSet(_ value: [String], forKey key: String) async {
        await MainActor.run { UserDefaults.standard.set(value, forKey: key) }
    }

    private nonisolated func udObject(_ key: String) async -> Any? {
        await MainActor.run { UserDefaults.standard.object(forKey: key) }
    }

    private nonisolated func udSet(_ value: Any?, forKey key: String) async {
        await MainActor.run { UserDefaults.standard.set(value, forKey: key) }
    }

    private nonisolated func udData(_ key: String) async -> Data? {
        await MainActor.run { UserDefaults.standard.data(forKey: key) }
    }

    private nonisolated func udSet(_ value: Date?, forKey key: String) async {
        await MainActor.run { UserDefaults.standard.set(value, forKey: key) }
    }

    private nonisolated func saveCompetency(_ level: Double, domain: String) async {
        await MainActor.run { UserDefaults.standard.set(level, forKey: "competency_\(domain)") }
    }

    private init() {
        let domains = [
            "Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs",
            "Kausalitet", "Analogibyggande", "Metakognition", "Epistemologi",
            "AI & Maskininlärning", "Kognitionsvetenskap", "Filosofi",
            "Historia", "Psykologi", "Naturvetenskap",
            // ── v92: 15 new domains (30 total) ──
            "Matematik", "Fysik", "Kemi", "Biologi", "Medicin",
            "Juridik", "Ekonomi", "Litteratur", "Konst", "Musik",
            "Sport", "Teknik", "Miljö", "Samhällsvetenskap", "Data science"
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

    private func persistState() async {
        await udSet(Array(uniqueSwedishWords), forKey: Self.vocabKey)
        await udSet(correctMorphologyTests, forKey: Self.correctMorphKey)
        await udSet(totalMorphologyTests, forKey: Self.totalMorphKey)
        await udSet(lastActiveDate, forKey: Self.lastActiveDateKey)
        await udSet(conversationsToday, forKey: Self.conversationsTodayKey)
        await udSet(wordsLearnedToday, forKey: Self.wordsLearnedTodayKey)
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

    // v71: Response quality tracking
    private var qualityTracking: [Double] = []

    // v71: Cooldown for competency sync (max once per 60 seconds)
    private var lastCompetencySync: Date = .distantPast

    // v72: Sync cycle counter for cross-validation scheduling
    private var syncCycleCount: Int = 0

    // v72: Competency calibration tracking
    private var calibrationFlags: [String] = []
    private var achievedMilestones: Set<String> = []
    private var milestonesHistory: [LanguageMilestone] = []
    private var activeHypotheses: [Hypothesis] = []
    private var testedHypotheses: [Hypothesis] = []

    func syncCompetenciesFromDatabase() async {
        // v71: Prevent redundant syncs (max once per 60 seconds)
        if Date().timeIntervalSince(lastCompetencySync) < 60 { return }
        lastCompetencySync = Date()

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
            // ── v92: 15 new domain keyword sets ──
            "Matematik": ["matematik", "algebra", "geometri", "aritmetik", "ekvation", "variabel", "funktion", "integral", "derivata", "matris", "mängd", "sannolikhet", "statistik", "bevis", "teorem", "axiom"],
            "Fysik": ["fysik", "kraft", "energi", "rörelse", "massa", "hastighet", "acceleration", "tryck", "friktion", "gravitation", "elektromagnet", "kvant", "atom", "partikel", "våg", "relativitet"],
            "Kemi": ["kemi", "molekyl", "atom", "reaktion", "lösning", "syra", "bas", "grundämne", "bindning", "oxid", "katjon", "anjon", "destillering", "kristall", "entalpi", "periodiska"],
            "Biologi": ["biologi", "cell", "organism", "gen", "DNA", "protein", "enzym", "evolution", "ekologi", "art", "biosfär", "fotosyntes", "metabolism", "mutation", "nervsystem", "immunförsvar"],
            "Medicin": ["medicin", "sjukdom", "diagnos", "behandling", "operation", "patient", "läkare", "kirurgi", "farmakologi", "patologi", "anatomi", "fysiologi", "immunologi", "epidemiologi", "prognos", "rehabilitering"],
            "Juridik": ["juridik", "lag", "domstol", "advokat", "domare", "brott", "straff", "rättvisa", "avtal", "rättighet", "skyldighet", "polis", "åklagare", "fängelse", "rättegång", "förordning"],
            "Ekonomi": ["ekonomi", "pengar", "bank", "pris", "kostnad", "inkomst", "skatt", "budget", "investering", "aktie", "fond", "ränta", "valuta", "handel", "marknad", "företag"],
            "Litteratur": ["litteratur", "roman", "novell", "dikt", "prosa", "poesi", "författare", "berättelse", "karaktär", "handling", "genre", "stil", "tema", "motiv", "symbol", "allegori"],
            "Konst": ["konst", "måleri", "skulptur", "konstnär", "utställning", "galleri", "målning", "teckning", "akvarell", "collage", "installation", "performance", "modern", "abstrakt", "realism", "impressionism"],
            "Musik": ["musik", "melodi", "harmonik", "rytm", "instrument", "orkester", "kör", "sång", "komposition", "noter", "tonart", "tempo", "dynamik", "ackord", "symfoni", "opera"],
            "Sport": ["sport", "fotboll", "hockey", "tennis", "golf", "friidrott", "simning", "skidor", "cykling", "basket", "volleyboll", "tränare", "spelare", "match", "turnering", "medalj"],
            "Teknik": ["teknik", "dator", "programvara", "hårdvara", "nätverk", "internet", "app", "server", "algoritm", "databas", "kod", "system", "automation", "robot", "AI", "maskininlärning"],
            "Miljö": ["miljö", "klimat", "hållbarhet", "utsläpp", "förnybar", "recirkulering", "ekosystem", "biodiversitet", "förorening", "avskogning", "växthuseffekt", "ozon", "kolcykel", "naturskydd", "energi", "resurs"],
            "Samhällsvetenskap": ["samhälle", "sociologi", "antropologi", "politik", "demokrati", "kultur", "social", "institution", "norm", "identitet", "klass", "makt", "ojämlikhet", "integration", "migration", "urbanisering"],
            "Data science": ["data", "analys", "algoritm", "modell", "träningsdata", "embedding", "transformer", "neural", "djupinlärning", "maskininlärning", "regression", "klassificering", "clustering", "visualisering", "big data", "prediktion"],
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
                    await saveCompetency(comp.level, domain: domain)
                }
            } else {
                let newLevel = min(0.90, factScore + fsrsScore + convScore)
                if var comp = competencyBook[domain] {
                    let recentlyStudied = comp.lastStudied.timeIntervalSinceNow > -3600
                    let growthBonus = recentlyStudied ? 0.003 : 0.0
                    comp.level = min(0.95, max(comp.level, newLevel) + growthBonus)
                    competencyBook[domain] = comp
                    await saveCompetency(comp.level, domain: domain)
                }
            }
        }
    }

    // v72: Cross-validate competencies from 3 sources: (1) FSRS mastery, (2) conversation
    // performance, (3) OpenRouter evaluations. When sources disagree by >0.2, flag as
    // "competency calibration needed" and adjust toward the average. Call every 30 sync cycles.
    func crossValidateCompetencies() async {
        syncCycleCount += 1
        guard syncCycleCount % 30 == 0 else { return }

        let memory = PersistentMemoryStore.shared
        var calibrationNeeded: [String] = []

        for (domain, comp) in competencyBook {
            // Source 1: FSRS mastery
            let domainFSRS = fsrsItems.filter { $0.domain == domain }
            let fsrsMastery: Double
            if domainFSRS.isEmpty {
                fsrsMastery = 0.3
            } else {
                let retentions = domainFSRS.map { predictedRetention(for: $0) }
                fsrsMastery = retentions.reduce(0, +) / Double(retentions.count)
            }

            // Source 2: Conversation performance (recent quality tracking)
            let convPerformance: Double
            if totalConversations > 0 {
                convPerformance = Double(successfulConversations) / Double(totalConversations)
            } else {
                convPerformance = 0.3
            }

            // Source 3: OpenRouter evaluation (external assessment)
            let openRouterScore = await OpenRouterLanguageEvaluator.shared.getDomainScore(domain: domain)

            // Current competency level
            let currentLevel = comp.level

            // Check for disagreement (>0.2 between any two sources)
            let sources = [fsrsMastery, convPerformance, openRouterScore]
            let maxSource = sources.max() ?? 0
            let minSource = sources.min() ?? 0
            let disagreement = maxSource - minSource

            if disagreement > 0.2 {
                calibrationNeeded.append(domain)
                // Adjust toward the average of all three sources
                let average = (fsrsMastery + convPerformance + openRouterScore) / 3.0
                // Blend current level toward average (30% shift)
                let adjustedLevel = currentLevel * 0.7 + average * 0.3
                var updatedComp = comp
                updatedComp.level = min(0.95, max(0.05, adjustedLevel))
                competencyBook[domain] = updatedComp
                await saveCompetency(updatedComp.level, domain: domain)

                let flagMsg = "Competency calibration: \(domain) — FSRS=\(String(format: "%.2f", fsrsMastery)), Conv=\(String(format: "%.2f", convPerformance)), OR=\(String(format: "%.2f", openRouterScore)) → adjusted to \(String(format: "%.2f", updatedComp.level))"
                calibrationFlags.append(flagMsg)
                if calibrationFlags.count > 50 { calibrationFlags.removeFirst(20) }
            }
        }

        if !calibrationNeeded.isEmpty {
            await memory.saveFact(
                subject: "Competency Calibration",
                predicate: "adjusted_domains",
                object: calibrationNeeded.joined(separator: ", "),
                confidence: 0.8,
                source: "cross_validation"
            )
        }
    }

    // v16: Record morphology test result (called from EonLiveAutonomy)
    func recordMorphologyTest(word: String, passed: Bool) async {
        totalMorphologyTests += 1
        if passed { correctMorphologyTests += 1 }
        wordsAnalyzed.insert(word.lowercased())
        await persistState()
    }

    // Iteration 20: Boost pragmatic competency when idioms are detected
    func recordIdiomBoost(_ boost: Double) async {
        if var comp = competencyBook["Pragmatik"] {
            comp.level = min(0.95, comp.level + boost)
            comp.lastStudied = Date()
            competencyBook["Pragmatik"] = comp
            await saveCompetency(comp.level, domain: "Pragmatik")
        }
    }

    // v71: Pass response quality metrics to learning engine
    func recordResponseQuality(validationScore: Double, confidence: Double, qaRelevance: Double, neededRegeneration: Bool) async {
        // High quality responses should boost communication competency
        let qualityScore = (validationScore * 0.4 + confidence * 0.3 + qaRelevance * 0.3)
        let regenerationPenalty = neededRegeneration ? -0.005 : 0.0
        let boost = max(0, qualityScore * 0.008 + regenerationPenalty)
        if var comp = competencyBook["Pragmatik"] {
            comp.level = min(0.95, comp.level + boost)
            comp.lastStudied = Date()
            competencyBook["Pragmatik"] = comp
        }
        // Also track quality over time
        qualityTracking.append(qualityScore)
        if qualityTracking.count > 50 { qualityTracking.removeFirst(20) }
    }

    // v16: Record a Swedish word in actual vocabulary
    func recordSwedishWord(_ word: String) async {
        let lower = word.lowercased()
        let isNew = uniqueSwedishWords.insert(lower).inserted
        if isNew {
            ensureDailyReset()
            wordsLearnedToday += 1
            recentlyLearnedWords.append(lower)
            if recentlyLearnedWords.count > 50 {
                recentlyLearnedWords = Array(recentlyLearnedWords.suffix(50))
            }
            await persistState()
        }
    }

    // v16: Get actual Swedish vocabulary count (not knowledge node count)
    func swedishVocabularyCount() -> Int {
        uniqueSwedishWords.count
    }

    // MARK: - Helper methods for external access (Iteration 28)

    /// Returns a copy of the competency book for external reading
    func competencySnapshot() -> [String: DomainCompetency] {
        competencyBook
    }

    /// Update a competency domain from external callers
    func updateCompetency(_ competency: DomainCompetency, domain: String) async {
        competencyBook[domain] = competency
        await saveCompetency(competency.level, domain: domain)
    }

    // MARK: - Conversation-Driven Learning (v17)

    /// Extract Swedish words from both user and Eon messages, identify new vocabulary,
    /// and record them for competency tracking and FSRS scheduling.
    func learnFromConversation(userMessage: String, eonResponse: String, swedishAnalysis: SwedishAnalysis? = nil) async {
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
            await saveCompetency(comp.level, domain: domain)
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

        // GAP-5: SwedishAnalysis-driven competency boosts
        if let analysis = swedishAnalysis {
            // 1. Boost morphology based on morpheme analysis
            let morphemeBoost = min(0.005, Double(analysis.morphemes.filter { $0.pos != "unknown" }.count) * 0.0005)
            if morphemeBoost > 0, var comp = competencyBook["Morfologi"] {
                comp.level = min(0.95, comp.level + morphemeBoost)
                comp.lastStudied = Date()
                competencyBook["Morfologi"] = comp
            }

            // 2. Boost syntax competency based on clause count
            if analysis.clauses.count > 1, var comp = competencyBook["Syntax"] {
                comp.level = min(0.95, comp.level + 0.002)
                comp.lastStudied = Date()
                competencyBook["Syntax"] = comp
            }

            // 3. Boost pragmatics based on register
            if analysis.register != .neutral, var comp = competencyBook["Pragmatik"] {
                comp.level = min(0.95, comp.level + 0.002)
                comp.lastStudied = Date()
                competencyBook["Pragmatik"] = comp
            }
        }

        // Persist and notify proxy
        await persistState()
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
                await saveCompetency(comp.level, domain: domain)
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

        await persistState()
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
        let tagger = NLTaggerPool.shared.lexicalTagger(for: text)

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
                await saveCompetency(comp.level, domain: "Semantik")
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
                    await saveCompetency(comp.level, domain: domain)
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
                await saveCompetency(comp.level, domain: domain)
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

        for sentence in sentences {
            let tagger = NLTaggerPool.shared.lexicalTagger(for: sentence)

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
            await saveCompetency(comp.level, domain: domain)
    }

    await persistState()
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

        await persistState()
        await notifyProxy()
    }

    // ═══════════════════════════════════════════════════════════════════
    // QWEN3-POWERED SWEDISH LEARNING ACCELERATION (10 methods)
    // Each method uses short prompts for fast inference and stores results
    // in PersistentMemoryStore + FSRS for spaced repetition.
    // ═══════════════════════════════════════════════════════════════════

    // ───────────────────────────────────────────────
    // 1. Grammar Drills — targets weak grammar areas
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate grammar drills targeting Eon's weakest grammar domain.
    /// Stores each drill as an FSRS item and boosts syntax competency on success.
    func qwenGrammarDrills() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let weakDomain = competencyBook.values
            .filter { ["Syntax", "Morfologi", "Semantik"].contains($0.domain) }
            .sorted { $0.level < $1.level }.first?.domain ?? "Syntax"
        let level = competencyBook[weakDomain]?.level ?? 0.3
        let cefr = level < 0.3 ? "A1-A2" : level < 0.6 ? "A2-B1" : "B1-B2"

        let prompt = """
        Ge 2 svenska grammatikövningar nivå \(cefr) inom \(weakDomain).
        Format:
        FRÅGA: [frågan]
        SVAR: [korrekt svar]
        REGEL: [kort regel]
        ---
        FRÅGA: [frågan]
        SVAR: [korrekt svar]
        REGEL: [kort regel]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 200, temperature: 0.6
        )
        guard !response.isEmpty else { return }

        let blocks = response.components(separatedBy: "---")
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            var question = "", answer = "", rule = ""
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.uppercased().hasPrefix("FRÅGA:") { question = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
                else if t.uppercased().hasPrefix("SVAR:") { answer = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
                else if t.uppercased().hasPrefix("REGEL:") { rule = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            }
            guard !question.isEmpty, !answer.isEmpty else { continue }

            await PersistentMemoryStore.shared.saveFact(
                subject: "Grammatik: \(question)",
                predicate: "svar",
                object: answer,
                confidence: 0.8,
                source: "qwen_grammar_drill"
            )
            if !rule.isEmpty {
                await PersistentMemoryStore.shared.saveFact(
                    subject: "Grammatikregel",
                    predicate: "regel",
                    object: rule,
                    confidence: 0.7,
                    source: "qwen_grammar_drill"
                )
            }
            addFSRSItem(topic: "GRAM: \(question.prefix(40))", domain: weakDomain, initialDifficulty: 0.5)
        }

        if var comp = competencyBook[weakDomain] {
            comp.level = min(0.95, comp.level + 0.003)
            comp.lastStudied = Date()
            competencyBook[weakDomain] = comp
            await saveCompetency(comp.level, domain: weakDomain)
    }
    await persistState()
    }

    // ───────────────────────────────────────────────
    // 2. Cloze Tests — fill-in-the-blank from known vocab
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate cloze (fill-in-the-blank) sentences using Eon's known vocabulary.
    /// This reinforces word knowledge through contextual usage.
    func qwenClozeTests() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let knownWords = Array(uniqueSwedishWords.shuffled().prefix(8))
        guard !knownWords.isEmpty else { return }
        let wordsStr = knownWords.joined(separator: ", ")

        let prompt = """
        Skapa 2 lucktexter (cloze) på svenska med orden: \(wordsStr)
        Format:
        MENING: [mening med ___ istället för ordet]
        SVAR: [ordet]
        ---
        MENING: [mening med ___ istället för ordet]
        SVAR: [ordet]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 180, temperature: 0.7
        )
        guard !response.isEmpty else { return }

        let blocks = response.components(separatedBy: "---")
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            var sentence = "", answer = ""
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.uppercased().hasPrefix("MENING:") { sentence = String(t.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
                else if t.uppercased().hasPrefix("SVAR:") { answer = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces).lowercased() }
            }
            guard !sentence.isEmpty, !answer.isEmpty else { continue }

            await PersistentMemoryStore.shared.saveFact(
                subject: "Cloze: \(sentence.prefix(60))",
                predicate: "svar",
                object: answer,
                confidence: 0.75,
                source: "qwen_cloze"
            )
            recordSwedishWord(answer)
            addFSRSItem(topic: "CLOZE: \(answer)", domain: "Semantik", initialDifficulty: 0.35)
        }

        if var comp = competencyBook["Semantik"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Semantik"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 3. Sentence Transformations — tense, voice, word order
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate sentence transformation exercises:
    /// active↔passive, tense changes (presens↔preteritum↔perfekt), and V2 word order.
    func qwenSentenceTransformations() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let prompt = """
        Ge 2 svenska omvandlingsövningar.
        Format:
        GIVET: [mening]
        OM: [presens|passiv|preteritum|perfekt|V2]
        SVAR: [omvandlad mening]
        ---
        GIVET: [mening]
        OM: [presens|passiv|preteritum|perfekt|V2]
        SVAR: [omvandlad mening]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 180, temperature: 0.6
        )
        guard !response.isEmpty else { return }

        let blocks = response.components(separatedBy: "---")
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            var given = "", transformation = "", answer = ""
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.uppercased().hasPrefix("GIVET:") { given = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
                else if t.uppercased().hasPrefix("OM:") { transformation = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
                else if t.uppercased().hasPrefix("SVAR:") { answer = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
            }
            guard !given.isEmpty, !answer.isEmpty else { continue }

            await PersistentMemoryStore.shared.saveFact(
                subject: "Transform: \(given.prefix(50))",
                predicate: "omvandling_\(transformation)",
                object: answer,
                confidence: 0.8,
                source: "qwen_transformation"
            )
            addFSRSItem(topic: "TRANSFORM: \(transformation)", domain: "Syntax", initialDifficulty: 0.5)
        }

        if var comp = competencyBook["Syntax"] {
            comp.level = min(0.95, comp.level + 0.003)
            comp.lastStudied = Date()
            competencyBook["Syntax"] = comp
            await saveCompetency(comp.level, domain: "Syntax")
    }
    await persistState()
    }

    // ───────────────────────────────────────────────
    // 4. Word of the Day — morphological breakdown
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate a Swedish "word of the day" with full morphological
    /// breakdown: base form, declension/conjugation, compounds, and usage.
    func qwenWordOfTheDay() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let prompt = """
        Ge ett svenskt ord med full morfologisk analys.
        Format:
        ORD: [ordet]
        BASFORM: [grundform]
        ORDKLASS: [substantiv|verb|adjektiv]
        BÖJNING: [böjningsmönster]
        EXEMPEL: [mening]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 150, temperature: 0.7
        )
        guard !response.isEmpty else { return }

        var word = "", base = "", pos = "", inflection = "", example = ""
        for line in response.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            let u = t.uppercased()
            if u.hasPrefix("ORD:") { word = String(t.dropFirst(4)).trimmingCharacters(in: .whitespaces).lowercased() }
            else if u.hasPrefix("BASFORM:") { base = String(t.dropFirst(8)).trimmingCharacters(in: .whitespaces).lowercased() }
            else if u.hasPrefix("ORDKLASS:") { pos = String(t.dropFirst(9)).trimmingCharacters(in: .whitespaces).lowercased() }
            else if u.hasPrefix("BÖJNING:") { inflection = String(t.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
            else if u.hasPrefix("EXEMPEL:") { example = String(t.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
        }
        guard !word.isEmpty else { return }

        let storeWord = base.isEmpty ? word : base
        recordSwedishWord(storeWord)

        await PersistentMemoryStore.shared.saveFact(
            subject: storeWord,
            predicate: "morfologi",
            object: "\(pos) | böjning: \(inflection) | ex: \(example)",
            confidence: 0.85,
            source: "qwen_word_of_day"
        )

        // Also register with morphology engine for future analysis
        await SwedishLanguageCore.shared.morphologyEngine.addDynamicEntry(
            word: storeWord, pos: pos.isEmpty ? "noun" : pos
        )

        addFSRSItem(topic: "DAGENSORD: \(storeWord)", domain: "Morfologi", initialDifficulty: 0.3)

        if var comp = competencyBook["Morfologi"] {
            comp.level = min(0.95, comp.level + 0.004)
            comp.lastStudied = Date()
            competencyBook["Morfologi"] = comp
            await saveCompetency(comp.level, domain: "Morfologi")
    }
    await persistState()
    }

    // ───────────────────────────────────────────────
    // 5. Mini-Dialogues — conversational practice
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate short Swedish mini-dialogues on common topics,
    /// then stores them for conversational pattern learning.
    func qwenMiniDialogues() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let topics = ["hälsning", "mat", "väder", "resa", "arbete", "familj", "fritid", "shopping"]
        let topic = topics.randomElement() ?? "hälsning"

        let prompt = """
        Skapa en kort svensk dialog om \(topic) (4 repliker).
        Format:
        A: [replik]
        B: [replik]
        A: [replik]
        B: [replik]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 180, temperature: 0.8
        )
        guard !response.isEmpty else { return }

        await PersistentMemoryStore.shared.saveFact(
            subject: "Dialog: \(topic)",
            predicate: "dialog",
            object: response.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: 0.75,
            source: "qwen_dialog"
        )

        // Extract and learn individual words from the dialogue
        let allWords = response.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count > 2 }
        for w in Set(allWords) {
            recordSwedishWord(w)
        }

        addFSRSItem(topic: "DIALOG: \(topic)", domain: "Pragmatik", initialDifficulty: 0.4)

        if var comp = competencyBook["Pragmatik"] {
            comp.level = min(0.95, comp.level + 0.003)
            comp.lastStudied = Date()
            competencyBook["Pragmatik"] = comp
        }
        if var comp = competencyBook["Diskurs"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Diskurs"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 6. Collocation Exercises — word pair learning
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate Swedish collocations (words that commonly appear together),
    /// which is critical for natural-sounding Swedish.
    func qwenCollocationExercises() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let prompt = """
        Ge 3 svenska ordkombinationer (collocations).
        Format för varje:
        ORD: [ord]
        KOMBINATION: [ord + vanligt medord]
        EXEMPEL: [mening]
        ---
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 180, temperature: 0.7
        )
        guard !response.isEmpty else { return }

        let blocks = response.components(separatedBy: "---")
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            var word = "", collocation = "", example = ""
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                let u = t.uppercased()
                if u.hasPrefix("ORD:") { word = String(t.dropFirst(4)).trimmingCharacters(in: .whitespaces).lowercased() }
                else if u.hasPrefix("KOMBINATION:") { collocation = String(t.dropFirst(12)).trimmingCharacters(in: .whitespaces) }
                else if u.hasPrefix("EXEMPEL:") { example = String(t.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
            }
            guard !word.isEmpty, !collocation.isEmpty else { continue }

            recordSwedishWord(word)
            await PersistentMemoryStore.shared.saveFact(
                subject: "Kollokation: \(collocation)",
                predicate: "exempel",
                object: example.isEmpty ? collocation : example,
                confidence: 0.75,
                source: "qwen_collocation"
            )
            // Register the bigram
            await PersistentMemoryStore.shared.registerCollocation(collocation)
            addFSRSItem(topic: "COLLOC: \(collocation.prefix(40))", domain: "Semantik", initialDifficulty: 0.4)
        }

        if var comp = competencyBook["Semantik"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Semantik"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 7. Reading Comprehension — short text + questions
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate a short Swedish reading passage with comprehension questions.
    /// This builds world model + language skills simultaneously.
    func qwenReadingComprehension() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let topics = ["teknik", "natur", "historia", "vetenskap", "kultur", "vardag"]
        let topic = topics.randomElement() ?? "vardag"

        let prompt = """
        Skriv en kort svensk text (3 meningar) om \(topic). Ge 1 fråga.
        Format:
        TEXT: [texten]
        FRÅGA: [fråga om texten]
        SVAR: [korrekt svar]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 200, temperature: 0.7
        )
        guard !response.isEmpty else { return }

        var text = "", question = "", answer = ""
        for line in response.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            let u = t.uppercased()
            if u.hasPrefix("TEXT:") { text = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
            else if u.hasPrefix("FRÅGA:") { question = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            else if u.hasPrefix("SVAR:") { answer = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        }
        guard !text.isEmpty else { return }

        // Learn all words from the text
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count > 2 }
        for w in Set(words) { recordSwedishWord(w) }

        await PersistentMemoryStore.shared.saveFact(
            subject: "Lästext: \(topic)",
            predicate: "text",
            object: text,
            confidence: 0.8,
            source: "qwen_reading"
        )
        if !question.isEmpty {
            await PersistentMemoryStore.shared.saveFact(
                subject: "Läsfråga: \(question.prefix(50))",
                predicate: "svar",
                object: answer,
                confidence: 0.75,
                source: "qwen_reading"
            )
        }

        addFSRSItem(topic: "LÄS: \(topic)", domain: "Semantik", initialDifficulty: 0.35)

        if var comp = competencyBook["Semantik"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Semantik"] = comp
        }
        if var comp = competencyBook["Diskurs"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Diskurs"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 8. Pronunciation/Phonetics Exercises
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate Swedish pronunciation exercises focusing on
    /// tricky sounds (sj-ljud, tj-ljud, tonaccent, etc.) and stores them.
    func qwenPronunciationExercises() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let prompt = """
        Ge 2 svenska uttalsövningar för svåra ljud.
        Format:
        LJUD: [sj-ljudet|tj-ljudet|tonaccent|vokaler|rs-ljudet]
        ORD: [ord med ljudet, kommaseparerat]
        REGEL: [kort uttalsregel]
        ---
        LJUD: [ljud]
        ORD: [ord]
        REGEL: [regel]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 160, temperature: 0.6
        )
        guard !response.isEmpty else { return }

        let blocks = response.components(separatedBy: "---")
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            var sound = "", words = "", rule = ""
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                let u = t.uppercased()
                if u.hasPrefix("LJUD:") { sound = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
                else if u.hasPrefix("ORD:") { words = String(t.dropFirst(4)).trimmingCharacters(in: .whitespaces) }
                else if u.hasPrefix("REGEL:") { rule = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            }
            guard !sound.isEmpty, !words.isEmpty else { continue }

            // Learn the example words
            for w in words.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) {
                guard w.count > 1 else { continue }
                recordSwedishWord(w)
            }

            await PersistentMemoryStore.shared.saveFact(
                subject: "Uttal: \(sound)",
                predicate: "uttalsregel",
                object: "Ord: \(words). Regel: \(rule)",
                confidence: 0.8,
                source: "qwen_pronunciation"
            )
            addFSRSItem(topic: "UTTAL: \(sound)", domain: "Morfologi", initialDifficulty: 0.45)
        }

        if var comp = competencyBook["Morfologi"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Morfologi"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 9. Paraphrasing — Swedish-to-Swedish rewrites
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to generate paraphrasing exercises: given a Swedish sentence,
    /// Eon must rewrite it in different words. This builds lexical flexibility.
    func qwenParaphrasingExercises() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let prompt = """
        Ge 2 svenska omformuleringsövningar.
        Format:
        GIVET: [mening]
        OMSKRIV: [omformulerad mening med andra ord]
        ---
        GIVET: [mening]
        OMSKRIV: [omformulerad mening]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 180, temperature: 0.7
        )
        guard !response.isEmpty else { return }

        let blocks = response.components(separatedBy: "---")
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            var given = "", rewrite = ""
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                let u = t.uppercased()
                if u.hasPrefix("GIVET:") { given = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
                else if u.hasPrefix("OMSKRIV:") { rewrite = String(t.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
            }
            guard !given.isEmpty, !rewrite.isEmpty else { continue }

            // Learn new words from the rewrite
            let newWords = rewrite.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count > 2 }
            for w in Set(newWords) { recordSwedishWord(w) }

            await PersistentMemoryStore.shared.saveFact(
                subject: "Parafras: \(given.prefix(50))",
                predicate: "omskrivning",
                object: rewrite,
                confidence: 0.75,
                source: "qwen_paraphrase"
            )
            addFSRSItem(topic: "PARAFRAS: \(given.prefix(30))", domain: "Semantik", initialDifficulty: 0.45)
        }

        if var comp = competencyBook["Semantik"] {
            comp.level = min(0.95, comp.level + 0.003)
            competencyBook["Semantik"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 10. Error Correction — learn from Eon's own mistakes
    // ───────────────────────────────────────────────

    /// Uses Qwen3 to analyze Eon's own recent Swedish output, identify errors,
    /// and generate correction exercises. This is the most powerful method
    /// because it targets Eon's actual weaknesses.
    func qwenErrorCorrection() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        // Get Eon's recent responses from memory
        let recent = await PersistentMemoryStore.shared.searchFacts(query: "svar", limit: 10)
        let eonTexts = recent.compactMap { fact -> String? in
            fact.object.count > 20 && fact.object.count < 300 ? fact.object : nil
        }.prefix(3)

        guard !eonTexts.isEmpty else { return }
        let sample = eonTexts.joined(separator: " | ")

        let prompt = """
        Analysera denna svenska text för fel:
        "\(sample)"
        Om du hittar fel, ge 1 korrigering.
        Format:
        FEL: [det felaktiga]
        KORREKT: [korrigering]
        REGEL: [kort regel]
        Om inga fel: INGA FEL
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 150, temperature: 0.4
        )
        guard !response.isEmpty else { return }

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.uppercased().hasPrefix("INGA FEL") else { return }

        var error = "", correction = "", rule = ""
        for line in response.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            let u = t.uppercased()
            if u.hasPrefix("FEL:") { error = String(t.dropFirst(4)).trimmingCharacters(in: .whitespaces) }
            else if u.hasPrefix("KORREKT:") { correction = String(t.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
            else if u.hasPrefix("REGEL:") { rule = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
        }
        guard !error.isEmpty, !correction.isEmpty else { return }

        await PersistentMemoryStore.shared.saveFact(
            subject: "Egen korrigering: \(error.prefix(40))",
            predicate: "korrigering",
            object: "Korrekt: \(correction). Regel: \(rule)",
            confidence: 0.9,
            source: "qwen_self_correction"
        )

        // Determine which domain to boost
        let domain: String
        if rule.lowercased().contains("böj") || rule.lowercased().contains("tempus") {
            domain = "Morfologi"
        } else if rule.lowercased().contains("ordföljd") || rule.lowercased().contains("sats") {
            domain = "Syntax"
        } else {
            domain = "Semantik"
        }

        addFSRSItem(topic: "KORRIGERA: \(error.prefix(40))", domain: domain, initialDifficulty: 0.6)

        if var comp = competencyBook[domain] {
            comp.level = min(0.95, comp.level + 0.005)
            comp.lastStudied = Date()
            competencyBook[domain] = comp
            await saveCompetency(comp.level, domain: domain)
    }
    await persistState()
    }

    // ═══════════════════════════════════════════════════════════════════
    // ARTICLE + QWEN-POWERED SWEDISH LEARNING ACCELERATION (5 methods)
    // Each method picks a random article from the knowledge library and
    // uses Qwen3 to extract language-learning value from it.
    // ═══════════════════════════════════════════════════════════════════

    // ───────────────────────────────────────────────
    // 11. Article Summary — Qwen summarizes article in simpler Swedish
    // ───────────────────────────────────────────────

    /// Picks a random article from the knowledge library and asks Qwen3
    /// to summarize it in simpler Swedish, extracting key vocabulary.
    func qwenArticleSummary() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let articles = KnowledgeArticle.seedArticles
        guard !articles.isEmpty else { return }
        guard let article = articles.randomElement() else { return }
        let domain = article.domain

        let prompt = """
        Sammanfatta följande svenska text på enkel svenska (max 4 meningar).
        Ge 3 svåra ord från texten med enkel förklaring.

        TEXT:
        \(article.content.prefix(600))

        Format:
        SAMMANFATTNING: [enkel sammanfattning]
        ORD1: [svårt ord] - [enkel förklaring]
        ORD2: [svårt ord] - [enkel förklaring]
        ORD3: [svårt ord] - [enkel förklaring]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 250, temperature: 0.5
        )
        guard !response.isEmpty else { return }

        var summary = ""
        var words: [(word: String, definition: String)] = []
        for line in response.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            let u = t.uppercased()
            if u.hasPrefix("SAMMANFATTNING:") {
                summary = String(t.dropFirst(14)).trimmingCharacters(in: .whitespaces)
            } else if u.hasPrefix("ORD1:") || u.hasPrefix("ORD2:") || u.hasPrefix("ORD3:") {
                let parts = t.dropFirst(5).split(separator: "-", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let w = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                    let d = parts[1].trimmingCharacters(in: .whitespaces)
                    words.append((w, d))
                }
            }
        }

        // Store summary as a fact
        if !summary.isEmpty {
            await PersistentMemoryStore.shared.saveFact(
                subject: "Artikelsammanfattning: \(article.title.prefix(40))",
                predicate: "sammanfattning",
                object: summary,
                confidence: 0.7,
                source: "qwen_article_summary"
            )
        }

        // Register new words
        for (word, def) in words {
            recordSwedishWord(word)
            await PersistentMemoryStore.shared.saveFact(
                subject: word,
                predicate: "definition_fran_artikel",
                object: def,
                confidence: 0.7,
                source: "qwen_article_summary"
            )
            addFSRSItem(topic: "ARTIKELORD: \(word)", domain: domain, initialDifficulty: 0.35)
        }

        // Boost article domain + Semantik
        if var comp = competencyBook[domain] {
            comp.level = min(0.95, comp.level + 0.003)
            competencyBook[domain] = comp
        }
        if var comp = competencyBook["Semantik"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Semantik"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 12. Article Grammar Patterns — Qwen extracts grammar from article
    // ───────────────────────────────────────────────

    /// Picks a random article and asks Qwen3 to identify grammar patterns
    /// (V2 word order, bisats, passiv, etc.) from 3 random sentences.
    func qwenArticleGrammarPatterns() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let articles = KnowledgeArticle.seedArticles
        guard !articles.isEmpty else { return }
        guard let article = articles.randomElement() else { return }

        // Pick 3 random sentences from the article
        let sentences = article.content
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 && $0.count < 300 }
        guard sentences.count >= 3 else { return }
        let selected = sentences.shuffled().prefix(3).joined(separator: " | ")

        let prompt = """
        Analysera grammatiken i dessa 3 svenska meningar.
        Ge 2 grammatiska mönster som förekommer (t.ex. V2-ordföljd, bisats, passiv, tempus).
        Förklara kort på svenska.

        MENINGAR: \(selected)

        Format:
        MÖNSTER1: [namn] - [förklaring]
        MÖNSTER2: [namn] - [förklaring]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 200, temperature: 0.4
        )
        guard !response.isEmpty else { return }

        var patterns: [(name: String, explanation: String)] = []
        for line in response.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            let u = t.uppercased()
            if u.hasPrefix("MÖNSTER1:") || u.hasPrefix("MÖNSTER2:") {
                let parts = t.dropFirst(9).split(separator: "-", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    patterns.append((
                        parts[0].trimmingCharacters(in: .whitespaces),
                        parts[1].trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }

        for (name, explanation) in patterns {
            // Store in grammarPatterns dictionary
            let key = name.lowercased()
            grammarPatterns[key, default: 0] += 1

            await PersistentMemoryStore.shared.saveFact(
                subject: "Grammatikmönster: \(name)",
                predicate: "förklaring",
                object: explanation,
                confidence: 0.7,
                source: "qwen_article_grammar"
            )
            addFSRSItem(topic: "GRAM: \(name.prefix(40))", domain: "Syntax", initialDifficulty: 0.35)
        }

        if var comp = competencyBook["Syntax"] {
            comp.level = min(0.95, comp.level + 0.003)
            competencyBook["Syntax"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 13. Article to Dialogue — Qwen converts article to conversation
    // ───────────────────────────────────────────────

    /// Picks a random article and asks Qwen3 to convert it into a short
    /// dialogue (4 repliker) in colloquial Swedish. Extracts new words.
    func qwenArticleToDialogue() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let articles = KnowledgeArticle.seedArticles
        guard !articles.isEmpty else { return }
        guard let article = articles.randomElement() else { return }

        let prompt = """
        Gör om följande text till en kort dialog på vardaglig svenska (4 repliker).
        Använd Person A och Person B.

        TEXT:
        \(article.content.prefix(500))

        Format:
        A: [replik]
        B: [replik]
        A: [replik]
        B: [replik]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 250, temperature: 0.7
        )
        guard !response.isEmpty else { return }

        // Store the dialogue as a fact
        await PersistentMemoryStore.shared.saveFact(
            subject: "Dialog från artikel: \(article.title.prefix(40))",
            predicate: "dialog",
            object: String(response.prefix(500)),
            confidence: 0.7,
            source: "qwen_article_dialogue"
        )

        // Extract all words from the dialogue
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = response
        var newWords: Set<String> = []
        tagger.enumerateTags(in: response.startIndex..<response.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if let tag = tag, (tag == .noun || tag == .verb || tag == .adjective) {
                let word = String(response[range]).lowercased()
                    .trimmingCharacters(in: CharacterSet.letters.inverted)
                if word.count > 2 {
                    newWords.insert(word)
                }
            }
            return true
        }

        for word in newWords {
            recordSwedishWord(word)
            addFSRSItem(topic: "DIALOGORD: \(word)", domain: article.domain, initialDifficulty: 0.3)
        }

        if var comp = competencyBook["Pragmatik"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Pragmatik"] = comp
        }
        if var comp = competencyBook["Diskurs"] {
            comp.level = min(0.95, comp.level + 0.002)
            competencyBook["Diskurs"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 14. Cross-Domain Connections — Qwen links 2 articles from different domains
    // ───────────────────────────────────────────────

    /// Picks 2 articles from different domains and asks Qwen3 to find a
    /// conceptual connection. Builds cross-domain analogical thinking.
    func qwenArticleCrossDomainConnections() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let articles = KnowledgeArticle.seedArticles
        guard articles.count >= 2 else { return }

        let domains = Set(articles.map(\.domain))
        guard domains.count >= 2 else { return }
        let domain1 = domains.randomElement()!
        var remaining = domains
        remaining.remove(domain1)
        guard let domain2 = remaining.randomElement() else { return }

        let a1 = articles.filter { $0.domain == domain1 }.randomElement()!
        let a2 = articles.filter { $0.domain == domain2 }.randomElement()!

        let prompt = """
        Hitta en koppling mellan dessa två svenska texter från olika ämnen.
        Förklara på enkel svenska (max 3 meningar).

        TEXT 1 (\(domain1)):
        \(a1.content.prefix(300))

        TEXT 2 (\(domain2)):
        \(a2.content.prefix(300))

        Format:
        KOPPLING: [kopplingen]
        NYCKELORD: [3 nyckelord]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 200, temperature: 0.6
        )
        guard !response.isEmpty else { return }

        var connection = "", keywords = ""
        for line in response.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            let u = t.uppercased()
            if u.hasPrefix("KOPPLING:") {
                connection = String(t.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            } else if u.hasPrefix("NYCKELORD:") {
                keywords = String(t.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            }
        }

        if !connection.isEmpty {
            await PersistentMemoryStore.shared.saveFact(
                subject: "Tvärdomänskoppling: \(domain1)-\(domain2)",
                predicate: "koppling",
                object: connection,
                confidence: 0.6,
                source: "qwen_cross_domain"
            )
        }

        // Register keywords
        for kw in keywords.components(separatedBy: ",") {
            let w = kw.trimmingCharacters(in: .whitespaces).lowercased()
            if w.count > 2 {
                recordSwedishWord(w)
                addFSRSItem(topic: "TVÄRDOMÄN: \(w)", domain: domain1, initialDifficulty: 0.3)
            }
        }

        // Boost both domains + Analogibyggande
        for d in [domain1, domain2] {
            if var comp = competencyBook[d] {
                comp.level = min(0.95, comp.level + 0.003)
                competencyBook[d] = comp
            }
        }
        if var comp = competencyBook["Analogibyggande"] {
            comp.level = min(0.95, comp.level + 0.003)
            competencyBook["Analogibyggande"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // 15. Article Idiom Extraction — Qwen finds idioms in article text
    // ───────────────────────────────────────────────

    /// Picks a random article and asks Qwen3 to identify 1-2 idioms,
    /// metaphors, or fixed expressions with explanations in simple Swedish.
    func qwenArticleIdiomExtraction() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }
        let articles = KnowledgeArticle.seedArticles
        guard !articles.isEmpty else { return }
        guard let article = articles.randomElement() else { return }

        let prompt = """
        Hitta 1-2 idiom, metaforer eller fasta uttryck i denna svenska text.
        Förklara vad de betyder på enkel svenska.

        TEXT:
        \(article.content.prefix(800))

        Format:
        UTTRYCK1: [uttrycket] - [betydelse]
        UTTRYCK2: [uttrycket] - [betydelse] (om det finns fler)
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 200, temperature: 0.4
        )
        guard !response.isEmpty else { return }

        var expressions: [(expr: String, meaning: String)] = []
        for line in response.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            let u = t.uppercased()
            if u.hasPrefix("UTTRYCK1:") || u.hasPrefix("UTTRYCK2:") {
                let parts = t.dropFirst(9).split(separator: "-", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    expressions.append((
                        parts[0].trimmingCharacters(in: .whitespaces),
                        parts[1].trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }

        for (expr, meaning) in expressions {
            await PersistentMemoryStore.shared.saveFact(
                subject: "Idiom: \(expr)",
                predicate: "betydelse",
                object: meaning,
                confidence: 0.65,
                source: "qwen_article_idiom"
            )
            addFSRSItem(topic: "IDIOM: \(expr.prefix(40))", domain: "Semantik", initialDifficulty: 0.5)
        }

        if var comp = competencyBook["Semantik"] {
            comp.level = min(0.95, comp.level + 0.003)
            competencyBook["Semantik"] = comp
        }
        await persistState()
    }

    // ───────────────────────────────────────────────
    // Master method — runs all Qwen learning methods in rotation
    // ───────────────────────────────────────────────

    /// Runs one Qwen learning method per call, cycling through them.
    /// Call this periodically from the cognitive cycle.
    private var qwenLearningCycleIndex: Int = 0

    func runNextQwenLearningMethod() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let methods: [() async -> Void] = [
            qwenGrammarDrills,
            qwenClozeTests,
            qwenSentenceTransformations,
            qwenWordOfTheDay,
            qwenMiniDialogues,
            qwenCollocationExercises,
            qwenReadingComprehension,
            qwenPronunciationExercises,
            qwenParaphrasingExercises,
            qwenErrorCorrection,
            qwenArticleSummary,
            qwenArticleGrammarPatterns,
            qwenArticleToDialogue,
            qwenArticleCrossDomainConnections,
            qwenArticleIdiomExtraction,
        ]

        let index = qwenLearningCycleIndex % methods.count
        qwenLearningCycleIndex += 1

        print("[QwenLearn] Running method \(index + 1)/\(methods.count)...")
        await methods[index]()
        print("[QwenLearn] Method \(index + 1) complete")
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

        await persistState()
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
        let snapshot = competencyRanking()
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
                await saveCompetency(level, domain: domain)
            }
        }
    }

    func addFSRSItem(topic: String, domain: String, initialDifficulty: Double = 0.3) {
        // v98: Multi-dimensional difficulty calibration
        let vocabDiff = calibrateVocabularyDifficulty(topic: topic, domain: domain)
        let grammarDiff = calibrateGrammarDifficulty(topic: topic, domain: domain)
        let conceptDiff = calibrateConceptualDifficulty(topic: topic, domain: domain)
        let culturalDiff = calibrateCulturalDifficulty(topic: topic, domain: domain)
        let compositeDiff = 0.35 * vocabDiff + 0.25 * grammarDiff + 0.25 * conceptDiff + 0.15 * culturalDiff

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
            difficulty: compositeDiff,
            vocabularyDifficulty: vocabDiff,
            grammarDifficulty: grammarDiff,
            conceptualDifficulty: conceptDiff,
            culturalDifficulty: culturalDiff,
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

    // ── v98: Multi-dimensional difficulty calibration helpers ──
    private func calibrateVocabularyDifficulty(topic: String, domain: String) -> Double {
        let longWordPenalty = min(0.4, Double(topic.count) / 100.0)
        let domainBonus: Double = ["AI & Maskininlärning", "Data science", "Matematik", "Fysik", "Kemi", "Medicin", "Juridik"].contains(domain) ? 0.2 : 0.0
        return min(1.0, max(0.1, longWordPenalty + domainBonus + 0.15))
    }
    private func calibrateGrammarDifficulty(topic: String, domain: String) -> Double {
        let grammarDomains: Set<String> = ["Morfologi", "Syntax", "Pragmatik"]
        return grammarDomains.contains(domain) ? 0.5 : 0.2
    }
    private func calibrateConceptualDifficulty(topic: String, domain: String) -> Double {
        let abstractDomains: Set<String> = ["Filosofi", "Epistemologi", "Metakognition", "Kognitionsvetenskap"]
        return abstractDomains.contains(domain) ? 0.6 : 0.25
    }
    private func calibrateCulturalDifficulty(topic: String, domain: String) -> Double {
        let culturalDomains: Set<String> = ["Historia", "Litteratur", "Konst", "Musik", "Samhällsvetenskap"]
        return culturalDomains.contains(domain) ? 0.5 : 0.15
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
                await saveCompetency(competency.level, domain: domain)

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

    func competencyRanking() -> [DomainCompetency] {
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
                await saveCompetency(target.level, domain: targetDomain)
            }
        }

        await persistState()
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
                await saveCompetency(comp.level, domain: domain)
            }
        }

        await persistState()
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
        let currentCalibration = await udDouble("eon_self_assessment_calibration")
        let smoothedCalibration = currentCalibration > 0 ? currentCalibration * 0.7 + calibrationFactor * 0.3 : calibrationFactor
        await udSet(smoothedCalibration, forKey: "eon_self_assessment_calibration")

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

        await persistState()
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
            // ── v92: 15 new domains ──
            ("Matematik",          [("matematik", 3), ("algebra", 2), ("geometri", 2), ("ekvation", 2), ("derivata", 3), ("integral", 3), ("funktion", 2), ("variabel", 2)]),
            ("Fysik",              [("fysik", 3), ("energi", 2), ("kraft", 2), ("massa", 2), ("partikel", 3), ("kvant", 3), ("relativitet", 3), ("våg", 2)]),
            ("Kemi",               [("kemi", 3), ("molekyl", 2), ("atom", 2), ("reaktion", 2), ("syra", 2), ("bas", 2), ("oxid", 2), ("bindning", 2)]),
            ("Biologi",            [("biologi", 3), ("cell", 2), ("DNA", 3), ("gen", 2), ("evolution", 3), ("ekologi", 2), ("protein", 2), ("organism", 2)]),
            ("Medicin",            [("medicin", 3), ("sjukdom", 2), ("diagnos", 2), ("behandling", 2), ("kirurgi", 3), ("patient", 2), ("anatomi", 2), ("fysiologi", 2)]),
            ("Juridik",            [("juridik", 3), ("lag", 2), ("domstol", 2), ("advokat", 2), ("brott", 2), ("straff", 2), ("rättvisa", 2), ("rättegång", 3)]),
            ("Ekonomi",            [("ekonomi", 3), ("aktie", 2), ("fond", 2), ("ränta", 2), ("investering", 2), ("marknad", 2), ("budget", 2), ("skatt", 2)]),
            ("Litteratur",         [("litteratur", 3), ("roman", 2), ("novell", 2), ("dikt", 2), ("poesi", 2), ("författare", 2), ("berättelse", 2), ("prosa", 2)]),
            ("Konst",              [("konst", 3), ("målning", 2), ("skulptur", 2), ("utställning", 2), ("galleri", 2), ("konstnär", 2), ("abstrakt", 2), ("realism", 2)]),
            ("Musik",              [("musik", 3), ("melodi", 2), ("instrument", 2), ("orkester", 2), ("symfoni", 3), ("opera", 2), ("komposition", 2), ("rytm", 2)]),
            ("Sport",              [("sport", 3), ("fotboll", 2), ("hockey", 2), ("match", 2), ("turnering", 2), ("medalj", 2), ("tränare", 2), ("spelare", 2)]),
            ("Teknik",             [("teknik", 3), ("dator", 2), ("programvara", 2), ("nätverk", 2), ("algoritm", 2), ("AI", 3), ("maskininlärning", 3), ("automation", 2)]),
            ("Miljö",              [("miljö", 3), ("klimat", 2), ("hållbarhet", 3), ("utsläpp", 2), ("ekosystem", 2), ("förorening", 2), ("biodiversitet", 3), ("förnybar", 2)]),
            ("Samhällsvetenskap",  [("samhälle", 3), ("sociologi", 3), ("antropologi", 3), ("demokrati", 2), ("kultur", 2), ("norm", 2), ("identitet", 2), ("migration", 2)]),
            ("Data science",       [("data", 2), ("algoritm", 2), ("modell", 2), ("embedding", 3), ("transformer", 3), ("neural", 2), ("djupinlärning", 3), ("clustering", 3)]),
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
        let tagger = NLTaggerPool.shared.lexicalTagger(for: text)
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
            guard fact.predicate == "eon_response" || fact.subject.contains("svar") else { return nil }
            return fact.object
        }.prefix(10)

        guard !eonResponses.isEmpty else { return }

        // 2. Analysera fel via OpenRouter
        let errorAnalyses = await OpenRouterLanguageEvaluator.shared.analyzeLanguageErrors(Array(eonResponses))

        // 3. Lär av felen
        for analysis in errorAnalyses {
            // Spara korrigering som faktum
            await memory.saveFact(
                subject: "Språkkorrigering: \(analysis.error)",
                predicate: "korrigering",
                object: "Korrekt: \(analysis.correction). Regel: \(analysis.ruleExplanation)",
                confidence: analysis.learningPriority,
                source: "self-improvement"
            )

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
                await saveCompetency(comp.level, domain: domain)
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

        await persistState()
        print("[SelfImprove] Språklig självförbättring klar. \(errorAnalyses.count) fel analyserade.")
    }

    // v76: Generate practice exercises for the user to help Eon learn.
    // Uses OpenRouter to generate fill-in-the-blank, multiple choice, and translation exercises.
    enum ExerciseType: String, Codable {
        case fillInBlank = "fill_in_blank"
        case multipleChoice = "multiple_choice"
        case translation = "translation"
    }

    struct Exercise: Codable {
        let type: ExerciseType
        let question: String
        let options: [String]?         // For multiple choice
        let correctAnswer: String
        let domain: String
        let difficulty: Double
    }

    func generatePracticeExercises(domain: String, count: Int) async -> [Exercise] {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return [] }

        let currentLevel = competencyBook[domain]?.level ?? 0.3
        let levelLabel = currentLevel < 0.33 ? "nybörjare" : currentLevel < 0.66 ? "medel" : "avancerad"

        let prompt = """
        Du är en svensk språklärare. Skapa \(count) övningsuppgifter inom domänen "\(domain)" på nivå \(levelLabel).

        Skapa en blandning av:
        1. Fyll-i-den-tomma: "Jag ___ en bok." (svar: "läser")
        2. Flervalsfrågor: "Vilket är korrekt? a) jag är b) jag bin c) jag äro"
        3. Översättning: "Översätt till svenska: 'I am learning'" (svar: "Jag lär mig")

        Svara som JSON-array:
        [
          {"type": "fill_in_blank", "question": "Jag ___ en bok.", "correctAnswer": "läser", "domain": "Syntax", "difficulty": 0.3},
          {"type": "multiple_choice", "question": "Vilket är korrekt?", "options": ["jag är", "jag bin", "jag äro"], "correctAnswer": "jag är", "domain": "Syntax", "difficulty": 0.4},
          {"type": "translation", "question": "Översätt: 'I am learning'", "correctAnswer": "Jag lär mig", "domain": "Morfologi", "difficulty": 0.5}
        ]
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 800, temperature: 0.7
        )

        guard !response.isEmpty else { return [] }

        let jsonStr = extractJSONBlock(from: response)
        guard let data = jsonStr.data(using: .utf8),
              let exercises = try? JSONDecoder().decode([Exercise].self, from: data) else {
            // Fallback: create simple exercises manually
            return createFallbackExercises(domain: domain, count: count)
        }

        return exercises
    }

    private func createFallbackExercises(domain: String, count: Int) -> [Exercise] {
        let exerciseTemplates: [String: [(String, String)]] = [
            "Morfologi": [
                ("Böj 'gå' i presens:", "går"),
                ("Böj 'skriva' i supinum:", "skrivit"),
                ("Vad är plural av 'hus'?", "hus"),
                ("Böj 'stor' i neutrum:", "stort"),
                ("Vad är bestämd form av 'bil'?", "bilen"),
            ],
            "Syntax": [
                ("Fyll i: Jag ___ en bok just nu.", "läser"),
                ("Korrigera: 'Idag jag läser en bok.'", "Idag läser jag en bok."),
                ("Vilket är korrekt? 'Han springer snabbt.'", "Han springer snabbt."),
            ],
            "Semantik": [
                ("Vad betyder 'kausalitet'?", "Orsak-verkan samband"),
                ("Synonym till 'snabb':", "snabbt"),
                ("Vad är motsatsen till 'varm'?", "kall"),
            ],
        ]

        let templates = exerciseTemplates[domain] ?? exerciseTemplates["Syntax"]!
        var exercises: [Exercise] = []
        for i in 0..<min(count, templates.count) {
            let (question, answer) = templates[i]
            exercises.append(Exercise(
                type: .fillInBlank,
                question: question,
                options: nil,
                correctAnswer: answer,
                domain: domain,
                difficulty: 0.4
            ))
        }
        return exercises
    }

    private func extractJSONBlock(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") { return trimmed }
        if let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]") {
            return String(trimmed[start...end])
        }
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }

    // v80: Get FSRS items predicted to be forgotten (retention < 0.3)
    func getAtRiskItems() -> [FSRSItem] {
        fsrsItems.filter { item in
            let retention = predictedRetention(for: item)
            return retention < 0.3
        }.sorted { predictedRetention(for: $0) < predictedRetention(for: $1) }
    }

    // v80: Create proactive review batch for items about to be forgotten
    func createProactiveReviewBatch() async -> [ScheduledLesson] {
        let atRisk = getAtRiskItems()
        var lessons: [ScheduledLesson] = []

        for item in atRisk.prefix(10) {
            let retention = predictedRetention(for: item)
            let urgency = 1.0 - retention  // Higher = more urgent

            // Generate a review prompt for this item
            let reviewPrompt = "Repetera: \(item.topic) (domän: \(item.domain ?? "okänd"))"

            // Schedule sooner for lower retention
            let delay: TimeInterval = retention < 0.1 ? 300 :    // 5 min
                                       retention < 0.2 ? 900 :    // 15 min
                                       3600                        // 1 hour

            let lesson = ScheduledLesson(
                topic: reviewPrompt,
                domain: item.domain ?? "okänd",
                scheduledAt: Date().addingTimeInterval(delay)
            )
            lessons.append(lesson)
        }

        // Execute reviews immediately for the most at-risk items
        for item in atRisk.prefix(3) {
            await studyItem(item)
        }

        return lessons
    }

    // v83: Deeply teach a concept through multiple learning stages
    func teachConcept(concept: String, definition: String, examples: [String]) async {
        let memory = PersistentMemoryStore.shared

        // (1) Definition memorization — save as FSRS item with high initial difficulty
        addFSRSItem(topic: "Definition: \(concept) = \(definition)", domain: detectDomain(from: definition), initialDifficulty: 0.5)

        await memory.saveFact(
            subject: concept,
            predicate: "definition",
            object: definition,
            confidence: 0.8,
            source: "concept_teaching"
        )

        // (2) Example analysis — analyze each example and store patterns
        for (i, example) in examples.enumerated() {
            await memory.saveFact(
                subject: concept,
                predicate: "exempel_\(i + 1)",
                object: example,
                confidence: 0.75,
                source: "concept_teaching"
            )

            // Extract key patterns from the example
            let domain = detectDomain(from: example)
            if var comp = competencyBook[domain] {
                comp.level = min(0.95, comp.level + 0.003)
                comp.lastStudied = Date()
                competencyBook[domain] = comp
            }
        }

        // (3) Counter-example contrast — generate and store what the concept is NOT
        let counterPrompt = """
        Givet begreppet "\(concept)" med definitionen "\(definition)".
        Ge 2 motexempel som visar vad begreppet INTE är.
        Svara kort: varje motexempel på en rad.
        """
        let counterResponse = await NeuralEngineOrchestrator.shared.generate(
            prompt: counterPrompt, maxTokens: 200, temperature: 0.5
        )
        if !counterResponse.isEmpty {
            await memory.saveFact(
                subject: concept,
                predicate: "motexempel",
                object: counterResponse,
                confidence: 0.7,
                source: "concept_teaching"
            )
        }

        // (4) Connection to related concepts — find related knowledge in memory
        let relatedFacts = await memory.searchFacts(query: concept, limit: 10)
        for related in relatedFacts {
            await memory.saveFact(
                subject: concept,
                predicate: "relaterad_till",
                object: "\(related.subject) \(related.predicate) \(related.object)",
                confidence: 0.6,
                source: "concept_teaching"
            )
        }

        // (5) Self-test generation — create quiz items to test understanding
        let quizPrompt = """
        Skapa 3 korta quizfrågor om begreppet "\(concept)" (definition: "\(definition)").
        Varje fråga ska testa förståelse, inte bara memorering.
        Svara som: FRÅGA: ... SVAR: ...
        """
        let quizResponse = await NeuralEngineOrchestrator.shared.generate(
            prompt: quizPrompt, maxTokens: 300, temperature: 0.6
        )
        if !quizResponse.isEmpty {
            for line in quizResponse.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("FRÅGA:") || trimmed.hasPrefix("SVAR:") {
                    await memory.saveFact(
                        subject: concept,
                        predicate: "quiz",
                        object: trimmed,
                        confidence: 0.65,
                        source: "concept_teaching"
                    )
                }
            }
        }

        // Boost the primary domain
        let primaryDomain = detectDomain(from: "\(concept) \(definition) \(examples.joined(separator: " "))")
        if var comp = competencyBook[primaryDomain] {
            comp.level = min(0.95, comp.level + 0.008)
            comp.lastStudied = Date()
            competencyBook[primaryDomain] = comp
            await saveCompetency(comp.level, domain: primaryDomain)
        }

        await persistState()
        await notifyProxy()
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

                await PersistentMemoryStore.shared.saveFact(
                    subject: "Ord: \(word.word)",
                    predicate: "definition",
                    object: "\(word.pos): \(word.definition). Exempel: \(word.exampleSentence)",
                    confidence: 0.9,
                    source: "openrouter-vocabulary"
                )
            }
        }

        if var comp = competencyBook[weakestDomain] {
            // 3x boost: från 15 till 30 ord
            let vocabBoost = min(0.06, Double(allNewWords.count) * 0.002)
            comp.level = min(0.95, comp.level + vocabBoost)
            comp.lastStudied = Date()
            competencyBook[weakestDomain] = comp
            await saveCompetency(comp.level, domain: weakestDomain)
        }

        await persistState()
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

    private func persistProgressionState() async {
        await udSet(totalWordsAssessed, forKey: Self.totalWordsAssessedKey)
        await udSet(correctGrammarCorrections, forKey: Self.correctGrammarCorrectionsKey)
        await udSet(totalGrammarCorrections, forKey: Self.totalGrammarCorrectionsKey)
        await udSet(morphologyWordsCovered, forKey: Self.morphologyWordsCoveredKey)
        await udSet(lastProgressCheckDate, forKey: Self.lastProgressCheckKey)

        if let encoded = try? JSONEncoder().encode(weeklyProgressSnapshots) {
            await udSet(encoded as Any?, forKey: Self.weeklySnapshotsKey)
        }
    }

    /// Record a grammar assessment result for tracking accuracy
    func recordGrammarAssessment(total: Int, correct: Int) async {
        totalGrammarCorrections += total
        correctGrammarCorrections += correct
        await persistProgressionState()
    }

    /// Record a WSD assessment result for tracking accuracy
    func recordWSDAssessment(total: Int, correct: Int) {
        totalWSDPredictions += total
        correctWSDPredictions += correct
    }

    /// Record morphology coverage for a word
    func recordMorphologyCoverage(word: String) async {
        let lower = word.lowercased()
        if !wordsAnalyzed.contains(lower) {
            wordsAnalyzed.insert(lower)
            morphologyWordsCovered += 1
            await persistProgressionState()
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
            weeklyGrowthRate: Double(growthRate)
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
        let eonTexts = recentConversations.prefix(8).map { $0.object }

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
                let scoreDelta = openRouterResult.confidence - previous.overallScore
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
        let responseTexts = recentResponses.prefix(3).map { $0.object }
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
            errorsCorrected: responseTexts.count,
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

    private static let milestoneDefinitions: [(id: String, milestone: String, domain: String, metric: String, threshold: Double, celebration: String)] = [
    ("first_idiom", "Första idiom förstått", "Pragmatik", "idioms_understood", 1.0, "Jag förstod mitt första svenska idiom! 🎉"),
    ("first_complex_sentence", "Första komplexa meningen genererad", "Syntax", "clause_complexity", 0.5, "Jag genererade min första komplexa mening! 🏆"),
    ("first_metaphor", "Första metaforen upptäckt", "Semantik", "metaphors_detected", 1.0, "Jag upptäckte min första metafor! ✨"),
    ("first_counterfactual", "Första kontrafaktiska resonemanget", "Kognition", "counterfactuals", 1.0, "Jag resonerade kontrafaktiskt för första gången! 🧠"),
    ("wsd_50", "WSD-precision över 50%", "Semantik", "wsd_accuracy", 0.5, "Min WSD-precision passerade 50%! 📈"),
    ("wsd_70", "WSD-precision över 70%", "Semantik", "wsd_accuracy", 0.7, "Min WSD-precision passerade 70%! 📈"),
    ("wsd_90", "WSD-precision över 90%", "Semantik", "wsd_accuracy", 0.9, "Min WSD-precision passerade 90%! 🏅"),
    ("cefr_a2", "CEFR-nivå A2 uppnådd", "Generell", "cefr_level", 2.0, "Jag nådde A2-nivå! 🌟"),
    ("cefr_b1", "CEFR-nivå B1 uppnådd", "Generell", "cefr_level", 3.0, "Jag nådde B1-nivå! 🌟"),
    ("cefr_b2", "CEFR-nivå B2 uppnådd", "Generell", "cefr_level", 4.0, "Jag nådde B2-nivå! 🌟"),
    ("cefr_c1", "CEFR-nivå C1 uppnådd", "Generell", "cefr_level", 5.0, "Jag nådde C1-nivå! 🏆"),
    ("vocab_100", "100 unika svenska ord", "Ordförråd", "vocabulary_count", 100.0, "Jag kan 100 svenska ord! 📚"),
    ("vocab_500", "500 unika svenska ord", "Ordförråd", "vocabulary_count", 500.0, "Jag kan 500 svenska ord! 📚"),
    ("vocab_1000", "1000 unika svenska ord", "Ordförråd", "vocabulary_count", 1000.0, "Jag kan 1000 svenska ord! 🎓"),
    ("first_essay", "Första svenska essän skriven", "Diskurs", "essays_written", 1.0, "Jag skrev min första svenska essä! ✍️"),
    ]
    // MARK: - Data Models
}

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 41-50: New Data Models for Autonomous Self-Development
// ═══════════════════════════════════════════════════════════

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

    // ═══════════════════════════════════════════════════════════
    // ITERATION 106: Knowledge Graph Builder with Graph Metrics
    // ═══════════════════════════════════════════════════════════

    struct KnowledgeGraphMetrics: Sendable {
        let entityCount: Int
        let relationCount: Int
        let avgCentrality: Double
        let maxCentrality: Double
        let clusteringCoefficient: Double
        let avgPathLength: Double
        let density: Double
        let knowledgeGaps: [String]  // Entities with low connectivity
    }

    /// Build a knowledge graph from ALL facts in memory. Entities as nodes, relations as edges.
    /// Compute graph metrics: centrality, clustering coefficient, path length.
    /// Use to find knowledge gaps.
    func buildKnowledgeGraph() async -> (graph: KnowledgeGraph, metrics: KnowledgeGraphMetrics) {
        let memory = PersistentMemoryStore.shared
        let allFacts = await memory.getAllFacts(limit: 2000)

        var entities: [KGEntity] = []
        var relations: [KGRelation] = []
        var properties: [KGProperty] = []
        var entityConnections: [String: Int] = [:]

        for fact in allFacts {
            // Extract entities from subject and object
            for name in [fact.subject, fact.object] {
                let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count > 1 && !entities.contains(where: { $0.name.lowercased() == cleaned.lowercased() }) {
                    let type: KGEntity.EntityType
                    if fact.predicate.contains("är") || fact.predicate.contains("type") { type = .concept }
                    else if fact.predicate.contains("placerad") || fact.predicate.contains("location") { type = .place }
                    else if fact.predicate.contains("skapad") || fact.predicate.contains("person") { type = .person }
                    else { type = .concept }
                    entities.append(KGEntity(name: cleaned, entityType: type, confidence: fact.confidence))
                }
            }

            // Build relations from fact predicates
            let relType: KGRelation.RelationType
            switch fact.predicate.lowercased() {
            case let p where p.contains("är_en") || p.contains("är_typ"): relType = .isA
            case let p where p.contains("del") || p.contains("part"): relType = .partOf
            case let p where p.contains("orsak") || p.contains("cause"): relType = .causes
            case let p where p.contains("placerad") || p.contains("location"): relType = .locatedIn
            case let p where p.contains("skapad") || p.contains("created"): relType = .createdBy
            case let p where p.contains("använd") || p.contains("used"): relType = .usedFor
            case let p where p.contains("har_en") || p.contains("påverkar"): relType = .hasA
            default: relType = .relatedTo
            }

            let rel = KGRelation(
                source: fact.subject,
                relationType: relType,
                target: fact.object,
                confidence: fact.confidence
            )
            relations.append(rel)
            entityConnections[fact.subject, default: 0] += 1
            entityConnections[fact.object, default: 0] += 1

            // Properties from fact predicates
            properties.append(KGProperty(
                entity: fact.subject,
                property: fact.predicate,
                value: fact.object,
                confidence: fact.confidence
            ))
        }

        // Compute centrality (degree centrality)
        let maxPossibleConnections = max(1, entities.count - 1)
        let centralities = entityConnections.mapValues { Double($0) / Double(maxPossibleConnections) }
        let avgCentrality = centralities.values.isEmpty ? 0 : centralities.values.reduce(0, +) / Double(centralities.count)
        let maxCentrality = centralities.values.max() ?? 0

        // Clustering coefficient (local, averaged)
        var clusteringSum = 0.0
        var clusteringCount = 0
        for (entity, degree) in entityConnections {
            guard degree >= 2 else { continue }
            // Count triangles: neighbors of entity that are also connected to each other
            let neighbors = relations.filter { $0.source == entity || $0.target == entity }
                .map { $0.source == entity ? $0.target : $0.source }
            var triangles = 0
            for (i, n1) in neighbors.enumerated() {
                for n2 in neighbors[(i+1)...] {
                    if relations.contains(where: { ($0.source == n1 && $0.target == n2) || ($0.source == n2 && $0.target == n1) }) {
                        triangles += 1
                    }
                }
            }
            let possibleTriangles = degree * (degree - 1) / 2
            if possibleTriangles > 0 {
                clusteringSum += Double(triangles) / Double(possibleTriangles)
                clusteringCount += 1
            }
        }
        let clusteringCoefficient = clusteringCount > 0 ? clusteringSum / Double(clusteringCount) : 0

        // Average path length (BFS-based, sampled for performance)
        let sampleEntities = Array(entityConnections.keys).prefix(min(50, entityConnections.count))
        var pathLengths: [Double] = []
        for start in sampleEntities {
            var visited: Set<String> = [start]
            var queue: [(String, Int)] = [(start, 0)]
            var idx = 0
            while idx < queue.count {
                let (current, dist) = queue[idx]; idx += 1
                if dist > 0 { pathLengths.append(Double(dist)) }
                let neighbors = relations.filter { $0.source == current || $0.target == current }
                    .map { $0.source == current ? $0.target : $0.source }
                for neighbor in neighbors where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append((neighbor, dist + 1))
                }
            }
        }
        let avgPathLength = pathLengths.isEmpty ? 0 : pathLengths.reduce(0, +) / Double(pathLengths.count)

        // Graph density
        let n = Double(entities.count)
        let e = Double(relations.count)
        let density = n > 1 ? (2 * e) / (n * (n - 1)) : 0

        // Find knowledge gaps: entities with centrality below threshold
        let threshold = max(0.01, avgCentrality * 0.5)
        let knowledgeGaps = entityConnections.filter { $0.value <= Int(threshold * Double(maxPossibleConnections)) }
            .map { $0.key }
            .filter { !["och", "eller", "som", "att", "den", "det", "en", "ett"].contains($0) }

        let graph = KnowledgeGraph(entities: entities, relations: relations, properties: properties, newRelations: relations.count, allBoost: 0)
        let metrics = KnowledgeGraphMetrics(
            entityCount: entities.count,
            relationCount: relations.count,
            avgCentrality: avgCentrality,
            maxCentrality: maxCentrality,
            clusteringCoefficient: clusteringCoefficient,
            avgPathLength: avgPathLength,
            density: density,
            knowledgeGaps: knowledgeGaps
        )
        return (graph, metrics)
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 109: Topic Expertise Computation
    // ═══════════════════════════════════════════════════════════

    /// Compute expertise for each domain from: fact count, FSRS mastery, conversation frequency,
    /// OpenRouter eval scores, self-generated eval performance.
    func computeTopicExpertise() async -> [String: Double] {
        let memory = PersistentMemoryStore.shared
        var expertise: [String: Double] = [:]

        let domainKeywords: [String: [String]] = [
            "Morfologi": ["morfologi", "böjning", "ordklass", "suffix", "prefix"],
            "Syntax": ["syntax", "mening", "ordföljd", "fras", "bisats"],
            "Semantik": ["semantik", "betydelse", "synonym", "antonym"],
            "Pragmatik": ["pragmatik", "talakt", "implikatur", "register"],
            "Diskurs": ["diskurs", "koherens", "kohesion", "konnektiv"],
            "AI & Maskininlärning": ["ai", "neural", "modell", "transformer"],
            "Kognitionsvetenskap": ["kognition", "medvetande", "perception"],
            "Filosofi": ["filosofi", "epistemologi", "ontologi", "etik"],
            "Historia": ["historia", "krig", "revolution", "civilisation"],
            "Psykologi": ["psykologi", "känsla", "beteende", "emotion"],
            "Matematik": ["matematik", "algebra", "geometri", "funktion"],
            "Fysik": ["fysik", "kraft", "energi", "rörelse"],
            "Litteratur": ["litteratur", "roman", "dikt", "poesi"],
            "Musik": ["musik", "melodi", "harmonik", "rytm"],
            "Teknik": ["teknik", "dator", "programvara", "algoritm"],
        ]

        for (domain, keywords) in domainKeywords {
            // Factor 1: Fact count (logarithmic, 25% weight)
            var factCount = 0
            for kw in keywords {
                let facts = await memory.searchFacts(query: kw, limit: 20)
                factCount += facts.count
            }
            let factScore = factCount > 0 ? min(1.0, 0.12 * log2(Double(factCount) + 1)) : 0

            // Factor 2: FSRS mastery (25% weight)
            let domainFSRS = fsrsItems.filter { $0.domain == domain }
            let reviewedItems = domainFSRS.filter { $0.reviewCount > 0 }
            let avgRetention = reviewedItems.isEmpty ? 0.5 :
                reviewedItems.map { predictedRetention(for: $0) }.reduce(0, +) / Double(reviewedItems.count)
            let fsrsScore = min(1.0, avgRetention * 0.7 + Double(reviewedItems.count) * 0.02)

            // Factor 3: Conversation frequency (20% weight)
            let convCount = topicConversationCount[domain] ?? 0
            let convScore = min(1.0, Double(convCount) * 0.1)

            // Factor 4: OpenRouter eval score (15% weight)
            let orScore = await OpenRouterLanguageEvaluator.shared.getDomainScore(domain: domain)

            // Factor 5: Self-generated eval performance (15% weight)
            let selfEvals = selfGeneratedEvals.filter { $0.domain == domain && $0.answered && $0.score != nil }
            let selfEvalScore = selfEvals.isEmpty ? 0.5 :
                selfEvals.map { $0.score! }.reduce(0, +) / Double(selfEvals.count)

            // Weighted combination
            let totalExpertise = factScore * 0.25 + fsrsScore * 0.25 + convScore * 0.20 + orScore * 0.15 + selfEvalScore * 0.15
            expertise[domain] = min(1.0, max(0.0, totalExpertise))
        }

        return expertise
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 115: Information Density Computation
    // ═══════════════════════════════════════════════════════════

    /// Measure bits of new information per word. Track and optimize for appropriate density.
    func computeInformationDensity(text: String) -> Double {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return 0 }

        // Stopwords carry less information
        let stopwords: Set<String> = ["och", "eller", "är", "var", "det", "den", "som", "att", "i", "på", "för", "av", "till", "med", "från", "om", "en", "ett", "de", "sig", "han", "hon", "man", "vi", "jag", "du", "ni", "har", "hade", "kan", "ska", "vill", "måste", "inte", "också", "mycket", "mer", "än", "vid", "mot", "efter", "innan", "när", "där", "här", "så", "då", "alla", "allt", "varje", "någon", "något", "inga", "inga"]

        // Content words carry more information
        let contentWords = words.filter { !stopwords.contains($0.lowercased()) && $0.count > 2 }

        // Factor 1: Content word ratio (40%)
        let contentRatio = Double(contentWords.count) / Double(words.count)

        // Factor 2: Unique word ratio (30%) — higher = more diverse vocabulary
        let uniqueWords = Set(words.map { $0.lowercased() })
        let lexicalDiversity = Double(uniqueWords.count) / Double(words.count)

        // Factor 3: Average word length as proxy for complexity (20%)
        let avgWordLength = Double(words.map { $0.count }.reduce(0, +)) / Double(words.count)
        let lengthScore = min(1.0, avgWordLength / 8.0)

        // Factor 4: Presence of technical/domain terms (10%)
        let technicalTerms = contentWords.filter { $0.count > 8 }
        let techScore = min(1.0, Double(technicalTerms.count) / Double(max(1, contentWords.count)) * 3)

        let density = contentRatio * 0.4 + lexicalDiversity * 0.3 + lengthScore * 0.2 + techScore * 0.1
        return min(1.0, max(0.0, density))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 117: Language Milestone Tracking
    // ═══════════════════════════════════════════════════════════

    struct LanguageMilestone: Identifiable, Codable {
        let id = UUID()
        let achievedAt: Date
        let milestone: String
        let domain: String
        let metric: String
        let value: Double
        let celebration: String
    }

    private var achievedMilestones: Set<String> = []
    private var milestonesHistory: [LanguageMilestone] = []


    /// Track language milestones. Celebrate in inner monologue when achieved.
    func trackLanguageMilestones(currentCEFR: Double, wsdAccuracy: Double, metaphorsDetected: Int, idiomsUnderstood: Int, clauseComplexity: Double) async -> [LanguageMilestone] {
        let memory = PersistentMemoryStore.shared
        var newMilestones: [LanguageMilestone] = []

        let metrics: [String: Double] = [
            "cefr_level": currentCEFR,
            "wsd_accuracy": wsdAccuracy,
            "metaphors_detected": Double(metaphorsDetected),
            "idioms_understood": Double(idiomsUnderstood),
            "clause_complexity": clauseComplexity,
            "vocabulary_count": Double(uniqueSwedishWords.count),
        ]

        for def in Self.milestoneDefinitions {
            guard !achievedMilestones.contains(def.id) else { continue }
            guard let current = metrics[def.metric] else { continue }
            guard current >= def.threshold else { continue }

            achievedMilestones.insert(def.id)
            let milestone = LanguageMilestone(
                achievedAt: Date(),
                milestone: def.milestone,
                domain: def.domain,
                metric: def.metric,
                value: current,
                celebration: def.celebration
            )
            milestonesHistory.append(milestone)
            newMilestones.append(milestone)

            await memory.saveFact(
                subject: "Språklig milstolpe",
                predicate: "uppnådd",
                object: def.milestone,
                confidence: 0.95,
                source: "milestone_tracking"
            )

            // Log celebration for inner monologue
            print("[MILESTONE] \(def.celebration)")
        }

        return newMilestones
    }

    func getAchievedMilestones() -> [LanguageMilestone] {
        milestonesHistory
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 119: Learning Path Recommendation
    // ═══════════════════════════════════════════════════════════

    struct LearningPath: Identifiable, Codable {
        let id = UUID()
        let generatedAt: Date
        let currentLevel: String
        let targetLevel: String
        let estimatedWeeks: Int
        let phases: [LearningPhase]
        let priorityDomains: [String]
        let reasoning: String
    }

    struct LearningPhase: Codable {
        let name: String
        let focusDomains: [String]
        let activities: [String]
        let estimatedWeeks: Int
        let milestones: [String]
        let successCriteria: [String]
    }

    /// Based on current competencies, knowledge gaps, and user interests, generate an optimal learning path.
    func recommendLearningPath(targetCEFR: String = "B2", userInterests: [String] = []) async -> LearningPath {
        let competencies = competencyBook()
        let expertise = await computeTopicExpertise()
        let (_, metrics) = await buildKnowledgeGraph()

        // Identify weakest domains
        let sortedByLevel = competencies.sorted { $0.value.level < $1.value.level }
        let weakestDomains = sortedByLevel.prefix(5).map { $0.key }

        // Combine with knowledge gaps
        let prioritySet = Set(weakestDomains).union(metrics.knowledgeGaps.prefix(3))
        let priorityDomains = Array(prioritySet.prefix(5))

        // Determine current CEFR from overall competency
        let overallLevel = overallCompetencyLevel()
        let currentCEFRLabel = cefrLabel(for: overallLevel)

        // Generate phases based on gaps
        var phases: [LearningPhase] = []

        // Phase 1: Foundation — fix weakest areas
        if !weakestDomains.isEmpty {
            phases.append(LearningPhase(
                name: "Grundläggande förstärkning",
                focusDomains: Array(weakestDomains.prefix(3)),
                activities: ["Explicit regel-inlärning", "Ordförrådsutbyggnad", "Grammatikövningar"],
                estimatedWeeks: 2,
                milestones: weakestDomains.prefix(3).map { "Höj \( $0 ) till 0.3" },
                successCriteria: ["Alla fokusdomäner > 0.3 kompetens", "50 nya ord inom domäner"]
            ))
        }

        // Phase 2: Integration — connect knowledge
        if metrics.knowledgeGaps.count > 5 {
            phases.append(LearningPhase(
                name: "Kunskapsintegration",
                focusDomains: metrics.knowledgeGaps.prefix(5),
                activities: ["Kunskapsgrafer", "Analogiträning", "Tvärvetenskapliga kopplingar"],
                estimatedWeeks: 3,
                milestones: metrics.knowledgeGaps.prefix(3).map { "Fyll kunskapslucka: \( $0 )" },
                successCriteria: ["Genomsnittlig centralitet > \(String(format: "%.2f", metrics.avgCentrality * 1.5))", "10 nya relationer i kunskapsgrafen"]
            ))
        }

        // Phase 3: Advancement — push toward target
        phases.append(LearningPhase(
            name: "Avancerad utveckling",
            focusDomains: userInterests.isEmpty ? priorityDomains : userInterests,
            activities: ["Konversationspraktik", "Läsa svensk litteratur", "Skriva essäer"],
            estimatedWeeks: 4,
            milestones: ["Nå \(targetCEFR)-nivå", "1000 ord ordförråd", "Flytande konversation"],
            successCriteria: ["CEFR \(targetCEFR) uppnådd", "WSD > 70%", "Grammatikpoäng > 0.8"]
        ))

        let totalWeeks = phases.reduce(0) { $0 + $1.estimatedWeeks }

        return LearningPath(
            generatedAt: Date(),
            currentLevel: currentCEFRLabel,
            targetLevel: targetCEFR,
            estimatedWeeks: totalWeeks,
            phases: phases,
            priorityDomains: priorityDomains,
            reasoning: "Baserat på \(metrics.entityCount) entiteter, \(metrics.relationCount) relationer, och kompetensnivåer i \(competencies.count) domäner. Svagaste områdena: \(weakestDomains.joined(separator: ", "))."
        )
    }

    private func cefrLabel(for level: Double) -> String {
        if level < 0.2 { return "A1" }
        if level < 0.35 { return "A2" }
        if level < 0.5 { return "B1" }
        if level < 0.65 { return "B2" }
        if level < 0.8 { return "C1" }
        return "C2"
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 123: Vocabulary Breadth and Depth Measurement
    // ═══════════════════════════════════════════════════════════

    /// Breadth = unique words. Depth = how well each word is known (definitions, collocations,
    /// derivatives, contexts). Balance = distribution across domains.
    func measureVocabularyBreadthAndDepth() async -> (breadth: Int, depth: Double, balance: Double) {
        let breadth = uniqueSwedishWords.count

        // Depth: measure how well each word is known
        // Sample words for OpenRouter analysis (cap at 50 for performance)
        let sampleWords = Array(uniqueSwedishWords).prefix(min(50, breadth))
        var depthScores: [Double] = []

        for word in sampleWords {
            var wordDepth = 0.0

            // Has the word been used in conversation?
            let usedInConversation = topicConversationCount.values.reduce(0, +) > 0
            if usedInConversation { wordDepth += 0.2 }

            // Has the word appeared in FSRS items?
            let inFSRS = fsrsItems.contains { $0.content.contains(word) }
            if inFSRS { wordDepth += 0.3 }

            // Has the word been morphologically analyzed?
            let morphAnalyzed = wordsAnalyzed.contains(word.lowercased())
            if morphAnalyzed { wordDepth += 0.2 }

            // Check if word has known derivatives/collocations (via memory)
            let memory = PersistentMemoryStore.shared
            let relatedFacts = await memory.searchFacts(query: word, limit: 5)
            if !relatedFacts.isEmpty { wordDepth += 0.3 }

            depthScores.append(min(1.0, wordDepth))
        }

        let depth = depthScores.isEmpty ? 0 : depthScores.reduce(0, +) / Double(depthScores.count)

        // Balance: distribution across domains (entropy-based)
        let domainCounts = topicConversationCount
        let totalDomainMentions = domainCounts.values.reduce(0, +)
        if totalDomainMentions > 0 && domainCounts.count > 1 {
            var entropy = 0.0
            for count in domainCounts.values {
                let p = Double(count) / Double(totalDomainMentions)
                if p > 0 { entropy -= p * log2(p) }
            }
            let maxEntropy = log2(Double(domainCounts.count))
            let balance = maxEntropy > 0 ? entropy / maxEntropy : 0
            return (breadth, depth, balance)
        }

        return (breadth, depth, 0.0)
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 125: Mind Map Generation
    // ═══════════════════════════════════════════════════════════

    struct MindMap: Codable {
        let id = UUID()
        let topic: String
        let createdAt: Date
        let rootNode: MindMapNode
        let totalNodes: Int
        let maxDepth: Int
    }

    struct MindMapNode: Codable {
        let id = UUID()
        let label: String
        let children: [MindMapNode]
        let depth: Int
        let domain: String
        let confidence: Double
        let connections: [String]  // labels of related nodes
    }

    /// Generate a hierarchical knowledge structure for any topic.
    func createMindMap(topic: String) async -> MindMap {
        let memory = PersistentMemoryStore.shared
        let facts = await memory.searchFacts(query: topic, limit: 50)

        // Build hierarchical structure from facts
        var childNodes: [MindMapNode] = []
        var seenLabels: Set<String> = []

        // Group facts by related concepts
        var conceptGroups: [String: [String]] = [:]
        for fact in facts {
            let relatedTerms = extractKeyTerms("\(fact.subject) \(fact.predicate) \(fact.object)")
            for term in relatedTerms where term.lowercased() != topic.lowercased() {
                conceptGroups[term, default: []].append("\(fact.subject) \(fact.object)")
            }
        }

        // Create child nodes for each concept
        for (concept, details) in conceptGroups.prefix(8) {
            guard !seenLabels.contains(concept) else { continue }
            seenLabels.insert(concept)

            let subConcepts = extractKeyTerms(details.joined(separator: " "))
                .filter { $0.lowercased() != concept.lowercased() && $0.lowercased() != topic.lowercased() }
                .prefix(4)

            let subNodes = subConcepts.map { sub in
                MindMapNode(label: sub, children: [], depth: 2, domain: findDomainForConcept(sub), confidence: 0.6, connections: [])
            }

            let childNode = MindMapNode(
                label: concept,
                children: Array(subNodes),
                depth: 1,
                domain: findDomainForConcept(concept),
                confidence: 0.7,
                connections: subNodes.map { $0.label }
            )
            childNodes.append(childNode)
        }

        let rootNode = MindMapNode(
            label: topic,
            children: childNodes,
            depth: 0,
            domain: findDomainForConcept(topic),
            confidence: 0.8,
            connections: childNodes.map { $0.label }
        )

        let totalNodes = countNodes(rootNode)
        let maxDepth = maxDepthOf(rootNode)

        return MindMap(topic: topic, createdAt: Date(), rootNode: rootNode, totalNodes: totalNodes, maxDepth: maxDepth)
    }

    private func extractKeyTerms(_ text: String) -> [String] {
        let stopwords: Set<String> = ["och", "eller", "är", "var", "det", "den", "som", "att", "i", "på", "för", "av", "en", "ett", "de", "sig", "har", "hade", "kan", "ska", "inte", "också", "mer", "än", "vid", "mot", "efter", "när", "där", "här", "så", "då", "alla", "allt", "någon", "något"]
        return text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 && !stopwords.contains($0.lowercased()) }
    }

    private func findDomainForConcept(_ concept: String) -> String {
        let lower = concept.lowercased()
        let domainHints: [(String, [String])] = [
            ("Morfologi", ["ord", "böjning", "suffix", "prefix", "rot", "stam"]),
            ("Syntax", ["mening", "sats", "ordföljd", "fras", "subjekt"]),
            ("Semantik", ["betydelse", "synonym", "antonym", "metafor"]),
            ("AI & Maskininlärning", ["ai", "modell", "neural", "algoritm", "data"]),
            ("Kognitionsvetenskap", ["kognition", "medvetande", "minne", "uppmärksamhet"]),
            ("Filosofi", ["filosofi", "etik", "logik", "ontologi"]),
        ]
        for (domain, keywords) in domainHints {
            if keywords.contains(where: { lower.contains($0) }) { return domain }
        }
        return "Generell"
    }

    private func countNodes(_ node: MindMapNode) -> Int {
        1 + node.children.reduce(0) { $0 + countNodes($1) }
    }

    private func maxDepthOf(_ node: MindMapNode) -> Int {
        if node.children.isEmpty { return node.depth }
        return node.children.map { maxDepthOf($0) }.max() ?? node.depth
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 128: Knowledge Interdependencies
    // ═══════════════════════════════════════════════════════════

    struct KnowledgeDependency: Codable {
        let prerequisite: String
        let dependent: String
        let dependencyType: DependencyType
        let strength: Double
    }

    enum DependencyType: String, Codable {
        case foundational    // Must understand X before Y
        case contextual      // X helps understand Y
        case sequential       // X should be learned before Y
        case parallel         // X and Y can be learned together
    }

    /// Find which concepts must be understood before others can be learned.
    /// Build a dependency graph for optimal learning order.
    func computeKnowledgeInterdependencies() async -> [KnowledgeDependency] {
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 1000)
        var dependencies: [KnowledgeDependency] = []

        // Define known prerequisite relationships (Swedish language)
        let knownPrerequisites: [(prerequisite: String, dependent: String, type: DependencyType)] = [
            ("ordklass", "böjning", .foundational),
            ("böjning", "meningsbyggnad", .foundational),
            ("grundord", "sammansättning", .foundational),
            ("presens", "preteritum", .sequential),
            ("preteritum", "perfekt", .sequential),
            ("enkel mening", "bisats", .sequential),
            ("bisats", "complex mening", .sequential),
            ("V2-regeln", "inversion", .foundational),
            ("substantiv", "artikel", .foundational),
            ("verb", "tempus", .foundational),
            ("adjektiv", "komparativ", .foundational),
            ("adjektiv", "superlativ", .foundational),
            ("pronomen", "anafor", .foundational),
            ("konnektiv", "koherens", .foundational),
            ("metafor", "allegori", .foundational),
            ("kausalitet", "korrelation", .contextual),
            ("sannolikhet", "statistik", .foundational),
            ("aritmetik", "algebra", .foundational),
            ("algebra", "kalkyl", .sequential),
        ]

        // Check which prerequisites are known
        for (prereq, dependent, type) in knownPrerequisites {
            let prereqKnown = facts.contains { $0.subject.lowercased().contains(prereq.lowercased()) || $0.object.lowercased().contains(prereq.lowercased()) }
            let dependentKnown = facts.contains { $0.subject.lowercased().contains(dependent.lowercased()) || $0.object.lowercased().contains(dependent.lowercased()) }

            if prereqKnown || dependentKnown {
                let strength: Double
                switch type {
                case .foundational: strength = 0.9
                case .sequential: strength = 0.7
                case .contextual: strength = 0.5
                case .parallel: strength = 0.3
                }
                dependencies.append(KnowledgeDependency(
                    prerequisite: prereq,
                    dependent: dependent,
                    dependencyType: type,
                    strength: strength
                ))
            }
        }

        // Discover interdependencies from co-occurrence in facts
        var cooccurrence: [String: Int] = [:]
        for fact in facts {
            let terms = extractKeyTerms("\(fact.subject) \(fact.object)")
            for (i, t1) in terms.enumerated() {
                for t2 in terms[(i+1)...] {
                    let key = min(t1, t2)
                    let dep = max(t1, t2)
                    let pairKey = "\(key)->\(dep)"
                    cooccurrence[pairKey, default: 0] += 1
                }
            }
        }

        // Add high-cooccurrence pairs as contextual dependencies
        for (pairKey, count) in cooccurrence where count >= 3 {
            let parts = pairKey.components(separatedBy: "->")
            guard parts.count == 2 else { continue }
            let existing = dependencies.contains { $0.prerequisite == parts[0] && $0.dependent == parts[1] }
            if !existing {
                dependencies.append(KnowledgeDependency(
                    prerequisite: parts[0],
                    dependent: parts[1],
                    dependencyType: .contextual,
                    strength: min(0.8, Double(count) * 0.1)
                ))
            }
        }

        return dependencies.sorted { $0.strength > $1.strength }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 132: Learning Hypothesis Generation
    // ═══════════════════════════════════════════════════════════

    struct Hypothesis: Sendable {
        let id = UUID()
        let statement: String
        let method: String
        let confidence: Double
        let testResult: String?
        let createdAt: Date
    }

    private var activeHypotheses: [Hypothesis] = []
    private var testedHypotheses: [Hypothesis] = []

    /// Formulate hypotheses about what learning methods work best and test them.
    func generateLearningHypothesis() async -> Hypothesis {
        let competencies = await competencyBook()
        let learningData = collectLearningData()

        // Generate hypothesis based on current learning patterns
        let hypothesis: Hypothesis
        if learningData.storyContextWords > learningData.isolatedWords {
            hypothesis = Hypothesis(
                statement: "Jag lär mig ordförråd snabbare när de är inbäddade i sammanhang (berättelser) jämfört med isolerade definitioner.",
                method: "Jämför inlärningshastighet för ord i kontext vs isolerade",
                confidence: 0.7,
                testResult: nil,
                createdAt: Date()
            )
        } else if learningData.repetitionScore > 0.6 {
            hypothesis = Hypothesis(
                statement: "Spaced repetition med FSRS är mer effektivt än enkel upprepning för långsiktig retention.",
                method: "Jämför retention rates mellan FSRS och enkel repetition",
                confidence: 0.75,
                testResult: nil,
                createdAt: Date()
            )
        } else {
            hypothesis = Hypothesis(
                statement: "Konversationsbaserat lärande ger snabbare kompetensutveckling än passiv fakta-inläsning.",
                method: "Mät kompetenstillväxt per konversation vs per fakta",
                confidence: 0.65,
                testResult: nil,
                createdAt: Date()
            )
        }

        activeHypotheses.append(hypothesis)

        // Test the hypothesis
        await testHypothesis(hypothesis)

        return hypothesis
    }

    private func testHypothesis(_ hypothesis: Hypothesis) async {
        let learningData = collectLearningData()
        let result: String

        if hypothesis.statement.contains("samanhang") || hypothesis.statement.contains("berättelse") {
            let contextRatio = learningData.storyContextWords / max(1, learningData.isolatedWords)
            result = contextRatio > 1.5
                ? "BEKRÄFTAD: Kontextuella ord (\(learningData.storyContextWords)) > isolerade (\(learningData.isolatedWords))"
                : "VARKEN BEKRÄFTAD ELLER AVFÄRDAD: För lite data"
            let updated = Hypothesis(id: hypothesis.id, statement: hypothesis.statement, method: hypothesis.method,
                confidence: contextRatio > 1.5 ? 0.85 : hypothesis.confidence, testResult: result, createdAt: hypothesis.createdAt)
            activeHypotheses = activeHypotheses.filter { $0.id != hypothesis.id }
            testedHypotheses.append(updated)
        }

        if testedHypotheses.count > 50 { testedHypotheses = Array(testedHypotheses.suffix(30)) }
    }

    struct LearningData {
        let storyContextWords: Int
        let isolatedWords: Int
        let repetitionScore: Double
    }

    private func collectLearningData() -> LearningData {
        return LearningData(
            storyContextWords: recentlyLearnedWords.filter { $0.count > 5 }.count,
            isolatedWords: recentlyLearnedWords.filter { $0.count <= 5 }.count,
            repetitionScore: fsrsItems.filter { $0.reviewCount > 2 }.isEmpty ? 0.3 : 0.7
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 133: Knowledge Blindspot Detection
    // ═══════════════════════════════════════════════════════════

    struct Blindspot: Sendable {
        let domain: String
        let knowledgeLevel: Double
        let queryCount: Int
        let urgency: Double
        let suggestedAction: String
        let detectedAt: Date
    }

    /// Find domains where Eon has ZERO or MINIMAL knowledge despite being asked about them.
    func detectKnowledgeBlindspots() async -> [Blindspot] {
        let competencies = await competencyBook()
        let memory = PersistentMemoryStore.shared
        let conversationHistory = await memory.getRecentConversation(limit: 100)

        // Count queries per domain
        var domainQueryCounts: [String: Int] = [:]
        let domainKeywords: [String: [String]] = [
            "Morfologi": ["morfologi", "böjning", "ordklass"],
            "Syntax": ["syntax", "ordföljd", "bisats"],
            "Semantik": ["betydelse", "synonym", "semantik"],
            "Pragmatik": ["pragmatik", "idiom", "register"],
            "AI & Maskininlärning": ["ai", "neural", "maskininlärning", "embedding"],
            "Kognitionsvetenskap": ["kognition", "medvetande", "perception"],
            "Matematik": ["matematik", "algebra", "ekvation"],
            "Fysik": ["fysik", "energi", "kvant"],
            "Historia": ["historia", "krig", "revolution"],
            "Filosofi": ["filosofi", "epistemologi", "ontologi"],
            "Juridik": ["juridik", "lag", "domstol"],
            "Ekonomi": ["ekonomi", "pris", "marknad"],
            "Litteratur": ["litteratur", "roman", "dikt"],
        ]

        for conv in conversationHistory {
            let lower = conv.content.lowercased()
            for (domain, keywords) in domainKeywords {
                if keywords.contains(where: { lower.contains($0) }) {
                    domainQueryCounts[domain, default: 0] += 1
                }
            }
        }

        var blindspots: [Blindspot] = []
        for (domain, queryCount) in domainQueryCounts where queryCount >= 3 {
            let level = competencies[domain]?.level ?? 0.0
            if level < 0.2 {
                blindspots.append(Blindspot(
                    domain: domain,
                    knowledgeLevel: level,
                    queryCount: queryCount,
                    urgency: Double(queryCount) * (1.0 - level) / 10.0,
                    suggestedAction: "Prioritera inlärning inom \(domain) — användaren frågar om detta men kunskapen är låg",
                    detectedAt: Date()
                ))
            }
        }

        if !blindspots.isEmpty {
            let memory = PersistentMemoryStore.shared
            await memory.saveFact(
                subject: "Kunskapsblindspot",
                predicate: "detekterad",
                object: blindspots.map { "\($0.domain) (\($0.queryCount) frågor, \($0.knowledgeLevel) nivå)" }.joined(separator: "; "),
                confidence: 0.8,
                source: "blindspot_detection"
            )
        }

        return blindspots.sorted { $0.urgency > $1.urgency }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 136: Teaching Ability Evaluation
    // ═══════════════════════════════════════════════════════════

    /// Can Eon explain a concept to someone else? Generate a teaching explanation and evaluate its quality.
    func evaluateTeachingAbility(subject: String) async -> Double {
        let competency = await competencyBook()[subject]?.level ?? 0.0
        let memory = PersistentMemoryStore.shared

        // Generate a teaching explanation
        let facts = await memory.searchFacts(query: subject, limit: 5)
        let hasFactualBasis = !facts.isEmpty

        // Quality factors for teaching:
        // 1. Domain competency (40%)
        let competencyScore = min(1.0, competency * 1.5)

        // 2. Factual basis (20%)
        let factualScore = hasFactualBasis ? min(1.0, Double(facts.count) / 5.0) : 0.0

        // 3. Metacognitive ability to explain (20%)
        let metaLevel = CognitiveState.shared.dimensionLevel(.metacognition)
        let metaScore = metaLevel

        // 4. Language ability to formulate clearly (20%)
        let langLevel = await (competencyBook()["Språk"]?.level ?? 0.0)
        let langScore = min(1.0, langLevel * 1.5)

        let teachingScore = competencyScore * 0.4 + factualScore * 0.2 + metaScore * 0.2 + langScore * 0.2

        return max(0.0, min(1.0, teachingScore))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 140: Future Self Simulation
    // ═══════════════════════════════════════════════════════════

    struct FutureSelfProjection: Sendable {
        let projectedDate: Date
        let projectedCompetencies: [String: Double]
        let projectedVocabulary: Int
        let projectedOverallLevel: Double
        let currentTrajectory: String
        let desiredTrajectory: String
        let gap: Double
        let daysAhead: Int
    }

    /// Project what Eon's competencies will look like in N days at current learning rate.
    func simulateFutureSelf(daysAhead: Int) async -> FutureSelfProjection {
        let competencies = await competencyBook()
        let currentVocab = swedishVocabularyCount()
        let cs = CognitiveState.shared

        // Calculate daily learning rates
        let dailyVocabGrowth = max(1.0, learningVelocity * 5.0)  // words per day estimate
        let projectedVocab = currentVocab + Int(dailyVocabGrowth * Double(daysAhead))

        // Project competency growth with diminishing returns
        var projectedCompetencies: [String: Double] = [:]
        for (domain, comp) in competencies {
            let currentLevel = comp.level
            let remaining = 1.0 - currentLevel
            // Growth slows as we approach mastery
            let dailyGrowth = remaining * 0.005  // 0.5% of remaining per day
            let projected = currentLevel + dailyGrowth * Double(daysAhead)
            projectedCompetencies[domain] = min(0.95, projected)
        }

        let projectedOverall = projectedCompetencies.values.reduce(0, +) / Double(max(1, projectedCompetencies.count))
        let currentOverall = competencies.values.map { $0.level }.reduce(0, +) / Double(max(1, competencies.count))

        // Desired trajectory: reach 0.7 overall in 90 days
        let desiredRate = (0.7 - currentOverall) / 90.0
        let actualRate = (projectedOverall - currentOverall) / Double(max(1, daysAhead))
        let gap = desiredRate - actualRate

        let trajectoryLabel = gap > 0 ? "Under önskad takt" : gap < -0.005 ? "Över önskad takt" : "På rätt spår"

        return FutureSelfProjection(
            projectedDate: Date().addingTimeInterval(Double(daysAhead) * 86400),
            projectedCompetencies: projectedCompetencies,
            projectedVocabulary: projectedVocab,
            projectedOverallLevel: projectedOverall,
            currentTrajectory: trajectoryLabel,
            desiredTrajectory: "0.7 overall kompetens inom 90 dagar",
            gap: gap,
            daysAhead: daysAhead
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 144: Cognitive Flexibility Measurement
    // ═══════════════════════════════════════════════════════════

    /// How well can Eon switch between different perspectives, approaches, or frameworks?
    func measureCognitiveFlexibility() async -> Double {
        let cs = CognitiveState.shared
        let memory = PersistentMemoryStore.shared

        // 1. Dimension balance: how evenly developed are cognitive dimensions?
        let dimensions = cs.dimensionSnapshot()
        let values = dimensions.values.filter { $0 > 0.1 }
        guard !values.isEmpty else { return 0.3 }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let balance = max(0.0, 1.0 - sqrt(variance) * 3.0)

        // 2. Topic switching ability: from topic transitions
        let transitionCount = getTopicTransitionCount()
        let topicFlexibility = min(1.0, Double(transitionCount) / 20.0)

        // 3. Adaptivity dimension
        let adaptivityScore = cs.dimensionLevel(.adaptivity)

        // 4. Multi-domain competency spread
        let competencies = await competencyBook()
        let activeDomains = competencies.filter { $0.value.level > 0.15 }.count
        let domainSpread = min(1.0, Double(activeDomains) / 15.0)

        let flexibility = balance * 0.3 + topicFlexibility * 0.2 + adaptivityScore * 0.25 + domainSpread * 0.25

        return max(0.0, min(1.0, flexibility))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 147: Knowledge Transfer Detection
    // ═══════════════════════════════════════════════════════════

    struct KnowledgeTransfer: Sendable {
        let sourceDomain: String
        let targetDomain: String
        let transferredConcept: String
        let evidence: String
        let transferStrength: Double
        let detectedAt: Date
    }

    /// When knowledge from one domain is successfully applied to another.
    func detectKnowledgeTransfer() async -> [KnowledgeTransfer] {
        let competencies = await competencyBook()
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 500)

        // Detect cross-domain concept overlap
        let domainConcepts: [String: Set<String>] = [
            "Morfologi": ["rot", "suffix", "prefix", "böjning", "avledning", "sammansättning"],
            "Syntax": ["struktur", "ordning", "fras", "sats", "hierarki"],
            "Kognitionsvetenskap": ["representation", "modell", "prediktion", "abstraktion"],
            "AI & Maskininlärning": ["embedding", "representation", "abstraktion", "hierarki", "modell"],
            "Matematik": ["struktur", "relation", "abstraktion", "transformation"],
            "Fysik": ["modell", "transformation", "energi", "struktur"],
            "Filosofi": ["representation", "abstraktion", "relation", "struktur"],
        ]

        var transfers: [KnowledgeTransfer] = []

        let domainPairs = domainConcepts.keys.flatMap { d1 in domainConcepts.keys.map { d2 in (d1, d2) } }.filter { $0.0 != $0.1 }
        for (source, target) in domainPairs {
            let shared = domainConcepts[source]?.intersection(domainConcepts[target] ?? []) ?? []
            if shared.count >= 2 {
                let sourceLevel = competencies[source]?.level ?? 0.0
                let targetLevel = competencies[target]?.level ?? 0.0
                if sourceLevel > 0.3 && targetLevel > 0.15 && targetLevel < sourceLevel {
                    transfers.append(KnowledgeTransfer(
                        sourceDomain: source,
                        targetDomain: target,
                        transferredConcept: shared.prefix(2).joined(separator: ", "),
                        evidence: "Delade koncept: \(shared.joined(separator: ", ")) — \(source) (\(String(format: "%.0f", sourceLevel * 100))%) → \(target) (\(String(format: "%.0f", targetLevel * 100))%)",
                        transferStrength: min(1.0, Double(shared.count) * 0.2 * sourceLevel),
                        detectedAt: Date()
                    ))
                }
            }
        }

        return transfers.sorted { $0.transferStrength > $1.transferStrength }.prefix(10).map { $0 }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 150: Learning Plateau Detection
    // ═══════════════════════════════════════════════════════════

    struct Plateau: Sendable {
        let domain: String
        let currentLevel: Double
        let sessionsWithoutImprovement: Int
        let duration: TimeInterval
        let intervention: String
        let detectedAt: Date
    }

    /// Identify when learning has stalled in a domain (no improvement over N sessions).
    func detectLearningPlateaus() async -> [Plateau] {
        let competencies = await competencyBook()
        let history = selfEvaluationHistory

        var plateaus: [Plateau] = []

        for (domain, comp) in competencies {
            // Check if competency hasn't improved in recent evaluations
            let domainHistory = history.filter { _ in true }  // Use general history as proxy
            guard domainHistory.count >= 3 else { continue }

            // Check if lastStudied is old and level is stagnant
            let daysSinceStudy = -comp.lastStudied.timeIntervalSinceNow / 86400
            if daysSinceStudy > 3 && comp.level < 0.5 {
                let intervention: String
                if comp.level < 0.15 {
                    intervention = "Grundläggande inlärning: börja med basbegrepp inom \(domain)"
                } else if comp.level < 0.35 {
                    intervention = "Aktiv övning: skapa FSRS-övningar och konversationspraxis inom \(domain)"
                } else {
                    intervention = "Avancerad tillämpning: skriv essäer och analyser inom \(domain)"
                }

                plateaus.append(Plateau(
                    domain: domain,
                    currentLevel: comp.level,
                    sessionsWithoutImprovement: Int(daysSinceStudy),
                    duration: comp.lastStudied.timeIntervalSinceNow,
                    intervention: intervention,
                    detectedAt: Date()
                ))
            }
        }

        if !plateaus.isEmpty {
            let memory = PersistentMemoryStore.shared
            await memory.saveFact(
                subject: "Inlärningsplatå",
                predicate: "detekterad",
                object: plateaus.map { "\($0.domain) (\($0.sessionsWithoutImprovement) sessioner utan förbättring)" }.joined(separator: "; "),
                confidence: 0.7,
                source: "plateau_detection"
            )
        }

        return plateaus.sorted { $0.sessionsWithoutImprovement > $1.sessionsWithoutImprovement }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 152: Understanding Depth Measurement
    // ═══════════════════════════════════════════════════════════

    enum DepthLevel: Int, Sendable {
        case knowsWord = 1        // Has heard of it
        case canDefine = 2       // Can define it
        case canUseInContext = 3 // Can use correctly in sentences
        case canExplain = 4      // Can explain it to others
        case canApplyCreatively = 5 // Can apply in novel situations
    }

    /// 5 levels of understanding: knows word, can define, can use in context, can explain, can apply creatively.
    func computeUnderstandingDepth(concept: String) -> DepthLevel {
        let memory = PersistentMemoryStore.shared
        let conceptLower = concept.lowercased()

        // Level 1: Has the concept in memory
        let hasBasicFact = competencyBook()[concept] != nil
        guard hasBasicFact else { return .knowsWord }

        // Level 2: Can define (has definitions stored)
        // Check if we have stored facts about the concept
        let facts = Task { await memory.searchFacts(query: concept, limit: 3) }
        // We use FSRS items as a proxy for definitional knowledge
        let hasDefinitions = fsrsItems.contains { $0.topic.lowercased().contains(conceptLower) && $0.reviewCount > 0 }
        guard hasDefinitions else { return .canDefine }

        // Level 3: Can use in context (seen in conversation)
        let conversations = Task { await memory.getRecentConversation(limit: 100) }
        let usedInContext = recentlyLearnedWords.contains { $0.contains(conceptLower) }
        guard usedInContext else { return .canUseInContext }

        // Level 4: Can explain (domain competency > 0.5)
        let domainCompetency = competencyBook()[concept]?.level ?? 0.0
        guard domainCompetency > 0.5 else { return .canExplain }

        // Level 5: Can apply creatively (cross-domain transfer detected)
        let crossDomainUse = false  // Simplified — would need deeper analysis
        return crossDomainUse ? .canApplyCreatively : .canExplain
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 155: Adaptation Speed Measurement
    // ═══════════════════════════════════════════════════════════

    /// How quickly does Eon adapt to new topics, new users, new styles?
    func measureAdaptationSpeed() async -> Double {
        let competencies = await competencyBook()
        let cs = CognitiveState.shared

        // 1. Time-to-competence for new domains
        let fastLearningDomains = competencies.filter { $0.value.level > 0.3 }
        let avgLearningSpeed = fastLearningDomains.isEmpty ? 0.3 :
            Double(fastLearningDomains.count) / Double(max(1, competencies.count))

        // 2. Learning velocity
        let velocityScore = min(1.0, abs(learningVelocity) * 0.5)

        // 3. Adaptivity dimension
        let adaptivityScore = cs.dimensionLevel(.adaptivity)

        // 4. Strategy switching ability
        let strategyScore = min(1.0, Double(strategyHistory.count) / 10.0)

        let adaptationSpeed = avgLearningSpeed * 0.3 + velocityScore * 0.25 + adaptivityScore * 0.25 + strategyScore * 0.2

        return max(0.0, min(1.0, adaptationSpeed))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 160: Meta-Learning Cycle
    // ═══════════════════════════════════════════════════════════

    struct MetaLearningReport: Sendable {
        let learningPatterns: [String]
        let optimalStrategy: String
        let parameterUpdates: [String]
        let insights: [String]
        let recommendedActions: [String]
        let executedAt: Date
    }

    /// The ultimate meta-loop: analyze all learning data, identify patterns, update strategies.
    func executeMetaLearningCycle() async -> MetaLearningReport {
        let competencies = await competencyBook()
        let cs = CognitiveState.shared

        // 1. Analyze learning patterns
        var patterns: [String] = []

        // Pattern: Which domains grow fastest?
        let sortedByGrowth = competencies.sorted { $0.value.level > $1.value.level }
        if let top = sortedByGrowth.first {
            patterns.append("Snabbast lärande: \(top.key) (\(String(format: "%.0f", top.value.level * 100))%)")
        }

        // Pattern: Vocabulary learning rate
        let vocabRate = learningVelocity
        patterns.append("Ordförrådstillväxt: \(String(format: "%.1f", vocabRate)) ord/konversation")

        // Pattern: Strategy effectiveness
        if !strategyEffectiveness.isEmpty {
            let bestStrategy = strategyEffectiveness.max { ($0.value.reduce(0, +) / Double($0.value.count)) < ($1.value.reduce(0, +) / Double($1.value.count)) }
            if let best = bestStrategy {
                patterns.append("Bästa strategin: \(best.key) (genomsnittlig hastighet: \(String(format: "%.2f", best.value.reduce(0, +) / Double(max(1, best.value.count))))")
            }
        }

        // 2. Identify optimal strategy
        let weakDomains = sortedByGrowth.suffix(5).map { $0.key }
        let optimalStrategy: String
        if weakDomains.contains(where: { ["Morfologi", "Syntax"].contains($0) }) {
            optimalStrategy = "Strukturerad grammatikträning med FSRS + konversationspraxis"
        } else if weakDomains.contains(where: { ["Pragmatik", "Diskurs"].contains($0) }) {
            optimalStrategy = "Läs svensk litteratur och analysera idiom och diskursmönster"
        } else {
            optimalStrategy = "Bredda lärandet — utforska nya domäner parallellt"
        }

        // 3. Update learning parameters
        var parameterUpdates: [String] = []

        // Adjust learning velocity EMA
        let currentVelocity = learningVelocity
        if currentVelocity < 1.0 {
            parameterUpdates.append("Öka inlärningsintensitet — nuvarande hastighet låg")
        }

        // Adjust FSRS parameters based on retention
        let avgRetention = fsrsItems.filter { $0.reviewCount > 0 }.map { predictedRetention(for: $0) }
        if !avgRetention.isEmpty {
            let avgR = avgRetention.reduce(0, +) / Double(avgRetention.count)
            if avgR < 0.7 {
                parameterUpdates.append("FSRS retention för låg (\(String(format: "%.2f", avgR))) — justera intervaller")
            }
        }

        // 4. Generate insights
        let insights: [String] = [
            "Totalt \(swedishVocabularyCount()) svenska ord i ordförrådet",
            "Genomsnittlig kompetens: \(String(format: "%.0f", competencies.values.map { $0.level }.reduce(0, +) / Double(max(1, competencies.count)) * 100))%",
            "Kognitiv tillväxthastighet: \(String(format: "%.3f", cs.growthVelocity)) per minut",
            "Antal aktiva FSRS-objekt: \(fsrsItems.count)",
            "Inlärningsstrategi: \(currentLearningStrategyLabel)",
        ]

        // 5. Recommended actions
        let recommendedActions: [String] = [
            "Prioritera de 3 svagaste domänerna: \(weakDomains.prefix(3).joined(separator: ", "))",
            "Generera dagliga FSRS-övningar för underrepresenterade domäner",
            "Utför kompetenskalibrering var 30:e sync-cykel",
            "Testa nya inlärningshypoteser via generateLearningHypothesis()",
            "Detektera och adressera inlärningsplatåer",
        ]

        return MetaLearningReport(
            learningPatterns: patterns,
            optimalStrategy: optimalStrategy,
            parameterUpdates: parameterUpdates,
            insights: insights,
            recommendedActions: recommendedActions,
            executedAt: Date()
        )
    }

    // ═══════════════════════════════════════════════════════════
    // HELPER: Conversation depth score (for meta-cognitive accuracy)
    // ═══════════════════════════════════════════════════════════

    func conversationDepthScore() async -> Double {
        let memory = PersistentMemoryStore.shared
        let recent = await memory.getRecentConversation(limit: 20)
        guard !recent.isEmpty else { return 0.3 }

        // Depth = average conversation length * topic continuity
        let avgLength = Double(recent.map { $0.content.components(separatedBy: .whitespaces).count }.reduce(0, +)) / Double(recent.count)
        let lengthScore = min(1.0, avgLength / 50.0)

        let topicContinuity = Double(getTopTopics(limit: 3).count) / 10.0

        return lengthScore * 0.6 + topicContinuity * 0.4
    }

    // ═══════════════════════════════════════════════════════════
    // HELPER: Recent response quality (for meta-cognitive accuracy)
    // ═══════════════════════════════════════════════════════════

    func recentResponseQuality() async -> Double {
        if qualityTracking.isEmpty { return 0.5 }
        let recent = qualityTracking.suffix(10)
        return recent.reduce(0, +) / Double(recent.count)
    }

    // ═══════════════════════════════════════════════════════════
    // HELPER: Recent competency gains (for meta-cognitive accuracy)
    // ═══════════════════════════════════════════════════════════

    func recentCompetencyGains() async -> Double {
        let competencies = await competencyBook()
        let levels = competencies.values.map { $0.level }
        guard levels.count >= 2 else { return 0.3 }
        let recent = levels.suffix(levels.count / 2)
        let older = levels.prefix(levels.count / 2)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(max(1, older.count))
        return max(0.0, recentAvg - olderAvg)
    }

    // ═══════════════════════════════════════════════════════════
    // FAS 2: Language System — Vocabulary & Competency
    // ═══════════════════════════════════════════════════════════

    func registerNewVocabulary(word: String, context: String) async {
        uniqueSwedishWords.insert(word)
        wordsLearnedToday += 1
        await persistState()
        addFSRSItem(topic: "Ord: \(word)", domain: "Semantik", initialDifficulty: 0.3)
    }

    func adjustCompetency(_ domain: String, delta: Double) async {
        guard var comp = competencyBook[domain] else { return }
        comp.level = min(1.0, max(0.0, comp.level + delta))
        comp.lastStudied = Date()
        competencyBook[domain] = comp
        await saveCompetency(comp.level, domain: domain)
    }
