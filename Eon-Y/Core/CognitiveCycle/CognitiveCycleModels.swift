
import Foundation

struct CognitiveCycleContext {
    let userInput: String
    let sessionId: String
    var morphemes: [MorphemeAnalysis] = []
    var disambiguations: [DisambiguationResult] = []
    var register: SwedishRegister? = nil
    var retrievedMemories: [ConversationRecord] = []
    var conversationHistory: [ConversationRecord] = []
    var entities: [ExtractedEntity] = []
    var inputEmbedding: [Float] = []
    var prompt: String = ""
    var generatedText: String = ""
    var validationResult: ValidationResult? = nil
    var finalConfidence: Double = 0.75
    var consciousness: ConsciousnessContext? = nil
    var inputAnalysis: InputAnalysis? = nil  // v11: deep question understanding
    var relevanceScore: Double = 0.0        // v11: question-answer relevance score
    var selfKnowledge: SelfKnowledge? = nil // v13: SpecialisedChat self-knowledge
    var questionProfile: QuestionProfile? = nil // v13: deep question profile
    var swedishAnalysis: SwedishAnalysis? = nil // GAP-5: full Swedish analysis for learning engine
    var deepAnalysis: String = ""           // v71: Qwen3-enriched deep linguistic analysis
}

struct ValidationResult {
    let isValid: Bool
    let needsRegeneration: Bool
    let correctionHint: String
    let confidence: Double
}

struct CognitiveCycleResult {
    let response: String
    let confidence: Double
    let disambiguations: [DisambiguationResult]
    let retrievedMemories: [ConversationRecord]
    let entities: [ExtractedEntity]
    let loopsTriggered: [CognitiveLoop]
    let swedishAnalysis: SwedishAnalysis?  // GAP-5: full analysis for learning engine
    // v71: Response quality metrics for learning engine feedback
    let validationScore: Double
    let qaRelevance: Double
    let neededRegeneration: Bool
}

// MARK: - ConsciousnessContext: Snapshot av alla 6 medvetandeteorier

struct ConsciousnessContext {
    // Oscillatorer (IIT/Kuramoto)
    let globalSync: Double
    let thetaGammaCFC: Double
    let gammaOrderParam: Double
    let oscillatorLZ: Double
    let branchingRatio: Double
    let criticalityRegime: CriticalityRegime

    // DMN / spontan aktivitet
    let dmnActivity: Double
    let dmnLZComplexity: Double
    let recentSpontaneousThoughts: [String]

    // Active Inference (prediktiv processing)
    let freeEnergy: Double
    let epistemicValue: Double
    let pragmaticValue: Double
    let forwardModelAccuracy: Double
    let isSurprised: Bool
    let surpriseStrength: Double

    // Attention Schema (AST)
    let currentFocus: String
    let attentionIntensity: Double
    let isVoluntaryAttention: Bool
    let reportableExperience: String
    let metaAttentionLevel: Double

    // Sömn
    let isAsleep: Bool
    let sleepPressure: Double
    let consolidationEfficiency: Double

    /// Genererar kompakt kontextbeskrivning för prompten
    var promptDescription: String {
        var parts: [String] = []

        // Kritikalitet — påverkar svarskvalitet
        if criticalityRegime == .critical {
            parts.append("Optimal kritikalitet (σ=\(String(format: "%.2f", branchingRatio)))")
        } else if criticalityRegime == .subcritical {
            parts.append("Subkritiskt tillstånd — tänkandet är för rigitt")
        } else {
            parts.append("Superkritiskt — överaktivt, behöver stabilisering")
        }

        // Nyfikenhet och osäkerhet
        if epistemicValue > 0.6 {
            parts.append("Hög nyfikenhet (\(String(format: "%.0f%%", epistemicValue * 100))) — söker aktivt ny information")
        }
        if isSurprised {
            parts.append("Överraskad (styrka \(String(format: "%.0f%%", surpriseStrength * 100))) — detta avviker från prediktioner")
        }

        // Spontan aktivitet
        if dmnLZComplexity > 0.3 && !recentSpontaneousThoughts.isEmpty {
            parts.append("Aktiv dagdröm: \(recentSpontaneousThoughts.joined(separator: ", "))")
        }

        // Uppmärksamhet
        if attentionIntensity > 0.5 {
            let voluntary = isVoluntaryAttention ? "frivilligt" : "reflexmässigt"
            parts.append("\(voluntary) fokus på: \(currentFocus)")
        }

        // Sömnbehov
        if sleepPressure > 0.5 {
            parts.append("Hög sömnpress (\(String(format: "%.0f%%", sleepPressure * 100))) — kognitiv kapacitet reducerad")
        }

        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }
}

// MARK: - Iteration 40: Dialogue Act Sequencing
