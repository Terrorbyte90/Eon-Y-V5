
import Foundation

struct EonHypothesis: Identifiable {
    let id = UUID()
    let statement: String
    let domain: String?
    let confidence: Double
    let generatedAt: Date = Date()
}

// MARK: - Deep Thought Engine (GPT-SW3 driven)
