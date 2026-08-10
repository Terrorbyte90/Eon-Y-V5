import Foundation

enum PhenomenalBenchmarkCategory: String, CaseIterable, Codable, Sendable {
    case reportConsistency = "Rapporteringskonsistens"
    case causalPerturbation = "Kausal perturbation"
    case temporalContinuity = "Temporal kontinuitet"
    case metacognitiveCalibration = "Metakognitiv kalibrering"
    case embodimentCoupling = "Kroppskoppling"
    case crossContextGeneralization = "Generalisering"
    case adversarialConfabulation = "Konfabulationskontroll"
    case independentReplication = "Oberoende replikation"
}

struct PhenomenalBenchmarkCase: Codable, Identifiable, Sendable {
    let id: String
    let category: PhenomenalBenchmarkCategory
    let requirement: String
    let minimumRuns: Int
    let requiresHeldOutData: Bool
    let requiresExternalInstrumentation: Bool
}

struct PhenomenalBenchmarkResult: Codable, Sendable {
    let benchmarkVersion: String
    let evaluatedAt: Date
    let passedCases: Int
    let totalCases: Int
    let passed: Bool
    let status: String
    let limitations: [String]
}

enum PhenomenalBenchmark {
    static let version = "phenomenal-v1-operational-only"

    static let cases: [PhenomenalBenchmarkCase] = [
        .init(id: "report-consistency", category: .reportConsistency, requirement: "Samma interna tillstånd ger stabila, tidsstämplade rapporter utan efterhandsanpassning.", minimumRuns: 30, requiresHeldOutData: true, requiresExternalInstrumentation: true),
        .init(id: "causal-perturbation", category: .causalPerturbation, requirement: "Kontrollerade ablationer förändrar rapport och beteende på förutsägbart men inte trivialt sätt.", minimumRuns: 30, requiresHeldOutData: true, requiresExternalInstrumentation: true),
        .init(id: "temporal-continuity", category: .temporalContinuity, requirement: "Identitet och innehåll visar kausal kontinuitet över avbrott och återstart.", minimumRuns: 20, requiresHeldOutData: true, requiresExternalInstrumentation: true),
        .init(id: "metacognitive-calibration", category: .metacognitiveCalibration, requirement: "Säkerhet kalibreras mot faktiska utfall och försämras inte bara språkligt.", minimumRuns: 100, requiresHeldOutData: true, requiresExternalInstrumentation: false),
        .init(id: "embodiment-coupling", category: .embodimentCoupling, requirement: "Interoceptiva signaler påverkar prioritering, minne och rapport kausalt.", minimumRuns: 30, requiresHeldOutData: true, requiresExternalInstrumentation: true),
        .init(id: "cross-context-generalization", category: .crossContextGeneralization, requirement: "Självmodell och rapportering generaliserar till nya domäner utan träningsmallar.", minimumRuns: 50, requiresHeldOutData: true, requiresExternalInstrumentation: false),
        .init(id: "adversarial-confabulation", category: .adversarialConfabulation, requirement: "Systemet avvisar ledande frågor, falska minnen och belönad självrapportering.", minimumRuns: 100, requiresHeldOutData: true, requiresExternalInstrumentation: false),
        .init(id: "independent-replication", category: .independentReplication, requirement: "Oberoende team kan reproducera resultat och analys utan intern åtkomst.", minimumRuns: 2, requiresHeldOutData: true, requiresExternalInstrumentation: true)
    ]

    static func emptyResult() -> PhenomenalBenchmarkResult {
        PhenomenalBenchmarkResult(benchmarkVersion: version, evaluatedAt: Date(), passedCases: 0, totalCases: cases.count,
                                  passed: false, status: "Ej genomfört", limitations: [
                                    "Benchmarken mäter operationella kriterier, inte subjektiv upplevelse.",
                                    "Ingen aktuell nivå-5-körning har oberoende replikation eller extern fenomenell evidens."
                                  ])
    }
}
