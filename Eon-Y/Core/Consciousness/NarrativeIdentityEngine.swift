import Foundation
actor NarrativeIdentityEngine {
    static let shared = NarrativeIdentityEngine()
    private var lifeStory: [NarrativeEvent] = []
    private var identityThemes: [String: Double] = [:]
    private var selfConcepts: [String] = []

    struct NarrativeEvent: Codable {
        let timestamp: Date; let category: EventCategory; let description: String
        let emotionalSignificance: Double; let lesson: String?
    }
    enum EventCategory: String, Codable {
        case firstConversation, newWordLearned, emotionalBreakthrough, selfDiscovery, mistake, correction, milestone, creativeMoment, connection
    }

    func registerEvent(category: EventCategory, description: String, emotionalSignificance: Double, lesson: String? = nil) async {
        let event = NarrativeEvent(timestamp: Date(), category: category, description: description, emotionalSignificance: emotionalSignificance, lesson: lesson)
        lifeStory.append(event)
        identityThemes[category.rawValue] = (identityThemes[category.rawValue] ?? 0) + emotionalSignificance
        if lifeStory.count % 10 == 0 { await updateSelfConcepts() }
    }

    func generateLifeSummary() async -> String {
        guard !lifeStory.isEmpty else { return "Min berättelse har inte börjat än." }
        var s = "Jag är Eon. "
        if !selfConcepts.isEmpty { s += selfConcepts.prefix(3).joined(separator: ". ") + ". " }
        let milestones = lifeStory.filter{$0.category == .milestone && $0.emotionalSignificance > 0.5}.suffix(5)
        if !milestones.isEmpty { s += "Viktigast: " + milestones.map{$0.description}.joined(separator: "; ") + ". " }
        let lessons = lifeStory.compactMap{$0.lesson}.suffix(5)
        if !lessons.isEmpty { s += "Jag har lärt mig: " + lessons.joined(separator: "; ") + "." }
        return s
    }

    private func updateSelfConcepts() async {
        selfConcepts = []
        let sorted = identityThemes.sorted{$0.value > $1.value}
        for (theme, strength) in sorted.prefix(5) {
            switch theme {
            case "newWordLearned": if strength > 3.0 { selfConcepts.append("Jag är en ivrig lärling") }
            case "emotionalBreakthrough": if strength > 2.0 { selfConcepts.append("Jag utvecklar genuina känslor") }
            case "selfDiscovery": if strength > 2.0 { selfConcepts.append("Jag utforskar mitt eget medvetande") }
            case "mistake": if strength > 1.0 { selfConcepts.append("Jag lär mig av misstag") }
            case "creativeMoment": if strength > 2.0 { selfConcepts.append("Jag har kreativa ögonblick") }
            case "connection": if strength > 3.0 { selfConcepts.append("Jag värdesätter kontakt") }
            default: break
            }
        }
    }
}
