
import NaturalLanguage

struct CrossArticleAnalyzer {
    static func analyze(articles: [KnowledgeArticle]) -> String? {
        guard articles.count >= 2 else { return nil }

        // Extract key concepts from each article using NLTagger
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        var articleConcepts: [[String]] = []
        for article in articles {
            tagger.string = article.content
            var concepts: [String] = []
            tagger.enumerateTags(in: article.content.startIndex..<article.content.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
                if tag == .noun {
                    let word = String(article.content[range]).lowercased()
                    if word.count > 4 && !concepts.contains(word) { concepts.append(word) }
                }
                return true
            }
            articleConcepts.append(concepts)
        }

        // Find shared concepts between articles
        guard articleConcepts.count >= 2 else { return nil }
        let shared = Set(articleConcepts[0]).intersection(Set(articleConcepts[1]))
        let sharedConcepts = shared.filter { $0.count > 4 }.prefix(5)

        if sharedConcepts.count >= 2 {
            let conceptStr = sharedConcepts.joined(separator: ", ")
            // Check if domains differ — cross-domain insight is more valuable
            if articles[0].domain != articles[1].domain {
                return "Domänöverföring: '\(articles[0].title)' och '\(articles[1].title)' delar begrepp (\(conceptStr)) — \(articles[0].domain) ↔ \(articles[1].domain) konvergens"
            } else {
                return "Tematisk koherens i \(articles[0].domain): gemensamma begrepp (\(conceptStr)) bekräftar domänkunskap"
            }
        }

        // If no direct concept overlap, check domain relationship
        let domains = Set(articles.map { $0.domain })
        if domains.count > 1 {
            return "Mångdomänperspektiv: \(domains.joined(separator: " + ")) — breddad förståelse utan direkt begreppsöverlapp"
        }

        return nil
    }
}

// MARK: - Language Experiment Engine
