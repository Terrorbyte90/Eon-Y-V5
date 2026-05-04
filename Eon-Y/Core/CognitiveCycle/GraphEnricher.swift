
import Foundation

actor GraphEnricher {
    /// v8: Enriched fact extraction patterns for Swedish text — 19 patterns
    private static let factPatterns: [(pattern: String, predicate: String, confidence: Double)] = [
        // "X är Y" — basic identity/classification
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+är\\s+((?:en|ett|den|det)?\\s*[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "är", 0.65),
        // "X har Y" — possession/attribute
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+)\\s+har\\s+((?:en|ett)?\\s*[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "har", 0.60),
        // "X kallas Y" — naming/alias
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+kallas\\s+(?:för\\s+)?([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "kallas", 0.70),
        // "X orsakar Y" / "X leder till Y" — causality
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:orsakar|leder\\s+till)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "orsakar", 0.55),
        // "X består av Y" — composition
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+består\\s+av\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "består_av", 0.60),
        // "X tillhör Y" — membership
        ("([\\wåäöÅÄÖ]+)\\s+tillhör\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "tillhör", 0.60),
        // "X påverkar Y" — influence
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+påverkar\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "påverkar", 0.55),
        // v7: "X grundades Y" — founding/creation
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+grundades\\s+(\\d{4}|av\\s+[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "grundades", 0.70),
        // v7: "X innehåller Y" — containment
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+innehåller\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "innehåller", 0.60),
        // v7: "X kräver Y" — requirement
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+kräver\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "kräver", 0.55),
        // v7: "X möjliggör Y" — enablement
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+möjliggör\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "möjliggör", 0.55),
        // v7: "X liknar Y" — similarity
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+liknar\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "liknar", 0.50),
        // v7: "X skiljer sig från Y" — difference
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+skiljer\\s+sig\\s+från\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "skiljer_sig_från", 0.55),
        // v7: "X uppfanns av Y" / "X utvecklades av Y" — invention/development
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:uppfanns|utvecklades|skapades)\\s+av\\s+([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "skapades_av", 0.65),
        // v7: "X ligger i Y" / "X finns i Y" — location
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:ligger|finns|befinner sig)\\s+i\\s+([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "finns_i", 0.60),
        // v8: "X förhindrar Y" / "X motverkar Y" — prevention
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:förhindrar|motverkar|hindrar)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "förhindrar", 0.55),
        // v8: "X leder till Y" — consequence (separate from orsakar)
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+leder\\s+till\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "leder_till", 0.55),
        // v8: "X används för Y" / "X används inom Y" — usage
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+används\\s+(?:för|inom|till)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "används_för", 0.55),
        // v8: "X definieras som Y" — definition
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+definieras\\s+som\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,4})", "definieras_som", 0.65),
    ]

    func enrich(text: String, entities: [ExtractedEntity], memory: PersistentMemoryStore) async {
        // 1. Entity mentions — link entities to conversation context
        for entity in entities where entity.text.count > 2 {
            await memory.saveFact(
                subject: entity.text,
                predicate: "nämndes_i",
                object: "konversation_\(Date().timeIntervalSince1970)",
                confidence: entity.confidence,
                source: "generation"
            )
        }

        // 2. Multi-pattern fact extraction
        let range = NSRange(text.startIndex..., in: text)
        for (patternStr, predicate, confidence) in Self.factPatterns {
            guard let regex = try? NSRegularExpression(pattern: patternStr, options: .caseInsensitive) else { continue }
            let matches = regex.matches(in: text, range: range)
            for match in matches.prefix(3) { // Limit per pattern to avoid spam
                guard let subjectRange = Range(match.range(at: 1), in: text),
                      let objectRange = Range(match.range(at: 2), in: text) else { continue }
                let subject = String(text[subjectRange]).trimmingCharacters(in: .whitespaces)
                let object = String(text[objectRange]).trimmingCharacters(in: .whitespaces)
                // Skip trivially short or stopword-only matches
                guard subject.count > 2, object.count > 2 else { continue }
                await memory.saveFact(
                    subject: subject,
                    predicate: predicate,
                    object: object,
                    confidence: confidence,
                    source: "generation"
                )
            }
        }

        // 3. Entity co-occurrence — if two entities appear in the same sentence, link them
        if entities.count >= 2 {
            let sentences = text.components(separatedBy: ". ")
            for sentence in sentences {
                let sentenceEntities = entities.filter { sentence.contains($0.text) }
                if sentenceEntities.count >= 2 {
                    let a = sentenceEntities[0]
                    let b = sentenceEntities[1]
                    await memory.saveFact(
                        subject: a.text,
                        predicate: "relaterar_till",
                        object: b.text,
                        confidence: min(a.confidence, b.confidence) * 0.8,
                        source: "co_occurrence"
                    )
                }
            }
        }
    }
}

// MARK: - MetacognitiveReviser (Loop 3)
