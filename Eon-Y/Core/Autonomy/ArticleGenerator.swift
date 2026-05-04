
import Foundation

struct ArticleGenerator {
    static func generate(
        topic: ArticleTopic,
        stage: DevelopmentalStage,
        existingKnowledge: Int,
        selfModel: EonSelfModel
    ) async -> KnowledgeArticle {

        // Försök generera med GPT-SW3 / FoundationModels
        let neo = NeuralEngineOrchestrator.shared
        let isLoaded = await neo.isLoaded

        var content: String
        if isLoaded {
            let prompt = buildGenerationPrompt(topic: topic, stage: stage, knowledge: existingKnowledge)
            let generated = await neo.generate(prompt: prompt, maxTokens: 400, temperature: 0.75)
            let cleaned = generated.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count > 100 {
                content = "## \(topic.title)\n\n\(topic.summary)\n\n\(cleaned)\n\n**Källa:** \(topic.source) · Eon-Y · \(Date().formatted(date: .abbreviated, time: .omitted))"
            } else {
                content = buildStaticContent(topic: topic, stage: stage, knowledge: existingKnowledge)
            }
        } else {
            content = buildStaticContent(topic: topic, stage: stage, knowledge: existingKnowledge)
        }

        let wordCount = content.split(separator: " ").count

        var article = KnowledgeArticle(
            title: topic.title,
            content: content,
            summary: topic.summary,
            domain: topic.domain,
            source: topic.source,
            date: Date(),
            isAutonomous: true
        )
        article.wordCount = wordCount
        article.generatedAt = Date()
        return article
    }

    private static func buildGenerationPrompt(topic: ArticleTopic, stage: DevelopmentalStage, knowledge: Int) -> String {
        let depth = stage == .mature ? "avancerad akademisk" : stage == .adolescent ? "analytisk" : "pedagogisk"
        return """
        Skriv en \(depth) artikel på svenska om: \(topic.title)
        
        Sammanfattning: \(topic.summary)
        
        Täck dessa aspekter:
        \(topic.sections.map { "- \($0.heading): \($0.content.prefix(100))" }.joined(separator: "\n"))
        
        Avsluta med: \(topic.conclusion)
        
        Skriv 200-300 ord. Välstrukturerat, faktabaserat, intelligent.
        """
    }

    private static func buildStaticContent(topic: ArticleTopic, stage: DevelopmentalStage, knowledge: Int) -> String {
        let depth = stage == .mature ? "djup" : stage == .adolescent ? "medel" : "grundläggande"
        let intro = "## \(topic.title)\n\n\(topic.summary)\n\n"
        let body = topic.sections.map { section in
            "### \(section.heading)\n\n\(section.content)\n\n"
        }.joined()
        let conclusion = "### Slutsats\n\nBaserat på \(knowledge) kunskapsnoder och \(depth) analys: \(topic.conclusion)\n\n"
        let sources = "**Källor:** \(topic.source) · Genererad autonomt av Eon-Y · \(Date().formatted(date: .abbreviated, time: .omitted))"
        return intro + body + conclusion + sources
    }
}

// MARK: - Article Topic Engine
