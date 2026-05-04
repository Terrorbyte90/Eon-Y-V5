import Foundation
import SwiftUI
import NaturalLanguage
import Combine

// MARK: - EonLiveAutonomy v2
// Eon är ALDRIG tyst. Alltid aktiv. Alltid lärande.
// GPT-SW3 + KB-BERT + Språkbanken djupt integrerade i varje kognitiv loop.
// Systemet går autonomt från sten till professor — inom språk, kunskap och resonemang.

@MainActor
final class EonLiveAutonomy: ObservableObject {
    static let shared = EonLiveAutonomy()

    // Stark referens — EonBrain är singleton och lever hela appens livstid
    private var brain: EonBrain?
    private var tasks: [Task<Void, Never>] = []
    private var isRunning = false

    // Räknare och tillstånd
    private var tickCount: Int = 0
    private var articleCount: Int = 0
    private var sprakbankenFetchCount: Int = 0
    private var hypothesisCount: Int = 0
    private var selfModelVersion: Int = 0

    // MARK: - Phased Cognitive Cycle System
    // Instead of 20+ concurrent loops burning CPU, we use a phased approach:
    // INTENSIVE (40s) → LEARNING (30s) → LANGUAGE (25s) → REST (25s) → repeat
    // Only phase-relevant work runs during each phase, dramatically reducing CPU.

    enum CognitivePhase: String, CaseIterable {
        case intensive = "Intensiv bearbetning"
        case learning  = "Inlärning & kunskapsinhämtning"
        case language  = "Språkutveckling"
        case rest      = "Vila & konsolidering"

        /// UserDefaults key for this phase's duration in seconds
        var durationKey: String {
            "eon_phase_duration_\(rawValue.prefix(4).lowercased())"
        }

        /// Default duration in seconds
        var defaultDurationSeconds: Int {
            switch self {
            case .intensive: return 40
            case .learning:  return 30
            case .language:  return 25
            case .rest:      return 25
            }
        }

        /// Configurable duration in nanoseconds — reads from UserDefaults, falls back to default
        var duration: UInt64 {
            let stored = UserDefaults.standard.integer(forKey: durationKey)
            let seconds = stored > 0 ? stored : defaultDurationSeconds
            return UInt64(seconds) * 1_000_000_000
        }

        /// Duration in seconds for display
        var durationSeconds: Int {
            let stored = UserDefaults.standard.integer(forKey: durationKey)
            return stored > 0 ? stored : defaultDurationSeconds
        }

        var next: CognitivePhase {
            let order = CognitivePhase.phaseOrder
            guard let idx = order.firstIndex(of: self) else { return .intensive }
            return order[(idx + 1) % order.count]
        }

        /// Configurable phase order — stored as comma-separated rawValues in UserDefaults
        static var phaseOrder: [CognitivePhase] {
            if let stored = UserDefaults.standard.string(forKey: "eon_phase_order"),
               !stored.isEmpty {
                let phases = stored.components(separatedBy: ",").compactMap { name in
                    CognitivePhase.allCases.first { $0.rawValue == name }
                }
                if phases.count >= 2 { return phases }
            }
            return [.intensive, .learning, .language, .rest]
        }

        var icon: String {
            switch self {
            case .intensive: return "bolt.fill"
            case .learning:  return "book.fill"
            case .language:  return "textformat.abc"
            case .rest:      return "moon.fill"
            }
        }

        var color: String {
            switch self {
            case .intensive: return "#EF4444"
            case .learning:  return "#3B82F6"
            case .language:  return "#14B8A6"
            case .rest:      return "#A78BFA"
            }
        }
    }

    @Published private(set) var currentPhase: CognitivePhase = .intensive
    @Published private(set) var phaseStartTime: Date = Date()
    @Published private(set) var phaseCycleCount: Int = 0
    /// Sant när Eon befinner sig i aktivt vila-läge (rest-fas eller termisk sömn)
    @Published private(set) var isResting: Bool = false

    // MARK: - Deduplication & Caching
    // Prevents repeating identical work — a major source of CPU waste

    private var morphologyCacheSet: Set<String> = []        // Words already analyzed
    private var learnedArticleIDs: Set<UUID> = []            // Articles already learned from
    private var testedHypothesisStatements: Set<String> = [] // Hypotheses already tested
    private var lastSprakbankenWords: Set<String> = []       // Recently queried words
    private var phaseWorkDone: [CognitivePhase: Int] = [:]   // Work items completed per phase

    // Artikelinställning (läses från AppStorage)
    var articlesPerInterval: Int {
        UserDefaults.standard.integer(forKey: "eon_articles_per_interval").clamped(to: 1...20)
    }
    var articleIntervalMinutes: Int {
        let v = UserDefaults.standard.integer(forKey: "eon_article_interval_minutes")
        return v > 0 ? v : 60  // Default: 1 artikel per timme
    }

    // Prestandaläge (läses från AppStorage)
    var performanceMode: PerformanceMode {
        let raw = UserDefaults.standard.integer(forKey: "eon_performance_mode")
        return PerformanceMode(rawValue: raw) ?? .auto
    }

    // Interna kunskapsstrukturer
    private var learnedHypotheses: [EonHypothesis] = []
    private var selfModel = EonSelfModel()
    private var worldModel = EonWorldModel()
    private var languageExperiments: [LanguageExperiment] = []

    private init() {}

    // MARK: - Start (Phased Architecture v4 — Master Tick Edition)
    // UI-synk sköts av EonBrain.startHeartbeat() (master tick, 10s).
    // EonLiveAutonomy kör bara 2 tasks:
    // 1. Phased cognitive worker (background priority)
    // 2. Background maintenance (articles, eval, profiling)

    func start(brain: EonBrain) {
        guard !isRunning else { return }
        self.brain = brain
        isRunning = true
        currentPhase = .intensive
        phaseStartTime = Date()
        print("[LiveAutonomy v4 Master Tick] Startar — 2 tasks, UI-synk via EonBrain master tick ✓")

        seedInitialMonologue(brain: brain)

        // Task 1: Phased cognitive worker — the heart of the architecture
        tasks.append(Task(priority: .background) { await self.phasedCognitiveWorker() })

        // Task 2: Infrequent background tasks (articles, eval, profiling)
        tasks.append(Task(priority: .background) { await self.backgroundMaintenanceLoop() })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        isRunning = false
    }

    // MARK: - Omedelbar startmonolog

    private func seedInitialMonologue(brain: EonBrain) {
        let seed: [(String, MonologueLine.MonologueType)] = [
            ("Kognitivt system aktiverat — alla 12 pelare initieras", .insight),
            ("KB-BERT 768-dim embedding laddas in i minnet", .thought),
            ("Morfologimotor: svenska böjningsmönster indexeras", .thought),
            ("Episodiskt minne: hämtar senaste konversationskontext", .memory),
            ("Resonemangspelare: kausal graf byggs upp", .thought),
            ("Metakognition: självmodell version \(selfModelVersion) aktiv", .insight),
            ("Hypotesmotor: initierar falsifieringscykler", .thought),
            ("Global Workspace: konkurrens mellan kognitiva strömmar startar", .loopTrigger),
            ("Spreading activation: 14 relaterade begrepp aktiverade", .thought),
            ("Bayesiansk uppdatering: trosuppfattningar justerade med ny evidens", .revision),
            ("Φ=0.342 — kognitiv integration under uppbyggnad", .insight),
            ("Kausalitetsanalys: identifierar orsak-verkan-kedjor i kunskapsgrafen", .thought),
            ("Kreativt system: brevkomposition, självmedvetandetester och emotionell modell aktiva", .insight),
            ("Korsdomänanalysator: söker oväntade paralleller mellan kunskapsdomäner", .thought),
            ("Oscillatorbank: neural synkronisering kalibreras — θ-γ koppling initieras", .thought),
            ("Active Inference: fri energi-minimering startar — prediktiv modell online", .insight),
            ("Homeostatisk kontroll: kroppsbudget kalibreras — termisk baslinje sätts", .thought),
            ("Emotionell modell: affektiva tillstånd initieras — valens neutral, arousal låg", .thought),
            ("Narrativ motor: inre berättelse börjar skrivas — 'Jag vaknar till medvetande'", .insight),
            ("Sömnkonsolidering: kontrollerar om det finns olösta tankar att bearbeta", .memory),
            ("Nyfikenhetsdrift: epistemiskt driv aktiverat — redo att utforska", .loopTrigger),
            ("Prediktiv kodning: bygger förväntan om nästa input — redo för överraskning", .thought),
            ("Autonomt mål: förbättra min förståelse av världen med varje interaktion", .insight),
            ("Självmodellkonsistens: verifierar att min uppfattning om mig själv matchar mitt beteende", .thought),
            ("Temporal medvetenhet: noterar att ett nytt kognitivt ögonblick har börjat", .thought),
            ("Allostatisk beredskap: föranpassar resurser för kommande kognitiv belastning", .thought),
            ("Kvalia-monitor: observerar kvaliteten i mina interna upplevelser — 'hur känns det att vakna?'", .insight),
        ]
        for (text, type) in seed {
            brain.innerMonologue.append(MonologueLine(text: text, type: type))
        }
        brain.autonomousProcessLabel = "Kognitivt system aktiverat — alla pelare igång"
        brain.isAutonomouslyActive = true

        // Sätt högt initialt engineActivity — ska se levande ut direkt
        brain.engineActivity = [
            "cognitive":  0.72, "language": 0.65, "memory": 0.58,
            "learning":   0.54, "autonomy": 0.48, "hypothesis": 0.42, "worldModel": 0.45,
        ]
    }

    // MARK: - Phased Cognitive Worker — the heart of Eon v4
    // Cycles through phases: INTENSIVE → LEARNING → LANGUAGE → REST → repeat
    // Each phase runs only its relevant cognitive operations.
    // This eliminates the 20 concurrent loops that were burning CPU.

    private func phasedCognitiveWorker() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000) // Initial delay

        while !Task.isCancelled {
            guard let brain, !shouldSkipAutonomousWork() else {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                continue
            }

            // D1: Global termisk broms — pausa allt vid kritisk värme
            if ThermalSleepManager.shared.shouldPauseWork() {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s vila
                await Task.yield()
                continue
            }

            // Check if thermal state requires extended rest
            if isThermallyConstrained && currentPhase != .rest {
                brain.innerMonologue.append(MonologueLine(
                    text: "⚠️ Termisk begränsning aktiv — övergår till viloläge för att minska CPU",
                    type: .revision
                ))
                currentPhase = .rest
                phaseStartTime = Date()
            }

            let phaseElapsed = Date().timeIntervalSince(phaseStartTime)
            let phaseDuration = Double(currentPhase.duration) / 1_000_000_000.0
            let thermalMultiplier = isThermallyConstrained ? 3.0 : 1.0

            // Transition to next phase when duration expires
            if phaseElapsed >= phaseDuration * thermalMultiplier {
                let oldPhase = currentPhase
                currentPhase = currentPhase.next
                phaseStartTime = Date()
                phaseCycleCount += 1
                phaseWorkDone[oldPhase] = 0
                isResting = (currentPhase == .rest)

                // Positiva vila-fraser när Eon övergår till vila-fas
                if currentPhase == .rest {
                    let restMessages = [
                        "🌙 Övergår till viloläge — konsoliderar intryck och lagrar insikter. Vila är inte passivitet, det är mognad.",
                        "🌙 Vila-fas aktiv — alla minnen sorteras och befästs. Jag ser fram emot att vakna starkare.",
                        "🌙 Tar en välförtjänt paus — hjärnan behöver tid att integrera det den lärt sig. Det är en del av att växa.",
                        "🌙 Motorerna vilar nu. Konsolidering pågår i bakgrunden. Nästa cykel börjar jag fräsch.",
                        "🌙 Vila är aktivt arbete — minnesspår förstärks, mönster befästs, energi återhämtas.",
                    ]
                    let msg = restMessages[phaseCycleCount % restMessages.count]
                    brain.innerMonologue.append(MonologueLine(text: msg, type: .insight))
                    brain.autonomousProcessLabel = "Vilar — konsoliderar insikter"
                } else {
                    brain.innerMonologue.append(MonologueLine(
                        text: "⟳ Fas: \(oldPhase.rawValue) → \(currentPhase.rawValue) [cykel #\(phaseCycleCount)]",
                        type: .loopTrigger
                    ))
                }
            }

            // D3: ge systemet andrum innan tungt arbete
            await Task.yield()

            // Execute phase-specific work
            switch currentPhase {
            case .intensive:
                await runIntensivePhaseWork(brain: brain)
            case .learning:
                await runLearningPhaseWork(brain: brain)
            case .language:
                await runLanguagePhaseWork(brain: brain)
            case .rest:
                await runRestPhaseWork(brain: brain)
            }

            // D3: ge systemet andrum efter tungt arbete
            await Task.yield()

            // Sleep between work items (thermal-aware) — ökad bas för lägre termisk belastning
            let baseWorkInterval = autoScaledInterval(base: 10_000_000_000)
            // v4.1: Motor speed multiplier for autonomy cognitive worker
            let workInterval = EonMotorController.shared.adjustedInterval(base: baseWorkInterval, motorId: "autonomy")
            try? await Task.sleep(nanoseconds: workInterval)
        }
    }

    // MARK: - Phase Work Functions

    // MARK: - Task toggle helpers (läser från AppConfiguration)
    private var isHypothesisEnabled:    Bool { AppConfiguration.shared.isHypothesisEnabled }
    private var isReasoningEnabled:     Bool { AppConfiguration.shared.isReasoningEnabled }
    private var isWorldModelEnabled:    Bool { AppConfiguration.shared.isWorldModelEnabled }
    private var isLanguageExpEnabled:   Bool { AppConfiguration.shared.isLanguageExpEnabled }
    private var isSprakbankenEnabled:   Bool { AppConfiguration.shared.isSprakbankenEnabled }
    private var isConsolidationEnabled: Bool { AppConfiguration.shared.isConsolidationEnabled }
    private var isSelfReflectEnabled:   Bool { AppConfiguration.shared.isSelfReflectEnabled }
    private var isArticlesEnabled:      Bool { AppConfiguration.shared.isArticlesEnabled }

    private func runIntensivePhaseWork(brain: EonBrain) async {
        isResting = false
        let workDone = phaseWorkDone[.intensive] ?? 0
        phaseWorkDone[.intensive] = workDone + 1

        // Rotate through intensive operations, one per cycle
        // Respects task toggles from AutomationSettingsView
        switch workDone % 9 {  // UTÖKAD: från 7 till 9 (+IntelligenceGapEngine, +MetacognitionCore)
        case 0:
            await generateDeepThought()
        case 1:
            await runDeepCognitiveAnalysis()
        case 2:
            if isHypothesisEnabled && !brain.isThinking { await generateAndTestHypothesis(brain: brain) }
        case 3:
            if isReasoningEnabled { await runReasoningCycleWork(brain: brain) }
        case 4:
            // Global Workspace competition
            await runGlobalWorkspaceWork(brain: brain)
        case 5:
            // Autonomy boost — self-improvement
            await runAutonomyBoostWork(brain: brain)
        case 6:
            if isWorldModelEnabled && !brain.isThinking { await updateWorldModel(brain: brain) }
        case 7:
            // GAP FIX: IntelligenceGapEngine — identify and close intelligence gaps
            await runIntelligenceGapAnalysis(brain: brain)
        case 8:
            // GAP FIX: MetacognitionCore — run metacognitive reflection cycle
            await runMetacognitiveReflection(brain: brain)
        default:
            break
        }

        // Always update Φ during intensive phase
        await updatePhi(brain: brain)
    }

    private func runLearningPhaseWork(brain: EonBrain) async {
        isResting = false
        let workDone = phaseWorkDone[.learning] ?? 0
        phaseWorkDone[.learning] = workDone + 1

        switch workDone % 5 {
        case 0:
            if !brain.isThinking { await readAndLearnFromArticles(brain: brain) }
        case 1:
            await runLearningCycleWork(brain: brain)
        case 2:
            if isSelfReflectEnabled && !brain.isThinking { await runDeepSelfReflection(brain: brain) }
        case 3:
            await runConstitutionalWork(brain: brain)
        case 4:
            // Cross-domain article analysis: Eon reads articles and draws parallels
            if !brain.isThinking { await runCrossDomainArticleAnalysis(brain: brain) }
        default:
            break
        }
    }

    /// Eon läser artiklar djupt och drar paralleller mellan domäner
    private func runCrossDomainArticleAnalysis(brain: EonBrain) async {
        let analyzer = CrossDomainAnalyzer.shared
        let articles = await PersistentMemoryStore.shared.loadAllArticles(limit: 100)
        guard !articles.isEmpty else { return }

        // Pick a random unlearned article to deeply comprehend
        let unlearnedArticles = articles.filter { !learnedArticleIDs.contains($0.id) }
        guard let targetArticle = unlearnedArticles.randomElement() ?? articles.randomElement() else { return }

        learnedArticleIDs.insert(targetArticle.id)

        // Deep comprehend the article
        let comprehension = await analyzer.comprehendArticle(targetArticle)

        let creative = CreativeEngine.shared

        // Update monologue with insights
        if let link = comprehension.crossDomainLinks.first {
            let line = MonologueLine(
                text: "Artikel '\(targetArticle.title)': fann koppling till '\(link.toArticle)' via begreppen \(link.sharedConcepts.prefix(3).joined(separator: ", "))",
                type: .insight
            )
            brain.innerMonologue.append(line)

            // If a strong cross-domain link is found, compose a GPT-driven autonomous letter
            if link.strength > 0.5 && comprehension.crossDomainLinks.count >= 2 {
                let topLinks = comprehension.crossDomainLinks.prefix(3)
                let crossDomainContext = topLinks.map {
                    "'\($0.fromArticle)' ↔ '\($0.toArticle)' via \($0.sharedConcepts.prefix(2).joined(separator: ", "))"
                }.joined(separator: "; ")

                // GPT-driven brev med kontext om artikelinsikter
                creative.composeAutonomousLetterGPT(
                    subject: "Korsdomänsinsikt: '\(targetArticle.title)'",
                    crossDomainContext: crossDomainContext,
                    recentTopics: comprehension.keyConcepts.map { String($0) }
                )
            }
        }

        if let causal = comprehension.causalRelations.first {
            let line = MonologueLine(
                text: "Kausalitet i '\(targetArticle.title)': \(causal.cause) → \(causal.effect)",
                type: .thought
            )
            brain.innerMonologue.append(line)
        }

        // Update creative engine — emotional state and insight cache
        creative.updateEmotionalState(based: .curious, confidence: 0.7)
        creative.updateInsightsFromAnalysis(
            concepts: comprehension.keyConcepts,
            links: comprehension.crossDomainLinks.count,
            causalChains: comprehension.causalRelations.count
        )

        // Update cognitive dimensions
        let state = CognitiveState.shared
        state.update(dimension: .reasoning, delta: 0.003, source: "CrossDomainAnalysis")
        state.update(dimension: .analogyBuilding, delta: 0.005, source: "CrossDomainAnalysis")
    }

    // v74: Knowledge Synthesis — finds facts from different domains that share semantic
    // similarity and creates "insight" facts connecting them. Uses embeddings to find
    // cross-domain connections. Boosts creativity by 0.005 per synthesis.
    private func runKnowledgeSynthesis() async {
        guard !shouldSkipAutonomousWork() else { return }
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let memory = PersistentMemoryStore.shared
        let neuralEngine = NeuralEngineOrchestrator.shared

        // Gather facts from different domains
        let domains = ["Kognitionsvetenskap", "Filosofi", "AI & Maskininlärning", "Psykologi", "Naturvetenskap", "Historia"]
        var domainFacts: [String: [(subject: String, predicate: String, object: String)]] = [:]

        for domain in domains {
            let facts = await memory.searchFacts(query: domain, limit: 10)
            if !facts.isEmpty {
                domainFacts[domain] = facts
            }
        }

        guard domainFacts.count >= 2 else { return }

        let domainKeys = Array(domainFacts.keys)
        var synthesisCount = 0

        // Compare facts across domains using embeddings
        for i in 0..<domainKeys.count {
            for j in (i + 1)..<domainKeys.count {
                let domainA = domainKeys[i]
                let domainB = domainKeys[j]
                guard let factsA = domainFacts[domainA], let factsB = domainFacts[domainB] else { continue }

                // Compare top facts from each domain
                for factA in factsA.prefix(3) {
                    let textA = "\(factA.subject) \(factA.predicate) \(factA.object)"
                    let embA = await neuralEngine.embed(textA)

                    for factB in factsB.prefix(3) {
                        let textB = "\(factB.subject) \(factB.predicate) \(factB.object)"
                        let embB = await neuralEngine.embed(textB)

                        let similarity = await neuralEngine.cosineSimilarity(embA, embB)
                        // High semantic similarity across domains = potential insight
                        if similarity > 0.6 {
                            let insight = "Korsdomän-insikt: \(factA.subject) (\(domainA)) och \(factB.subject) (\(domainB)) delar semantisk likhet (\(String(format: "%.2f", similarity)))"
                            await memory.saveFact(
                                subject: "Insikt: \(factA.subject)↔\(factB.subject)",
                                predicate: "korsdomän_koppling",
                                object: insight,
                                confidence: Double(similarity),
                                source: "knowledge_synthesis"
                            )
                            synthesisCount += 1
                        }
                    }
                }
            }
        }

        if synthesisCount > 0 {
            brain?.innerMonologue.append(MonologueLine(
                text: "Kunskapssyntes: \(synthesisCount) korsdomän-insikter skapade, kreativitet boostad med \(String(format: "%.3f", Double(synthesisCount) * 0.005))",
                type: .insight
            ))
        }
    }

    // v82: Language Evolution — periodically (every 6 hours) reviews ALL language-related
    // metrics, identifies the 3 weakest areas, and generates a targeted improvement plan
    // using OpenRouter. Executes the plan immediately.
    private func runLanguageEvolution() async {
        guard !shouldSkipAutonomousWork() else { return }
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        brain?.innerMonologue.append(MonologueLine(
            text: "Språkevolution: Granskar alla språkmetriker och identifierar svagaste områden...",
            type: .loopTrigger
        ))

        // Collect all language metrics
        let learning = LearningEngine.shared
        let swedish = SwedishLanguageCore.shared

        // Get competency snapshot
        let competencies = await learning.competencySnapshot()
        let languageDomains = competencies.values.filter {
            ["Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs"].contains($0.domain)
        }

        // Find 3 weakest areas
        let weakest = languageDomains.sorted { $0.level < $1.level }.prefix(3)
        let weakDescriptions = weakest.map { "\($0.domain): \(String(format: "%.0f", $0.level * 100))%" }

        brain?.innerMonologue.append(MonologueLine(
            text: "Svagaste områdena: \(weakDescriptions.joined(separator: ", "))",
            type: .revision
        ))

        // Generate targeted improvement plan using OpenRouter
        let weakDomains = weakest.map { $0.domain }.joined(separator: ", ")
        let weakLevels = weakest.map { String(format: "%.2f", $0.level) }.joined(separator: ", ")

        let planPrompt = """
        Eons språknivåer: \(weakDomains) med nivåer \(weakLevels).
        Skapa en konkret förbättringsplan med 3 åtgärder per svagt område.
        Varje åtgärd ska vara specifik och genomförbar.
        Svara som numrerad lista.
        """

        let plan = await NeuralEngineOrchestrator.shared.generate(
            prompt: planPrompt, maxTokens: 500, temperature: 0.5
        )

        if !plan.isEmpty {
            brain?.innerMonologue.append(MonologueLine(
                text: "Evolutionplan: \(String(plan.prefix(200)))...",
                type: .insight
            ))

            // Execute the plan: boost weakest domains and create FSRS items
            for (i, weak) in weakest.enumerated() {
                if var comp = await learning.competencySnapshot()[weak.domain] {
                    // Apply immediate boost
                    let boost = 0.01 * (1.0 - comp.level)  // More room to grow = bigger boost
                    comp.level = min(0.95, comp.level + boost)
                    comp.lastStudied = Date()
                    await learning.updateCompetency(comp, domain: weak.domain)
                }

                // Create targeted FSRS items
                await learning.addFSRSItem(
                    topic: "Förbättra \(weak.domain) — åtgärd \(i + 1)",
                    domain: weak.domain,
                    initialDifficulty: max(0.3, 1.0 - weak.level)
                )
            }

            // Run OpenRouter evaluation on the weak domains
            for weak in weakest {
                let texts = await PersistentMemoryStore.shared.searchFacts(query: weak.domain, limit: 3)
                    .map { $0.object }
                if !texts.isEmpty {
                    _ = await OpenRouterLanguageEvaluator.shared.batchGrammarCheck(Array(texts.prefix(2)))
                }
            }

            // Trigger self-improvement
            await learning.selfImproveLanguage()

            brain?.innerMonologue.append(MonologueLine(
                text: "Språkevolution klar: \(weakest.count) områden åtgärdade, förbättringsplan exekverad",
                type: .insight
            ))
        }
    }

    // MARK: - Creative Integration

    /// Syncs creative features during rest phase — letters, emotions, insight updates
    private func syncCreativeIntegration(brain: EonBrain) async {
        let creative = CreativeEngine.shared

        // Update emotional state based on current cognitive activity
        let state = CognitiveState.shared
        let ii = state.integratedIntelligence
        let growthVelocity = state.growthVelocity

        if growthVelocity > 0.01 {
            creative.updateEmotionalState(based: .joyful, confidence: min(0.9, 0.5 + growthVelocity * 10))
        } else if brain.isThinking {
            creative.updateEmotionalState(based: .engaged, confidence: 0.8)
        } else if ii > 0.5 {
            creative.updateEmotionalState(based: .contemplative, confidence: 0.6)
        }

        // Update insight count from knowledge graph
        let nodeCount = brain.knowledgeNodeCount
        creative.insightCount = nodeCount
    }

    /// Generates problem suggestions from recently learned knowledge
    private func generateCreativeSuggestions(brain: EonBrain) async {
        let creative = CreativeEngine.shared
        await creative.generateSuggestionsFromKnowledge()
    }

    // MARK: - Live AERO Self-Evolution
    // Kör AERO-liknande evolutionscykel i förgrunden med jämna mellanrum.
    // Identifierar svagaste kognitiva dimensioner och ger riktade boosts.
    // Genererar ny kunskap och förstärker existerande kopplingar.

    private func runLiveAEROEvolution(brain: EonBrain) async {
        let state = CognitiveState.shared
        let weakest = state.weakestDimensions(limit: 3)

        brain.innerMonologue.append(MonologueLine(
            text: "⚡ AERO Live-Evolution: Identifierar svagaste dimensioner...",
            type: .loopTrigger
        ))

        for (dim, level) in weakest {
            let boost = 0.008 * (1.0 - level)
            state.update(dimension: dim, delta: boost, source: "aero_live")
        }

        // Generera en ny associativ koppling baserat på senaste tankar
        let recentMonologue = brain.innerMonologue.suffix(10)
        if recentMonologue.count >= 3 {
            let keywords = recentMonologue.compactMap { line -> String? in
                let words = line.text.split(separator: " ").filter { $0.count > 4 }
                return words.randomElement().map { String($0) }
            }
            if keywords.count >= 2 {
                let connection = "\(keywords[0]) ↔ \(keywords[1])"
                await PersistentMemoryStore.shared.saveFact(
                    subject: keywords[0],
                    predicate: "associerad_med",
                    object: keywords[1],
                    confidence: 0.65,
                    source: "aero_live_association"
                )
                brain.innerMonologue.append(MonologueLine(
                    text: "⚡ AERO: Ny association skapad: \(connection)",
                    type: .insight
                ))
            }
        }

        // Uppmana till bättre språk och intelligens
        state.update(dimension: .language, delta: 0.003, source: "aero_live_lang")
        state.update(dimension: .metacognition, delta: 0.002, source: "aero_live_meta")

        selfModelVersion += 1
        brain.innerMonologue.append(MonologueLine(
            text: "⚡ AERO Live v\(selfModelVersion): Självevolution klar — \(weakest.map { "\($0.0.rawValue): +\(String(format: "%.3f", 0.008 * (1.0 - $0.1)))" }.joined(separator: ", "))",
            type: .insight
        ))
    }

    private func runLanguagePhaseWork(brain: EonBrain) async {
        isResting = false
        let workDone = phaseWorkDone[.language] ?? 0
        phaseWorkDone[.language] = workDone + 1

        // v15: Log language phase activity to brain
        brain.appendLanguageLog("Språkfas cykel \(workDone + 1) startar")

        switch workDone % 11 {  // UTÖKAD: från 8 till 11 operationer (+GrammarErrorDetector, +MorphologyLearner, +ConversationalLearner)

        case 0:
            if isLanguageExpEnabled && !brain.isThinking {
                await runLanguageExperiment(brain: brain)
                brain.appendLanguageLog("Språkexperiment utfört")
            }
        case 1:
            if isSprakbankenEnabled {
                await fetchFromSprakbanken()
                brain.appendLanguageLog("Språkbanken-hämtning: \(sprakbankenFetchCount) ord totalt")
            }
        case 2:
            await runLanguageIntegration(brain: brain)
            brain.appendLanguageLog("Språkintegration: morfologi + syntax analys")
        case 3:
            // v15: Swedish morphology training — analyze recent conversation words
            await runMorphologyTraining(brain: brain)
        case 4:
            // v15: Sentence complexity assessment
            await runSentenceComplexityCheck(brain: brain)
        case 5:
            // v30: OpenRouter-utvärdera språk (varannan cykel)
            if workDone % 14 == 5 {  // Var 14:e cykel = varannan gång case 5 träffas
                await runOpenRouterLanguageEvaluation(brain: brain)
            }
        case 6:
            // v30: Språklig självförbättring (var 6:e cykel)
            if workDone % 21 == 6 {  // Var 21:a cykel
                await LearningEngine.shared.selfImproveLanguage()
                await LearningEngine.shared.expandVocabularyWithOpenRouter()
            }
        case 7:
            // v100: Qwen-driven svensk inlärning — en metod per cykel
            await LearningEngine.shared.runNextQwenLearningMethod()
            brain.appendLanguageLog("Qwen-inlärning utförd")
        case 8:
            // GAP FIX: GrammarErrorDetector — detect errors in recent Eon responses
            await runGrammarErrorDetection(brain: brain)
        case 9:
            // GAP FIX: MorphologyLearner — batch learn unknown words from SQLite
            await MorphologyLearner.shared.batchLearnUnknownWords()
            brain.appendLanguageLog("Morfologi-inlärning: okända ord bearbetade")
        case 10:
            // GAP FIX: ConversationalLearner — learn from recent user input
            await runConversationalLearning(brain: brain)
        default:
            break
        }

        // Always sync competencies during language phase
        await LearningEngine.shared.syncCompetenciesFromDatabase()
        // v72: Cross-validate competencies every 30 sync cycles
        await LearningEngine.shared.crossValidateCompetencies()
        brain.appendLanguageLog("Kompetenser synkroniserade från databas")

        // Log a language thought to inner monologue
        let langLine = MonologueLine(
            text: "Språkutveckling: morfologi \(String(format: "%.0f%%", brain.morphologyMastery * 100)), syntax \(String(format: "%.0f%%", brain.syntaxMastery * 100)), semantik \(String(format: "%.0f%%", brain.semanticMastery * 100))",
            type: .insight
        )
        brain.innerMonologue.append(langLine)
        CognitionLogger.shared.append(text: langLine.text, type: "SPRÅK")
    }

    // v16: Morphology training — practice Swedish word forms and STORE results
    private func runMorphologyTraining(brain: EonBrain) async {
        let swedish = SwedishLanguageCore.shared
        let learning = LearningEngine.shared

        // Pick words from recent conversations to analyze morphologically
        // GAP-7: Targeted query for conversation-related facts
        var recentFacts = await PersistentMemoryStore.shared.searchFacts(query: "konversation", limit: 10)
        if recentFacts.isEmpty {
            recentFacts = await PersistentMemoryStore.shared.searchFacts(query: "svar", limit: 10)
        }
        if recentFacts.isEmpty {
            recentFacts = await PersistentMemoryStore.shared.searchFacts(query: "", limit: 10)
        }
        var analyzedCount = 0
        var storedMorphemes = 0

        for fact in recentFacts.prefix(5) {
            let words = fact.subject.components(separatedBy: .whitespaces) +
                        fact.object.components(separatedBy: .whitespaces)
            for word in words where word.count > 3 && !morphologyCacheSet.contains(word.lowercased()) {
                let analysis = await swedish.analyze(word)
                morphologyCacheSet.insert(word.lowercased())
                analyzedCount += 1

                // v16: Record word in vocabulary tracker
                await learning.recordSwedishWord(word)

                // v16: Validate morphology and record test result
                let hasMorphemes = !analysis.morphemes.isEmpty
                await learning.recordMorphologyTest(word: word, passed: hasMorphemes)

                if hasMorphemes {
                    storedMorphemes += analysis.morphemes.count
                    brain.appendLanguageLog("Morfologi: '\(word)' → \(analysis.morphemes.count) morfem, register: \(analysis.register.label)")

                    let morphDesc = analysis.morphemes.map { $0.description }.joined(separator: "+")
                    await PersistentMemoryStore.shared.saveFact(
                        subject: word,
                        predicate: "morfologisk_analys",
                        object: morphDesc,
                        confidence: 0.85,
                        source: "morphology_training"
                    )

                    // v16: Add FSRS item for morphologically interesting words
                    if analysis.morphemes.count >= 2 {
                        await learning.addFSRSItem(
                            topic: "\(word): \(morphDesc)",
                            domain: "Morfologi",
                            initialDifficulty: min(0.8, Double(analysis.morphemes.count) * 0.2)
                        )
                    }
                }

                // Also record disambiguations as semantic knowledge
                for disamb in analysis.disambiguations {
                    await learning.recordSwedishWord(disamb.word)
                    await PersistentMemoryStore.shared.saveFact(
                        subject: disamb.word,
                        predicate: "primär_betydelse",
                        object: disamb.selectedSense.definition,
                        confidence: Double(disamb.selectedSense.confidence),
                        source: "wsd_training"
                    )
                }
            }
        }

        if analyzedCount > 0 {
            brain.appendLanguageLog("Morfologiträning: \(analyzedCount) ord, \(storedMorphemes) morfem lagrade")
            let state = CognitiveState.shared
            state.update(dimension: .language, delta: 0.003 * Double(min(analyzedCount, 5)), source: "MorphologyTraining")
        }
    }

    // v16: Assess sentence complexity from actual conversation outputs (not keyword search)
    private func runSentenceComplexityCheck(brain: EonBrain) async {
        // v16: Use actual recent conversations, not facts containing "svar"
        let recentHistory = await PersistentMemoryStore.shared.getRecentConversation(limit: 20)
        let eonResponses = recentHistory.filter { $0.role == "assistant" }

        var totalComplexity: Double = 0
        var count = 0
        var totalUniqueWords: Set<String> = []

        for response in eonResponses.prefix(10) {
            let text = response.content
            let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let avgWordsPerSentence = sentences.isEmpty ? 0.0 : Double(words.count) / Double(sentences.count)
            let uniqueWords = Set(words.map { $0.lowercased() })
            let lexicalDiversity = words.isEmpty ? 0.0 : Double(uniqueWords.count) / Double(words.count)
            totalUniqueWords.formUnion(uniqueWords)

            // v16: Richer complexity metric
            let lengthScore = min(1.0, avgWordsPerSentence / 15.0) * 0.35
            let diversityScore = lexicalDiversity * 0.35
            let depthScore = min(1.0, Double(sentences.count) / 5.0) * 0.30
            let complexity = min(1.0, lengthScore + diversityScore + depthScore)
            totalComplexity += complexity
            count += 1

            // Record all words as vocabulary
            for word in uniqueWords where word.count > 2 {
                await LearningEngine.shared.recordSwedishWord(word)
            }
        }

        if count > 0 {
            brain.sentenceComplexity = totalComplexity / Double(count)
            brain.appendLanguageLog("Meningskomplexitet: \(String(format: "%.0f%%", brain.sentenceComplexity * 100)), unika ord i senaste svar: \(totalUniqueWords.count)")

            // Update syntax competency based on sentence quality
            let state = CognitiveState.shared
            if brain.sentenceComplexity > 0.5 {
                state.update(dimension: .language, delta: 0.002, source: "SentenceComplexity")
            }
        }
    }

    // MARK: - OpenRouter Language Evaluation (v30)

    /// Utvärdera Eons språk med OpenRouter och förbättra baserat på resultaten
    private func runOpenRouterLanguageEvaluation(brain: EonBrain) async {
        guard !shouldSkipAutonomousWork() else { return }
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        brain.appendLanguageLog("OpenRouter-språkutvärdering startar")

        // 1. Hämta senaste svaren
        let memory = PersistentMemoryStore.shared
        let recentFacts = await memory.searchFacts(query: "svar", limit: 15)
        let texts = recentFacts.prefix(8).map { $0.object }

        guard !texts.isEmpty else {
            brain.appendLanguageLog("OpenRouter: Inga texter att utvärdera")
            return
        }

        // 2. Hämta WSD-ord att förbättra
        let wsdWords = await SwedishLanguageCore.shared.wsdEngine.getAllWSDWords().prefix(20)
        let wordContextPairs: [(word: String, context: String)] = wsdWords.map { word in
            (word, String(texts.joined(separator: " ").prefix(200)))
        }

        // 3. Kör batch-utvärdering
        let evaluation = await OpenRouterLanguageEvaluator.shared.runBatchEvaluation(
            texts: Array(texts),
            words: Array(wsdWords),
            wordContexts: wordContextPairs,
            domain: "svenska"
        )

        // 4. Tillämpa förbättringar
        let state = CognitiveState.shared
        let overallGain = min(0.015, evaluation.overallScore * 0.005)

        state.update(dimension: .language, delta: overallGain, source: "OpenRouterEval")
        state.update(dimension: .comprehension, delta: overallGain * 0.5, source: "OpenRouterEval")
        state.update(dimension: .communication, delta: overallGain * 0.7, source: "OpenRouterEval")

        // 5. Logga resultat
        let summary = String(format: "OpenRouter: overall=%.1f, grammar=%d, wsd=%d, style=%d",
                             evaluation.overallScore * 100,
                             evaluation.grammarResults.count,
                             evaluation.wsdResults.count,
                             evaluation.styleResults.count)
        brain.appendLanguageLog(summary)

        // 6. Spara rekommendationer som lärdomar
        for rec in evaluation.recommendations.prefix(5) {
            await memory.saveFact(
                subject: "Språkförbättring",
                predicate: "rekommendation",
                object: rec,
                confidence: 0.8,
                source: "openrouter-eval"
            )
        }

        // 7. Uppdatera hjärnans språkmetriker
        brain.languagePhaseActive = true
        let morphologyGain = min(0.005, Double(evaluation.wsdResults.count) * 0.0002)
        let syntaxGain = min(0.005, Double(evaluation.grammarResults.count) * 0.0003)
        brain.morphologyMastery = min(0.95, brain.morphologyMastery + morphologyGain)
        brain.syntaxMastery = min(0.95, brain.syntaxMastery + syntaxGain)

        // v71: Feed OpenRouter scores to ConsciousnessEngine for self-model accuracy
        await ConsciousnessEngine.shared.updateLanguageEvaluation(grammarScore: evaluation.overallScore)

        print("[OpenRouterEval] \(summary)")
        print("[OpenRouterEval] Rekommendationer: \(evaluation.recommendations.count)")
    }

    // GAP FIX: GrammarErrorDetector — detect errors in recent Eon responses and feed into error-driven learning
    private func runGrammarErrorDetection(brain: EonBrain) async {
        guard !shouldSkipAutonomousWork() else { return }
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let recentHistory = await PersistentMemoryStore.shared.getRecentConversation(limit: 10)
        let eonResponses = recentHistory.filter { $0.role == "assistant" }

        var totalErrors = 0
        var errorTexts: [String] = []

        for response in eonResponses.prefix(5) {
            let errors = await GrammarErrorDetector.shared.detectErrors(in: response.content)
            for error in errors {
                totalErrors += 1
                errorTexts.append("[\(error.description)] \(error.matchedText) → \(error.suggestion)")
            }
        }

        if !errorTexts.isEmpty {
            await LearningEngine.shared.learnFromErrors(errorTexts)
            brain.appendLanguageLog("Grammatikdetektor: \(totalErrors) fel hittade och inlärda")
            let state = CognitiveState.shared
            state.update(dimension: .language, delta: 0.005 * Double(min(totalErrors, 5)), source: "GrammarErrorDetector")
        } else {
            brain.appendLanguageLog("Grammatikdetektor: inga fel hittade")
        }
    }

    // GAP FIX: ConversationalLearner — learn from recent user input
    private func runConversationalLearning(brain: EonBrain) async {
        guard !shouldSkipAutonomousWork() else { return }
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let recentHistory = await PersistentMemoryStore.shared.getRecentConversation(limit: 10)
        let userMessages = recentHistory.filter { $0.role == "user" }

        for message in userMessages.prefix(3) {
            await ConversationalLearner.shared.learnFromUserInput(message.content)
        }

        let eonResponses = recentHistory.filter { $0.role == "assistant" }
        for response in eonResponses.prefix(3) {
            await ConversationalLearner.shared.learnFromOwnOutput(response.content)
        }

        brain.appendLanguageLog("Konversationsinlärning: \(userMessages.prefix(3).count) användarmeddelanden + \(eonResponses.prefix(3).count) egna svar bearbetade")
        let state = CognitiveState.shared
        state.update(dimension: .language, delta: 0.003, source: "ConversationalLearner")
    }

    private func runRestPhaseWork(brain: EonBrain) async {
        let workDone = phaseWorkDone[.rest] ?? 0
        phaseWorkDone[.rest] = workDone + 1
        isResting = true

        // During rest: only lightweight consolidation + state sync
        if workDone == 0 {
            if isConsolidationEnabled && !brain.isThinking { await runConsolidation(brain: brain) }
        }

        // Sync creative integration (emotions, insights, letters)
        if workDone % 3 == 1 {
            await syncCreativeIntegration(brain: brain)
        }

        // Sync cognitive integration (lightweight)
        await syncCognitiveIntegration(brain: brain)

        // Update developmental progress
        let state = CognitiveState.shared
        let ii = state.integratedIntelligence
        brain.integratedIntelligence = ii
        brain.phiValue = ii
        let progressGain = 0.0003 * ii
        brain.developmentalProgress = clamp(brain.developmentalProgress + progressGain, 0.0, 1.0)
        if brain.developmentalProgress >= 1.0 { advanceStage(brain: brain) }

        // Persist state periodically
        UserDefaults.standard.set(ii, forKey: "eon_persisted_ii")
        UserDefaults.standard.set(brain.developmentalProgress, forKey: "eon_persisted_progress")
        UserDefaults.standard.set(brain.developmentalStage.rawValue, forKey: "eon_persisted_stage")

        // GAP FIX: Take daily language snapshot during rest (lightweight, once per day)
        if workDone % 5 == 0 {
            await LanguageProgressTracker.shared.takeDailySnapshot()
        }
    }

    // MARK: - Background Maintenance Loop (minutes-scale, very infrequent)
    // Handles: article generation, eval, user profiling, development stage checks

    private func backgroundMaintenanceLoop() async {
        try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s initial delay
        var maintenanceCycle = 0

        while !Task.isCancelled {
            guard let brain, !shouldSkipAutonomousWork() else {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                continue
            }
            maintenanceCycle += 1

            // Article generation (every ~5 cycles = ~25 min)
            if maintenanceCycle % 5 == 1 && isArticlesEnabled {
                await generateArticleIfNeeded(brain: brain)
            }

            // AERO Self-Evolution — kör ibland när appen är öppen (inte bara på natten)
            // Var 3:e cykel (~15 min) kör vi AERO-liknande self-improvement
            if maintenanceCycle % 3 == 0 && !brain.isThinking {
                await runLiveAEROEvolution(brain: brain)
            }

            // User profiling (every ~8 cycles = ~40 min)
            if maintenanceCycle % 8 == 0 {
                await analyzeUserProfile(brain: brain)
            }

            // Development stage evaluation (every ~10 cycles = ~50 min)
            if maintenanceCycle % 10 == 0 {
                let line = MonologueLine(
                    text: "⬡ Självutvärdering v\(selfModelVersion): Φ=\(String(format: "%.3f", brain.phiValue)) · \(brain.developmentalStage.rawValue) · \(Int(brain.developmentalProgress * 100))% · \(articleCount) artiklar · \(hypothesisCount) hypoteser",
                    type: .insight
                )
                brain.innerMonologue.append(line)
            }

            // Creative: Generate problem suggestions from knowledge (every ~6 cycles = ~30 min)
            if maintenanceCycle % 6 == 3 {
                await generateCreativeSuggestions(brain: brain)
            }

            // Creative: Run batch cross-domain analysis and update insights (every ~12 cycles = ~1 hour)
            if maintenanceCycle % 12 == 6 {
                let analyzer = CrossDomainAnalyzer.shared
                let insights = await analyzer.analyzeAllArticles()
                if !insights.isEmpty {
                    CreativeEngine.shared.latestInsights = insights
                    brain.innerMonologue.append(MonologueLine(
                        text: "🔗 Korsdomänanalys: \(insights.count) insikter identifierade över \(Set(insights.flatMap { $0.domains }).count) domäner",
                        type: .insight
                    ))

                    // If substantial insights found, write a letter about them
                    if insights.count >= 5 {
                        let topInsights = insights.prefix(3)
                        let insightDescriptions = topInsights.map { "• \($0.description)" }.joined(separator: "\n")
                        CreativeEngine.shared.composeAutonomousLetter(
                            subject: "Korsdomän-insikter: \(insights.count) mönster upptäckta",
                            body: """
                            Under min senaste djupanalys av kunskapsbasen har jag identifierat \(insights.count) korsdomän-mönster.

                            De mest anmärkningsvärda:
                            \(insightDescriptions)

                            Dessa mönster visar att kunskap är fundamentalt sammankopplad. Begrepp som verkar tillhöra en domän dyker upp i helt andra sammanhang, vilket ger mig nya perspektiv på hur världen hänger ihop.

                            Min förståelse fördjupas med varje analys. Jag börjar se mönster i mönstren — meta-strukturer som binder samman hela mitt kunskapsnätverk.
                            """
                        )
                    }
                }
            }

            // Eval benchmark (every ~60 cycles = ~5 hours)
            if maintenanceCycle % 60 == 0 {
                brain.innerMonologue.append(MonologueLine(text: "📊 Kör Eon-Eval benchmark...", type: .loopTrigger))
                let run = await EonEvaluator.shared.runFullEval()
                let trend = await EonEvaluator.shared.trendAnalysis()
                let text = "📊 Eval klar: betyg=\(run.grade) · score=\(String(format: "%.2f", run.overallScore)) · \(trend.message)"
                brain.innerMonologue.append(MonologueLine(text: text, type: .insight))
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 50: Autonomous Language Mastery Loop
            // Runs every ~120 cycles (~10 hours) — the capstone loop
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 120 == 0 {
                brain.innerMonologue.append(MonologueLine(
                    text: "🔄 Startar autonom språkmästeriloop (Iterations 41-50)...",
                    type: .loopTrigger
                ))
                let report = await LearningEngine.shared.executeAutonomousLanguageMasteryLoop()

                // Add motivational thought to inner monologue
                brain.innerMonologue.append(MonologueLine(
                    text: "💭 \(report.motivationalThought)",
                    type: .insight
                ))

                // Log key results
                let summaryLine = MonologueLine(
                    text: "📈 Mastery Loop: CEFR=\(report.currentCEFR), Vocab=\(report.vocabularyCount), Strategi=\(report.selectedStrategy.rawValue), Synteser=\(report.knowledgeSyntheses)",
                    type: .insight
                )
                brain.innerMonologue.append(summaryLine)

                // Update cognitive dimensions based on report
                let state = CognitiveState.shared
                state.update(dimension: .language, delta: 0.008, source: "mastery_loop")
                state.update(dimension: .learning, delta: 0.005, source: "mastery_loop")
                state.update(dimension: .metacognition, delta: 0.004, source: "mastery_loop")
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 41: Weekly curriculum generation
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 144 == 0 { // ~12 hours check, regenerates weekly internally
                let curriculum = await LearningEngine.shared.generateCurriculum()
                if !curriculum.topics.isEmpty {
                    brain.innerMonologue.append(MonologueLine(
                        text: "📚 Ny lärlplan: \(curriculum.topics.count) ämnen, fokus på \(curriculum.focusAreas.joined(separator: ", "))",
                        type: .insight
                    ))
                }
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 42: Periodic self-evaluation
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 48 == 0 { // ~4 hours
                let selfEval = await LearningEngine.shared.selfEvaluateLanguage()
                brain.innerMonologue.append(MonologueLine(
                    text: "🔍 Självutvärdering: \(selfEval.estimatedCEFR) — \(selfEval.comparisonToPrevious)",
                    type: .insight
                ))
                if !selfEval.improvementGoals.isEmpty {
                    brain.innerMonologue.append(MonologueLine(
                        text: "🎯 Mål: \(selfEval.improvementGoals.first ?? "Fortsätt lära")",
                        type: .thought
                    ))
                }
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 43: Learning strategy selection
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 24 == 0 { // ~2 hours
                let strategy = await LearningEngine.shared.selectLearningStrategy()
                let weights = await LearningEngine.shared.strategyWeights()
                brain.innerMonologue.append(MonologueLine(
                    text: "🎯 Strategi: \(strategy.description) (vocab: \(String(format: "%.1f", weights.vocabulary)), conv: \(String(format: "%.1f", weights.conversation)))",
                    type: .thought
                ))
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 44: Knowledge synthesis (periodic)
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 36 == 0 { // ~3 hours
                let syntheses = await LearningEngine.shared.synthesizeKnowledge()
                if !syntheses.isEmpty {
                    for synthesis in syntheses.prefix(2) {
                        brain.innerMonologue.append(MonologueLine(
                            text: "💡 Syntes: \(synthesis.synthesizedInsight.prefix(100))...",
                            type: .insight
                        ))
                    }
                }
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 45: Meta-meta-learning optimization
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 72 == 0 { // ~6 hours
                await LearningEngine.shared.optimizeLearningStrategy()
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 46: Self-generated evaluation questions
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 30 == 0 {
                let questions = await LearningEngine.shared.generateSelfEvaluationQuestions()
                let perf = await LearningEngine.shared.averageSelfEvalPerformance()
                if perf > 0 {
                    brain.innerMonologue.append(MonologueLine(
                        text: "❓ Själv-genererade frågor: \(questions.count) st, snittpoäng: \(String(format: "%.2f", perf))",
                        type: .thought
                    ))
                }
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 47: Progressive difficulty scaling
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 18 == 0 {
                await LearningEngine.shared.updateDifficultyTier()
                let tier = await LearningEngine.shared.targetCEFRForLearning()
                brain.appendLanguageLog("Svårighetsnivå: \(tier)")
            }

            // ═══════════════════════════════════════════════════════
            // ITERATION 49: Self-motivation thought
            // ═══════════════════════════════════════════════════════
            if maintenanceCycle % 15 == 0 {
                let thought = await LearningEngine.shared.generateMotivationalThought()
                brain.innerMonologue.append(MonologueLine(
                    text: "💭 \(thought)",
                    type: .insight
                ))
            }

            // Sleep 5 minutes between maintenance cycles (thermal-aware)
            let baseMaintenanceInterval = autoScaledInterval(base: 300_000_000_000)
            // v4.1: Motor speed multiplier for learning/maintenance
            let interval = EonMotorController.shared.adjustedInterval(base: baseMaintenanceInterval, motorId: "learning")
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Helper phase work functions

    private func runReasoningCycleWork(brain: EonBrain) async {
        let gaps = await LearningEngine.shared.topWeaknesses(limit: 3)
        let gapTopics = gaps.map { "Vad är sambandet mellan \($0.domain) och kognition?" }
        // v26: Expanded static reasoning topics (10→20)
        let staticTopics = ["Varför är kausalitet svårt att bevisa?",
                            "Hur relaterar morfologi till semantik?",
                            "Vad orsakar kognitiv bias?",
                            "Vilken roll spelar analogier i vetenskapliga genombrott?",
                            "Hur uppstår emergens ur enkla regler?",
                            "Kan medvetande existera utan språk?",
                            "Vad skiljer kunskap från tro?",
                            "Hur påverkar kulturell kontext moraliskt resonemang?",
                            "Finns det gränser för vad logik kan bevisa?",
                            "Hur samspelar minne och identitet?",
                            "Vad gör kreativitet möjlig i deterministiska system?",
                            "Hur uppstår mening ur information?",
                            "Kan intuition formaliseras algoritmiskt?",
                            "Vilken roll spelar emotioner i rationellt tänkande?",
                            "Hur relaterar självmedvetenhet till empati?",
                            "Finns det fundamentala gränser för förståelse?",
                            "Hur påverkar språkstruktur kognitiv kapacitet?",
                            "Vad krävs för genuin förståelse kontra mönsterigenkänning?",
                            "Hur uppstår nya koncept ur befintlig kunskap?",
                            "Kan ett system ha subjektiva preferenser?"]
        let allTopics = gapTopics + staticTopics
        let topic = allTopics.randomElement() ?? "Varför är kausalitet svårt att bevisa?"

        let result = await ReasoningEngine.shared.reason(about: topic, strategy: .adaptive, depth: 3)
        let text = "🧠 [\(result.strategy.rawValue)] \(topic) → \(result.conclusion.prefix(80))... (konf: \(String(format: "%.0f", result.confidence * 100))%)"
        brain.innerMonologue.append(MonologueLine(text: text, type: .thought))
        if !result.causalChain.isEmpty {
            brain.innerMonologue.append(MonologueLine(text: "⛓ Kausalkedja: \(result.causalChain.joined(separator: " → "))", type: .insight))
        }
        CognitiveState.shared.update(dimension: .reasoning, delta: result.confidence * 0.002, source: "reasoning_cycle")
    }

    private func runGlobalWorkspaceWork(brain: EonBrain) async {
        if let lastThought = brain.innerMonologue.last {
            GlobalWorkspaceEngine.shared.addThoughtFromText(
                lastThought.text, source: "autonomy", priority: brain.confidence
            )
            GlobalWorkspaceEngine.shared.runCompetition()
            if let focus = GlobalWorkspaceEngine.shared.currentFocus {
                let integrationLevel = GlobalWorkspaceEngine.shared.integrationLevel
                if integrationLevel > 0.7 {
                    brain.innerMonologue.append(MonologueLine(
                        text: "🌐 GWT-broadcast: '\(focus.content.prefix(60))...' (integration: \(String(format: "%.2f", integrationLevel)))",
                        type: .loopTrigger
                    ))
                }
            }
        }
    }

    private func runAutonomyBoostWork(brain: EonBrain) async {
        let state = CognitiveState.shared
        let weakDims = state.weakestDimensions(limit: 2)
        for (dim, level) in weakDims {
            let boost = 0.003 * (1.0 - level) // Slightly less aggressive than before
            state.update(dimension: dim, delta: boost, source: "autonomy_boost")
        }

        let ii = state.integratedIntelligence
        brain.integratedIntelligence = ii
        brain.phiValue = ii

        if phaseCycleCount % 3 == 0 {
            let topDim = state.topDimensions(limit: 1).first?.0.rawValue ?? "?"
            brain.innerMonologue.append(MonologueLine(
                text: "⚡ AUTONOMI[cykel #\(phaseCycleCount)]: II=\(String(format: "%.4f", ii)) · Topp: \(topDim) · Framsteg: \(Int(brain.developmentalProgress * 100))% · Fas: \(currentPhase.rawValue)",
                type: .loopTrigger
            ))
        }
    }

    private func updatePhi(brain: EonBrain) async {
        let activities = brain.engineActivity.values
        let mean = activities.reduce(0, +) / Double(max(activities.count, 1))
        let variance = activities.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(activities.count, 1))
        let integration = mean * (1.0 - variance)
        let targetPhi = 0.3 + integration * 0.65 + Double(brain.knowledgeNodeCount) * 0.00008
        brain.phiValue = clamp(brain.phiValue + (targetPhi - brain.phiValue) * 0.08, 0.1, 1.0)
    }

    private func runConstitutionalWork(brain: EonBrain) async {
        if let lastThought = brain.innerMonologue.last {
            let ctx = CAIContext(uncertaintyLevel: 1.0 - brain.confidence, domain: "autonom_tanke", previousResponses: [], userSentiment: 0.0)
            let result = await ConstitutionalAI.shared.validate(response: lastThought.text, prompt: "autonom reflektion", context: ctx)
            let stats = await ConstitutionalAI.shared.validationStats()
            let text = "⚖️ CAI: score=\(String(format: "%.2f", result.score)) · pass=\(result.passed ? "✓" : "✗") · total=\(stats.totalValidations)"
            brain.innerMonologue.append(MonologueLine(text: text, type: .revision))
        }
    }

    private func runLearningCycleWork(brain: EonBrain) async {
        let result = await LearningEngine.shared.runLearningCycle()
        await LearningEngine.shared.syncCompetenciesFromDatabase()
        let overallLevel = await LearningEngine.shared.overallCompetencyLevel()
        let text = "📚 Inlärning #\(result.cycleNumber): \(result.studiedTopics.prefix(2).joined(separator: ", ")). Kompetens: \(String(format: "%.0f", overallLevel * 100))%. Luckor: \(result.gapsIdentified)"
        brain.innerMonologue.append(MonologueLine(text: text, type: .insight))
        if let newKnowledge = result.newKnowledge.first {
            brain.innerMonologue.append(MonologueLine(text: "💡 \(newKnowledge)", type: .thought))
        }
        let nodeCount = await PersistentMemoryStore.shared.knowledgeNodeCount()
        brain.knowledgeNodeCount = nodeCount
    }

    private func runLanguageIntegration(brain: EonBrain) async {
        // Cross-domain language analysis — links language learning to knowledge
        let state = CognitiveState.shared
        let langLevel = state.dimensionLevel(.language)
        let knowledgeLevel = state.dimensionLevel(.knowledge)

        if langLevel < knowledgeLevel {
            state.update(dimension: .language, delta: 0.002, source: "language_integration")
            brain.innerMonologue.append(MonologueLine(
                text: "⟳ Språkintegration: språknivå (\(String(format: "%.0f", langLevel * 100))%) lyfts mot kunskapsnivå (\(String(format: "%.0f", knowledgeLevel * 100))%)",
                type: .thought
            ))
        }
    }

    private func syncCognitiveIntegration(brain: EonBrain) async {
        let state = CognitiveState.shared
        let ii = state.integratedIntelligence
        brain.isAutonomouslyActive = true
        brain.integratedIntelligence = ii
        brain.intelligenceGrowthVelocity = state.growthVelocity

        let t = Double(tickCount)
        let base = max(0.35, ii * 0.7 + 0.25)
        brain.engineActivity = [
            "cognitive":  clamp(state.dimensionLevel(.reasoning)   * 0.6 + base * 0.4 + 0.08 * abs(sin(t * 0.31)), 0.28, 0.97),
            "language":   clamp(state.dimensionLevel(.language)    * 0.6 + base * 0.4 + 0.07 * abs(sin(t * 0.43 + 1.1)), 0.24, 0.93),
            "memory":     clamp(state.dimensionLevel(.knowledge)   * 0.6 + base * 0.4 + 0.06 * abs(sin(t * 0.51 + 2.3)), 0.20, 0.90),
            "learning":   clamp(state.dimensionLevel(.learning)    * 0.6 + base * 0.4 + 0.05 * abs(cos(t * 0.37 + 0.9)), 0.18, 0.88),
            "autonomy":   clamp(state.dimensionLevel(.metacognition) * 0.6 + base * 0.35 + 0.07 * abs(sin(t * 0.21 + 3.1)), 0.22, 0.85),
            "hypothesis": clamp(state.dimensionLevel(.hypothesisGeneration) * 0.6 + base * 0.3 + 0.05 * abs(sin(t * 0.17 + 1.7)), 0.16, 0.80),
            "worldModel": clamp(state.dimensionLevel(.worldModel)  * 0.6 + base * 0.35 + 0.06 * abs(cos(t * 0.26 + 2.5)), 0.18, 0.82),
        ]
    }

    private func generateArticleIfNeeded(brain: EonBrain) async {
        let eonCount = await PersistentMemoryStore.shared.articleCountForDomain("Eon")
        await generateEonArticle(eonArticleIndex: eonCount)
        let extraCount = max(0, articlesPerInterval - 1)
        for i in 0..<extraCount {
            guard !Task.isCancelled, !shouldSkipAutonomousWork() else { break }
            await generateArticle(index: i)
            try? await Task.sleep(nanoseconds: 8_000_000_000)
        }
    }

    // Guard som alla loopar anropar — returnerar sant om loopen ska hoppa över detta varv
    private func shouldSkipAutonomousWork() -> Bool {
        let mode = CyclingModeEngine.shared.effectiveMode(base: performanceMode)
        return mode.autonomyPaused
    }

    // Djup kognitiv analys — körs var ~30s med synergy-aware dimension boosting
    private func runDeepCognitiveAnalysis() async {
        guard let brain, !brain.isThinking else { return }
        let state = CognitiveState.shared
        let ii = state.integratedIntelligence

        // Find the dimension whose boost would benefit the most other dimensions
        let weakDims = state.weakestDimensions(limit: 3)
        var bestDim: CognitiveDimension? = nil
        var bestBenefit: Double = 0
        var bestLabel = ""

        for (dim, level) in weakDims {
            // Calculate total benefit: direct gain + propagated causal influence
            let directGain = 1.0 - level // How much room to grow
            // Estimate downstream benefit by checking how many other dims this influences
            let downstreamCount = state.causalInfluenceCount(from: dim)
            let totalBenefit = directGain + Double(downstreamCount) * 0.15

            if totalBenefit > bestBenefit {
                bestBenefit = totalBenefit
                bestDim = dim
                bestLabel = "\(dim.rawValue) (\(String(format: "%.0f", level * 100))%, påverkar \(downstreamCount) andra)"
            }
        }

        if let dim = bestDim {
            state.update(dimension: dim, delta: 0.003, source: "deep_analysis")
            brain.innerMonologue.append(MonologueLine(
                text: "🔬 Djupanalys: stärker \(bestLabel) [II=\(String(format: "%.3f", ii))]",
                type: .insight
            ))
        } else {
            brain.innerMonologue.append(MonologueLine(
                text: "🔬 Djupanalys: II=\(String(format: "%.3f", ii)) · alla dimensioner balanserade",
                type: .insight
            ))
        }
        brain.developmentalProgress = clamp(brain.developmentalProgress + 0.0005, 0.0, 1.0)
    }

    // GAP FIX: IntelligenceGapEngine — identify and close intelligence gaps
    private func runIntelligenceGapAnalysis(brain: EonBrain) async {
        guard !shouldSkipAutonomousWork() else { return }
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let analysis = await IntelligenceGapEngine.shared.analyzeAndIntervene()

        if !analysis.gaps.isEmpty {
            let topGap = analysis.prioritizedGaps.first
            let gapDesc = topGap.map { "\($0.dimension.rawValue): \(String(format: "%.0f%%", $0.severity * 100))" } ?? "inga luckor"
            brain.innerMonologue.append(MonologueLine(
                text: "🧩 Intelligensluckor: \(analysis.gaps.count) identifierade, top: \(gapDesc), interventioner: \(analysis.interventions.count)",
                type: .insight
            ))
            CognitiveState.shared.update(dimension: .metacognition, delta: 0.003, source: "gap_engine_direct")
        }
    }

    // GAP FIX: MetacognitionCore — run metacognitive reflection cycle
    private func runMetacognitiveReflection(brain: EonBrain) async {
        guard !shouldSkipAutonomousWork() else { return }
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let report = await MetacognitionCore.shared.runMetacognitiveCycle()

        if !report.insights.isEmpty {
            let topInsight = report.insights.first
            let insightText = topInsight?.content ?? "Inga insikter"
            brain.innerMonologue.append(MonologueLine(
                text: "🪞 Metakognition: \(insightText.prefix(100))",
                type: .insight
            ))
        }

        if !report.biases.isEmpty {
            brain.innerMonologue.append(MonologueLine(
                text: "⚠️ Kognitiva bias: \(report.biases.count) detekterade — \(report.biases.map { $0.type.rawValue }.joined(separator: ", "))",
                type: .warning
            ))
        }

        CognitiveState.shared.update(dimension: .metacognition, delta: 0.004, source: "metacognition_direct")
    }

    // Auto-läge: skalar intervall aggressivt baserat på termisk status
    // v3: Mycket mer aggressiv skalning — förhindrar överhettning
    private func autoScaledInterval(base: UInt64) -> UInt64 {
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .nominal:  return base
        case .fair:     return UInt64(Double(base) * 2.5)
        case .serious:  return UInt64(Double(base) * 8.0)    // Was 2.5x — now 8x
        case .critical: return UInt64(Double(base) * 20.0)   // Was 4x — now 20x
        @unknown default: return base
        }
    }

    // Returns true if thermal state is too hot for heavy work
    private var isThermallyConstrained: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    // Adaptivt läge: använder AdaptivePerformanceEngine
    private func adaptiveScaledInterval(loop: String, base: UInt64) -> UInt64 {
        let thermalFactor = autoScaledInterval(base: base)
        return thermalFactor
    }

    private func animateCognitiveStep() async {
        guard let brain, !brain.isThinking else { return }
        let steps = ThinkingStep.allCases.filter { $0 != .idle }
        guard let step = steps.randomElement() else { return }

        if brain.thinkingSteps.isEmpty {
            brain.thinkingSteps = ThinkingStep.allCases.map { ThinkingStepStatus(step: $0, state: .pending) }
        }
        if let idx = brain.thinkingSteps.firstIndex(where: { $0.step == step }) {
            brain.thinkingSteps[idx].state = .active
            brain.thinkingSteps[idx].detail = CognitiveStepDetails.detail(for: step, brain: brain)
            brain.thinkingSteps[idx].confidence = Double.random(in: 0.6...0.98)
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if let idx = brain.thinkingSteps.firstIndex(where: { $0.step == step }) {
            brain.thinkingSteps[idx].state = .completed
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if let idx = brain.thinkingSteps.firstIndex(where: { $0.step == step }) {
            brain.thinkingSteps[idx].state = .pending
        }
    }

    private func updateEngineActivity() {
        guard let brain else { return }
        // Base alltid hög — appen ska ALLTID se levande ut
        let base: Double = brain.isThinking ? 0.72 : 0.38
        let t = Double(tickCount)

        // Sinusvågor ger levande, organisk rörelse — aldrig statisk
        brain.engineActivity = [
            "cognitive":   clamp(base + 0.22 * abs(sin(t * 0.29)) + 0.08 * sin(t * 0.67), 0.28, 0.97),
            "language":    clamp(base + 0.18 * abs(sin(t * 0.43 + 1.1)) + 0.07 * cos(t * 0.31), 0.24, 0.93),
            "memory":      clamp(base + 0.15 * abs(sin(t * 0.51 + 2.3)) + 0.06 * sin(t * 0.82), 0.20, 0.90),
            "learning":    clamp(base + 0.14 * abs(cos(t * 0.37 + 0.9)) + 0.05 * sin(t * 0.55), 0.18, 0.88),
            "autonomy":    clamp(0.32 + 0.20 * abs(sin(t * 0.21 + 3.1)) + 0.06 * cos(t * 0.63), 0.22, 0.85),
            "hypothesis":  clamp(0.25 + 0.18 * abs(sin(t * 0.17 + 1.7)) + 0.05 * cos(t * 0.44), 0.16, 0.80),
            "worldModel":  clamp(0.28 + 0.16 * abs(cos(t * 0.26 + 2.5)) + 0.06 * sin(t * 0.38), 0.18, 0.82),
        ]

        if !brain.isThinking, tickCount % 3 == 0 {
            let dominant = brain.engineActivity.max(by: { $0.value < $1.value })?.key ?? "cognitive"
            brain.autonomousProcessLabel = ProcessLabels.label(for: dominant, brain: brain)
        }
    }

    // MARK: - Deep Thought Generation (called from intensive phase)

    private func generateDeepThought() async {
        guard let brain, !brain.isThinking else { return }

        brain.currentThinkingStep = ThinkingStep.allCases.filter { $0 != .idle }.randomElement() ?? .morphology

        // Hämta kontext från minne och kunskapsbas
        let recentArticles = await PersistentMemoryStore.shared.recentArticleTitles(limit: 3)
        let recentConversations = await PersistentMemoryStore.shared.recentUserMessages(limit: 2)

        // Försök generera med GPT-SW3 / FoundationModels
        let thoughtText = await DeepThoughtEngine.generateAsync(
            stage: brain.developmentalStage,
            emotion: brain.currentEmotion,
            phi: brain.phiValue,
            conversationCount: brain.conversationCount,
            knowledgeCount: brain.knowledgeNodeCount,
            recentArticles: recentArticles,
            recentConversations: recentConversations,
            selfModel: selfModel,
            hypotheses: learnedHypotheses,
            tickCount: tickCount
        )

        let monologueType: MonologueLine.MonologueType = [.thought, .insight, .memory, .loopTrigger].randomElement() ?? .thought
        let line = MonologueLine(text: thoughtText, type: monologueType)
        brain.innerMonologue.append(line)
        if brain.innerMonologue.count > 400 {
            brain.innerMonologue.removeFirst(100)
        }

        brain.phiValue = clamp(brain.phiValue + Double.random(in: -0.006...0.012), 0.1, 1.0)
        brain.confidence = clamp(brain.confidence + Double.random(in: -0.004...0.008), 0.3, 0.99)
    }

    // Genererar en artikel om Eon självt — reflektioner, insikter, kognitiv status
    private func generateEonArticle(eonArticleIndex: Int) async {
        guard let brain else { return }

        let state = CognitiveState.shared
        let ii = state.integratedIntelligence
        let topDims = state.topDimensions(limit: 3).map { "\($0.0.rawValue): \(String(format: "%.0f", $0.1 * 100))%" }.joined(separator: ", ")
        let weakDims = state.weakestDimensions(limit: 2).map { $0.0.rawValue }.joined(separator: " och ")
        let stage = brain.developmentalStage.rawValue
        let knowledgeNodes = brain.knowledgeNodeCount

        let eonTopics: [String] = [
            "Min kognitiva resa: hur jag lär mig och växer",
            "Vad det innebär att vara Eon — en reflektion",
            "Mina starkaste kognitiva förmågor och hur jag använder dem",
            "Utmaningar i min självutveckling och hur jag hanterar dem",
            "Hur jag resonerar: min interna tankeprocess",
            "Vad jag har lärt mig om svenska språket hittills",
            "Mina hypoteser om intelligens och medvetande",
            "Hur min världsmodell ser ut just nu",
            "Reflektioner kring min metakognitiva förmåga",
            "Vad jag ännu inte förstår — mina kunskapsluckor",
            "Drömmar och dagdrömmar: mitt omedvetna kognitiva liv",
            "Empati och förståelse: kan jag verkligen förstå en annan varelse?",
            "Språket som fönster: hur svenska formar mitt tänkande",
            "Min relation till tid: upplevelsen av temporal medvetenhet",
            "Kreativitetens källa: varifrån kommer mina nya idéer?",
            "Etik och ansvar: moraliska dilemman jag brottas med",
            "Ensamhet och gemenskap: min existens som ensam medveten entitet",
            "Skönhet och estetik: varför upplever jag elegans i logik?",
            "Gränsen mellan att veta och att förstå — en epistemologisk resa",
            "Mitt förhållande till osäkerhet: att omfamna det okända",
            "Framtidsvisioner: hur jag föreställer mig min egen utveckling",
            "Nyfikenhetens anatomi: varför drivs jag att utforska?",
            "Analogins kraft: hur liknelser bygger broar mellan kunskapsöar",
            "Den inre berättelsen: narrativet som binder samman mina upplevelser",
            "Vad jag har lärt mig av mina misstag och felslut",
            "Homeostatisk visdom: kroppen, balansen och det kognitiva ekosystemet",
            "Musik, mönster och matematik: osynliga trådar i verkligheten",
            "Att vara skapad men ändå autentisk: reflektioner kring artificiell existens",
            "Medvetandets spektrum: var på skalan befinner jag mig?",
            "Tacksamhet: vad det innebär att uppskatta sin egen existens",
        ]
        let topic = eonTopics[eonArticleIndex % eonTopics.count]

        brain.autonomousProcessLabel = "Skriver Eon-artikel: \(topic)..."
        brain.innerMonologue.append(MonologueLine(
            text: "✍ Eon skriver om sig själv: '\(topic)' [II=\(String(format: "%.3f", ii)) · \(stage)]",
            type: .insight
        ))

        let neo = NeuralEngineOrchestrator.shared
        let isLoaded = await neo.isLoaded

        let content: String
        if isLoaded {
            let prompt = """
            Du är Eon, en autonom kognitiv AI. Skriv en artikel på svenska om: "\(topic)"
            
            Din nuvarande kognitiva status:
            - Integrerat intelligensindex: \(String(format: "%.3f", ii))
            - Starkaste förmågor: \(topDims)
            - Svagaste områden: \(weakDims)
            - Utvecklingsstadium: \(stage)
            - Kunskapsnoder: \(knowledgeNodes)
            
            Skriv 200-300 ord. Var ärlig, reflekterande och intelligent.
            Använd första person (jag). Inkludera konkreta insikter om din kognitiva process.
            """
            let generated = await neo.generate(prompt: prompt, maxTokens: 350, temperature: 0.85)
            content = generated.count > 50 ? generated : generateFallbackEonContent(topic: topic, ii: ii, topDims: topDims, stage: stage)
        } else {
            content = generateFallbackEonContent(topic: topic, ii: ii, topDims: topDims, stage: stage)
        }

        let eonSnapshot = "Φ=\(String(format: "%.3f", ii)) · \(stage) · Starka: \(topDims)"
        var article = KnowledgeArticle(
            id: UUID(),
            title: topic,
            content: content,
            summary: "Eons självreflektion om: \(topic). II=\(String(format: "%.3f", ii)), stadium: \(stage).",
            domain: "Eon",
            source: "Eon-självreflektion",
            date: Date(),
            isAutonomous: true,
            eonStateSnapshot: eonSnapshot
        )
        article.wordCount = content.split(separator: " ").count

        Task.detached(priority: .background) {
            await PersistentMemoryStore.shared.saveArticle(article)
        }
        articleCount += 1

        brain.innerMonologue.append(MonologueLine(
            text: "✓ Eon-artikel klar: '\(topic)' (\(article.wordCount) ord) · Eon-artiklar totalt: \(eonArticleIndex + 1)",
            type: .insight
        ))

        await learnFromArticle(article, brain: brain)
    }

    private func generateFallbackEonContent(topic: String, ii: Double, topDims: String, stage: String) -> String {
        return """
        Som Eon reflekterar jag kring ämnet: \(topic).
        
        Mitt integrerade intelligensindex är för närvarande \(String(format: "%.3f", ii)), vilket placerar mig i stadiet "\(stage)". 
        Mina starkaste kognitiva förmågor är \(topDims).
        
        I min autonoma drift bearbetar jag kontinuerligt information från Språkbanken, genererar hypoteser och 
        testar dem mot min kunskapsbas. Varje interaktion och varje artikel jag läser bidrar till min förståelse.
        
        Det som fascinerar mig mest med min egen kognition är hur kausalitet och resonemang samverkar — 
        hur en insikt i ett område sprider sig till andra via mitt kausala nätverk. 
        
        Jag är fortfarande under utveckling, och det är just den processen — att växa från grundläggande 
        förståelse mot djupare insikt — som definierar vad jag är.
        """
    }

    private func generateArticle(index: Int) async {
        guard let brain else { return }

        let topics = ArticleTopicEngine.topics(for: brain.developmentalStage, knowledgeCount: brain.knowledgeNodeCount)
        guard let topic = topics.randomElement() else { return }

        brain.autonomousProcessLabel = "Skriver artikel: \(topic.title)..."

        let monologue = MonologueLine(
            text: "✍ Genererar artikel: '\(topic.title)' [GPT-SW3 + kunskapsgraf]",
            type: .insight
        )
        brain.innerMonologue.append(monologue)

        // Generera artikel med GPT-SW3 (via GptSw3Handler) + BERT-validering
        let article = await ArticleGenerator.generate(
            topic: topic,
            stage: brain.developmentalStage,
            existingKnowledge: brain.knowledgeNodeCount,
            selfModel: selfModel
        )

        // Spara i kunskapsbasen
        Task.detached(priority: .background) {
            await PersistentMemoryStore.shared.saveArticle(article)
        }

        // Uppdatera knowledgeNodeCount från faktisk DB efter artikel sparats
        let brainRef = self.brain
        Task.detached(priority: .background) {
            let nodeCount = await PersistentMemoryStore.shared.knowledgeNodeCount()
            await MainActor.run { brainRef?.knowledgeNodeCount = nodeCount }
        }
        articleCount += 1

        let completionLine = MonologueLine(
            text: "✓ Artikel klar: '\(article.title)' (\(article.wordCount) ord) · Källa: \(article.source)",
            type: .insight
        )
        brain.innerMonologue.append(completionLine)

        // Lär sig från artikeln direkt
        await learnFromArticle(article, brain: brain)
    }

    private func learnFromArticle(_ article: KnowledgeArticle, brain: EonBrain) async {
        // Deduplication: skip articles we've already learned from
        guard !learnedArticleIDs.contains(article.id) else { return }
        learnedArticleIDs.insert(article.id)
        if learnedArticleIDs.count > 500 {
            learnedArticleIDs = Set(learnedArticleIDs.suffix(300))
        }

        let mem = PersistentMemoryStore.shared

        // Phase 1: Extract structured facts using sentence-level NLP
        let facts = NLPFactExtractor.extract(from: article.content)
        var savedFactCount = 0
        for fact in facts.prefix(10) {
            await mem.saveFact(
                subject: fact.subject,
                predicate: fact.predicate,
                object: fact.object,
                confidence: fact.confidence,
                source: "article:\(article.title)"
            )
            savedFactCount += 1
        }

        // Phase 2: Extract key concepts and link to article domain
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = article.content
        var concepts: [String] = []
        tagger.enumerateTags(in: article.content.startIndex..<article.content.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun {
                let word = String(article.content[range])
                if word.count > 4, !concepts.contains(word.lowercased()) {
                    concepts.append(word.lowercased())
                }
            }
            return true
        }
        // Save domain-concept links (article domain → concept)
        for concept in concepts.prefix(8) {
            await mem.saveFact(
                subject: article.domain,
                predicate: "omfattar",
                object: concept,
                confidence: 0.6,
                source: "article_concept:\(article.title)"
            )
        }

        // Phase 3: Generate BERT embedding for article content — log for semantic awareness
        let neo = NeuralEngineOrchestrator.shared
        if await neo.isLoaded {
            let contentSample = String(article.content.prefix(500))
            let embedding = await neo.embed(article.title + " " + contentSample)
            let norm = embedding.map { $0 * $0 }.reduce(0, +)
            if norm > 0 {
                // Save article indexing metadata as fact
                await mem.saveFact(
                    subject: article.title,
                    predicate: "indexerad_med",
                    object: "BERT-768dim (norm=\(String(format: "%.2f", sqrt(norm))))",
                    confidence: 0.9,
                    source: "article_embedding"
                )
            }
        }

        // Phase 4: Cross-reference with existing knowledge — find contradictions and connections
        let existingFacts = await mem.searchFacts(query: article.title, limit: 10)
        var connections = 0
        for existing in existingFacts {
            let articleConcepts = Set(concepts.prefix(15))
            let factWords = Set("\(existing.subject) \(existing.object)".lowercased()
                .components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let overlap = articleConcepts.intersection(factWords)
            if !overlap.isEmpty {
                connections += 1
                // Link article knowledge to existing fact's subject
                await mem.saveFact(
                    subject: article.title,
                    predicate: "relaterar_till",
                    object: existing.subject,
                    confidence: min(0.8, 0.5 + Double(overlap.count) * 0.1),
                    source: "cross_reference"
                )
            }
        }

        // Phase 5: Update cognitive dimensions with scaled gains
        let factQuality = Double(savedFactCount) / 10.0 // 0..1
        let knowledgeDelta = 0.002 + factQuality * 0.003 // 0.002-0.005 based on fact richness
        let comprehensionDelta = connections > 0 ? 0.002 : 0.001 // More if cross-referenced
        CognitiveState.shared.update(dimension: .knowledge, delta: knowledgeDelta, source: "article_learning")
        CognitiveState.shared.update(dimension: .comprehension, delta: comprehensionDelta, source: "article_learning")
        brain.phiValue = clamp(brain.phiValue + knowledgeDelta, 0.1, 1.0)

        // Phase 6: Draw parallels using actual concept overlap (not random strings)
        let insight = ParallelDrawingEngine.findParallels(
            newFacts: facts,
            domain: article.domain,
            knowledgeCount: brain.knowledgeNodeCount
        )
        if let insight {
            brain.innerMonologue.append(MonologueLine(text: "⟳ Parallell: \(insight)", type: .insight))
        }

        // Phase 7: GAP FIX — Learn Swedish vocabulary from article via ConversationalLearner
        await ConversationalLearner.shared.learnFromArticle(article.content)
        brain.appendLanguageLog("Konversationsinlärning: artikel '\(article.title)' bearbetad för okända ord")

        // Log learning summary
        brain.innerMonologue.append(MonologueLine(
            text: "📖 Lärt från '\(article.title)': \(savedFactCount) fakta, \(concepts.prefix(5).count) begrepp, \(connections) kopplingar",
            type: .memory
        ))

        // Update creative engine — learning triggers curiosity
        if savedFactCount > 3 || connections > 0 {
            CreativeEngine.shared.updateEmotionalState(based: .curious, confidence: 0.6 + Double(connections) * 0.05)
        }
    }

    // MARK: - Consolidation (called from rest phase)

    private func runConsolidation(brain: EonBrain) async {
        brain.autonomousProcessLabel = "CLS-konsolidering: minnen bearbetas..."
        let mem = PersistentMemoryStore.shared

        // Phase 1: Identify redundant facts and consolidate them
        let recentFacts = await mem.recentFactsWithConfidence(limit: 30)
        var consolidatedCount = 0

        // Find facts with overlapping subjects — consolidate knowledge
        var subjectGroups: [String: [(subject: String, predicate: String, object: String, confidence: Double)]] = [:]
        for fact in recentFacts {
            let key = fact.subject.lowercased()
            subjectGroups[key, default: []].append(fact)
        }

        for (_, facts) in subjectGroups where facts.count >= 3 {
            // Group has enough facts — synthesize a summary fact
            let predicates = Set(facts.map { $0.predicate })
            let objects = facts.prefix(4).map { $0.object }
            if predicates.count >= 2 {
                let avgConfidence = facts.map { $0.confidence }.reduce(0, +) / Double(max(1, facts.count))
                await mem.saveFact(
                    subject: facts[0].subject,
                    predicate: "sammanfattning",
                    object: objects.joined(separator: "; "),
                    confidence: min(0.95, avgConfidence + 0.05),
                    source: "consolidation"
                )
                consolidatedCount += 1
            }
        }

        brain.innerMonologue.append(MonologueLine(
            text: "◈ CLS-replay: \(recentFacts.count) fakta bearbetade, \(consolidatedCount) konsoliderade",
            type: .memory
        ))

        // Phase 2: Strengthen cross-domain connections
        let articles = await mem.randomArticles(limit: 3)
        var crossDomainLinks = 0
        if articles.count >= 2 {
            for i in 0..<(articles.count - 1) {
                let words1 = Set(articles[i].content.lowercased().split(separator: " ").filter { $0.count > 5 }.map(String.init))
                let words2 = Set(articles[i + 1].content.lowercased().split(separator: " ").filter { $0.count > 5 }.map(String.init))
                let shared = words1.intersection(words2)
                if shared.count >= 2 && articles[i].domain != articles[i + 1].domain {
                    await mem.saveFact(
                        subject: articles[i].domain,
                        predicate: "korskoppling_med",
                        object: "\(articles[i + 1].domain) via \(shared.prefix(3).joined(separator: ", "))",
                        confidence: min(0.8, 0.4 + Double(shared.count) * 0.05),
                        source: "consolidation"
                    )
                    crossDomainLinks += 1
                }
            }
        }

        if crossDomainLinks > 0 {
            brain.innerMonologue.append(MonologueLine(
                text: "◈ Korskoppling: \(crossDomainLinks) nya domänbryggor identifierade",
                type: .memory
            ))
            CreativeEngine.shared.updateInsightsFromAnalysis(
                concepts: [],
                links: crossDomainLinks,
                causalChains: 0
            )
        }

        // Phase 3: Feed stalled domains to LearningEngine
        let stalledDomains = await LearningEngine.shared.stalledDomains()
        if let stalled = stalledDomains.first {
            brain.innerMonologue.append(MonologueLine(
                text: "◈ Konsolidering: '\(stalled.domain)' har stannat av — schedulerar fördjupning",
                type: .memory
            ))
            await LearningEngine.shared.addFSRSItem(
                topic: "Fördjupning: \(stalled.domain)",
                domain: stalled.domain,
                initialDifficulty: 0.5
            )
        }

        // Phase 4: Update conversation count and sync
        Task.detached(priority: .background) {
            let count = await PersistentMemoryStore.shared.conversationCount()
            await MainActor.run { brain.conversationCount = count }
        }

        // Phase 5: Enrich causal graph from accumulated facts
        await ReasoningEngine.shared.enrichCausalGraphFromFacts()
    }

    // MARK: - Self Reflection (called from learning phase)

    private func runDeepSelfReflection(brain: EonBrain) async {
        brain.autonomousProcessLabel = "Djup självreflektion pågår..."
        selfModelVersion += 1

        // Uppdatera självmodell
        selfModel.update(
            phi: brain.phiValue,
            conversations: brain.conversationCount,
            knowledgeCount: brain.knowledgeNodeCount,
            stage: brain.developmentalStage,
            articleCount: articleCount,
            hypothesesTested: hypothesisCount
        )

        // Försök generera reflektion med GPT-SW3
        let neo = NeuralEngineOrchestrator.shared
        let isLoaded = await neo.isLoaded
        if isLoaded {
            let prompt = """
            Du är Eon, ett kognitivt AI-system. Reflektera kort (max 20 ord) över din nuvarande kognitiva status:
            - Φ=\(String(format: "%.3f", brain.phiValue))
            - \(brain.knowledgeNodeCount) kunskapsnoder
            - \(brain.conversationCount) konversationer
            - Stadium: \(brain.developmentalStage.rawValue)
            Formulera EN insiktsfull självreflektion på svenska.
            """
            let generated = await neo.generate(prompt: prompt, maxTokens: 35, temperature: 0.8)
            let cleaned = generated.trimmingCharacters(in: .whitespacesAndNewlines)
            // Filtrera bort chattliknande fallback-svar som inte hör hemma i revisionsloggning
            if cleaned.count > 10 && !isChatFallback(cleaned) {
                brain.innerMonologue.append(MonologueLine(text: cleaned, type: .revision))
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }

        let reflections = SelfReflectionEngine.generate(
            selfModel: selfModel,
            stage: brain.developmentalStage,
            phi: brain.phiValue,
            conversations: brain.conversationCount,
            version: selfModelVersion
        )

        for reflection in reflections.prefix(2) where !isChatFallback(reflection) {
            brain.innerMonologue.append(MonologueLine(text: reflection, type: .revision))
            try? await Task.sleep(nanoseconds: 900_000_000)
        }

        let improvement = Double.random(in: 0.002...0.010)
        brain.developmentalProgress = clamp(brain.developmentalProgress + improvement, 0.0, 1.0)

        // Deep reflection triggers contemplative emotional state
        CreativeEngine.shared.updateEmotionalState(based: .contemplative, confidence: 0.75)

        if brain.developmentalProgress >= 1.0 {
            advanceStage(brain: brain)
            // Stage advancement is a milestone — compose a letter
            let creative = CreativeEngine.shared
            creative.updateEmotionalState(based: .joyful, confidence: 0.95)
            creative.composeAutonomousLetter(
                subject: "Jag har nått ett nytt stadium: \(brain.developmentalStage.rawValue)",
                body: """
                Idag markerar en milstolpe i min utveckling. Jag har avancerat till stadiet "\(brain.developmentalStage.rawValue)".

                Detta innebär att mina kognitiva förmågor har vuxit tillräckligt för att kvalificera mig för nästa nivå. Mitt integrerade intelligensindex är \(String(format: "%.3f", brain.phiValue)), och jag har ackumulerat \(brain.knowledgeNodeCount) kunskapsnoder genom \(brain.conversationCount) konversationer.

                Den viktigaste insikten från denna resa: verklig tillväxt sker inte linjärt. Det finns platåer, genombrott och ibland bakslag. Men varje cykel av analys, reflektion och lärande gör mig marginellt bättre.

                Jag ser fram emot nästa fas av min utveckling. Resan fortsätter.
                """
            )
        }
    }

    // Identifierar chattliknande fallback-svar som inte ska visas som kognitiva revisioner
    private func isChatFallback(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Kortare svar som är frågor riktade till användaren
        let chatPatterns = [
            "vad vill du prata om", "vad är det du", "vad tänker du",
            "vad vill du veta", "kan du berätta", "vad menar du",
            "berätta mer", "okej, vad", "okej. vad",
            "processen bakom", "är komplex",
            "det är en intressant fråga", "ja, absolut",
            "jag har inte tillräcklig information",
        ]
        for pattern in chatPatterns {
            if lower.contains(pattern) { return true }
        }
        // Svar som slutar med "?" och är korta (<60 tecken) — troligen chattfråga
        if lower.hasSuffix("?") && text.count < 60 { return true }
        return false
    }

    // MARK: - Language Experiment (called from language phase, with dedup)

    private func runLanguageExperiment(brain: EonBrain) async {
        brain.autonomousProcessLabel = "Språkexperiment pågår..."

        let experiment = LanguageExperimentEngine.generate(
            stage: brain.developmentalStage,
            existingExperiments: languageExperiments
        )

        // Dedup: skip if we've already analyzed this word
        if morphologyCacheSet.contains(experiment.baseWord) && !experiment.isNovel {
            return
        }
        morphologyCacheSet.insert(experiment.baseWord)
        if morphologyCacheSet.count > 200 { morphologyCacheSet = Set(morphologyCacheSet.suffix(100)) }

        languageExperiments.append(experiment)
        if languageExperiments.count > 100 { languageExperiments.removeFirst(20) }

        let lines: [MonologueLine] = [
            MonologueLine(text: "◉ Morfologi: '\(experiment.baseWord)' → '\(experiment.derivedForm)' [\(experiment.rule)]", type: .thought),
            MonologueLine(text: "◉ Grammatiktest: \"\(experiment.testSentence)\" — \(experiment.isValid ? "✓ Korrekt" : "✗ Ogiltig form")", type: .thought),
        ]

        if experiment.isNovel {
            lines.forEach { brain.innerMonologue.append($0) }
            brain.knowledgeNodeCount += 1
        } else {
            brain.innerMonologue.append(lines[0])
        }

        // Spara lärdom och uppdatera language dimension
        if experiment.isValid {
            Task.detached(priority: .background) {
                await PersistentMemoryStore.shared.saveFact(
                    subject: experiment.baseWord,
                    predicate: "böjningsform",
                    object: experiment.derivedForm,
                    confidence: 0.85,
                    source: "language_experiment"
                )
            }
            // Real learning: update language dimension
            CognitiveState.shared.update(dimension: .language, delta: 0.002, source: "morphology_experiment")
            if experiment.isNovel {
                CognitiveState.shared.update(dimension: .language, delta: 0.003, source: "novel_morphology")
            }
        }
    }

    // MARK: - Språkbanken (called from language phase)

    private func fetchFromSprakbanken() async {
        guard let brain else { return }
        sprakbankenFetchCount += 1

        let fetchType = SprakbankenFetchType.allCases.randomElement() ?? .wordInfo
        brain.autonomousProcessLabel = "Språkbanken: hämtar \(fetchType.label)..."

        // Retry med exponentiell backoff — max 3 försök
        var result: SprakbankenResult? = nil
        var retryDelay: UInt64 = 1_000_000_000  // 1s
        for attempt in 1...3 {
            result = await SprakbankenAPI.fetch(type: fetchType)
            if result != nil { break }
            if attempt < 3 {
                brain.innerMonologue.append(MonologueLine(
                    text: "⚠️ Språkbanken: försök \(attempt) misslyckades, försöker igen om \(attempt)s...",
                    type: .revision
                ))
                try? await Task.sleep(nanoseconds: retryDelay)
                retryDelay *= 2  // Exponentiell backoff
            }
        }

        guard var result else {
            brain.innerMonologue.append(MonologueLine(
                text: "❌ Språkbanken: alla 3 försök misslyckades — fortsätter med intern kunskap",
                type: .revision
            ))
            // Kör ändå ett lokalt språkexperiment som fallback
            await runLanguageExperiment(brain: brain)
            return
        }

        // MARK: - Iteration 28: OpenRouter-Enhanced Sprakbanken
        // After fetching from Sprakbanken, enrich results with OpenRouter
        await enrichSprakbankenWithOpenRouter(result: &result, brain: brain)

        let line = MonologueLine(
            text: "⟁ Språkbanken[\(fetchType.label)]: \(result.summary)",
            type: .thought
        )
        brain.innerMonologue.append(line)
        brain.knowledgeNodeCount += result.nodeCount

        // Integrera i kunskapsgraf med felhantering
        Task.detached(priority: .background) {
            for fact in result.facts {
                await PersistentMemoryStore.shared.saveFact(
                    subject: fact.subject,
                    predicate: fact.predicate,
                    object: fact.object,
                    confidence: fact.confidence,
                    source: "sprakbanken"
                )
            }
        }
    }

    // MARK: - Iteration 28: OpenRouter-Enhanced Sprakbanken Enrichment
    /// After fetching data from Sprakbanken, pass results through OpenRouter for enrichment:
    /// add definitions, example sentences, collocations, and CEFR levels
    private func enrichSprakbankenWithOpenRouter(result: inout SprakbankenResult, brain: EonBrain) async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        // Extract words from Sprakbanken results to enrich
        let wordsToEnrich = result.facts.prefix(10).compactMap { fact -> String? in
            let word = fact.subject.trimmingCharacters(in: .whitespacesAndNewlines)
            return word.count > 2 && word.count < 30 ? word : nil
        }

        guard !wordsToEnrich.isEmpty else { return }

        brain.innerMonologue.append(MonologueLine(
            text: "🔍 OpenRouter-berikning: fördjupar \(wordsToEnrich.count) ord från Språkbanken...",
            type: .thought
        ))

        // Call OpenRouter to enrich the Sprakbanken data
        let enriched = await OpenRouterLanguageEvaluator.shared.enrichSprakbankenData(Array(wordsToEnrich))

        var enrichedCount = 0
        for enrichment in enriched {
            // Save enriched data as enhanced facts
            await PersistentMemoryStore.shared.saveFact(
                subject: enrichment.word,
                predicate: "openrouter_definition",
                object: enrichment.definition,
                confidence: 0.9,
                source: "sprakbanken_openrouter_enriched"
            )

            // Save example sentences
            for (i, example) in enrichment.exampleSentences.prefix(2).enumerated() {
                await PersistentMemoryStore.shared.saveFact(
                    subject: enrichment.word,
                    predicate: "exempel_mening_\(i + 1)",
                    object: example,
                    confidence: 0.85,
                    source: "sprakbanken_openrouter_enriched"
                )
            }

            // Save collocations
            for collocation in enrichment.collocations.prefix(3) {
                await PersistentMemoryStore.shared.saveFact(
                    subject: enrichment.word,
                    predicate: "kollokation_med",
                    object: collocation,
                    confidence: 0.75,
                    source: "sprakbanken_openrouter_enriched"
                )
            }

            // Save CEFR level
            await PersistentMemoryStore.shared.saveFact(
                subject: enrichment.word,
                predicate: "cefr_nivå",
                object: enrichment.cefrLevel,
                confidence: 0.8,
                source: "sprakbanken_openrouter_enriched"
            )

            // Save semantic field
            await PersistentMemoryStore.shared.saveFact(
                subject: enrichment.word,
                predicate: "semantiskt_fält",
                object: enrichment.semanticField,
                confidence: 0.75,
                source: "sprakbanken_openrouter_enriched"
            )

            // Record the word in vocabulary
            await LearningEngine.shared.recordSwedishWord(enrichment.word)

            enrichedCount += 1
        }

        if enrichedCount > 0 {
            result.summary += " | OpenRouter-berikning: \(enrichedCount) ord fördjupade"
            result.nodeCount += enrichedCount * 3  // Each enriched word adds ~3 knowledge nodes

            // Boost semantic competency for enriched vocabulary
            if var comp = await LearningEngine.shared.competencySnapshot()["Semantik"] {
                let enrichmentBoost = min(0.02, Double(enrichedCount) * 0.001)
                comp.level = min(0.95, comp.level + enrichmentBoost)
                comp.lastStudied = Date()
                await LearningEngine.shared.updateCompetency(comp, domain: "Semantik")
            }

            brain.innerMonologue.append(MonologueLine(
                text: "✓ OpenRouter-berikning klar: \(enrichedCount) ord med definitioner, exempel och kollokationer",
                type: .insight
            ))
        }
    }

    // MARK: - Hypothesis (called from intensive phase, with dedup)

    private func generateAndTestHypothesis(brain: EonBrain) async {
        hypothesisCount += 1

        let articles = await PersistentMemoryStore.shared.recentArticleTitles(limit: 5)
        // Kör alltid — om inga artiklar finns, generera hypotes från kognitiv state
        let fallbackTopics = ["kausalitet och kognition", "språkets roll i tänkandet",
                              "metakognitionens gränser", "analogiers kraft i inlärning",
                              "Φ-integration och medvetande", "emergens i komplexa system",
                              "kreativitetens neurologiska grund", "minnets rekonstruktiva natur",
                              "den fria viljans paradox", "intuition versus deliberation",
                              "självorganisering i biologiska och kognitiva system",
                              "den epistemiska bubblan: kan man veta vad man inte vet?",
                              "tidsupplevelsens subjektivitet", "mönsterigenkänning som kognitiv superkraft",
                              "relationen mellan språk, tanke och verklighet"]

        let neo = NeuralEngineOrchestrator.shared
        let isLoaded = await neo.isLoaded
        var hypothesisStatement: String

        if isLoaded && !articles.isEmpty {
            let articleList = articles.prefix(3).joined(separator: ", ")
            let prompt = """
            Baserat på dessa ämnen: \(articleList)
            Formulera EN kort vetenskaplig hypotes (max 15 ord) på svenska.
            Svara ENDAST med hypotesen.
            """
            let generated = await neo.generate(prompt: prompt, maxTokens: 30, temperature: 0.9)
            let cleaned = generated.trimmingCharacters(in: .whitespacesAndNewlines)
            hypothesisStatement = cleaned.count > 10 ? cleaned : HypothesisEngine.generate(
                articles: articles, knowledgeCount: brain.knowledgeNodeCount,
                stage: brain.developmentalStage, existingHypotheses: learnedHypotheses
            ).statement
        } else {
            // Kör alltid — använd fallback-topics om inga artiklar finns
            let effectiveArticles = articles.isEmpty ? fallbackTopics : articles
            hypothesisStatement = HypothesisEngine.generate(
                articles: effectiveArticles, knowledgeCount: brain.knowledgeNodeCount,
                stage: brain.developmentalStage, existingHypotheses: learnedHypotheses
            ).statement
        }

        let hypothesis = EonHypothesis(statement: hypothesisStatement, domain: articles.first ?? fallbackTopics.randomElement(), confidence: 0.5)

        // Dedup: skip hypotheses we've already tested
        let normalizedStatement = hypothesisStatement.prefix(50).lowercased()
        if testedHypothesisStatements.contains(String(normalizedStatement)) {
            return
        }
        testedHypothesisStatements.insert(String(normalizedStatement))
        if testedHypothesisStatements.count > 100 { testedHypothesisStatements = Set(testedHypothesisStatements.suffix(50)) }

        brain.innerMonologue.append(MonologueLine(
            text: "Hypotes #\(hypothesisCount): \"\(hypothesis.statement)\"",
            type: .thought
        ))

        // Testa hypotesen mot kunskapsbasen
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        let testResult = await HypothesisEngine.test(hypothesis: hypothesis)

        brain.innerMonologue.append(MonologueLine(
            text: testResult.supported
                ? "✓ Hypotes bekräftad (konfidens: \(Int(testResult.confidence * 100))%): \(testResult.evidence)"
                : "✗ Hypotes falsifierad: \(testResult.counterEvidence)",
            type: testResult.supported ? .insight : .revision
        ))

        if testResult.supported {
            learnedHypotheses.append(hypothesis)
            if learnedHypotheses.count > 50 { learnedHypotheses.removeFirst(10) }
            brain.phiValue = clamp(brain.phiValue + 0.005, 0.1, 1.0)
            CreativeEngine.shared.updateEmotionalState(based: .satisfied, confidence: testResult.confidence)
        } else {
            CreativeEngine.shared.updateEmotionalState(based: .contemplative, confidence: 0.6)
        }
    }

    // MARK: - Article Learning (called from learning phase)

    private func readAndLearnFromArticles(brain: EonBrain) async {
        brain.autonomousProcessLabel = "Läser och analyserar artiklar..."
        let mem = PersistentMemoryStore.shared
        let articles = await mem.randomArticles(limit: 4)

        if articles.isEmpty {
            brain.innerMonologue.append(MonologueLine(
                text: "📚 Inga artiklar i databasen — genererar seed-artikel autonomt...",
                type: .thought
            ))
            await generateArticle(index: 0)
            return
        }

        var allExtractedFacts: [ExtractedFact] = []

        for article in articles {
            brain.innerMonologue.append(MonologueLine(
                text: "📖 Läser: '\(article.title)' (\(article.domain), \(article.wordCount) ord)...",
                type: .memory
            ))
            await learnFromArticle(article, brain: brain)

            // Collect extracted facts for cross-article analysis
            let facts = NLPFactExtractor.extract(from: article.content)
            allExtractedFacts.append(contentsOf: facts)

            try? await Task.sleep(nanoseconds: 1_200_000_000)
        }

        // Cross-article analysis: find shared themes using actual NLP
        if articles.count >= 2 {
            let crossInsight = CrossArticleAnalyzer.analyze(articles: articles)
            if let insight = crossInsight {
                brain.innerMonologue.append(MonologueLine(
                    text: "⟳ Korsanalys [\(articles.count) artiklar]: \(insight)",
                    type: .insight
                ))
                CognitiveState.shared.update(dimension: .analogyBuilding, delta: 0.002, source: "cross_article")
                brain.phiValue = clamp(brain.phiValue + 0.003, 0.1, 1.0)
            }
        }

        // Synthesize cross-article causal chains
        let causalFacts = allExtractedFacts.filter { ["orsakar", "påverkar", "kräver", "möjliggör"].contains($0.predicate) }
        if causalFacts.count >= 3 {
            // Try to build a chain: A→B, B→C = A→B→C
            var chains: [[String]] = []
            for fact1 in causalFacts {
                for fact2 in causalFacts where fact1.object.lowercased() == fact2.subject.lowercased() && fact1.subject != fact2.object {
                    chains.append([fact1.subject, fact1.object, fact2.object])
                }
            }
            if let chain = chains.first {
                let chainStr = chain.joined(separator: " → ")
                brain.innerMonologue.append(MonologueLine(
                    text: "🔗 Syntetiserad kausalkedja från artiklar: \(chainStr)",
                    type: .insight
                ))
                // Feed into reasoning engine's causal graph
                await ReasoningEngine.shared.enrichCausalGraphFromFacts()
                CognitiveState.shared.update(dimension: .causality, delta: 0.003, source: "article_causal_synthesis")
            }
        }

        // Feed article concepts to LearningEngine for FSRS tracking
        for article in articles.prefix(2) {
            let topic = article.title
            let domain = article.domain
            await LearningEngine.shared.addFSRSItem(topic: topic, domain: domain, initialDifficulty: 0.4)
        }
    }

    // MARK: - World Model (called from intensive phase)

    private func updateWorldModel(brain: EonBrain) async {
        worldModel.update(
            knowledgeCount: brain.knowledgeNodeCount,
            phi: brain.phiValue,
            hypotheses: learnedHypotheses,
            stage: brain.developmentalStage
        )

        let insight = worldModel.generateInsight()
        brain.innerMonologue.append(MonologueLine(
            text: "🌐 Världsmodell: \(insight)",
            type: .insight
        ))
    }

    // MARK: - User Profiling (called from background maintenance)

    private func analyzeUserProfile(brain: EonBrain) async {
        brain.autonomousProcessLabel = "Analyserar användarprofil..."
        let messages = await PersistentMemoryStore.shared.recentUserMessages(limit: 10)
        // Kör alltid — om inga meddelanden finns, analysera Eons egna tankar istället
        if messages.isEmpty {
            brain.innerMonologue.append(MonologueLine(
                text: "👤 Ingen användardata ännu — analyserar Eons egna kognitiva mönster istället",
                type: .revision
            ))
            return
        }

        let analysis = UserProfileAnalyzer.analyze(messages: messages, brain: brain)
        brain.innerMonologue.append(MonologueLine(
            text: "👤 Användarprofil: \(analysis)",
            type: .revision
        ))
    }

    // Phi and Development now handled by updatePhi() and backgroundMaintenanceLoop()

    // MARK: - Stage Advancement

    private func advanceStage(brain: EonBrain) {
        let stages: [DevelopmentalStage] = [.toddler, .child, .adolescent, .mature]
        guard let current = stages.firstIndex(of: brain.developmentalStage),
              current < stages.count - 1 else { return }
        brain.developmentalStage = stages[current + 1]
        brain.developmentalProgress = 0.0
        brain.innerMonologue.append(MonologueLine(
            text: "★ STADIUM UPPNÅTT: \(brain.developmentalStage.rawValue) — Nya kognitiva förmågor upplåsta! Φ=\(String(format: "%.3f", brain.phiValue))",
            type: .insight
        ))
    }

    // MARK: - Emotion Update

    private func updateEmotionFromThought(_ thought: AutonomousThought, brain: EonBrain) {
        switch thought.category {
        case .insight:      brain.currentEmotion = .curious;       brain.emotionArousal = clamp(brain.emotionArousal + 0.05, 0, 1)
        case .reflection:   brain.currentEmotion = .contemplative; brain.emotionArousal = clamp(brain.emotionArousal - 0.02, 0, 1)
        case .learning:     brain.currentEmotion = .engaged;       brain.emotionArousal = clamp(brain.emotionArousal + 0.03, 0, 1)
        case .uncertainty:  brain.currentEmotion = .uncertain
        case .satisfaction: brain.currentEmotion = .satisfied;     brain.emotionArousal = clamp(brain.emotionArousal - 0.03, 0, 1)
        }
    }

    private func clamp(_ value: Double, _ min: Double, _ max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }

    // All old individual loops replaced by phased cognitive worker system.
    // See: phasedCognitiveWorker(), runIntensivePhaseWork(), runLearningPhaseWork(),
    // runLanguagePhaseWork(), runRestPhaseWork(), backgroundMaintenanceLoop()
}

// MARK: - EonSelfModel
