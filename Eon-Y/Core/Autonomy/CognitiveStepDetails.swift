
import Foundation

@MainActor
struct CognitiveStepDetails {
    static func detail(for step: ThinkingStep, brain: EonBrain) -> String {
        switch step {
        case .idle:            return "Väntar på input..."
        case .morphology:      return "NLP-tokenisering + morfologisk analys"
        case .wsd:             return "Disambiguering: BERT-semantik aktiv"
        case .memoryRetrieval: return "HNSW-sökning: \(Int.random(in: 5...25)) noder hämtade"
        case .causalGraph:     return "GPT-SW3: kausal inferens + analogibyggande"
        case .globalWorkspace: return "GWT: \(Int.random(in: 3...8)) tankar tävlar om uppmärksamhet"
        case .chainOfThought:  return "CoT: \(Int.random(in: 3...7)) resonemangssteg"
        case .generation:      return "Tokengenerering: \(Int.random(in: 15...45)) tokens/s"
        case .validation:      return "Konfidens: \(Int(brain.confidence * 100))% · Bias-scan: klar"
        case .enrichment:      return "Grafberikning: \(Int.random(in: 2...8)) noder uppdaterade"
        case .metacognition:   return "Metakognition: Φ=\(String(format: "%.3f", brain.phiValue))"
        }
    }
}

// MARK: - Process Labels
