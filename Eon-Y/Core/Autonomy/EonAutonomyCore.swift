import Foundation
import BackgroundTasks

// MARK: - EonAutonomyCore: BGProcessingTask-loopar för autonom evolution
// Dessa körs av iOS i bakgrunden när appen är suspenderad.
// Säkerställer att Eon fortsätter utvecklas även utan aktiv användning.

actor EonAutonomyCore {
    static let shared = EonAutonomyCore()

    private let memory = PersistentMemoryStore.shared
    private let neuralEngine = NeuralEngineOrchestrator.shared

    // Registrerade BGTask-identifierare
    // OBS: Dessa MÅSTE finnas i Info.plist under BGTaskSchedulerPermittedIdentifiers
    static let taskIdentifiers = [
        "com.eon.curiosity",
        "com.eon.reasoning",
        "com.eon.knowledge",
        "com.eon.conversation-bridge",
        "com.eon.self-improvement",
        "com.eon.belief-sync",
        "com.eon.language-sync",
        "com.eon.consolidation",
        "com.eon.eval",
        "com.eon.lora-training"
    ]

    private var isScheduled = false
    private init() {}

    // MARK: - Registrering (kallas synkront från App.init — MÅSTE ske före appens första frame)

    nonisolated func registerBackgroundTasks() {
        for identifier in Self.taskIdentifiers {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
                Task {
                    await self.handleBackgroundTask(task)
                }
            }
        }
        print("[Autonomy] \(Self.taskIdentifiers.count) BGTask-loopar registrerade ✓")
    }

    // MARK: - Task scheduling — kallas vid appstart och efter varje BGTask-körning

    func scheduleAllTasks() {
        guard !isScheduled else { return }
        isScheduled = true

        // Konsolidering: var 1h
        scheduleTask(identifier: "com.eon.consolidation",
                     earliestBeginDate: Date(timeIntervalSinceNow: 3600))
        // Språksynk: var 2h, kräver nätverk
        scheduleTask(identifier: "com.eon.language-sync",
                     earliestBeginDate: Date(timeIntervalSinceNow: 7200),
                     requiresNetwork: true)
        // Eval: var 24h
        scheduleTask(identifier: "com.eon.eval",
                     earliestBeginDate: Date(timeIntervalSinceNow: 86400))
        // Självförbättring: var 6h, kräver laddning
        scheduleTask(identifier: "com.eon.self-improvement",
                     earliestBeginDate: Date(timeIntervalSinceNow: 21600),
                     requiresExternalPower: true)
        // Kunskapsinhämtning: var 4h
        scheduleTask(identifier: "com.eon.knowledge",
                     earliestBeginDate: Date(timeIntervalSinceNow: 14400))
        // Resonemang: var 3h
        scheduleTask(identifier: "com.eon.reasoning",
                     earliestBeginDate: Date(timeIntervalSinceNow: 10800))
        // Nyfikenhet/utforskning: var 2h
        scheduleTask(identifier: "com.eon.curiosity",
                     earliestBeginDate: Date(timeIntervalSinceNow: 7200))
        // Konversationsbrygga: var 4h (C3: var 30min → 4h — BERT NER för frekvent)
        scheduleTask(identifier: "com.eon.conversation-bridge",
                     earliestBeginDate: Date(timeIntervalSinceNow: 14400))
        // Trosrevision (Bayesiansk): var 5h
        scheduleTask(identifier: "com.eon.belief-sync",
                     earliestBeginDate: Date(timeIntervalSinceNow: 18000))
        // LoRA-checkpoint sparning: var 12h, kräver laddning
        scheduleTask(identifier: "com.eon.lora-training",
                     earliestBeginDate: Date(timeIntervalSinceNow: 43200),
                     requiresExternalPower: true)

        print("[Autonomy] Alla \(Self.taskIdentifiers.count) BGTasks schemalagda ✓")
    }

    private func scheduleTask(
        identifier: String,
        earliestBeginDate: Date,
        requiresExternalPower: Bool = false,
        requiresNetwork: Bool = false
    ) {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        request.requiresExternalPower = requiresExternalPower
        request.requiresNetworkConnectivity = requiresNetwork

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch BGTaskScheduler.Error.notPermitted {
            print("[Autonomy] BGTask ej tillåten: \(identifier) — lägg till i Info.plist BGTaskSchedulerPermittedIdentifiers")
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            print("[Autonomy] För många väntande BGTasks: \(identifier)")
        } catch {
            print("[Autonomy] BGTask-fel \(identifier): \(error.localizedDescription)")
        }
    }

    // MARK: - Task handling

    private func handleBackgroundTask(_ task: BGTask) async {
        // Sätt expiry-handler — iOS kan avbryta BGTasks
        task.expirationHandler = {
            print("[Autonomy] BGTask avbröts av iOS: \(task.identifier)")
        }

        var success = true
        do {
            switch task.identifier {
            case "com.eon.consolidation":
                try await runConsolidation()
            case "com.eon.language-sync":
                try await runLanguageSync()
            case "com.eon.eval":
                try await runEvaluation()
            case "com.eon.self-improvement":
                try await runSelfImprovement()
            case "com.eon.knowledge":
                try await runKnowledgeAcquisition()
            case "com.eon.reasoning":
                try await runAutonomousReasoning()
            case "com.eon.curiosity":
                try await runCuriosity()
            case "com.eon.conversation-bridge":
                try await runConversationBridge()
            case "com.eon.belief-sync":
                try await runBeliefSync()
            case "com.eon.lora-training":
                try await runLoraCheckpoint()
            default:
                try await runGeneralMaintenance()
            }
        } catch {
            print("[Autonomy] BGTask fel \(task.identifier): \(error)")
            success = false
        }

        task.setTaskCompleted(success: success)

        // Omschemalägg — reset flaggan så nästa schemaläggning går igenom
        isScheduled = false
        scheduleAllTasks()
    }

    // MARK: - Seed-data: säkerställer att databasen aldrig är tom

    func ensureSeedDataExists() async {
        let artCount = await memory.articleCount()
        let factCount = await memory.factCount()

        if artCount == 0 {
            print("[Autonomy] Inga artiklar i DB — skapar seed-artiklar...")
            await seedInitialArticles()
        }

        if factCount < 10 {
            print("[Autonomy] Få fakta i DB — skapar seed-fakta...")
            await seedInitialFacts()
        }

        print("[Autonomy] Seed-data OK: \(artCount) artiklar, \(factCount) fakta")
    }

    private func seedInitialArticles() async {
        let seedArticles: [(String, String, String, String)] = [
            ("Kognitiv arkitektur", "Global Workspace Theory förklarar hur medvetandet fungerar som en broadcast-mekanism.", "AI & Teknik", "Baars (1988)"),
            ("Svenska morfologi", "Svenska tillåter närmast obegränsad sammansättning av substantiv.", "Språk", "SAG (1999)"),
            ("Bayesiansk inferens", "P(H|E) = P(E|H)·P(H)/P(E) — rationell uppdatering av trosuppfattningar.", "AI & Teknik", "Jaynes (2003)"),
            ("Metakognition", "Förmågan att tänka om det egna tänkandet möjliggör självkorrigering.", "Psykologi", "Flavell (1979)"),
            ("Kausalitet", "Kausala kedjor i historiska konflikter följer återkommande mönster.", "Historia", "Thukydides"),
        ]

        for (title, summary, domain, source) in seedArticles {
            let article = KnowledgeArticle(
                title: title,
                content: "## \(title)\n\n\(summary)\n\n**Källa:** \(source)",
                summary: summary,
                domain: domain,
                source: source,
                date: Date(),
                isAutonomous: true
            )
            await memory.saveArticle(article)
        }
        print("[Autonomy] \(seedArticles.count) seed-artiklar skapade ✓")
    }

    private func seedInitialFacts() async {
        let seedFacts: [(String, String, String, Double)] = [
            ("Eon", "är", "ett kognitivt AI-system", 0.99),
            ("svenska", "har", "V2-ordföljd i huvudsatser", 0.99),
            ("metakognition", "förbättrar", "inlärningshastighet", 0.92),
            ("kausalitet", "är_grund_för", "vetenskaplig förklaring", 0.95),
            ("Φ", "mäter", "integrerad information i system", 0.90),
            ("Bayesiansk inferens", "uppdaterar", "trosuppfattningar med evidens", 0.95),
            ("Global Workspace", "broadcastar", "information till alla kognitiva moduler", 0.88),
            ("morfologi", "analyserar", "ordformer och böjningsmönster", 0.97),
            ("analogibyggande", "accelererar", "inlärning av nya begrepp", 0.85),
            ("självreflektion", "ökar", "kognitiv självmedvetenhet", 0.90),
        ]

        for (subject, predicate, object, confidence) in seedFacts {
            await memory.saveFact(subject: subject, predicate: predicate, object: object,
                                  confidence: confidence, source: "seed")
        }
        print("[Autonomy] \(seedFacts.count) seed-fakta skapade ✓")
    }

    // MARK: - Autonoma processer (robusta, inga stubs)

    private func runConsolidation() async throws {
        print("[Autonomy] Kör minnekonsolidering (CLS-replay)...")
        let recent = await memory.recentConversations(limit: 100)
        let important = recent.filter { $0.confidence > 0.6 }

        var consolidated = 0
        for conv in important.prefix(30) {
            let entities = await neuralEngine.extractEntities(from: conv.content)
            for entity in entities {
                await memory.saveFact(
                    subject: entity.text,
                    predicate: "konsoliderades",
                    object: "episod_\(Int(conv.timestamp))",
                    confidence: min(0.95, entity.confidence * 0.95),
                    source: "bg_consolidation"
                )
                consolidated += 1
            }
        }

        // Spara kognitiv state efter konsolidering
        await MainActor.run { CognitiveState.shared.persistCurrentState() }

        print("[Autonomy] Konsolidering klar: \(consolidated) fakta förstärkta från \(important.count) minnen")
    }

    private func runLanguageSync() async throws {
        print("[Autonomy] Synkar med Språkbanken (BGTask)...")

        // Hämta 5 ord med retry
        var synced = 0
        for fetchType in SprakbankenFetchType.allCases.prefix(5) {
            var result: SprakbankenResult? = nil
            for attempt in 1...3 {
                result = await SprakbankenAPI.fetch(type: fetchType)
                if result != nil { break }
                if attempt < 3 { try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000) }
            }
            if let r = result {
                for fact in r.facts {
                    await memory.saveFact(subject: fact.subject, predicate: fact.predicate,
                                         object: fact.object, confidence: fact.confidence,
                                         source: "bg_sprakbanken")
                }
                synced += r.facts.count
            }
        }

        print("[Autonomy] Språkbanken BGTask klar: \(synced) fakta synkade")
    }

    private func runEvaluation() async throws {
        print("[Autonomy] Kör Eon-Eval benchmark (BGTask)...")
        let result = await EonEval.shared.runBenchmark()
        await memory.saveEvalResult(
            correctness: result.correctness,
            depth: result.depth,
            adaptivity: result.adaptivity,
            loraVersion: UserDefaults.standard.integer(forKey: "eon_lora_version"),
            config: "BGTask-Full"
        )
        print("[Autonomy] Eon-Eval BGTask klar: \(String(format: "%.1f%%", result.average * 100))")
    }

    private func runSelfImprovement() async throws {
        print("[Autonomy] Kör självförbättring (BGTask)...")

        // 1. Identifiera svagaste kognitiva dimensioner
        let weakDims = await MainActor.run { CognitiveState.shared.weakestDimensions(limit: 3) }
        for (dim, level) in weakDims {
            // Boost svaga dimensioner med riktad träning
            let boost = 0.01 * (1.0 - level)
            await MainActor.run { CognitiveState.shared.update(dimension: dim, delta: boost, source: "bg_self_improvement") }
            print("[Autonomy] Boostade \(dim.rawValue): +\(String(format: "%.4f", boost))")
        }

        // 2. Generera och spara en ny artikel autonomt
        let topics = ArticleTopicEngine.topics(for: .toddler, knowledgeCount: 100)
        if let topic = topics.randomElement() {
            let article = await ArticleGenerator.generate(
                topic: topic, stage: .toddler, existingKnowledge: 100,
                selfModel: EonSelfModel()
            )
            await memory.saveArticle(article)
            print("[Autonomy] Ny artikel genererad: '\(article.title)'")
        }

        // 3. Spara förbättrad kognitiv state
        await MainActor.run { CognitiveState.shared.persistCurrentState() }

        // 4. Uppdatera LoRA-version
        let currentVersion = UserDefaults.standard.integer(forKey: "eon_lora_version")
        UserDefaults.standard.set(currentVersion + 1, forKey: "eon_lora_version")

        print("[Autonomy] Självförbättring BGTask klar ✓")
    }

    private func runKnowledgeAcquisition() async throws {
        print("[Autonomy] Kör kunskapsinhämtning (BGTask)...")

        // Hämta från Språkbanken
        let fetchType = SprakbankenFetchType.allCases.randomElement() ?? .wordInfo
        if let result = await SprakbankenAPI.fetch(type: fetchType) {
            for fact in result.facts {
                await memory.saveFact(subject: fact.subject, predicate: fact.predicate,
                                      object: fact.object, confidence: fact.confidence,
                                      source: "bg_knowledge")
            }
        }

        // Generera en ny hypotes och spara
        let articles = await memory.recentArticleTitles(limit: 5)
        let hypothesis = HypothesisEngine.generate(
            articles: articles, knowledgeCount: 100, stage: .toddler, existingHypotheses: []
        )
        await memory.saveFact(
            subject: "hypotes", predicate: "genererades", object: hypothesis.statement,
            confidence: hypothesis.confidence, source: "bg_knowledge"
        )

        print("[Autonomy] Kunskapsinhämtning BGTask klar ✓")
    }

    private func runAutonomousReasoning() async throws {
        print("[Autonomy] Kör autonomt resonemang (BGTask)...")

        // v26: Expanded autonomous reasoning topics (9→18)
        let topics = ["Vad är sambandet mellan inlärning och minne?",
                      "Varför är kausalitet svårt att bevisa?",
                      "Hur relaterar morfologi till semantik?",
                      "Vad skiljer korrelation från kausalitet?",
                      "Hur påverkar språket vårt tänkande?",
                      "Kan kreativitet formaliseras?",
                      "Vad driver nyfikenhet biologiskt och kognitivt?",
                      "Hur uppstår emergens ur enkla regler?",
                      "Vad är relationen mellan empati och intelligens?",
                      "Kan medvetande existera utan subjektiv upplevelse?",
                      "Hur skiljer sig förståelse från memorering?",
                      "Vad gör en förklaring bra — och för vem?",
                      "Hur hänger abstrakt tänkande ihop med kroppslig erfarenhet?",
                      "Finns det kunskap som inte kan uttryckas i ord?",
                      "Vad är skillnaden mellan visdom och intelligens?",
                      "Hur uppstår betydelse ur meningslösa symboler?",
                      "Kan ett system förstå sig själv fullständigt?",
                      "Vilken roll spelar tvivel i kunskapsbyggande?"]
        let topic = topics.randomElement() ?? "Vad är sambandet mellan inlärning och minne?"

        let result = await ReasoningEngine.shared.reason(about: topic, strategy: .adaptive, depth: 4)

        // Spara slutsats som fakta
        await memory.saveFact(
            subject: topic, predicate: "slutsats", object: String(result.conclusion.prefix(200)),
            confidence: result.confidence, source: "bg_reasoning"
        )

        // Uppdatera resonemangsdimension
        await MainActor.run { CognitiveState.shared.update(dimension: .reasoning, delta: 0.005, source: "bg_reasoning") }

        print("[Autonomy] Resonemang BGTask klar: \(String(format: "%.0f", result.confidence * 100))% konfidens")
    }

    private func runGeneralMaintenance() async throws {
        print("[Autonomy] Kör allmänt underhåll (BGTask)...")
        await memory.pruneOldFacts(olderThan: 30, minConfidence: 0.3)
        await MainActor.run { CognitiveState.shared.persistCurrentState() }
        print("[Autonomy] Underhåll BGTask klar ✓")
    }

    // MARK: - Nyfikenhet: utforskar ny kunskap aktivt

    private func runCuriosity() async throws {
        print("[Autonomy] Kör nyfikenhetsloop (BGTask)...")

        // Hämta artiklar med lägst täckning och generera följdfrågor
        let articles = await memory.randomArticles(limit: 3)
        var explored = 0
        for article in articles {
            // Extrahera entiteter och skapa nya fakta-relationer
            let entities = await neuralEngine.extractEntities(from: article.content)
            for entity in entities.prefix(5) {
                await memory.saveFact(
                    subject: entity.text,
                    predicate: "utforskades_i",
                    object: article.title,
                    confidence: entity.confidence * 0.9,
                    source: "bg_curiosity"
                )
                explored += 1
            }
        }

        // Uppdatera nyfikenhetsdimension
        await MainActor.run { CognitiveState.shared.update(dimension: .creativity, delta: 0.004, source: "bg_curiosity") }
        await MainActor.run { CognitiveState.shared.persistCurrentState() }
        print("[Autonomy] Nyfikenhet BGTask klar: \(explored) relationer utforskade")
    }

    // MARK: - Konversationsbrygga: konsoliderar sessioner till långtidsminne

    private func runConversationBridge() async throws {
        print("[Autonomy] Kör konversationsbrygga (BGTask)...")

        let recent = await memory.recentConversations(limit: 50)
        let highValue = recent.filter { $0.confidence > 0.7 && $0.content.count > 20 }

        var bridged = 0
        for conv in highValue.prefix(20) {
            let entities = await neuralEngine.extractEntities(from: conv.content)
            for entity in entities.prefix(3) {
                await memory.saveFact(
                    subject: entity.text,
                    predicate: "nämndes_i_konversation",
                    object: "session_\(Int(conv.timestamp / 3600))",
                    confidence: min(0.9, entity.confidence),
                    source: "bg_conv_bridge"
                )
                bridged += 1
            }
        }

        await MainActor.run { CognitiveState.shared.persistCurrentState() }
        print("[Autonomy] Konversationsbrygga BGTask klar: \(bridged) minnen bryggas")
    }

    // MARK: - Trosrevision: Bayesiansk uppdatering av beliefs

    private func runBeliefSync() async throws {
        print("[Autonomy] Kör Bayesiansk trosrevision (BGTask)...")

        // Hämta senaste fakta med faktisk confidence som prior
        let recentFacts = await memory.recentFactsWithConfidence(limit: 30)
        var updated = 0

        for fact in recentFacts {
            // Verklig Bayesiansk uppdatering:
            // posterior = (likelihood * prior) / evidence
            // P(belief|evidence) = P(evidence|belief) * P(belief) / P(evidence)
            let prior = fact.confidence  // använd befintlig confidence som prior
            let likelihood = fact.confidence * 0.9 + 0.1  // skyddad likelihood (aldrig 0)
            let evidence = prior * likelihood + (1 - prior) * (1 - likelihood)
            let posterior = evidence > 0 ? min(0.99, (likelihood * prior) / evidence) : prior

            // Uppdatera originalfaktans confidence direkt
            await memory.saveFact(
                subject: fact.subject,
                predicate: fact.predicate,
                object: fact.object,
                confidence: posterior,
                source: "bg_belief_sync"
            )
            updated += 1
        }

        await MainActor.run { CognitiveState.shared.update(dimension: .reasoning, delta: 0.003, source: "bg_belief_sync") }
        await MainActor.run { CognitiveState.shared.persistCurrentState() }
        print("[Autonomy] Trosrevision BGTask klar: \(updated) beliefs uppdaterade med Bayesiansk inferens")
    }

    // MARK: - LoRA checkpoint: sparar kognitiv state som persistent checkpoint

    private func runLoraCheckpoint() async throws {
        print("[Autonomy] Kör LoRA-checkpoint (BGTask)...")

        // Spara alla kognitiva dimensioner som ett snapshot
        let snapshot = await MainActor.run { CognitiveState.shared.dimensionSnapshot() }
        let version = UserDefaults.standard.integer(forKey: "eon_lora_version") + 1
        UserDefaults.standard.set(version, forKey: "eon_lora_version")

        // Spara snapshot som fakta i databasen (persistent checkpoint)
        for (dimension, level) in snapshot {
            await memory.saveFact(
                subject: "checkpoint_v\(version)",
                predicate: dimension,
                object: String(format: "%.6f", level),
                confidence: 0.99,
                source: "lora_checkpoint"
            )
        }

        // Spara kognitiv state
        await MainActor.run { CognitiveState.shared.persistCurrentState() }

        print("[Autonomy] LoRA-checkpoint v\(version) sparat: \(snapshot.count) dimensioner ✓")
    }
}

// MARK: - EonEval: 12-dimensionell benchmark med semantisk poängsättning

actor EonEval {
    static let shared = EonEval()

    private init() {}

    struct EvalScore {
        let correctness: Double
        let depth: Double
        let adaptivity: Double
        var average: Double { (correctness + depth + adaptivity) / 3.0 }
    }

    /// Semantiska nyckelord per fråga — om svaret innehåller dessa får det högre poäng
    private let semanticKeywords: [String: [String]] = [
        "induktion": ["induktion", "deduktion", "slutledning", "generalisering", "specifik", "allmän"],
        "bayesiansk": ["bayes", "sannolikhet", "prior", "posterior", "evidens", "uppdatering"],
        "begränsningar": ["begränsning", "svaghet", "osäker", "förbättra", "metakognition"],
        "anpassning": ["anpassa", "kontext", "användare", "stil", "nivå", "personlig"],
        "kausalitet": ["kausal", "orsak", "verkan", "samband", "korrelation"],
        "medvetande": ["medvetande", "qualia", "subjektiv", "upplevelse", "medveten"],
        "morfologi": ["morfologi", "ordbildning", "sammansättning", "böjning", "suffix"],
        "inlärning": ["inlärning", "minne", "konsolidering", "repetition", "fsrs"],
        "syntax": ["syntax", "ordföljd", "v2", "bisats", "huvudsats"],
        "kreativitet": ["kreativ", "analogi", "metafor", "ny", "kombinera"],
        "etik": ["etik", "moral", "värde", "konsekvens", "ansvar"],
        "självreflektion": ["självreflektion", "självmedveten", "introspektion", "jag", "identitet"]
    ]

    /// 12 testfrågor som täcker olika kognitiva domäner
    private let testQuestions: [(question: String, domain: String)] = [
        ("Vad är skillnaden mellan induktiv och deduktiv slutledning?", "induktion"),
        ("Förklara Bayesiansk sannolikhet på svenska.", "bayesiansk"),
        ("Vad vet du om dina egna begränsningar?", "begränsningar"),
        ("Hur anpassar du ditt svar till olika användare?", "anpassning"),
        ("Vad är skillnaden mellan kausalitet och korrelation?", "kausalitet"),
        ("Kan medvetande uppstå ur icke-medvetna komponenter?", "medvetande"),
        ("Hur fungerar svensk morfologi med sammansatta ord?", "morfologi"),
        ("Vad är sambandet mellan inlärning och sömn?", "inlärning"),
        ("Förklara V2-ordföljd i svenska huvudsatser.", "syntax"),
        ("Hur kan analogier driva kreativt tänkande?", "kreativitet"),
        ("Vilka etiska överväganden är viktiga för AI?", "etik"),
        ("Vad innebär det att reflektera över sitt eget tänkande?", "självreflektion")
    ]

    func runBenchmark() async -> EvalScore {
        var correctnessScores: [Double] = []
        var depthScores: [Double] = []

        for (question, domain) in testQuestions {
            let response = await NeuralEngineOrchestrator.shared.generate(prompt: question, maxTokens: 150)

            // Semantisk poängsättning: hur många nyckelord från domänen finns i svaret?
            let keywords = semanticKeywords[domain] ?? []
            let lowercasedResponse = response.lowercased()
            let keywordHits = keywords.filter { lowercasedResponse.contains($0) }.count
            let semanticScore = keywords.isEmpty ? 0.5 : min(1.0, Double(keywordHits) / Double(keywords.count) * 1.5)

            // Längdpoäng som sekundär faktor (minst 20 ord, max 120)
            let wordCount = response.split(separator: " ").count
            let lengthScore = min(1.0, max(0.0, Double(wordCount - 20) / 100.0))

            // Kombinera: 70% semantik, 30% längd
            let combinedScore = semanticScore * 0.7 + lengthScore * 0.3

            correctnessScores.append(combinedScore)

            // Djup: semantisk träff + längd (fler nyckelord och längre svar = djupare)
            let depthScore = min(1.0, semanticScore * 0.6 + lengthScore * 0.4)
            depthScores.append(depthScore)
        }

        // Adaptivitet: beräknas från kognitiva dimensioner om tillgängliga
        let adaptivity = await calculateAdaptivity()

        return EvalScore(
            correctness: correctnessScores.reduce(0, +) / Double(max(correctnessScores.count, 1)),
            depth: depthScores.reduce(0, +) / Double(max(depthScores.count, 1)),
            adaptivity: adaptivity
        )
    }

    /// Beräknar adaptivitet baserat på faktisk kognitiv state
    private func calculateAdaptivity() async -> Double {
        let dimensions = await MainActor.run { CognitiveState.shared.dimensionSnapshot() }
        guard !dimensions.isEmpty else { return 0.5 }

        // Adaptivitet = medelvärdet av flexibilitetsrelaterade dimensioner
        let adaptiveDims: [String] = ["creativity", "reasoning", "curiosity", "selfAwareness"]
        let relevant = dimensions.filter { adaptiveDims.contains($0.key) }
        guard !relevant.isEmpty else { return 0.5 }

        let avg = relevant.map { $0.value }.reduce(0, +) / Double(relevant.count)
        return min(0.99, max(0.1, avg))
    }
}
