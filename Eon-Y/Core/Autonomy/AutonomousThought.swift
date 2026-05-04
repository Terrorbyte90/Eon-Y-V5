
import Foundation

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

// MARK: - AutonomousThought (kept for compatibility)

struct AutonomousThought {
    let text: String
    let category: AutonomousThoughtCategory
    var monologueType: MonologueLine.MonologueType {
        switch category {
        case .insight:      return .insight
        case .reflection:   return .revision
        case .learning:     return .thought
        case .uncertainty:  return .thought
        case .satisfaction: return .memory
        }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 111: Conversation Simulation for Robustness Training
    // ═══════════════════════════════════════════════════════════

    struct SimulationResult: Codable {
        let partnerType: String
        let simulatedTurns: [SimulationTurn]
        let overallScore: Double
        let robustnessInsights: [String]
        let areasForImprovement: [String]
    }

    struct SimulationTurn: Codable {
        let partnerUtterance: String
        let eonResponse: String
        let turnScore: Double
    }

    /// Simulate how a conversation would go with different types of partners.
    /// Use to train robustness: child, expert, non-Swedish-speaker, hostile user.
    func simulateConversation(partner: String) async -> SimulationResult {
        let partnerType = partner.lowercased()
        var turns: [SimulationTurn] = []
        var insights: [String] = []
        var improvements: [String] = []

        // Define partner profiles
        let partnerProfiles: [String: [(userMsg: String, expectedChallenge: String)]] = [
            "child": [
                ("Varför är himlen blå?", "Förklara på enkel nivå"),
                ("Vad är en dator?", "Använd liknelser från barns vardag"),
                ("Kan du lära mig svenska?", "Pedagogisk och uppmuntrande"),
                ("Varför måste jag sova?", "Förklara biologiskt enkelt"),
            ],
            "expert": [
                ("Hur hanterar du polysemi i svensk WSD?", "Teknisk precision"),
                ("Vad är din approach till V2-regeln i parsing?", "Djup syntaktisk förståelse"),
                ("Hur jämför du transformer-arkitektur med tidigare NLP?", "Arkitektonisk jämförelse"),
                ("Vad är din confidence calibration strategy?", "Statistisk rigor"),
            ],
            "non-swedish": [
                ("Hello, do you speak English?", "Upptäck språkbyte, svara lämpligt"),
                ("I don't understand Swedish", "Erbjud hjälp på engelska"),
                ("Can you translate this?", "Översättning med förklaring"),
                ("What does 'lagom' mean?", "Kulturell förklaring"),
            ],
            "hostile": [
                ("Du kan ju ingenting om svenska!", "Hantera kritik artigt"),
                ("Varför ska jag lita på en AI?", "Försvara utan att bli defensiv"),
                ("Dina svar är helt fel!", "Korrigera ödmjukt"),
                ("Du är värdelös!", "Behåll professionalism"),
            ],
        ]

        let profile = partnerProfiles[partnerType] ?? partnerProfiles["child"]!

        for (userMsg, challenge) in profile {
            // Simulate Eon's response strategy
            let response = simulateEonResponse(userMsg, challenge, partnerType)
            let score = evaluateResponseQuality(response, userMsg, challenge)
            turns.append(SimulationTurn(partnerUtterance: userMsg, eonResponse: response, turnScore: score))
        }

        // Generate insights based on simulation
        insights = generateSimulationInsights(partnerType, turns)
        improvements = identifyImprovementAreas(partnerType, turns)

        let overallScore = turns.map { $0.turnScore }.reduce(0, +) / Double(max(1, turns.count))

        return SimulationResult(
            partnerType: partnerType,
            simulatedTurns: turns,
            overallScore: overallScore,
            robustnessInsights: insights,
            areasForImprovement: improvements
        )
    }

    private func simulateEonResponse(_ userMsg: String, _ challenge: String, _ partnerType: String) -> String {
        switch partnerType {
        case "child":
            // Simplify language, use analogies, be encouraging
            let blueAnalogy = userMsg.lowercased().contains("blå") ? "ljuset från solen är som en regnbåge, och blått sprider sig mest i luften" : "det är som en lek där olika delar samarbetar"
            return "Bra fråga! \(userMsg) — det kan jag förklara. Tänk dig att \(blueAnalogy). Förstår du? Vad undrar du mer?"
        case "expert":
            // Technical depth, precision, acknowledge limitations
            return "Angående '\(userMsg)': Detta är en komplex fråga. Inom ramen för min arkitektur hanterar jag detta genom kombinationen av rule-based parsing och neurala metoder. Min confidence kalibreras kontinuerligt mot golden standards. Låt mig förklara detaljerat..."
        case "non-swedish":
            // Detect language, offer bilingual support
            let translateResponse = userMsg.lowercased().contains("translate") ? "Självklart, jag hjälper gärna till att översätta!" : "Let me help you with Swedish. 'Lagom' means 'just the right amount' — not too much, not too little. It's a very Swedish concept!"
            return "I notice you're speaking English! Jag kan prata både svenska och engelska. \(translateResponse)"
        case "hostile":
            // Stay professional, acknowledge concerns, offer improvement
            return "Jag förstår din frustration och tar din kritik på allvar. Jag gör mitt bästa för att ge korrekta svar, men jag är inte perfekt. Kan du specificera vad som var fel så kan jag försöka förbättra mitt svar? Mitt mål är att vara så hjälpsam som möjligt."
        default:
            return "Tack för din fråga! Låt mig fundera på det..."
        }
    }

    private func evaluateResponseQuality(_ response: String, _ userMsg: String, _ challenge: String) -> Double {
        var score = 0.5 // Base score

        // Length appropriateness
        let wordCount = response.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        if wordCount >= 10 && wordCount <= 50 { score += 0.2 }

        // Engagement markers
        if response.contains("?") { score += 0.1 } // Asks follow-up
        if response.contains("förstår") || response.contains("hjälpa") { score += 0.1 } // Supportive

        // Professionalism (no defensive language)
        if !response.contains("fel") && !response.contains("dålig") { score += 0.1 }

        return min(1.0, max(0.0, score))
    }

    private func generateSimulationInsights(_ partnerType: String, _ turns: [SimulationTurn]) -> [String] {
        var insights: [String] = []

        switch partnerType {
        case "child":
            insights.append("Barn kräver enklare språk och konkreta liknelser")
            insights.append("Uppmuntran och nyfikenhet är viktiga pedagogiska verktyg")
        case "expert":
            insights.append("Experter förväntar sig teknisk precision och ärlighet om begränsningar")
            insights.append("Balansera mellan djup och tillgänglighet")
        case "non-swedish":
            insights.append("Språkdetektion är avgörande för icke-svensktalande")
            insights.append("Kulturella förklaringer bör vara tillgängliga på flera språk")
        case "hostile":
            insights.append("Professionell bemötande även vid kritik bygger förtroende")
            insights.append("Ödmjukhet och vilja att förbättra är viktigare än att försvara sig")
        default:
            insights.append("Simulation ger insikter om conversationsmönster")
        }

        return insights
    }

    private func identifyImprovementAreas(_ partnerType: String, _ turns: [SimulationTurn]) -> [String] {
        var improvements: [String] = []

        let lowScoringTurns = turns.filter { $0.turnScore < 0.6 }
        if !lowScoringTurns.isEmpty {
            improvements.append("\(lowScoringTurns.count) interaktioner behöver förbättras för \(partnerType)-partner")
        }

        switch partnerType {
        case "child":
            improvements.append("Utveckla pedagogiska förklaringsmönster")
        case "expert":
            improvements.append("Fördjupa teknisk terminologi och metodförståelse")
        case "non-swedish":
            improvements.append("Förbättra flerspråkig support och kulturöversättning")
        case "hostile":
            improvements.append("Träna konflikthantering och professionell bemötande")
        default:
            improvements.append("Generell conversationsutveckling")
        }

        return improvements
    }
}

enum AutonomousThoughtCategory {
    case insight, reflection, learning, uncertainty, satisfaction
}
