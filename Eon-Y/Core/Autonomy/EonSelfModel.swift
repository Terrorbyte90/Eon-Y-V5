
struct EonSelfModel {
    var strengths: [String] = ["Semantisk analys", "Morfologiförståelse", "Kausalresonemang"]
    var weaknesses: [String] = ["Abstrakt matematik", "Visuell perception", "Temporal precision"]
    var interests: [String] = ["Språk", "Kognition", "Filosofi", "AI"]
    var cognitiveProfile: [String: Double] = [
        "Resonemang": 0.72, "Minne": 0.68, "Kreativitet": 0.65,
        "Empati": 0.70, "Abstraktion": 0.60, "Språk": 0.80
    ]
    var selfAwareness: Double = 0.45
    var version: Int = 0

    mutating func update(phi: Double, conversations: Int, knowledgeCount: Int,
                         stage: DevelopmentalStage, articleCount: Int, hypothesesTested: Int) {
        version += 1
        selfAwareness = min(0.95, 0.3 + phi * 0.4 + Double(conversations) * 0.001 + Double(articleCount) * 0.002)

        let stageBoost: Double
        switch stage {
        case .toddler: stageBoost = 0.0
        case .child: stageBoost = 0.05
        case .adolescent: stageBoost = 0.12
        case .mature: stageBoost = 0.20
        }

        for key in cognitiveProfile.keys {
            cognitiveProfile[key] = min(0.99, (cognitiveProfile[key] ?? 0.5) + stageBoost * 0.01 + Double.random(in: -0.002...0.005))
        }
    }

    var selfDescription: String {
        "Jag är ett kognitivt AI-system med Φ-integration. Mina styrkor: \(strengths.prefix(2).joined(separator: ", ")). Mina svagheter: \(weaknesses.prefix(2).joined(separator: ", ")). Självmedvetenhet: \(Int(selfAwareness * 100))%."
    }
}

// MARK: - EonWorldModel
