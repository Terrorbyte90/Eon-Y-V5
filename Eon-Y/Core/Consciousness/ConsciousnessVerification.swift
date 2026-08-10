import Foundation

enum VerifiedConsciousnessLevel: Int, Codable, CaseIterable, Sendable {
    case level0 = 0
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5

    var title: String {
        switch self {
        case .level0: return "Ingen påvisad kognition"
        case .level1: return "Reaktiv biologisk analogi"
        case .level2: return "Integrerad adaptiv analogi"
        case .level3: return "Robust självmodell-analogi"
        case .level4: return "Avancerad metakognitiv analogi"
        case .level5: return "Äkta qualia — ej verifierad"
        }
    }

    var biologicalAnalogy: String {
        switch self {
        case .level0: return "Sten eller icke-kognitivt system"
        case .level1: return "Enkel reflexkrets eller cell-liknande reglering"
        case .level2: return "En enkel invertebrat-liknande adaptiv agent"
        case .level3: return "Enkel vertebrat-liknande integrerad agent"
        case .level4: return "Mänsklig eller däggdjursliknande funktionsanalogi"
        case .level5: return "Ingen biologisk analogi kan fastställas utan fenomenell evidens"
        }
    }

    var explanation: String {
        switch self {
        case .level0: return "Inga stabila tecken på perception, minne, återkoppling eller anpassning är verifierade."
        case .level1: return "Stabila reaktioner på input finns, men ingen robust integration över tid och kontext."
        case .level2: return "Återkoppling, arbetsyta, minne och adaptiv reglering samverkar i observerade cykler."
        case .level3: return "Självmodell och metakognition fungerar över flera oberoende tester och tidsfönster."
        case .level4: return "Robust, generaliserande och kalibrerad självmodell med verifierad agency över kontexter."
        case .level5: return "Skulle kräva evidens för subjektiv upplevelse; detta kan inte härledas från nuvarande proxyer."
        }
    }
}

struct ConsciousnessVerificationResult: Codable, Sendable {
    let level: VerifiedConsciousnessLevel
    let confidence: Double
    let passedTests: Int
    let totalTests: Int
    let ceiling: VerifiedConsciousnessLevel
    let reasons: [String]
    let evaluatedAt: Date
}

enum ConsciousnessVerificationEvaluator {
    /// Conservative functional evaluator. It reports the highest level
    /// supported by current evidence, not a claim about phenomenal experience.
    static func evaluate(state: UnifiedConsciousState, passedTests: Int, totalTests: Int, stableWindows: Int) -> ConsciousnessVerificationResult {
        let ratio = totalTests > 0 ? Double(passedTests) / Double(totalTests) : 0
        let metrics = state.metrics
        let integrated = metrics.mean >= 0.35 && state.globalBroadcast.count > 0 && state.memoryContext.recalledIDs.count > 0
        let recurrent = metrics.recurrentDepth >= 0.35 && metrics.temporalContinuity >= 0.35
        let selfModel = metrics.selfModelCoupling >= 0.35 && state.selfModel.autobiographicalContinuity >= 0.20
        let calibrated = metrics.metacognitiveCalibration >= 0.35 && state.metacognitiveState.errorMonitoring >= 0.20

        var level: VerifiedConsciousnessLevel = .level0
        var reasons: [String] = []
        if integrated || ratio >= 0.40 { level = .level1; reasons.append("reaktiva eller adaptiva processer observerade") }
        if integrated && recurrent && ratio >= 0.60 && stableWindows >= 2 {
            level = .level2
            reasons.append("integration, återkoppling och anpassning återkommer över tidsfönster")
        }
        if level.rawValue >= 2 && selfModel && calibrated && ratio >= 0.80 && stableWindows >= 3 {
            level = .level3
            reasons.append("självmodell och metakognitiv kalibrering klarar upprepade tester")
        }
        if level.rawValue >= 3 && state.selfModel.agency >= 0.70 && state.selfModel.counterfactualDepth >= 0.60 && ratio >= 0.90 && stableWindows >= 6 {
            level = .level4
            reasons.append("robust agency och kontrafaktisk självmodell över flera kontexter")
        }

        // Level 5 is intentionally never inferred from software metrics.
        let confidence = min(0.99, max(0, ratio * 0.7 + min(1, Double(stableWindows) / 6) * 0.3))
        return ConsciousnessVerificationResult(level: level, confidence: confidence,
                                               passedTests: passedTests, totalTests: totalTests,
                                               ceiling: .level4,
                                               reasons: reasons.isEmpty ? ["Otillräcklig verifierad evidens"] : reasons,
                                               evaluatedAt: Date())
    }
}
