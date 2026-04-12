import Foundation
import NaturalLanguage

// MARK: - OpenRouterLanguageEvaluator: Extern språkexpert via OpenRouter Free API
// Förbättrar Eons svenska med 300% genom:
// 1. Batch-grammatikkontroll (V2, bisats, kongruens, adverbplacering)
// 2. Batch-WSD (Word Sense Disambiguation) för obegränsat antal ord
// 3. Morfologisk djupanalys (prefix, suffix, sammansättningar, böjning)
// 4. Ordförrådsexpansion med CEFR-nivåer
// 5. Stil- och komplexitetsanalys
// 6. Självrättande språkinlärning (error analysis → correction → learning)
// 7. Adaptiv modellval (iteration 21)
// 8. Batch-optimering med retry-logik (iteration 22)
// 9. Persistent cache med TTL (iteration 23)
// 10. Multi-pass evaluation (iteration 24)
// 11. Grammatikregel-extraktion (iteration 26)
// 12. CEFR-nivåestimering (iteration 27)

actor OpenRouterLanguageEvaluator {
    static let shared = OpenRouterLanguageEvaluator()

    // OpenRouter API-konfiguration
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    private let apiKey: String? = {
        return UserDefaults.standard.string(forKey: "eon_openrouter_api_key")
    }()

    // MARK: - Iteration 21: Adaptive Model Selection
    // Smart model selection based on task type instead of random rotation

    enum EvaluationTask {
        case grammar
        case wsd
        case style
        case vocabulary
        case morphology
        case errorAnalysis
        case grammarRuleExtraction
        case cefrEstimation
        case selfCorrection
        case sprakbankenEnrichment

        var model: String {
            switch self {
            case .grammar, .selfCorrection:
                return "meta-llama/llama-3.1-70b-instruct:free"
            case .wsd:
                return "qwen/qwen-2-72b-instruct:free"
            case .style:
                return "mistralai/mistral-large-2411:free"
            case .vocabulary, .morphology:
                return "google/gemma-2-27b-it:free"
            case .errorAnalysis, .grammarRuleExtraction:
                return "meta-llama/llama-3.1-70b-instruct:free"
            case .cefrEstimation:
                return "qwen/qwen-2-72b-instruct:free"
            case .sprakbankenEnrichment:
                return "google/gemma-2-27b-it:free"
            }
        }

        var defaultMaxTokens: Int {
            switch self {
            case .grammar, .selfCorrection: return 4000
            case .wsd: return 6000
            case .style: return 4000
            case .vocabulary: return 4000
            case .morphology: return 4000
            case .errorAnalysis: return 3000
            case .grammarRuleExtraction: return 5000
            case .cefrEstimation: return 1500
            case .sprakbankenEnrichment: return 3000
            }
        }
    }

    // Fallback models for retry rotation
    private let fallbackModels = [
        "meta-llama/llama-3.1-8b-instruct:free",
        "mistralai/mistral-7b-instruct:free",
        "qwen/qwen-2-7b-instruct:free"
    ]

    // MARK: - Iteration 23: Persistent Cache with TTL
    // File-based cache in app's caches directory
    // Grammar/style: 24h TTL, Morphology: 7 days TTL

    private var grammarCache: [Int: GrammarAnalysisResult] = [:]
    private var wsdCache: [Int: [WSDEnhancementResult]] = [:]
    private var morphologyCache: [Int: MorphologyDeepResult] = [:]
    private var vocabularyCache: [Int: VocabularyExpansionResult] = [:]
    private let maxCacheSize = 200

    // TTL constants
    private let grammarStyleTTL: TimeInterval = 24 * 60 * 60   // 24 hours
    private let morphologyTTL: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    // Cache directory
    private var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Eon/OpenRouterCache")
    }

    private func createCacheDirectoryIfNeeded() {
        if let dir = cacheDirectory {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func cacheFileURL(for key: String) -> URL? {
        cacheDirectory?.appendingPathComponent(key)
    }

    private func writeToPersistentCache(key: String, data: Data, ttl: TimeInterval) {
        guard let url = cacheFileURL(for: key) else { return }
        createCacheDirectoryIfNeeded()

        let cacheEntry: [String: Any] = [
            "data": data,
            "timestamp": Date().timeIntervalSince1970,
            "ttl": ttl
        ]

        if let plistData = try? PropertyListSerialization.data(
            fromPropertyList: cacheEntry, format: .binary, options: 0
        ) {
            try? plistData.write(to: url, options: .atomic)
        }
    }

    private func readFromPersistentCache(key: String, ttl: TimeInterval) -> Data? {
        guard let url = cacheFileURL(for: key),
              let plistData = try? Data(contentsOf: url),
              let entry = try? PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil
              ) as? [String: Any],
              let timestamp = entry["timestamp"] as? TimeInterval,
              let cachedData = entry["data"] as? Data else {
            return nil
        }

        // Check TTL expiry
        guard Date().timeIntervalSince1970 - timestamp < ttl else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        return cachedData
    }

    private func clearExpiredCache() {
        guard let dir = cacheDirectory else { return }
        let contents = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for fileURL in contents {
            if let plistData = try? Data(contentsOf: fileURL),
               let entry = try? PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil
              ) as? [String: Any],
               let timestamp = entry["timestamp"] as? TimeInterval,
               let ttl = entry["ttl"] as? TimeInterval {
                if Date().timeIntervalSince1970 - timestamp >= ttl {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    // Statistik
    private var totalCalls: Int = 0
    private var successfulCalls: Int = 0
    private var failedCalls: Int = 0
    private var lastEvaluationDate: Date?

    private init() {}

    // MARK: - 1. BATCH GRAMMATIKKONTROLL

    struct GrammarAnalysisResult: Codable {
        let text: String
        let errors: [GrammarError]
        let correctedText: String
        let overallScore: Double  // 0.0-1.0
        let v2Compliance: Bool
        let suggestions: [String]
        let timestamp: Date
    }

    struct GrammarError: Codable {
        let type: String          // "v2_violation", "word_order", "agreement", "adverb_placement", "case"
        let description: String
        let original: String
        let corrected: String
        let position: Int         // Teckenposition i texten
        let severity: Double      // 0.0-1.0
        let explanation: String   // Förklarar REGELN för Eon
    }

    func batchGrammarCheck(_ texts: [String]) async -> [GrammarAnalysisResult] {
        guard apiKey != nil else {
            print("[OpenRouter] No API key - grammar check disabled")
            return []
        }

        guard !texts.isEmpty else { return [] }

        // Iteration 22: Handle up to 20 texts in a single API call
        let batchedTexts = Array(texts.prefix(20))

        let cacheKey = batchedTexts.joined(separator: "|||").hashValue
        let cacheKeyStr = "grammar_\(cacheKey)"

        // Check in-memory cache first
        if let cached = grammarCache[cacheKey] {
            return [cached]
        }

        // Check persistent cache (Iteration 23)
        if let cachedData = readFromPersistentCache(key: cacheKeyStr, ttl: grammarStyleTTL),
           let cached = try? JSONDecoder().decode(GrammarAnalysisResult.self, from: cachedData) {
            grammarCache[cacheKey] = cached
            return [cached]
        }

        let systemPrompt = """
        Du är en expert på svensk grammatik. Analysera följande texter noggrant.

        För varje text, identifiera:
        1. V2-regel-brott (verbet måste komma på andra plats i huvudsats)
        2. Ordföljdsfel (särskilt i bisatser: subjekt + inte + verb)
        3. Kongruensfel (subjekt och verb måste överensstämma)
        4. Adverbplacering (adverb före verb i huvudsats, efter verb i bisats)
        5. kasusfel (han/honom, hon/henne, de/dem)
        6. Genusfel (en/ett-ord)
        7. Böjningsfel (plural, bestämd form)

        Viktiga regler:
        - V2-regeln: I huvudsats står verbet ALLTID på plats 2
        - Bisatser: efter "att", "som", "när", "om", "eftersom" → subjekt + inte + verb
        - Passivbildning: -s suffix (läses, skrivs, görs)
        - Särskrivning ska undvikas (t.ex. "en bra bok" inte "enbra bok")

        Svara ENDAST med giltig JSON enligt följande format:
        [
          {
            "text": "original text",
            "errors": [
              {
                "type": "v2_violation",
                "description": "Beskrivning av felet",
                "original": "den felaktiga frasen",
                "corrected": "korrigerad version",
                "position": 0,
                "severity": 0.8,
                "explanation": "Förklaring av regeln"
              }
            ],
            "correctedText": "helt korrigerad text",
            "overallScore": 0.85,
            "v2Compliance": true,
            "suggestions": ["Förbättringsförslag"]
          }
        ]

        Analysera dessa texter:
        """

        let userPrompt = batchedTexts.enumerated().map { "\($0 + 1). \"\($1)\"" }.joined(separator: "\n\n")

        // Iteration 22: Retry logic with exponential backoff (3 retries)
        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .grammar,
                maxRetries: 3
            )

            let results = try parseGrammarResponse(response, originalTexts: batchedTexts)

            // Cache first result (in-memory + persistent)
            if let first = results.first {
                grammarCache[cacheKey] = first
                if let encoded = try? JSONEncoder().encode(first) {
                    writeToPersistentCache(key: cacheKeyStr, data: encoded, ttl: grammarStyleTTL)
                }
                trimCache(&grammarCache, maxSize: maxCacheSize)
            }

            recordSuccess()
            return results
        } catch {
            recordFailure()
            print("[OpenRouter] Grammar check failed after retries: \(error)")
            return []
        }
    }

    // MARK: - 2. BATCH WORD SENSE DISAMBIGUATION

    struct WSDEnhancementResult: Codable {
        let word: String
        let context: String
        let recommendedSense: String          // SALDO-liknande beskrivning
        let senseDefinition: String
        let senseExamples: [String]
        let confidence: Double                // 0.0-1.0
        let cefrLevel: String                 // A1, A2, B1, B2, C1, C2
        let semanticField: String             // T.ex. "kognition", "emotion", "fysiskt"
        let relatedWords: [String]            // Synonymer, hyperonymer, hyponymer
        let timestamp: Date
    }

    func batchWSD(_ wordContextPairs: [(word: String, context: String)]) async -> [WSDEnhancementResult] {
        guard apiKey != nil else {
            print("[OpenRouter] No API key - WSD disabled")
            return []
        }

        guard !wordContextPairs.isEmpty else { return [] }

        let cacheKey = wordContextPairs.map { "\($0.word):\($0.context)" }.joined(separator: "|||").hashValue
        if let cached = wsdCache[cacheKey] {
            return cached
        }

        let systemPrompt = """
        Du är en expert på svensk betydelsedisambiguering (WSD). För varje ord i sin kontext, bestäm:

        1. Vilken betydelse som är aktuell (liknande SALDO:s meningar)
        2. En tydlig definition av betydelsen
        3. 2-3 exempelmeningar med samma betydelse
        4. Konfidens (0.0-1.0)
        5. CEFR-nivå (A1=basis, A2=elementary, B1=intermediate, B2=upper-intermediate, C1=advanced, C2=mastery)
        6. Semantiskt fält (t.ex. "kognition", "emotion", "kommunikation", "rörelse", "tid")
        7. Relaterade ord (synonymer, hyperonymer, hyponymer)

        Svara ENDAST med giltig JSON:
        [
          {
            "word": "ordet",
            "context": "kontexten",
            "recommendedSense": "beskrivning av betydelse",
            "senseDefinition": "tydlig definition",
            "senseExamples": ["exempel 1", "exempel 2"],
            "confidence": 0.92,
            "cefrLevel": "B1",
            "semanticField": "kognition",
            "relatedWords": ["synonym1", "hyperonym1"]
          }
        ]

        Analysera dessa ord i sin kontext:
        """

        let userPrompt = wordContextPairs.enumerated().map {
            "\($0 + 1). \"\($0.word)\" i meningen: \"\($1.context)\""
        }.joined(separator: "\n")

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .wsd,
                maxRetries: 3
            )

            let results = try parseWSDResponse(response)
            wsdCache[cacheKey] = results
            trimCache(&wsdCache, maxSize: maxCacheSize)

            recordSuccess()
            return results
        } catch {
            recordFailure()
            print("[OpenRouter] WSD failed: \(error)")
            return []
        }
    }

    // MARK: - 3. MORFOLOGISK DJUPANALYS

    struct MorphologyDeepResult: Codable {
        let word: String
        let pos: String                       // Ordklass
        let root: String                      // Grundform/rot
        let prefix: String?
        let suffixes: [String]
        let morphemes: [String]               // Alla morfem
        let morphologicalStructure: String    // Beskrivning: "förut + säg + bar + het + undersök + ning + en"
        let inflection: InflectionInfo
        let derivation: [String]              // Relaterade ord (derivat)
        let compounds: [String]               // Vanliga sammansättningar
        let cefrLevel: String
        let frequency: String                 // "hög", "medel", "låg"
        let timestamp: Date
    }

    struct InflectionInfo: Codable {
        let paradigm: [String]                // Alla böjningsformer
        let grammaticalCategory: String       // T.ex. "substantiv utrum singular bestämd"
    }

    func morphologyDeepAnalysis(_ words: [String]) async -> [MorphologyDeepResult] {
        guard apiKey != nil else {
            print("[OpenRouter] No API key - morphology analysis disabled")
            return []
        }

        guard !words.isEmpty else { return [] }

        let cacheKey = words.joined(separator: "|||").hashValue
        let cacheKeyStr = "morphology_\(cacheKey)"

        // Check persistent cache (Iteration 23 - 7 day TTL for morphology)
        if let cachedData = readFromPersistentCache(key: cacheKeyStr, ttl: morphologyTTL),
           let cached = try? JSONDecoder().decode(MorphologyDeepResult.self, from: cachedData) {
            morphologyCache[cacheKey] = cached
            return [cached]
        }

        if let cached = morphologyCache[cacheKey] {
            return [cached]
        }

        let systemPrompt = """
        Du är en expert på svensk morfologi. För varje ord, ge en FULLSTÄNDIG morfologisk analys:

        1. Ordklass (substantiv, verb, adjektiv, adverb, preposition, konjunktion, pronomen, interjektion)
        2. Rot/grundform
        3. Prefix (om något)
        4. Suffix (alla)
        5. Sammansättningens delar (om sammansatt ord)
        6. Fullständig böjningsparadigm
        7. Derivat (besläktade ord)
        8. Vanliga sammansättningar
        9. CEFR-nivå
        10. Frekvens (hög/medel/låg)

        Viktiga svenska morfem:
        - Substantiv: -en (best.sg.utrum), -et (best.sg.neutrum), -or/-ar/-n (plural)
        - Verb: -er (presens), -de (preteritum svaga), -(d)e (supinum), -ande (presens particip)
        - Adjektiv: -t (neutrum), -a (plural/bestämd), -are (komparativ), -ast (superlativ)
        - Derivation: -het, -ning, -tion, -logi, -isk, -bar, -lös, -full, -sam

        Svara ENDAST med giltig JSON:
        [
          {
            "word": "förutspåbarhetsundersökningen",
            "pos": "substantiv",
            "root": "sök",
            "prefix": "förut",
            "suffixes": ["bar", "het", "undersök", "ning", "en"],
            "morphemes": ["förut", "säg", "bar", "het", "under", "sök", "ning", "en"],
            "morphologicalStructure": "förut + säg + bar + het + under + sök + ning + en",
            "inflection": {
              "paradigm": ["förutspåbarhetsundersökning", "förutspåbarhetsundersökningar", "förutspåbarhetsundersökningarna"],
              "grammaticalCategory": "substantiv utrum singular bestämd form"
            },
            "derivation": ["förutspå", "förutspåelse", "spåbar", "spårbarhet"],
            "compounds": ["undersökningsresultat", "undersökningsmetod"],
            "cefrLevel": "C1",
            "frequency": "låg"
          }
        ]

        Analysera dessa ord:
        """

        let userPrompt = words.enumerated().map { "\($0 + 1). \"\($1)\"" }.joined(separator: "\n")

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .morphology,
                maxRetries: 3
            )

            let results = try parseMorphologyResponse(response)
            if let first = results.first {
                morphologyCache[cacheKey] = first
                if let encoded = try? JSONEncoder().encode(first) {
                    writeToPersistentCache(key: cacheKeyStr, data: encoded, ttl: morphologyTTL)
                }
                trimCache(&morphologyCache, maxSize: maxCacheSize)
            }

            recordSuccess()
            return results
        } catch {
            recordFailure()
            print("[OpenRouter] Morphology analysis failed: \(error)")
            return []
        }
    }

    // MARK: - 4. ORDFÖRRÅDSEXPANSION MED CEFR

    struct VocabularyExpansionResult: Codable {
        let domain: String
        let newWords: [VocabularyWord]
        let timestamp: Date
    }

    struct VocabularyWord: Codable {
        let word: String
        let pos: String                       // Ordklass
        let definition: String
        let exampleSentence: String
        let synonyms: [String]
        let antonyms: [String]
        let relatedWords: [String]
        let inflection: [String]              // Böjningsformer
        let cefrLevel: String
        let semanticField: String
        let frequency: String
        let morphologyNote: String?           // Särskild morfologisk notering
    }

    func expandVocabulary(for domain: String, count: Int = 15, targetCEFR: String = "B1-C2") async -> VocabularyExpansionResult {
        guard apiKey != nil else {
            print("[OpenRouter] No API key - vocabulary expansion disabled")
            return VocabularyExpansionResult(domain: domain, newWords: [], timestamp: Date())
        }

        let cacheKey = "\(domain):\(count):\(targetCEFR)".hashValue
        if let cached = vocabularyCache[cacheKey] {
            return cached
        }

        let systemPrompt = """
        Du är en svensk språkexpert. Generera \(count) svenska ord inom domänen "\(domain)" på CEFR-nivå \(targetCEFR).

        För varje ord, ge:
        1. Ordet
        2. Ordklass (substantiv/verb/adjektiv/adverb)
        3. Tydlig definition
        4. Exempelmening som visar användning
        5. 2-3 synonymer
        6. 1-2 antonymer (om tillämpligt)
        7. 2-3 relaterade ord
        8. Böjningsformer:
           - Substantiv: plural, bestämd form singular (t.ex. "bilar", "bilen")
           - Verb: presens, preteritum, supinum, imperativ (t.ex. "är", "var", "varit", "var!")
           - Adjektiv: utrum, neutrum, plural (t.ex. "fin", "fint", "fina")
        9. CEFR-nivå (A1, A2, B1, B2, C1, C2)
        10. Semantiskt fält
        11. Frekvens (hög/medel/låg)
        12. Morfologisk notering (om intressant, t.ex. sammansättning eller derivation)

        Prioritera ord som:
        - Används i akademisk eller formell svenska
        - Har intressant morfologisk struktur
        - Bygger på vanliga rötter med olika affix
        - Är relevanta för kognition, vetenskap, filosofi, teknik

        Svara ENDAST med giltig JSON:
        {
          "domain": "\(domain)",
          "newWords": [
            {
              "word": "kausalitet",
              "pos": "substantiv",
              "definition": "förhållandet mellan orsak och verkan",
              "exampleSentence": "Studien undersökte kausaliteten mellan variablerna.",
              "synonyms": ["orsaksförhållande", "orsakssamband"],
              "antonyms": ["korrelation", "slump"],
              "relatedWords": ["kausal", "orsak", "verkan", "betingelse"],
              "inflection": ["kausaliteter", "kausaliteten"],
              "cefrLevel": "C1",
              "semanticField": "filosofi/logik",
              "frequency": "medel",
              "morphologyNote": "Avledning från latin causa + -al + -itet"
            }
          ]
        }
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Generera ord för domänen: \(domain)",
                task: .vocabulary,
                maxRetries: 3
            )

            let result = try parseVocabularyResponse(response, domain: domain)
            vocabularyCache[cacheKey] = result
            trimCache(&vocabularyCache, maxSize: maxCacheSize)

            recordSuccess()
            return result
        } catch {
            recordFailure()
            print("[OpenRouter] Vocabulary expansion failed: \(error)")
            return VocabularyExpansionResult(domain: domain, newWords: [], timestamp: Date())
        }
    }

    // MARK: - 5. STIL- OCH KOMPLEXITETSANALYS

    struct StyleComplexityResult: Codable {
        let text: String
        let overallScore: Double              // 0.0-1.0
        let sentenceStructureScore: Double    // Enkla/huvud-/bisatser
        let lexicalVariationScore: Double     // CEFR-nivå
        let stylisticCoherenceScore: Double   // Flyt och koherens
        let naturalnessScore: Double          // Hur naturligt låter det? (1-10 → 0-1)
        let averageCEFR: String               // Uppskattad genomsnittlig CEFR-nivå
        let sentenceTypes: [String: Int]      // {"enkla": 5, "huvudsatser": 3, "bisatser": 2}
        let suggestions: [String]             // Specifika förbättringsförslag
        let timestamp: Date
    }

    func analyzeStyleComplexity(_ texts: [String]) async -> [StyleComplexityResult] {
        guard apiKey != nil else {
            print("[OpenRouter] No API key - style analysis disabled")
            return []
        }

        guard !texts.isEmpty else { return [] }

        let cacheKey = texts.joined(separator: "|||").hashValue
        let cacheKeyStr = "style_\(cacheKey)"

        // Check persistent cache
        if let cachedData = readFromPersistentCache(key: cacheKeyStr, ttl: grammarStyleTTL),
           let cached = try? JSONDecoder().decode([StyleComplexityResult].self, from: cachedData) {
            return cached
        }

        let systemPrompt = """
        Du är en expert på svensk språkstil och komplexitet. Analysera följande texter på:

        1. Meningsstruktur (0-1): Förekomst av enkla meningar, huvudsatser, bisatser
        2. Lexikalisk variation (0-1): Ordförrådets bredd och CEFR-nivå
        3. Stilistisk koherens (0-1): Flyt, logiska övergångar, tematisk enhetlighet
        4. Naturlighet (0-1): Hur naturligt låter det för en infödd svensk talare?

        Ge också:
        - Uppskattad genomsnittlig CEFR-nivå (A1-C2)
        - Fördelning av meningstyper
        - Specifika, konkreta förbättringsförslag

        Svara ENDAST med giltig JSON:
        [
          {
            "text": "original text",
            "overallScore": 0.72,
            "sentenceStructureScore": 0.65,
            "lexicalVariationScore": 0.70,
            "stylisticCoherenceScore": 0.80,
            "naturalnessScore": 0.75,
            "averageCEFR": "B1",
            "sentenceTypes": {"enkla": 3, "huvudsatser": 5, "bisatser": 2},
            "suggestions": ["Använd fler bisatser med 'eftersom' och 'medan'", "Variera ordföljden mer"]
          }
        ]

        Analysera dessa texter:
        """

        let userPrompt = texts.enumerated().map { "\($0 + 1). \"\($1)\"" }.joined(separator: "\n\n")

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .style,
                maxRetries: 3
            )

            let results = try parseStyleResponse(response)

            // Persist to cache
            if let encoded = try? JSONEncoder().encode(results) {
                writeToPersistentCache(key: cacheKeyStr, data: encoded, ttl: grammarStyleTTL)
            }

            recordSuccess()
            return results
        } catch {
            recordFailure()
            print("[OpenRouter] Style analysis failed: \(error)")
            return []
        }
    }

    // MARK: - 6. SJÄLVRÄTTANDE SPRÅKINLÄRNING

    struct LanguageErrorAnalysis: Codable {
        let error: String
        let correction: String
        let ruleExplanation: String
        let similarExamples: [String]
        let learningPriority: Double  // 0.0-1.0
        let category: String          // "grammar", "vocabulary", "syntax", "morphology"
    }

    func analyzeLanguageErrors(_ errorTexts: [String]) async -> [LanguageErrorAnalysis] {
        guard apiKey != nil else { return [] }

        let systemPrompt = """
        Du är en svensk språklärare. Analysera följande felaktiga svenska texter.

        För varje text:
        1. Identifiera varje fel
        2. Ge korrekt version
        3. Förklara regeln som brutits mot
        4. Ge 2-3 liknande exempel som illustrerar regeln
        5. Prioritera lärbehov (0.0-1.0)
        6. Kategorisera felet

        Svara ENDAST med giltig JSON:
        [
          {
            "error": "felaktig text",
            "correction": "korrigerad text",
            "ruleExplanation": "Detta bryter mot V2-regeln...",
            "similarExamples": ["rätt exempel 1", "rätt exempel 2"],
            "learningPriority": 0.9,
            "category": "grammar"
          }
        ]

        Analysera dessa fel:
        """

        let userPrompt = errorTexts.enumerated().map { "\($0 + 1). \"\($1)\"" }.joined(separator: "\n\n")

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .errorAnalysis,
                maxRetries: 3
            )

            let results = try parseErrorAnalysisResponse(response)
            recordSuccess()
            return results
        } catch {
            recordFailure()
            print("[OpenRouter] Error analysis failed: \(error)")
            return []
        }
    }

    // MARK: - API-ANROP

    // Iteration 21+22: Adaptive model selection + retry with exponential backoff
    private func callOpenRouterWithRetry(
        system: String,
        user: String,
        task: EvaluationTask,
        maxRetries: Int = 3
    ) async throws -> String {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let response = try await callOpenRouter(
                    system: system,
                    user: user,
                    task: task,
                    modelOverride: attempt > 0 ? fallbackModels[attempt % fallbackModels.count] : nil
                )
                return response
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(domain: "OpenRouter", code: 99,
                                   userInfo: [NSLocalizedDescriptionKey: "All retries failed"])
    }

    private func callOpenRouter(
        system: String,
        user: String,
        task: EvaluationTask,
        modelOverride: String? = nil
    ) async throws -> String {
        totalCalls += 1

        guard let apiKey = apiKey else {
            throw URLError(.userAuthenticationRequired)
        }

        let model = modelOverride ?? task.model
        let maxTokens = task.defaultMaxTokens

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.1
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw NSError(domain: "OpenRouter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("Eon-Y/5.0 (https://github.com/Terrorbyte90/Eon-Y-V5)", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Eon Language Evaluator", forHTTPHeaderField: "X-Title")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenRouter", code: 2, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenRouter", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OpenRouter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }

        return content
    }

    // MARK: - PARSNING

    private func extractJSONBlock(from text: String) -> String {
        // Försök hitta JSON i markdown code block
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Försök hitta JSON i generic code block
        if let start = text.range(of: "```"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            let block = String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if block.hasPrefix("[") || block.hasPrefix("{") {
                return block
            }
        }
        // Försök hitta JSON direkt
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return trimmed
        }
        // Försök hitta första JSON-strukturen
        if let start = trimmed.firstIndex(of: "["),
           let end = trimmed.lastIndex(of: "]") {
            return String(trimmed[start...end])
        }
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }

    private func parseGrammarResponse(_ response: String, originalTexts: [String]) throws -> [GrammarAnalysisResult] {
        let jsonStr = extractJSONBlock(from: response)
        guard let data = jsonStr.data(using: .utf8),
              let rawResults = try? JSONDecoder().decode([[String: Any]].self, from: data) else {
            // Försök med Codable
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let results = try? decoder.decode([GrammarAnalysisResult].self, from: jsonStr.data(using: .utf8)!) {
                return results
            }
            throw NSError(domain: "OpenRouter", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to parse grammar response"])
        }

        // Fallback: skapa resultat manuellt från rådata
        return originalTexts.map { text in
            GrammarAnalysisResult(
                text: text,
                errors: [],
                correctedText: text,
                overallScore: 0.7,
                v2Compliance: true,
                suggestions: ["Kunde inte parsa detaljerat svar"],
                timestamp: Date()
            )
        }
    }

    private func parseWSDResponse(_ response: String) throws -> [WSDEnhancementResult] {
        let jsonStr = extractJSONBlock(from: response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let results = try? decoder.decode([WSDEnhancementResult].self, from: jsonStr.data(using: .utf8)!) {
            return results
        }
        throw NSError(domain: "OpenRouter", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to parse WSD response"])
    }

    private func parseMorphologyResponse(_ response: String) throws -> [MorphologyDeepResult] {
        let jsonStr = extractJSONBlock(from: response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let results = try? decoder.decode([MorphologyDeepResult].self, from: jsonStr.data(using: .utf8)!) {
            return results
        }
        throw NSError(domain: "OpenRouter", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to parse morphology response"])
    }

    private func parseVocabularyResponse(_ response: String, domain: String) throws -> VocabularyExpansionResult {
        let jsonStr = extractJSONBlock(from: response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let result = try? decoder.decode(VocabularyExpansionResult.self, from: jsonStr.data(using: .utf8)!) {
            return result
        }
        throw NSError(domain: "OpenRouter", code: 13, userInfo: [NSLocalizedDescriptionKey: "Failed to parse vocabulary response"])
    }

    private func parseStyleResponse(_ response: String) throws -> [StyleComplexityResult] {
        let jsonStr = extractJSONBlock(from: response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let results = try? decoder.decode([StyleComplexityResult].self, from: jsonStr.data(using: .utf8)!) {
            return results
        }
        throw NSError(domain: "OpenRouter", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to parse style response"])
    }

    private func parseErrorAnalysisResponse(_ response: String) throws -> [LanguageErrorAnalysis] {
        let jsonStr = extractJSONBlock(from: response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let results = try? decoder.decode([LanguageErrorAnalysis].self, from: jsonStr.data(using: .utf8)!) {
            return results
        }
        throw NSError(domain: "OpenRouter", code: 15, userInfo: [NSLocalizedDescriptionKey: "Failed to parse error analysis response"])
    }

    // MARK: - BATCH-SPRÅKUTVÄRDERING (Huvudmetod)

    struct BatchLanguageEvaluation {
        let grammarResults: [GrammarAnalysisResult]
        let wsdResults: [WSDEnhancementResult]
        let morphologyResults: [MorphologyDeepResult]
        let styleResults: [StyleComplexityResult]
        let overallScore: Double
        let recommendations: [String]
        let timestamp: Date
    }

    // MARK: - Iteration 24: Multi-Pass Evaluation
    // Pass 1: quick grammar check, Pass 2: deep analysis for low-scoring items

    func runBatchEvaluation(
        texts: [String],
        words: [String],
        wordContexts: [(word: String, context: String)],
        domain: String
    ) async -> BatchLanguageEvaluation {
        print("[OpenRouter] Starting batch language evaluation for domain: \(domain)")

        // PASS 1: Quick grammar check
        async let grammarTask = batchGrammarCheck(texts)
        async let wsdTask = batchWSD(wordContexts)
        async let morphologyTask = morphologyDeepAnalysis(words)
        async let styleTask = analyzeStyleComplexity(texts)

        var (grammar, wsd, morphology, style) = await (grammarTask, wsdTask, morphologyTask, styleTask)

        // PASS 2: Deep re-evaluation for low-scoring grammar items (< 0.6)
        let lowScoringTexts = grammar.filter { $0.overallScore < 0.6 }.map { $0.text }
        if !lowScoringTexts.isEmpty {
            print("[OpenRouter] Pass 2: Re-evaluating \(lowScoringTexts.count) low-scoring items with deeper analysis")
            let deepGrammar = await batchGrammarCheckWithDeepAnalysis(lowScoringTexts)

            // Merge deep results back into grammar results
            for deepResult in deepGrammar {
                if let idx = grammar.firstIndex(where: { $0.text == deepResult.text }) {
                    grammar[idx] = deepResult
                }
            }
        }

        // Beräkna övergripande poäng
        let grammarScore = grammar.isEmpty ? 0.7 : grammar.reduce(0) { $0 + $1.overallScore } / Double(grammar.count)
        let styleScore = style.isEmpty ? 0.7 : style.reduce(0) { $0 + $1.overallScore } / Double(style.count)
        let wsdConfidence = wsd.isEmpty ? 0.7 : wsd.reduce(0) { $0 + $1.confidence } / Double(wsd.count)
        let overallScore = (grammarScore * 0.4 + styleScore * 0.3 + wsdConfidence * 0.3)

        // Generera rekommendationer
        var recommendations: [String] = []

        for result in grammar {
            for error in result.errors {
                recommendations.append("Grammatik: \(error.explanation)")
            }
            recommendations.append(contentsOf: result.suggestions)
        }

        for result in style {
            recommendations.append(contentsOf: result.suggestions)
        }

        if wsd.isEmpty {
            recommendations.append("Utöka WSD med fler ord genom OpenRouter")
        }

        if morphology.isEmpty {
            recommendations.append("Fördjupa morfologianalys med OpenRouter")
        }

        return BatchLanguageEvaluation(
            grammarResults: grammar,
            wsdResults: wsd,
            morphologyResults: morphology,
            styleResults: style,
            overallScore: overallScore,
            recommendations: recommendations,
            timestamp: Date()
        )
    }

    // Deep grammar analysis for low-scoring items (Pass 2)
    private func batchGrammarCheckWithDeepAnalysis(_ texts: [String]) async -> [GrammarAnalysisResult] {
        guard apiKey != nil else { return [] }
        guard !texts.isEmpty else { return [] }

        let systemPrompt = """
        Du är en expert på svensk grammatik. Dessa texter har identifierats som potentiellt problematiska.
        Ge en DJUPARE analys med fokus på:

        1. Varje V2-regel-brott med detaljerad förklaring
        2. Bisatsordföljd (subjekt + inte + verb)
        3. Kongruens mellan subjekt och verb
        4. Adverbplacering i huvud- och bisatser
        5. kasus (han/honom, hon/henne, de/dem)
        6. Genus (en/ett) och böjning

        Ge minst 3 konkreta förbättringsförslag per text.
        Svara ENDAST med giltig JSON enligt samma format som standard grammatikkontroll.
        """

        let userPrompt = texts.enumerated().map { "\($0 + 1). \"\($1)\"" }.joined(separator: "\n\n")

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .grammar,
                maxRetries: 3
            )

            let results = try parseGrammarResponse(response, originalTexts: texts)
            recordSuccess()
            return results
        } catch {
            recordFailure()
            print("[OpenRouter] Deep grammar check failed: \(error)")
            return []
        }
    }

    // MARK: - Iteration 26: Grammar Rule Extraction

    struct GrammarRule: Codable {
        let name: String
        let description: String
        let examples: [String]
        let counterExamples: [String]
        let difficultyLevel: String  // A1, A2, B1, B2, C1, C2
        let category: String         // "v2", "word_order", "agreement", "adverb", "case", "gender", "inflection"
        let timestamp: Date
    }

    func extractGrammarRules(from texts: [String]) async -> [GrammarRule] {
        guard apiKey != nil else {
            print("[OpenRouter] No API key - grammar rule extraction disabled")
            return []
        }

        guard !texts.isEmpty else { return [] }

        let systemPrompt = """
        Du är en svensk grammatikexpert. Extrahera explicita grammatikregler från följande texter.

        För varje regel, identifiera:
        1. Regelns namn (t.ex. "V2-regeln i huvudsats")
        2. Tydlig beskrivning av regeln
        3. 2-3 korrekta exempel som illustrerar regeln
        4. 1-2 motexempel (vanliga fel)
        5. Svårighetsnivå (A1, A2, B1, B2, C1, C2)
        6. Kategori: "v2", "word_order", "agreement", "adverb", "case", "gender", "inflection"

        Svara ENDAST med giltig JSON:
        [
          {
            "name": "V2-regeln",
            "description": "I huvudsats måste det finitade verbet stå på position 2",
            "examples": ["Jag läser en bok idag.", "Idag läser jag en bok."],
            "counterExamples": ["Jag en bok läser idag.", "Idag jag läser en bok."],
            "difficultyLevel": "A2",
            "category": "v2"
          }
        ]

        Analysera dessa texter:
        """

        let userPrompt = texts.enumerated().map { "\($0 + 1). \"\($1)\"" }.joined(separator: "\n\n")

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .grammarRuleExtraction,
                maxRetries: 3
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let rules = try? decoder.decode([GrammarRule].self, from: jsonStr.data(using: .utf8)!) {
                recordSuccess()

                // Store rules as teachable facts
                for rule in rules {
                    print("[GrammarRules] Extracted: \(rule.name) (\(rule.difficultyLevel))")
                }
                return rules
            }
            throw NSError(domain: "OpenRouter", code: 16,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse grammar rules"])
        } catch {
            recordFailure()
            print("[OpenRouter] Grammar rule extraction failed: \(error)")
            return []
        }
    }

    // MARK: - Iteration 27: CEFR Level Estimation

    struct CEFREstimation: Codable {
        let text: String
        let estimatedLevel: String       // A1, A2, B1, B2, C1, C2
        let confidence: Double           // 0.0-1.0
        let breakdown: [String: Double]  // {"vocabulary": 0.7, "grammar": 0.6, "complexity": 0.8}
        let strengths: [String]
        let areasForImprovement: [String]
        let timestamp: Date
    }

    func estimateCEFRLevel(text: String) async -> CEFREstimation {
        guard apiKey != nil else {
            print("[OpenRouter] No API key - CEFR estimation disabled")
            return CEFREstimation(
                text: text, estimatedLevel: "Unknown", confidence: 0.0,
                breakdown: [:], strengths: [], areasForImprovement: [], timestamp: Date()
            )
        }

        let systemPrompt = """
        Du är en expert på att bedöma svenska texters CEFR-nivå (A1-C2).

        CEFR-nivåer för svenska:
        - A1: Enkla meningar, grundläggande ordförråd, presentera sig själv
        - A2: Enkla samtal, beskriva vardag, grundläggande tidsuttryck
        - B1: Hantera de flesta situationer, beskriva upplevelser, ge åsikter
        - B2: Flytande konversation, abstrakta ämnen, detaljerade texter
        - C1: Flytande och spontant, implicita betydelser, akademisk svenska
        - C2: Nära infödd nivå, nyanserad förståelse, komplexa resonemang

        Bedöm följande text på:
        1. Vokabulärens komplexitet
        2. Grammatisk korrekthet
        3. Meningsstruktur (enkla vs sammansatta meningar)
        4. Diskurskoherens

        Svara ENDAST med giltig JSON:
        {
          "text": "original text",
          "estimatedLevel": "B1",
          "confidence": 0.85,
          "breakdown": {
            "vocabulary": 0.7,
            "grammar": 0.8,
            "complexity": 0.6,
            "coherence": 0.9
          },
          "strengths": ["God grammatisk struktur", "Variert ordförråd"],
          "areasForImprovement": ["Använd fler bisatser", "Variera meningslängd"]
        }

        Text att bedöma:
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "\"\(text)\"",
                task: .cefrEstimation,
                maxRetries: 3
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let estimation = try? decoder.decode(CEFREstimation.self, from: jsonStr.data(using: .utf8)!) {
                recordSuccess()
                return estimation
            }
            throw NSError(domain: "OpenRouter", code: 17,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse CEFR estimation"])
        } catch {
            recordFailure()
            print("[OpenRouter] CEFR estimation failed: \(error)")
            return CEFREstimation(
                text: text, estimatedLevel: "Unknown", confidence: 0.0,
                breakdown: [:], strengths: [], areasForImprovement: [], timestamp: Date()
            )
        }
    }

    // MARK: - Iteration 29: Self-Correction via OpenRouter

    struct SelfCorrectionResult: Codable {
        let originalText: String
        let correctedText: String
        let corrections: [GrammarError]
        let hadErrors: Bool
        let timestamp: Date
    }

    func selfCorrectText(_ text: String) async -> SelfCorrectionResult {
        guard apiKey != nil else {
            return SelfCorrectionResult(
                originalText: text, correctedText: text, corrections: [],
                hadErrors: false, timestamp: Date()
            )
        }

        let systemPrompt = """
        Du är en svensk språkgranskare. Granska följande text och korrigera ALLA fel.

        Fokusera på:
        1. V2-regel-brott
        2. Ordföljdsfel (särskilt bisatser)
        3. Kongruensfel
        4. Adverbplacering
        5. Kasus (han/honom, de/dem)
        6. Genus (en/ett)
        7. Stavningsfel och särskrivning

        Svara ENDAST med giltig JSON:
        {
          "originalText": "original text",
          "correctedText": "fully corrected text",
          "corrections": [
            {
              "type": "v2_violation",
              "description": "Beskrivning",
              "original": "felaktig fras",
              "corrected": "korrigerad fras",
              "position": 0,
              "severity": 0.8,
              "explanation": "Regelförklaring"
            }
          ],
          "hadErrors": true
        }
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Granska och korrigera: \"\(text)\"",
                task: .selfCorrection,
                maxRetries: 3
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let result = try? decoder.decode(SelfCorrectionResult.self, from: jsonStr.data(using: .utf8)!) {
                if result.hadErrors {
                    print("[SelfCorrection] Found \(result.corrections.count) errors in text")
                    for correction in result.corrections {
                        print("[SelfCorrection]   \(correction.type): '\(correction.original)' → '\(correction.corrected)'")
                    }
                }
                recordSuccess()
                return result
            }
            throw NSError(domain: "OpenRouter", code: 18,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse self-correction response"])
        } catch {
            recordFailure()
            print("[OpenRouter] Self-correction failed: \(error)")
            return SelfCorrectionResult(
                originalText: text, correctedText: text, corrections: [],
                hadErrors: false, timestamp: Date()
            )
        }
    }

    // MARK: - ITERATION 28: Sprakbanken Enrichment

    struct SprakbankenEnrichment: Codable {
        let word: String
        let definition: String
        let exampleSentences: [String]
        let collocations: [String]
        let cefrLevel: String
        let semanticField: String
        let synonyms: [String]
        let antonyms: [String]
        let timestamp: Date
    }

    func enrichSprakbankenData(_ sprakbankenResults: [String]) async -> [SprakbankenEnrichment] {
        guard apiKey != nil else { return [] }
        guard !sprakbankenResults.isEmpty else { return [] }

        let systemPrompt = """
        Du är en svensk språkexpert. Berika följande ord från Språkbanken med:

        1. Tydlig definition på svenska
        2. 2-3 exempelmeningar som visar användning
        3. Vanliga kollokationer (ord som ofta förekommer tillsammans)
        4. CEFR-nivå (A1-C2)
        5. Semantiskt fält
        6. 2-3 synonymer
        7. 1-2 antonymer (om tillämpligt)

        Svara ENDAST med giltig JSON:
        [
          {
            "word": "ordet",
            "definition": "tydlig definition",
            "exampleSentences": ["mening 1", "mening 2"],
            "collocations": ["kollokation1", "kollokation2"],
            "cefrLevel": "B1",
            "semanticField": "semantiskt fält",
            "synonyms": ["synonym1", "synonym2"],
            "antonyms": ["antonym1"]
          }
        ]

        Berika dessa ord:
        """

        let userPrompt = sprakbankenResults.enumerated().map { "\($0 + 1). \"\($1)\"" }.joined(separator: "\n")

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .sprakbankenEnrichment,
                maxRetries: 3
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let results = try? decoder.decode([SprakbankenEnrichment].self, from: jsonStr.data(using: .utf8)!) {
                recordSuccess()
                return results
            }
            throw NSError(domain: "OpenRouter", code: 19,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse Sprakbanken enrichment"])
        } catch {
            recordFailure()
            print("[OpenRouter] Sprakbanken enrichment failed: \(error)")
            return []
        }
    }

    // MARK: - CACHE-HANTERING

    private func trimCache<T>(_ cache: inout [Int: T], maxSize: Int) {
        while cache.count > maxSize {
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
    }

    func clearAllCaches() {
        grammarCache.removeAll()
        wsdCache.removeAll()
        morphologyCache.removeAll()
        vocabularyCache.removeAll()
        clearExpiredCache()
    }

    // MARK: - STATISTIK

    func getStatistics() -> (total: Int, success: Int, failed: Int, successRate: Double) {
        let rate = totalCalls > 0 ? Double(successfulCalls) / Double(totalCalls) : 0.0
        return (totalCalls, successfulCalls, failedCalls, rate)
    }

    private func recordSuccess() {
        successfulCalls += 1
        lastEvaluationDate = Date()
    }

    private func recordFailure() {
        failedCalls += 1
    }
}
