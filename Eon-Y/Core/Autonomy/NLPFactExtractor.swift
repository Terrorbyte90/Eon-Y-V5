
import Foundation
import NaturalLanguage

struct ExtractedFact {
    let subject: String
    let predicate: String
    let object: String
    let confidence: Double
}

struct NLPFactExtractor {
    /// Swedish predicate patterns for sentence-level fact extraction
    private static let predicatePatterns: [(regex: String, predicate: String, confidence: Double)] = [
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+är\\s+((?:en|ett|den|det|)\\s*[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "är", 0.75),
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+har\\s+((?:en|ett|)\\s*[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "har", 0.68),
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+(?:orsakar|leder\\s+till|ger\\s+upphov\\s+till)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "orsakar", 0.65),
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+(?:påverkar|förändrar|styr)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "påverkar", 0.62),
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+kallas\\s+(?:för\\s+)?([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "kallas", 0.72),
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+(?:består\\s+av|innehåller)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "består_av", 0.68),
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+(?:kräver|förutsätter|behöver)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "kräver", 0.64),
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+(?:möjliggör|underlättar)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "möjliggör", 0.62),
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})\\s+(?:tillhör|ingår\\s+i)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "tillhör", 0.66),
    ]

    static func extract(from text: String) -> [ExtractedFact] {
        var facts: [ExtractedFact] = []
        var seenTriples = Set<String>()

        // Strategy 1: Sentence-level regex extraction (high quality)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 10 }

        for sentence in sentences {
            let range = NSRange(sentence.startIndex..., in: sentence)
            for (pattern, predicate, confidence) in predicatePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
                let matches = regex.matches(in: sentence, range: range)
                for match in matches.prefix(2) {
                    guard let subjRange = Range(match.range(at: 1), in: sentence),
                          let objRange = Range(match.range(at: 2), in: sentence) else { continue }
                    let subject = String(sentence[subjRange]).trimmingCharacters(in: .whitespaces)
                    let object = String(sentence[objRange]).trimmingCharacters(in: .whitespaces)
                    guard subject.count > 2, object.count > 2, subject != object else { continue }

                    let key = "\(subject.lowercased())|\(predicate)|\(object.lowercased())"
                    guard !seenTriples.contains(key) else { continue }
                    seenTriples.insert(key)

                    facts.append(ExtractedFact(
                        subject: subject,
                        predicate: predicate,
                        object: object,
                        confidence: confidence
                    ))
                }
            }
        }

        // Strategy 2: NLTagger-based concept co-occurrence (for sentences without pattern matches)
        if facts.count < 3 {
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            for sentence in sentences.prefix(10) where sentence.count > 20 {
                tagger.string = sentence
                var sentenceNouns: [String] = []
                tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
                    if tag == .noun {
                        let word = String(sentence[range])
                        if word.count > 3 { sentenceNouns.append(word) }
                    }
                    return true
                }
                // Co-occurring nouns in same sentence → "relaterar_till"
                let unique = Array(Set(sentenceNouns))
                if unique.count >= 2 {
                    let key = "\(unique[0].lowercased())|relaterar_till|\(unique[1].lowercased())"
                    if !seenTriples.contains(key) {
                        seenTriples.insert(key)
                        facts.append(ExtractedFact(
                            subject: unique[0],
                            predicate: "relaterar_till",
                            object: unique[1],
                            confidence: 0.55
                        ))
                    }
                }
                if facts.count >= 12 { break }
            }
        }

        // Sort by confidence, return top results
        return Array(facts.sorted { $0.confidence > $1.confidence }.prefix(12))
    }
}

// MARK: - Parallel Drawing Engine
