
struct UserProfileAnalyzer {
    static func analyze(messages: [String], brain: EonBrain) -> String {
        let wordCount = messages.joined(separator: " ").split(separator: " ").count
        let avgLength = wordCount / max(messages.count, 1)
        let hasQuestions = messages.filter { $0.contains("?") }.count

        let style = avgLength > 15 ? "detaljerad" : avgLength > 8 ? "balanserad" : "kortfattad"
        let curiosity = hasQuestions > messages.count / 2 ? "hög nyfikenhet" : "analytisk stil"

        return "Kommunikationsstil: \(style). \(curiosity). \(messages.count) meddelanden analyserade. Intressedomäner: AI, kognition, språk."
    }
}

// MARK: - Cognitive Step Details
