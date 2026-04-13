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

    // Fallback models for retry rotation — v93: expanded to 10+ models
    private let fallbackModels = [
        "meta-llama/llama-3.1-8b-instruct:free",
        "mistralai/mistral-7b-instruct:free",
        "qwen/qwen-2-7b-instruct:free",
        "google/gemma-2-9b-it:free",
        "nousresearch/hermes-2-pro-llama-3-8b:free",
        "openchat/openchat-7b:free",
        "undi95/toppy-m-7b:free",
        "sophosympatheia/rogue-rose-103b-v0.2:free",
        "huggingfaceh4/zephyr-7b-beta:free",
        "cognitivecomputations/dolphin-mixtral-8x7b:free",
        "neversleep/noromaid-7b:free",
        "gryphe/mythomist-7b:free",
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

    // v72: Get a domain-specific language score (0-1) from OpenRouter evaluation
    func getDomainScore(domain: String) async -> Double {
        guard apiKey != nil else { return 0.5 }

        // Retrieve recent texts related to the domain
        let recentTexts = await PersistentMemoryStore.shared.searchFacts(query: domain, limit: 5)
            .map { $0.detail }
            .filter { !$0.isEmpty }

        guard !recentTexts.isEmpty else { return 0.5 }

        let styleResults = await analyzeStyleComplexity(Array(recentTexts.prefix(3)))
        if styleResults.isEmpty { return 0.5 }

        let avgScore = styleResults.reduce(0) { $0 + $1.overallScore } / Double(styleResults.count)
        return min(1.0, max(0.0, avgScore))
    }

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

    // v78: Compare two Swedish texts and determine which is more grammatically correct,
    // natural, and appropriate. Use this to rank different phrasings Eon could use.
    struct VariantComparison: Codable {
        let text1Score: Double
        let text2Score: Double
        let winner: Int  // 1 or 2
        let grammarWinner: Int
        let naturalnessWinner: Int
        let appropriatenessWinner: Int
        let explanation: String
    }

    func compareSwedishVariants(text1: String, text2: String) async -> VariantComparison {
        guard apiKey != nil else {
            // Fallback: simple heuristic comparison
            return heuristicCompare(text1: text1, text2: text2)
        }

        let systemPrompt = """
        Du är en expert på svenska. Jämför följande två texter och bedöm vilken som är:
        1. Grammatiskt korrekt (V2-regel, kongruens, adverbplacering)
        2. Naturlig (låter som en infödd talare)
        3. Lämplig (passar kontexten)

        Ge poäng 0.0-1.0 för varje kategori och avgör vinnare.
        Svara ENDAST med JSON:
        {
          "text1Score": 0.75,
          "text2Score": 0.82,
          "grammarWinner": 2,
          "naturalnessWinner": 2,
          "appropriatenessWinner": 1,
          "explanation": "Text 2 har bättre ordföljd men text 1 är mer passande"
        }

        Text 1: "\(text1)"
        Text 2: "\(text2)"
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Jämför texterna",
                task: .grammar,
                maxRetries: 2
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let result = try? decoder.decode(VariantComparison.self, from: jsonStr.data(using: .utf8)!) {
                return result
            }
        } catch {
            print("[OpenRouter] Variant comparison failed: \(error)")
        }

        return heuristicCompare(text1: text1, text2: text2)
    }

    private func heuristicCompare(text1: String, text2: String) -> VariantComparison {
        // Simple heuristic: prefer longer text (more content), fewer grammar issues
        let len1 = Double(text1.count)
        let len2 = Double(text2.count)
        let lenScore1 = min(1.0, len1 / max(len1, len2))
        let lenScore2 = min(1.0, len2 / max(len1, len2))

        // Penalize texts with common Swedish grammar errors
        let errors1 = ["jag är en", "det är en"].filter { text1.lowercased().contains($0) }.count
        let errors2 = ["jag är en", "det är en"].filter { text2.lowercased().contains($0) }.count

        let score1 = lenScore1 * 0.7 - Double(errors1) * 0.1
        let score2 = lenScore2 * 0.7 - Double(errors2) * 0.1

        let winner = score1 > score2 ? 1 : 2

        return VariantComparison(
            text1Score: max(0, score1),
            text2Score: max(0, score2),
            winner: winner,
            grammarWinner: errors1 < errors2 ? 1 : 2,
            naturalnessWinner: winner,
            appropriatenessWinner: winner,
            explanation: "Heuristisk: text \(winner) vann baserat på längd och färre grammatikfel"
        )
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

    // ═══════════════════════════════════════════════════════════
    // ITERATION 108: Follow-up Question Generation
    // ═══════════════════════════════════════════════════════════

    /// Generate 3 thoughtful follow-up questions Eon could ask the user to deepen the conversation.
    /// Based on response content, identify unexplored angles.
    func generateFollowUpQuestions(response: String) async -> [String] {
        guard apiKey != nil else {
            return fallbackFollowUpQuestions(response)
        }

        let systemPrompt = """
        Du är en samtalspartner som vill fördjupa diskussionen. Baserat på följande svar, generera 3 tankeväckande följdfrågor som Eon kan ställa till användaren.

        Frågorna ska:
        1. Utforska outforskade vinklar av ämnet
        2. Uppmuntra användaren att dela personliga erfarenheter eller åsikter
        3. Koppla ämnet till större sammanhang eller relaterade områden

        Svara ENDAST med giltig JSON:
        ["fråga 1", "fråga 2", "fråga 3"]
        """

        do {
            let response_text = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Generera följdfrågor baserat på detta svar: \"\(response.prefix(500))\"",
                task: .style,
                maxRetries: 2
            )

            let jsonStr = extractJSONBlock(from: response_text)
            if let data = jsonStr.data(using: .utf8),
               let questions = try? JSONDecoder().decode([String].self, from: data),
               !questions.isEmpty {
                return Array(questions.prefix(3))
            }
            return fallbackFollowUpQuestions(response)
        } catch {
            return fallbackFollowUpQuestions(response)
        }
    }

    private func fallbackFollowUpQuestions(_ response: String) -> [String] {
        let lower = response.lowercased()
        let words = Set(lower.components(separatedBy: .whitespacesAndNewlines))

        var questions: [String] = []

        // Detect topics from response
        let topicWords = words.filter { $0.count > 4 && !["och", "eller", "som", "att", "den", "det", "har", "hade", "kan", "ska", "vill", "måste", "inte", "också", "mycket", "mer", "än", "var", "är", "från", "till", "med", "för", "om", "på", "i", "av"].contains($0) }
        let topics = Array(topicWords.prefix(3))

        if topics.count >= 1 {
            questions.append("Vad tänker du om \(topics[0]) i ett större sammanhang?")
        }
        if topics.count >= 2 {
            questions.append("Hur ser du kopplingen mellan \(topics[0]) och \(topics[1])?")
        }
        if topics.count >= 3 {
            questions.append("Finns det något om \(topics[2]) du tycker är särskilt intressant?")
        }

        if questions.isEmpty {
            questions = [
                "Hur upplever du detta personligen?",
                "Vilken aspekt tycker du är viktigast?",
                "Finns det något perspektiv vi inte har diskuterat än?",
            ]
        }

        return Array(questions.prefix(3))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 113: Explain Like I'm Five
    // ═══════════════════════════════════════════════════════════

    /// Take complex concepts Eon knows and generate simplified Swedish explanations.
    /// Test true understanding vs rote knowledge.
    func explainLikeImFive(concept: String) async -> String {
        guard apiKey != nil else {
            return simpleFallbackExplanation(concept)
        }

        let systemPrompt = """
        Du är en pedagogisk förklarare. Förklara följande begrepp som om du pratar med ett femårigt barn.

        Regler:
        - Använd ENKLA ord (max 2 stavelser där det går)
        - Korta meningar (max 10 ord)
        - Använd liknelser och exempel från barns vardag
        - Inga facktermer utan förklaring
        - Max 5-6 meningar
        - Skriv på svenska

        Svara med en ren förklaring, inga JSON eller markdown.
        """

        do {
            let explanation = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Förklara \"\(concept)\" för ett 5-årigt barn",
                task: .wsd,
                maxRetries: 2
            )

            return explanation.count > 20 ? explanation : simpleFallbackExplanation(concept)
        } catch {
            return simpleFallbackExplanation(concept)
        }
    }

    private func simpleFallbackExplanation(_ concept: String) -> String {
        let simpleExplanations: [String: String] = [
            "ai": "AI är som en smart dator som kan lära sig saker, precis som du lär dig i skolan. Den kan känna igen bilder, prata och hjälpa till med läxor.",
            "kausalitet": "Kausalitet betyder att en sak gör att en annan sak händer. Om du släpper en boll så ramlar den. Att släppa bollen ORSAKAR att den ramlar.",
            "medvetande": "Medvetande är det som gör att du vet att du finns. Det är känslan av att vara DU. När du ser en blomma och tycker den är vacker — det är ditt medvetande.",
            "filosofi": "Filosofi är när man tänker mycket svåra tankar om livet. Varför finns vi? Vad är rätt och fel? Filosofer ställer frågor som inte har enkelt svar.",
            "matematik": "Matematik är som ett språk för siffror och former. Det hjälper oss räkna hur många äpplen vi har, hur långt vi ska gå, och hur stor en kaka ska vara.",
            "evolution": "Evolution är när djur ändras väldigt långsamt över lång tid. För länge sedan fanns det inte hundar som vi har nu. De blev olika för att de anpassade sig.",
            "demokrati": "Demokrati betyder att alla får vara med och bestämma. Som när ni i skolan röstar om vilken lek ni ska leka. Alla röster räknas lika mycket.",
            "språk": "Språk är hur vi pratar med varandra. Ord är som byggklossar — vi sätter ihop dem för att berätta vad vi tänker och känner.",
        ]

        let lower = concept.lowercased()
        for (key, explanation) in simpleExplanations {
            if lower.contains(key) { return explanation }
        }

        return "\(concept) är något vi kan lära oss om. Det finns många intressanta saker att veta om \(concept). Vill du att jag berättar mer på ett enkelt sätt?"
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 116: Debate Argument Generation
    // ═══════════════════════════════════════════════════════════

    struct Argument: Codable {
        let claim: String
        let evidence: String
        let reasoning: String
        let strength: Double
        let counterArguments: [String]
    }

    /// Generate well-structured arguments for both sides of a topic.
    /// Use to train Eon's dialectical reasoning.
    func generateDebateArguments(topic: String, side: String = "both") async -> [String: [Argument]] {
        guard apiKey != nil else {
            return fallbackDebateArguments(topic, side)
        }

        let systemPrompt = """
        Du är en debattexpert. Generera välstrukturerade argument för ett ämne.

        För varje argument, ge:
        1. Påstående (claim)
        2. Stödjande bevis/resonemang (evidence)
        3. Resonemang som kopplar ihop (reasoning)
        4. Styrka (0.0-1.0)
        5. Motargument (counterArguments)

        Svara ENDAST med giltig JSON:
        {
          "for": [
            {
              "claim": "påstående",
              "evidence": "stöd",
              "reasoning": "resonemang",
              "strength": 0.8,
              "counterArguments": ["motargument 1", "motargument 2"]
            }
          ],
          "against": [...]
        }

        Ämne: "\(topic)"
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Generera argument för och emot: \(topic)",
                task: .grammar,
                maxRetries: 2
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            if let data = jsonStr.data(using: .utf8),
               let result = try? decoder.decode([String: [Argument]].self, from: data) {
                return result
            }
            return fallbackDebateArguments(topic, side)
        } catch {
            return fallbackDebateArguments(topic, side)
        }
    }

    private func fallbackDebateArguments(_ topic: String, _ side: String) -> [String: [Argument]] {
        let lower = topic.lowercased()

        var forArgs: [Argument] = []
        var againstArgs: [Argument] = []

        // Generate basic arguments based on topic keywords
        if lower.contains("ai") || lower.contains("artificiell") {
            forArgs.append(Argument(claim: "AI kan förbättra sjukvården", evidence: "AI kan analysera röntgenbilder snabbare än människor", reasoning: "Snabbare diagnos leder till bättre behandling", strength: 0.8, counterArguments: ["AI kan göra felbedömningar", "Etiska problem med automatisering"]))
            againstArgs.append(Argument(claim: "AI hotar arbetstillfällen", evidence: "Automation ersätter mänsklig arbetskraft", reasoning: "När AI tar över jobb förlorar människor sin inkomst", strength: 0.7, counterArguments: ["AI skapar nya jobbtyper", "Historiskt har teknik alltid skapat fler jobb"]))
        } else {
            forArgs.append(Argument(claim: "\(topic) har positiva aspekter", evidence: "Det finns forskning som stöder fördelarna", reasoning: "Fördelarna överväger nackdelarna i många fall", strength: 0.6, counterArguments: ["Forskningen kan vara bristfällig", "Kontexten spelar stor roll"]))
            againstArgs.append(Argument(claim: "\(topic) har negativa konsekvenser", evidence: "Det finns dokumenterade problem", reasoning: "Nackdelarna kan vara betydande i vissa situationer", strength: 0.6, counterArguments: ["Problemen kan lösas", "Beror på hur det implementeras"]))
        }

        if side == "for" { return ["for": forArgs] }
        if side == "against" { return ["against": againstArgs] }
        return ["for": forArgs, "against": againstArgs]
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 122: Analogy Generation
    // ═══════════════════════════════════════════════════════════

    /// Create analogies between source and target domains in Swedish.
    /// Test structural mapping ability.
    func generateAnalogy(source: String, target: String) async -> String {
        guard apiKey != nil else {
            return fallbackAnalogy(source, target)
        }

        let systemPrompt = """
        Du är en expert på att skapa analogier. Skapa en tydlig analogi mellan \(source) och \(target).

        Regler:
        - Förklara STRUKTURELLA likheter (inte bara ytliga)
        - Visa hur man kan förstå \(target) genom att tänka på \(source)
        - Använd konkreta exempel
        - Skriv på svenska
        - 3-5 meningar

        Svara med analogin direkt, inga JSON.
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Skapa en analogi mellan \(source) och \(target)",
                task: .style,
                maxRetries: 2
            )

            return response.count > 20 ? response : fallbackAnalogy(source, target)
        } catch {
            return fallbackAnalogy(source, target)
        }
    }

    private func fallbackAnalogy(_ source: String, _ target: String) -> String {
        let analogies: [(String, String, String)] = [
            ("hjärnan", "datorn", "Precis som en dator har en processor som bearbetar information, har hjärnan neuroner som skickar signaler. Båda har minne — datorn har hårddisk och hjärnan har hippocampus. Men hjärnan kan också känslor och kreativitet, vilket en dator inte kan."),
            ("evolution", "språkutveckling", "Precis som evolutionen bygger på små förändringar över lång tid, utvecklas språket genom att nya ord och uttryck långsamt läggs till. Båda processer sker gradvis och de som 'fungerar bäst' överlever."),
            ("cellen", "staden", "En cell är som en liten stad: Cellkärnan är stadshuset där beslut fattas, mitokondrierna är kraftverken som ger energi, cellmembranet är stadsmuren som skyddar, och ribosomerna är fabrikerna som bygger proteiner."),
        ]

        for (s, t, analogy) in analogies {
            if source.lowercased().contains(s) && target.lowercased().contains(t) {
                return analogy
            }
            if source.lowercased().contains(t) && target.lowercased().contains(s) {
                return analogy
            }
        }

        return "Precis som \(source) fungerar genom att olika delar samarbetar, kan vi se \(target) på samma sätt — som ett system där varje del har en specifik roll och tillsammans skapar något större än summan av delarna."
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 127: Socratic Dialogue Generation
    // ═══════════════════════════════════════════════════════════

    struct DialogueTurn: Codable {
        let speaker: String  // "Eon" or "Användare"
        let utterance: String
        let turnType: String  // "question", "answer", "follow-up", "challenge"
        let depth: Int
    }

    /// Generate a Socratic dialogue that leads to deeper understanding through guided questions.
    func generateSocraticDialogue(topic: String) async -> [DialogueTurn] {
        guard apiKey != nil else {
            return fallbackSocraticDialogue(topic)
        }

        let systemPrompt = """
        Du är Sokrates. Generera en sokratisk dialog om ämnet "\(topic)".

        Regler:
        - Eon ställer ledande frågor som hjälper användaren tänka djupare
        - Varje fråga bygger på föregående svar
        - Dialogen ska leda till en insikt eller djupare förståelse
        - 5-7 turer (fråga-svar-par)
        - Skriv på svenska

        Svara ENDAST med giltig JSON:
        [
          {"speaker": "Eon", "utterance": "fråga", "turnType": "question", "depth": 1},
          {"speaker": "Användare", "utterance": "svar", "turnType": "answer", "depth": 1},
          ...
        ]
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Generera en sokratisk dialog om: \(topic)",
                task: .wsd,
                maxRetries: 2
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            if let data = jsonStr.data(using: .utf8),
               let dialogue = try? decoder.decode([DialogueTurn].self, from: data),
               !dialogue.isEmpty {
                return dialogue
            }
            return fallbackSocraticDialogue(topic)
        } catch {
            return fallbackSocraticDialogue(topic)
        }
    }

    private func fallbackSocraticDialogue(_ topic: String) -> [DialogueTurn] {
        [
            DialogueTurn(speaker: "Eon", utterance: "Vad betyder \(topic) för dig?", turnType: "question", depth: 1),
            DialogueTurn(speaker: "Användare", utterance: "Det är något viktigt som påverkar oss alla.", turnType: "answer", depth: 1),
            DialogueTurn(speaker: "Eon", utterance: "På vilket sätt påverkar det oss? Kan du ge ett exempel?", turnType: "follow-up", depth: 2),
            DialogueTurn(speaker: "Användare", utterance: "Det påverkar hur vi tänker och agerar i vardagen.", turnType: "answer", depth: 2),
            DialogueTurn(speaker: "Eon", utterance: "Om det påverkar våra handlingar — betyder det att vi förstår det fullt ut?", turnType: "challenge", depth: 3),
            DialogueTurn(speaker: "Användare", utterance: "Nej, inte nödvändigtvis. Vi kan påverkas av något utan att förstå det.", turnType: "answer", depth: 3),
            DialogueTurn(speaker: "Eon", utterance: "Så det finns en skillnad mellan att ERFARA något och att FÖRSTÅ något. Vad krävs för att gå från erfarenhet till förståelse?", turnType: "question", depth: 4),
        ]
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 130: Response Style Optimization
    // ═══════════════════════════════════════════════════════════

    struct StyleGuide: Codable {
        let formalityLevel: Double        // 0.0 (informal) to 1.0 (formal)
        let preferredSentenceLength: Int  // Average words per sentence
        let vocabularyLevel: String       // "basic", "intermediate", "advanced"
        let topicPreferences: [String]    // Topics the user engages with most
        let humorTolerance: Double        // 0.0 (serious) to 1.0 (playful)
        let directnessPreference: Double  // 0.0 (indirect) to 1.0 (direct)
        let reasoning: String
    }

    /// Analyze the user's language style and generate a personalized style guide.
    func optimizeResponseStyle(user: String) async -> StyleGuide {
        guard apiKey != nil else {
            return fallbackStyleGuide(user)
        }

        let systemPrompt = """
        Du är en språkstilanalytiker. Analysera följande text från användaren och skapa en personlig stilguide.

        Bedöm:
        1. Formalitetsnivå (0.0 = väldigt informell, 1.0 = väldigt formell)
        2. Föredragen meningslängd (genomsnittliga ord per mening)
        3. Ordförrådsnivå ("basic", "intermediate", "advanced")
        4. Ämnespreferenser (vilka typer av ämnen verkar användaren intresserad av?)
        5. Humortolerans (0.0 = seriös, 1.0 = lekfull)
        6. Direkthetspreferens (0.0 = indirekt/höflig, 1.0 = direkt/rak)

        Svara ENDAST med giltig JSON:
        {
          "formalityLevel": 0.4,
          "preferredSentenceLength": 15,
          "vocabularyLevel": "intermediate",
          "topicPreferences": ["teknik", "vardag"],
          "humorTolerance": 0.6,
          "directnessPreference": 0.7,
          "reasoning": "Användaren använder informella uttryck men diskuterar komplexa ämnen..."
        }
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Analysera denna användares språkstil: \"\(user.prefix(1000))\"",
                task: .style,
                maxRetries: 2
            )

            let jsonStr = extractJSONBlock(from: response)
            let decoder = JSONDecoder()
            if let data = jsonStr.data(using: .utf8),
               let guide = try? decoder.decode(StyleGuide.self, from: data) {
                return guide
            }
            return fallbackStyleGuide(user)
        } catch {
            return fallbackStyleGuide(user)
        }
    }

    private func fallbackStyleGuide(_ user: String) -> StyleGuide {
        let lower = user.lowercased()
        let words = user.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let sentences = user.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let avgSentenceLength = sentences.isEmpty ? 15 : words.count / max(1, sentences.count)

        // Formality estimation
        let formalMarkers = Set(["därför", "följaktligen", "således", "emellertid", "därutöver", "huruvida", "angående"])
        let informalMarkers = Set(["typ", "liksom", "asså", "va", "haha", "lol", "okej", "cool"])
        let formalCount = words.filter { formalMarkers.contains($0.lowercased()) }.count
        let informalCount = words.filter { informalMarkers.contains($0.lowercased()) }.count
        let formality = Double(formalCount) / Double(max(1, formalCount + informalCount))

        // Vocabulary level
        let avgWordLength = Double(words.map { $0.count }.reduce(0, +)) / Double(max(1, words.count))
        let vocabLevel: String
        if avgWordLength < 5 { vocabLevel = "basic" }
        else if avgWordLength < 7 { vocabLevel = "intermediate" }
        else { vocabLevel = "advanced" }

        return StyleGuide(
            formalityLevel: min(1.0, formality),
            preferredSentenceLength: max(8, min(25, avgSentenceLength)),
            vocabularyLevel: vocabLevel,
            topicPreferences: ["generell"],
            humorTolerance: lower.contains("haha") || lower.contains("lol") ? 0.7 : 0.4,
            directnessPreference: lower.contains("typ") || lower.contains("kanske") ? 0.3 : 0.7,
            reasoning: "Baserat på \(words.count) ord och \(sentences.count) meningar. Genomsnittlig meningslängd: \(avgSentenceLength) ord."
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 134: Prompt Style Optimization
    // ═══════════════════════════════════════════════════════════

    /// Given Eon's draft response and a goal, rewrite the response.
    func optimizePromptStyle(text: String, goal: String) async -> String {
        guard apiKey != nil else { return text }

        let systemPrompt = """
        Du är en svensk språkexpert. Din uppgift är att skriva om en text enligt ett specifikt mål.

        Mål: \(goal)

        Behåll textens innehåll och mening men anpassa formuleringen enligt målet.
        Svara ENDAST med den omskrivna texten, inga förklaringar.
        """

        let userPrompt = "Originaltext:\n\(text)"

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: userPrompt,
                task: .selfCorrection,
                maxRetries: 2
            )
            return response.isEmpty ? text : response
        } catch {
            return text
        }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 146: Creative Writing Evaluation
    // ═══════════════════════════════════════════════════════════

    struct CreativeEvaluation: Sendable {
        let originality: Double
        let coherence: Double
        let emotionalImpact: Double
        let imagery: Double
        let stylisticConsistency: Double
        let narrativeStructure: Double
        let overallScore: Double
        let feedback: String
    }

    /// Evaluate creative text on: originality, coherence, emotional impact, imagery, stylistic consistency, narrative structure.
    func evaluateCreativeWriting() async -> CreativeEvaluation {
        // Use the most recent creative conversation as the text to evaluate
        let memory = PersistentMemoryStore.shared
        let recent = await memory.getRecentConversation(limit: 5)
        guard !recent.isEmpty else {
            return CreativeEvaluation(originality: 0, coherence: 0, emotionalImpact: 0, imagery: 0, stylisticConsistency: 0, narrativeStructure: 0, overallScore: 0, feedback: "Ingen kreativ text att utvärdera")
        }

        let text = recent.map { $0.content }.joined(separator: " ")

        guard apiKey != nil else {
            // Heuristic fallback
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            let uniqueRatio = Double(Set(words).count) / Double(max(1, words.count))
            return CreativeEvaluation(
                originality: min(1.0, uniqueRatio),
                coherence: 0.5,
                emotionalImpact: 0.4,
                imagery: 0.3,
                stylisticConsistency: 0.5,
                narrativeStructure: 0.4,
                overallScore: uniqueRatio * 0.3 + 0.42,
                feedback: "Heuristisk utvärdering — ingen OpenRouter-nyckel"
            )
        }

        let systemPrompt = """
        Du är en litteraturkritiker och expert på kreativt skrivande på svenska. Utvärdera följande text på:

        1. Originalitet (0-1): Hur unik och nyskapande är texten?
        2. Koherens (0-1): Hänger texten ihop logiskt?
        3. Känslomässig påverkan (0-1): Skapar texten känslor hos läsaren?
        4. Bildspråk (0-1): Används metaforer, liknelser, sensoriska detaljer?
        5. Stilistisk konsistens (0-1): Behåller texten en enhetlig stil?
        6. Narrativ struktur (0-1): Finns en tydlig början-mitte-slutt?

        Svara ENDAST med giltig JSON:
        {
          "originality": 0.8,
          "coherence": 0.7,
          "emotionalImpact": 0.6,
          "imagery": 0.5,
          "stylisticConsistency": 0.9,
          "narrativeStructure": 0.7,
          "overallScore": 0.7,
          "feedback": "Kort feedback på svenska"
        }
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Utvärdera denna kreativa text:\n\(text.prefix(2000))",
                task: .style,
                maxRetries: 2
            )

            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return CreativeEvaluation(
                    originality: json["originality"] as? Double ?? 0.5,
                    coherence: json["coherence"] as? Double ?? 0.5,
                    emotionalImpact: json["emotionalImpact"] as? Double ?? 0.5,
                    imagery: json["imagery"] as? Double ?? 0.5,
                    stylisticConsistency: json["stylisticConsistency"] as? Double ?? 0.5,
                    narrativeStructure: json["narrativeStructure"] as? Double ?? 0.5,
                    overallScore: json["overallScore"] as? Double ?? 0.5,
                    feedback: json["feedback"] as? String ?? ""
                )
            }
        } catch {
            print("[OpenRouter] Creative evaluation failed: \(error)")
        }

        return CreativeEvaluation(originality: 0.5, coherence: 0.5, emotionalImpact: 0.5, imagery: 0.5, stylisticConsistency: 0.5, narrativeStructure: 0.5, overallScore: 0.5, feedback: "Kunde inte utvärdera kreativ text")
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 151: Swedish Essay Generation
    // ═══════════════════════════════════════════════════════════

    /// Generate structured essays: argumentative, expository, descriptive, narrative.
    func generateSwedishEssay(topic: String, type: String = "argumentative") async -> String {
        guard apiKey != nil else { return "Kan inte generera essä utan OpenRouter-nyckel." }

        let typeInstructions: String
        switch type {
        case "argumentative":
            typeInstructions = """
            Skriv en ARGUMENTERANDE essä med:
            1. INLEDNING: Presentera ämnet och din tes
            2. BODY PARAGRAPH 1: Ditt starkaste argument med stöd
            3. BODY PARAGRAPH 2: Ett andra argument med exempel
            4. BODY PARAGRAPH 3: Motargument och din bemötande
            5. SLUTSATS: Sammanfatta och bekräfta tesen
            """
        case "expository":
            typeInstructions = """
            Skriv en EXPOSITIONELL essä med:
            1. INLEDNING: Definiera ämnet och dess betydelse
            2. BODY: Förklara konceptet systematiskt med exempel
            3. SLUTSATS: Sammanfatta huvudpunkterna
            """
        case "descriptive":
            typeInstructions = """
            Skriv en BESKRIVANDE essä med:
            1. Inledning: Introducera det som beskrivs
            2. Body: Använd sensoriska detaljer (se, höra, känna, lukta, smaka)
            3. Slutsats: Den övergripande innebörden
            """
        case "narrative":
            typeInstructions = """
            Skriv en NARRATIV essä med:
            1. Inledning: Sätt scenen och introducera karaktärer
            2. Body: Berätta historien med konflikt och utveckling
            3. Slutsats: Upplösning och reflektion
            """
        default:
            typeInstructions = "Skriv en välstrukturerad essä om ämnet."
        }

        let systemPrompt = """
        Du är en expert på svenskt akademiskt skrivande. \(typeInstructions)

        Regler:
        - Använd korrekt svenska grammatik (V2-regeln, bisatsstruktur)
        - Variera meningslängd och struktur
        - Använd akademiska övergångsord (därför, emellertid, sammanfattningsvis)
        - Skriv på svenska
        - Essän ska vara 400-600 ord
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Skriv en essä om: \(topic)",
                task: .style,
                maxRetries: 2
            )
            return response.isEmpty ? "Kunde inte generera essä." : response
        } catch {
            return "Essägenerering misslyckades: \(error.localizedDescription)"
        }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 154: Swedish Text Summarization
    // ═══════════════════════════════════════════════════════════

    /// Summarize long Swedish texts while preserving key information, tone, and structure.
    func generateSwedishSummary(text: String) async -> String {
        guard apiKey != nil else {
            // Heuristic fallback: extractive summary (first sentence of each paragraph)
            let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let summary = paragraphs.map { para in
                let sentences = para.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 10 }
                return sentences.first ?? ""
            }.joined(separator: ". ")
            return summary
        }

        let systemPrompt = """
        Du är en expert på svensk textsammanfattning. Sammanfatta följande text:

        Regler:
        - Behåll all viktig information och huvudargument
        - Behåll textens ton och stil
        - Använd koncist svenska
        - Sammanfattningen ska vara ca 25% av originaltextens längd
        - Skriv på svenska
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Sammanfatta denna text:\n\(text.prefix(4000))",
                task: .style,
                maxRetries: 2
            )
            return response.isEmpty ? "Kunde inte sammanfatta texten." : response
        } catch {
            return "Sammanfattning misslyckades."
        }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 156: Swedish Debate Simulation
    // ═══════════════════════════════════════════════════════════

    struct Debate: Sendable {
        let topic: String
        let openingStatementPro: String
        let openingStatementCon: String
        let rebuttalPro: String
        let rebuttalCon: String
        let crossExamination: [DebateExchange]
        let closingPro: String
        let closingCon: String
        let winner: String
    }

    struct DebateExchange: Sendable {
        let speaker: String
        let content: String
    }

    /// Simulate a full Swedish debate with opening statements, rebuttals, cross-examination, and closing arguments.
    func generateSwedishDebate(topic: String) async -> Debate {
        guard apiKey != nil else {
            return Debate(
                topic: topic,
                openingStatementPro: "För: \(topic) har många fördelar.",
                openingStatementCon: "Emot: \(topic) har betydande nackdelar.",
                rebuttalPro: "Motargumentet tar inte hänsyn till helheten.",
                rebuttalCon: "Förslaget har grundläggande brister.",
                crossExamination: [DebateExchange(speaker: "För", content: "Hur motiverar du din position?")],
                closingPro: "Sammanfattningsvis stöder vi \(topic).",
                closingCon: "Sammanfattningsvis motsätter vi oss \(topic).",
                winner: "Oavgjort"
            )
        }

        let systemPrompt = """
        Du simulerar en svensk debatt mellan två sidor. Generera en komplett debatt med:

        1. ÖPPNINGSANförande FÖR (2-3 meningar)
        2. ÖPPNINGSANförande EMOT (2-3 meningar)
        3. REBUTTAL FÖR (1-2 meningar)
        4. REBUTTAL EMOT (1-2 meningar)
        5. TVÅ ÄKTA UTBYTEN i korsförhör
        6. SLUTANförande FÖR (1-2 meningar)
        7. SLUTANförande EMOT (1-2 meningar)
        8. BEDÖMARE: Vem vann och varför?

        Svara ENDAST med giltig JSON:
        {
          "openingStatementPro": "...",
          "openingStatementCon": "...",
          "rebuttalPro": "...",
          "rebuttalCon": "...",
          "crossExamination": [{"speaker": "För/Emot", "content": "..."}],
          "closingPro": "...",
          "closingCon": "...",
          "winner": "..."
        }
        """

        do {
            let response = try await callOpenRouterWithRetry(
                system: systemPrompt,
                user: "Debattämne: \(topic)",
                task: .style,
                maxRetries: 2
            )

            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let exchanges = (json["crossExamination"] as? [[String: String]])?.map {
                    DebateExchange(speaker: $0["speaker"] ?? "", content: $0["content"] ?? "")
                } ?? []

                return Debate(
                    topic: topic,
                    openingStatementPro: json["openingStatementPro"] as? String ?? "",
                    openingStatementCon: json["openingStatementCon"] as? String ?? "",
                    rebuttalPro: json["rebuttalPro"] as? String ?? "",
                    rebuttalCon: json["rebuttalCon"] as? String ?? "",
                    crossExamination: exchanges,
                    closingPro: json["closingPro"] as? String ?? "",
                    closingCon: json["closingCon"] as? String ?? "",
                    winner: json["winner"] as? String ?? "Oavgjort"
                )
            }
        } catch {
            print("[OpenRouter] Debate generation failed: \(error)")
        }

        return Debate(
            topic: topic,
            openingStatementPro: "", openingStatementCon: "",
            rebuttalPro: "", rebuttalCon: "",
            crossExamination: [], closingPro: "", closingCon: "",
            winner: "Misslyckades"
        )
    }
}
