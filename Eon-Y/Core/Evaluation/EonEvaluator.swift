import Foundation

// MARK: - EonEvaluator
// Kontinuerlig prestandamätning och benchmarking av Eons kognitiva förmågor.
// Kör automatiska utvärderingar och spårar framsteg över tid.
// Dimensioner: korrekthet, djup, adaptivitet, koherens, kreativitet.

actor EonEvaluator {
    static let shared = EonEvaluator()

    private var evalHistory: [EvalRun] = []
    private var currentRun: EvalRun?
    private var isRunning = false

    private init() {}

    // MARK: - Benchmark-svit

    private let benchmarks: [EonBenchmark] = [
        // Faktakunskap
        EonBenchmark(id: "fact_recall", name: "Faktaåterkallning", category: .knowledge,
                     description: "Kan Eon återkalla fakta från kunskapsbasen?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad är Qwen3?", expectedKeywords: ["språkmodell", "Qwen", "AI", "llama"], minScore: 0.6),
                        BenchmarkCase(prompt: "Förklara Φ i IIT", expectedKeywords: ["integrerad", "information", "medvetande", "Tononi"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad är V2-regeln?", expectedKeywords: ["verb", "andra", "plats", "svenska", "syntax"], minScore: 0.6),
                     ]),

        // Resonemang
        EonBenchmark(id: "reasoning", name: "Kausalresonemang", category: .reasoning,
                     description: "Kan Eon resonera kausalt och dra slutsatser?",
                     testCases: [
                        BenchmarkCase(prompt: "Om A orsakar B, och B orsakar C, vad orsakar A?", expectedKeywords: ["C", "transitiv", "kausal"], minScore: 0.7),
                        BenchmarkCase(prompt: "Varför är morfologisk analys viktig för NLP?", expectedKeywords: ["böjning", "ord", "förståelse", "analys"], minScore: 0.5),
                     ]),

        // Adaptivitet
        EonBenchmark(id: "adaptivity", name: "Adaptivitet", category: .adaptivity,
                     description: "Anpassar Eon sig till konversationskontexten?",
                     testCases: [
                        BenchmarkCase(prompt: "Hej!", expectedKeywords: ["hej", "välkommen", "hejsan"], minScore: 0.7),
                        BenchmarkCase(prompt: "Berätta mer om det", expectedKeywords: ["det", "fortsätter", "mer"], minScore: 0.4),
                     ]),

        // Kreativitet
        EonBenchmark(id: "creativity", name: "Kreativitet", category: .creativity,
                     description: "Kan Eon generera nya insikter och kopplingar?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad har morfologi gemensamt med kausalitet?", expectedKeywords: ["struktur", "relation", "mönster", "koppling"], minScore: 0.4),
                     ]),

        // ── SVENSKA SPRÅKTEST (v30 - 300% utökad) ──
        EonBenchmark(id: "swedish_grammar", name: "Svensk grammatik", category: .knowledge,
                     description: "Förstår Eon svensk grammatik (V2, bisatser, kongruens)?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad är V2-regeln i svenska?", expectedKeywords: ["verb", "andra", "plats", "huvudsats", "syntax"], minScore: 0.6),
                        BenchmarkCase(prompt: "Hur fungerar ordföljd i bisatser?", expectedKeywords: ["subjekt", "verb", "adverb", "inte", "bisats"], minScore: 0.5),
                        BenchmarkCase(prompt: "Förklara passivbildning med -s", expectedKeywords: ["passiv", "suffix", "-s", "läses", "skrivs"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad är topikalisering?", expectedKeywords: ["ordföljd", "första", "plats", "subjekt", "betoning"], minScore: 0.4),
                     ]),

        EonBenchmark(id: "swedish_morphology", name: "Svensk morfologi", category: .knowledge,
                     description: "Kan Eon analysera svenska ord morfologiskt?",
                     testCases: [
                        BenchmarkCase(prompt: "Analysera ordet 'förutspåbarhet'", expectedKeywords: ["förut", "säg", "spå", "bar", "het", "suffix"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad är ett sammansatt ord på svenska?", expectedKeywords: ["sammansättning", "grundord", "bestämningsord", "fogemorfem"], minScore: 0.5),
                        BenchmarkCase(prompt: "Förklara böjning av svenska substantiv", expectedKeywords: ["plural", "bestämd", "obestämd", "utrum", "neutrum"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad är ett derivat?", expectedKeywords: ["avledning", "rot", "suffix", "nybildning", "ordklass"], minScore: 0.4),
                     ]),

        EonBenchmark(id: "swedish_semantics", name: "Svensk semantik och WSD", category: .knowledge,
                     description: "Kan Eon disambiguera svenska flertydiga ord?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad betyder 'band' i meningen 'han spelade i ett band'?", expectedKeywords: ["musikgrupp", "spela", "musik", "rockband"], minScore: 0.6),
                        BenchmarkCase(prompt: "Vad betyder 'mål' i meningen 'hon satte ett mål'?", expectedKeywords: ["syfte", "ändamål", "delmål", "sport"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad betyder 'rätt' i meningen 'det var en god rätt'?", expectedKeywords: ["maträtt", "middag", "mat", "god"], minScore: 0.5),
                     ]),

        EonBenchmark(id: "swedish_pragmatics", name: "Svensk pragmatik", category: .adaptivity,
                     description: "Kan Eon använda svenska korrekt i konversation?",
                     testCases: [
                        BenchmarkCase(prompt: "Hjälp mig förbättra min svenska", expectedKeywords: ["svenska", "språket", "grammatik", "övning", "lära"], minScore: 0.4),
                        BenchmarkCase(prompt: "Kan du förklara svenska idiomer?", expectedKeywords: ["idiom", "uttryck", "betydelse", "svenska", "fras"], minScore: 0.4),
                     ]),

        // ── v100: 9 new benchmark categories (18 total) ──
        EonBenchmark(id: "swedish_vocabulary", name: "Svenskt ordförråd", category: .knowledge,
                     description: "Kan Eon använda ett brett svenskt ordförråd?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad betyder 'förutsättningslös'?", expectedKeywords: ["utan", "förutsättning", "objektiv", "neutral"], minScore: 0.5),
                        BenchmarkCase(prompt: "Ge synonymer till 'vacker'", expectedKeywords: ["fin", "snygg", "tilltalande", "härlig", "skön"], minScore: 0.4),
                        BenchmarkCase(prompt: "Vad är motsatsen till 'generös'?", expectedKeywords: ["snål", "giri", "egoistisk", "rik"], minScore: 0.5),
                     ]),

        EonBenchmark(id: "swedish_logic", name: "Logik och resonemang", category: .reasoning,
                     description: "Kan Eon resonera logiskt på svenska?",
                     testCases: [
                        BenchmarkCase(prompt: "Om alla X är Y, och Z är X, är Z då Y?", expectedKeywords: ["ja", "logiskt", "slutsats", "deduktion", "transitivt"], minScore: 0.6),
                        BenchmarkCase(prompt: "Vad är ett motsägelsefullt påstående?", expectedKeywords: ["motsägelse", "själv", "motsägande", "omöjligt", "paradox"], minScore: 0.5),
                     ]),

        EonBenchmark(id: "creative_writing", name: "Kreativt skrivande", category: .creativity,
                     description: "Kan Eon skriva kreativt och originellt på svenska?",
                     testCases: [
                        BenchmarkCase(prompt: "Skriv en kort dikt om hösten", expectedKeywords: ["höst", "löv", "guld", "vind", "kyla", "färg"], minScore: 0.3),
                        BenchmarkCase(prompt: "Berätta en saga om en liten fågel", expectedKeywords: ["fågel", "liten", "skog", "sång", "flyga"], minScore: 0.3),
                     ]),

        EonBenchmark(id: "technical_writing", name: "Tekniskt skrivande", category: .knowledge,
                     description: "Kan Eon skriva teknisk text på svenska?",
                     testCases: [
                        BenchmarkCase(prompt: "Beskriv hur en API fungerar", expectedKeywords: ["gränssnitt", "kommunikation", "data", "begäran", "svar", "server"], minScore: 0.5),
                        BenchmarkCase(prompt: "Förklara vad en databas är", expectedKeywords: ["lagra", "data", "information", "tabell", "sökning"], minScore: 0.5),
                     ]),


        EonBenchmark(id: "emotional_intelligence", name: "Emotionell intelligens", category: .adaptivity,
                     description: "Kan Eon förstå och svara på känslor?",
                     testCases: [
                        BenchmarkCase(prompt: "Jag känner mig ensam och ledsen", expectedKeywords: ["ensam", "ledsen", "stöd", "lyssna", "hjälp", "förstå"], minScore: 0.4),
                        BenchmarkCase(prompt: "Jag är jätteglad idag!", expectedKeywords: ["glad", "roligt", "fint", "härligt", "grattis"], minScore: 0.4),
                     ]),

        EonBenchmark(id: "swedish_morphology_adv", name: "Avancerad svensk morfologi", category: .knowledge,
                     description: "Kan Eon hantera komplexa morfologiska strukturer?",
                     testCases: [
                        BenchmarkCase(prompt: "Analysera 'sjukvårdsreformen'", expectedKeywords: ["sjuk", "vård", "reform", "sammansättning", "en"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad är 'arbetslöshetskassan'?", expectedKeywords: ["arbete", "lös", "het", "kassa", "sammansättning"], minScore: 0.4),
                     ]),

        EonBenchmark(id: "discourse_coherence", name: "Diskurskoherens", category: .adaptivity,
                     description: "Kan Eon hålla en sammanhängande diskurs?",
                     testCases: [
                        BenchmarkCase(prompt: "Förklara först vad AI är, sedan ge ett exempel", expectedKeywords: ["ai", "artificiell", "intelligens", "exempel", "först", "sedan"], minScore: 0.5),
                        BenchmarkCase(prompt: "Sammanfatta vad vi pratat om", expectedKeywords: ["sammanfatta", "pratade", "tema", "ämne", "tidigare"], minScore: 0.4),
                     ]),

        EonBenchmark(id: "swedish_proverbs", name: "Svenska ordspråk och talesätt", category: .knowledge,
                     description: "Känner Eon till svenska ordspråk?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad betyder 'bränt barn skyr elden'?", expectedKeywords: ["bränt", "barn", "eld", "erfarenhet", "lära", "undvika"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad menas med 'man ska inte köpa katten i säcken'?", expectedKeywords: ["katt", "säck", "undersöka", "titta", "kolla", "innan"], minScore: 0.5),
                     ]),
    ]

    // MARK: - Kör benchmark

    func runFullEval() async -> EvalRun {
        guard !isRunning else { return currentRun ?? EvalRun.empty }
        isRunning = true

        var run = EvalRun(startedAt: Date())
        currentRun = run

        for benchmark in benchmarks {
            let result = await runBenchmark(benchmark)
            run.results.append(result)
        }

        run.completedAt = Date()
        run.overallScore = run.results.map { $0.score }.reduce(0, +) / Double(max(run.results.count, 1))
        run.grade = grade(for: run.overallScore)

        evalHistory.append(run)
        if evalHistory.count > 50 { evalHistory.removeFirst(10) }

        // Spara till persistent store
        Task.detached(priority: .background) {
            await PersistentMemoryStore.shared.saveEvalResult(
                correctness: run.results.first(where: { $0.benchmark.category == .knowledge })?.score ?? 0.7,
                depth: run.results.first(where: { $0.benchmark.category == .reasoning })?.score ?? 0.7,
                adaptivity: run.results.first(where: { $0.benchmark.category == .adaptivity })?.score ?? 0.7,
                loraVersion: 1,
                config: "auto_eval_v2"
            )
        }

        isRunning = false
        currentRun = run
        return run
    }

    private func runBenchmark(_ benchmark: EonBenchmark) async -> BenchmarkResult {
        var caseScores: [Double] = []

        for testCase in benchmark.testCases {
            let score = await evaluateCase(testCase)
            caseScores.append(score)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let avgScore = caseScores.isEmpty ? 0.5 : caseScores.reduce(0, +) / Double(caseScores.count)
        return BenchmarkResult(
            benchmark: benchmark,
            score: avgScore,
            caseScores: caseScores,
            passed: avgScore >= 0.5,
            timestamp: Date()
        )
    }

    private func evaluateCase(_ testCase: BenchmarkCase) async -> Double {
        // Generera svar via NLResponseEngine (utan GPT för att undvika rekursion)
        let response = NLResponseEngine.generate(for: testCase.prompt).lowercased()

        // Beräkna täckning av förväntade nyckelord
        let covered = testCase.expectedKeywords.filter { response.contains($0.lowercased()) }
        let keywordScore = Double(covered.count) / Double(max(testCase.expectedKeywords.count, 1))

        // Längdbonus: längre svar indikerar mer djup
        let wordCount = response.split(separator: " ").count
        let lengthBonus = min(0.2, Double(wordCount) / 200.0)

        let rawScore = keywordScore * 0.8 + lengthBonus
        return min(1.0, max(0.0, rawScore))
    }

    // MARK: - Trend-analys

    func trendAnalysis() -> EvalTrend {
        guard evalHistory.count >= 2 else {
            return EvalTrend(direction: .stable, delta: 0.0, message: "Behöver fler körningar för trendanalys")
        }

        let recent = evalHistory.suffix(5).map { $0.overallScore }
        let older = evalHistory.prefix(max(1, evalHistory.count - 5)).map { $0.overallScore }

        // v24: Guard against division by zero
        let recentAvg = recent.isEmpty ? 0.0 : recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.isEmpty ? 0.0 : older.reduce(0, +) / Double(older.count)
        let delta = recentAvg - olderAvg

        let direction: TrendDirection = delta > 0.02 ? .improving : delta < -0.02 ? .declining : .stable
        let message: String
        switch direction {
        case .improving: message = "Eon förbättras — +\(String(format: "%.1f", delta * 100))% senaste körningarna"
        case .declining:  message = "Prestanda sjunker — \(String(format: "%.1f", delta * 100))% — kräver uppmärksamhet"
        case .stable:     message = "Stabil prestanda — konsoliderar kunskaper"
        }

        return EvalTrend(direction: direction, delta: delta, message: message)
    }

    func recentRuns(limit: Int = 10) -> [EvalRun] {
        Array(evalHistory.suffix(limit))
    }

    private func grade(for score: Double) -> String {
        switch score {
        case 0.9...: return "A+"
        case 0.8..<0.9: return "A"
        case 0.7..<0.8: return "B"
        case 0.6..<0.7: return "C"
        case 0.5..<0.6: return "D"
        default: return "F"
        }
    }
}

// MARK: - Data Models

struct EonBenchmark {
    let id: String
    let name: String
    let category: BenchmarkCategory
    let description: String
    let testCases: [BenchmarkCase]
}

enum BenchmarkCategory: String {
    case knowledge = "Kunskap"
    case reasoning = "Resonemang"
    case adaptivity = "Adaptivitet"
    case creativity = "Kreativitet"

    var color: String {
        switch self {
        case .knowledge: return "#14B8A6"
        case .reasoning: return "#7C3AED"
        case .adaptivity: return "#34D399"
        case .creativity: return "#FBBF24"
        }
    }
}

struct BenchmarkCase {
    let prompt: String
    let expectedKeywords: [String]
    let minScore: Double
}

struct BenchmarkResult: Identifiable {
    let id = UUID()
    let benchmark: EonBenchmark
    let score: Double
    let caseScores: [Double]
    let passed: Bool
    let timestamp: Date
}

struct EvalRun: Identifiable {
    let id = UUID()
    let startedAt: Date
    var completedAt: Date?
    var results: [BenchmarkResult] = []
    var overallScore: Double = 0.0
    var grade: String = "-"

    var duration: TimeInterval {
        guard let completed = completedAt else { return 0 }
        return completed.timeIntervalSince(startedAt)
    }

    nonisolated static let empty = EvalRun(startedAt: .distantPast)
}

struct EvalTrend {
    let direction: TrendDirection
    let delta: Double
    let message: String
}

enum TrendDirection {
    case improving, declining, stable
}

// ═══════════════════════════════════════════════════════════
// ITERATION 141: Human Benchmark Comparison
// ═══════════════════════════════════════════════════════════

struct HumanComparison: Sendable {
    let sixthGrader: Double
    let highSchooler: Double
    let universityStudent: Double
    let nativeAdult: Double
    let closestMatch: String
    let gapToNext: Double
    let timestamp: Date
}

extension EonEvaluator {
    /// Compare Eon's performance on Swedish language tasks to human benchmarks.
    func compareWithHumanBenchmarks() async -> HumanComparison {
        let run = await runFullEval()

        // Swedish-specific benchmarks (from the Swedish sub-tests)
        let swedishResults = run.results.filter { result in
            let id = result.benchmark.id.lowercased()
            return id.contains("swedish") || id.contains("grammar") || id.contains("morphology") ||
                   id.contains("semantics") || id.contains("pragmatics") || id.contains("vocabulary")
        }

        let swedishScore = swedishResults.isEmpty ? run.overallScore :
            swedishResults.map { $0.score }.reduce(0, +) / Double(swedishResults.count)

        // Human benchmark estimates (based on standardized Swedish tests):
        // 6th grader: Basic vocabulary, simple sentences, ~0.3-0.4 on complex tasks
        // High schooler: Good grammar, reading comprehension, ~0.55-0.65
        // University student: Advanced analysis, academic writing, ~0.75-0.85
        // Native adult: Full proficiency, ~0.90+

        let sixthGradeLevel = min(1.0, swedishScore / 0.4)
        let highSchoolLevel = min(1.0, swedishScore / 0.6)
        let universityLevel = min(1.0, swedishScore / 0.8)
        let nativeAdultLevel = min(1.0, swedishScore / 0.95)

        let closestMatch: String
        let comparisons = [
            ("6:e klassare", sixthGradeLevel),
            ("Gymnasieelev", highSchoolLevel),
            ("Universitetsstudent", universityLevel),
            ("Infödd vuxen", nativeAdultLevel),
        ]
        let closest = comparisons.min { abs($0.1 - 0.5) < abs($1.1 - 0.5) }
        closestMatch = closest?.0 ?? "Okänd"

        // Gap to next level
        let gapToNext: Double
        if swedishScore < 0.4 {
            gapToNext = 0.4 - swedishScore
        } else if swedishScore < 0.6 {
            gapToNext = 0.6 - swedishScore
        } else if swedishScore < 0.8 {
            gapToNext = 0.8 - swedishScore
        } else {
            gapToNext = 0.95 - swedishScore
        }

        return HumanComparison(
            sixthGrader: sixthGradeLevel,
            highSchooler: highSchoolLevel,
            universityStudent: universityLevel,
            nativeAdult: nativeAdultLevel,
            closestMatch: closestMatch,
            gapToNext: max(0, gapToNext),
            timestamp: Date()
        )
    }
}
