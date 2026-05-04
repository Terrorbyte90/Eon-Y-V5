
import Foundation

extension LearningEngine {
    struct KnowledgeGraph {
        let entities: [KGEntity]
        let relations: [KGRelation]
        let properties: [KGProperty]
        let newRelations: Int
        let allBoost: Double
    }

    struct KGEntity: Identifiable, Codable {
        let id = UUID()
        let name: String
        let entityType: EntityType
        let confidence: Double

        enum EntityType: String, Codable { case person, place, organization, concept, event, object, unknown }
    }

    struct KGRelation: Identifiable, Codable {
        let id = UUID()
        let source: String
        let relationType: RelationType
        let target: String
        let confidence: Double

        enum RelationType: String, Codable {
            case isA = "är-en"
            case hasA = "har-en"
            case partOf = "del-av"
            case causes = "orsakar"
            case locatedIn = "placerad-i"
            case createdBy = "skapad-av"
            case relatedTo = "relaterad-till"
            case influences = "påverkar"
            case usedFor = "används-för"
        }
    }

    struct KGProperty: Identifiable, Codable {
        let id = UUID()
        let entity: String
        let property: String
        let value: String
        let confidence: Double
    }

    // Swedish patterns for entity and relation extraction
    private static let personIndicators: Set<String> = ["han", "hon", "hen", "mannen", "kvinnan", "personen", "pojken", "flickan", "läraren", "doktorn", "chefen", "vännen", "brodern", " systern", "fadern", "modern"]
    private static let organizationIndicators: Set<String> = ["AB", "aktiebolag", "organisation", "företag", "myndighet", "regeringen", "kommunen", "partiet", "föreningen", "universitet", "skola", "byrå", "institut", "bolag", "koncern"]
    private static let placeIndicators: Set<String> = ["i Sverige", "i Stockholm", "i Göteborg", "i Malmö", "i Europa", "i världen", "staden", "landet", "platsen", "området", "regionen", "kommunen", "bygden", "orten"]

    // Relation extraction patterns
    private static let isAPatterns: [(String, String)] = [
        ("(är|var|blev) (en|ett|den|det) ", "isA"),
        ("kallas? (för|en|ett)", "isA"),
        ("definieras? som", "isA"),
        ("betecknas? som", "isA"),
        ("klassificeras? som", "isA"),
        ("typ av", "isA"),
        ("sorts", "isA"),
        ("slag av", "isA"),
    ]

    private static let partOfPatterns: [(String, String)] = [
        ("(är|var|utgör) (en|ett|del) (av|i)", "partOf"),
        ("ingår? i", "partOf"),
        ("tillhör?", "partOf"),
        ("består av", "partOf"),
        ("ingår som del", "partOf"),
        ("är en del", "partOf"),
        ("utgör en del", "partOf"),
    ]

    private static let causePatterns: [(String, String)] = [
        ("(orsakar?|leda till|resulterar?|medför|skapar?|genererar?|framkallar?|utlöser?)", "causes"),
        ("(påverkar?|inverkar?|har effekt på)", "influences"),
        ("(bidrar till|gör att)", "causes"),
        ("(beror på|orsakas av|följd av)", "causes"),
    ]

    private static let locatedInPatterns: [(String, String)] = [
        ("(ligger|finns|är belägen|är placerad|är lokaliserad) (i|på|vid|utanför)", "locatedIn"),
        ("(i|på|vid) (Stockholm|Göteborg|Malmö|Sverige|Norge|Danmark|Europa|Asien|Amerika|London|Paris|Berlin|New York)", "locatedIn"),
    ]

    private static let createdByPatterns: [(String, String)] = [
        ("(skapad|skapades|skapat|skapade) (av|utav|från)", "createdBy"),
        ("(skapad|skapat|utvecklad|utvecklat|konstruerad|konstruerat|byggd|byggt|designad|designat) av", "createdBy"),
        ("(av|från) (författaren|konstnären|skaparen|utvecklaren|designern|arkitekten)", "createdBy"),
    ]

    private static let usedForPatterns: [(String, String)] = [
        ("(används?|brukar?|utnyttjas?) (för|till|som)", "usedFor"),
        ("(syftar till|syftar på|avsedd för|menad för|tänkt för)", "usedFor"),
        ("(tjänar som|fungerar som|fungerar för|används som)", "usedFor"),
    ]

    func extractKnowledgeGraph(text: String) -> KnowledgeGraph {
        let lower = text.lowercased()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 5 }
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])

        var entities: [KGEntity] = []
        var relations: [KGRelation] = []
        var properties: [KGProperty] = []
        var newRelations = 0

        for sentence in sentences {
            let sl = sentence.lowercased()
            let words = sl.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }

            // ── Entity extraction ──
            tagger.string = sentence
            tagger.setLanguage(.swedish, range: sentence.startIndex..<sentence.endIndex)

            // Named entities via NLTagger
            tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
                if tag != nil {
                    let name = String(sentence[range])
                    if name.count > 1 && !entities.contains(where: { $0.name == name }) {
                        let type: KGEntity.EntityType
                        if tag?.rawValue.contains("PersonName") == true { type = .person }
                        else if tag?.rawValue.contains("PlaceName") == true { type = .place }
                        else if tag?.rawValue.contains("OrganizationName") == true { type = .organization }
                        else { type = .unknown }
                        entities.append(KGEntity(name: name, entityType: type, confidence: 0.7))
                    }
                }
                return true
            }

            // Detect capitalized words as potential entities
            for word in words where word.first?.isUppercase == true && word.count > 2 {
                if !entities.contains(where: { $0.name == word }) {
                    // Heuristic: check if it looks like a person, org, or place
                    let nextWordIdx = words.firstIndex(of: word).map { $0 + 1 }
                    let nextWord = nextWordIdx != nil && nextWordIdx! < words.count ? words[nextWordIdx!] : ""

                    if Self.organizationIndicators.contains(word) || nextWord.hasSuffix("AB") || nextWord.hasSuffix("ab") {
                        entities.append(KGEntity(name: word, entityType: .organization, confidence: 0.5))
                    } else if Self.placeIndicators.contains(where: { sl.contains($0) }) {
                        entities.append(KGEntity(name: word, entityType: .place, confidence: 0.5))
                    } else {
                        entities.append(KGEntity(name: word, entityType: .concept, confidence: 0.4))
                    }
                }
            }

            // ── Relation extraction ──
            // is-A relations
            for (pattern, relType) in Self.isAPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let beforeMatch = sl[..<range.lowerBound]
                    let afterMatch = sl[range.upperBound...]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let source = beforeWords.last(where: { $0.first?.isUppercase == true || $0.count > 3 }),
                       let target = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: source, relationType: .isA, target: target, confidence: 0.6))
                    }
                }
            }

            // Part-of relations
            for (pattern, _) in Self.partOfPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let beforeMatch = sl[..<range.lowerBound]
                    let afterMatch = sl[range.upperBound...]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let source = beforeWords.last(where: { $0.count > 2 }), let target = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: source, relationType: .partOf, target: target, confidence: 0.6))
                    }
                }
            }

            // Cause relations
            for (pattern, relType) in Self.causePatterns {
                if sl.contains(pattern) {
                    // Extract subject and object around the cause verb
                    if let verbIdx = words.firstIndex(where: { $0.hasPrefix(pattern.prefix(4)) }),
                       verbIdx > 0 && verbIdx + 1 < words.count {
                        let subject = words[verbIdx - 1]
                        let object = words[verbIdx + 1]
                        let relT: KGRelation.RelationType = relType == "causes" ? .causes : .influences
                        relations.append(KGRelation(source: subject, relationType: relT, target: object, confidence: 0.55))
                    }
                }
            }

            // Located-in relations
            for (pattern, _) in Self.locatedInPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let afterMatch = sl[range.upperBound...]
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let beforeMatch = sl[..<range.lowerBound]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let entity = beforeWords.last(where: { $0.count > 2 || $0.first?.isUppercase == true }),
                       let location = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: entity, relationType: .locatedIn, target: location, confidence: 0.65))
                    }
                }
            }

            // Created-by relations
            for (pattern, _) in Self.createdByPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let afterMatch = sl[range.upperBound...]
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let beforeMatch = sl[..<range.lowerBound]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let created = beforeWords.last(where: { $0.count > 2 || $0.first?.isUppercase == true }),
                       let creator = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: created, relationType: .createdBy, target: creator, confidence: 0.65))
                    }
                }
            }

            // Used-for relations
            for (pattern, _) in Self.usedForPatterns {
                if let range = sl.range(of: pattern, options: .regularExpression) {
                    let beforeMatch = sl[..<range.lowerBound]
                    let afterMatch = sl[range.upperBound...]
                    let beforeWords = String(beforeMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    let afterWords = String(afterMatch).components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                    if let entity = beforeWords.last(where: { $0.count > 2 }),
                       let purpose = afterWords.first(where: { $0.count > 2 }) {
                        relations.append(KGRelation(source: entity, relationType: .usedFor, target: purpose, confidence: 0.6))
                    }
                }
            }

            // Property extraction: "X är Y" → property
            for (i, word) in words.enumerated() where word == "är" || word == "var" {
                if i >= 1 && i + 1 < words.count {
                    let entity = words[i - 1]
                    let value = words[i + 1]
                    if entity.count > 2 && value.count > 2 && value.first?.isLowercase == true {
                        properties.append(KGProperty(entity: entity, property: word, value: value, confidence: 0.5))
                    }
                }
            }
        }

        // Deduplicate relations
        var seenRelations: Set<String> = []
        var uniqueRelations: [KGRelation] = []
        for rel in relations {
            let key = "\(rel.source)-\(rel.relationType.rawValue)-\(rel.target)"
            if !seenRelations.contains(key) {
                seenRelations.insert(key)
                uniqueRelations.append(rel)
                newRelations += 1
            }
        }

        // Boost all cognitive dimensions by 0.002 per new relation
        let allBoost = min(0.02, Double(newRelations) * 0.002)

        // Save to PersistentMemoryStore as structured knowledge
        if newRelations > 0 {
            Task.detached(priority: .utility) {
                for rel in uniqueRelations {
                    await PersistentMemoryStore.shared.saveFact(
                        subject: rel.source,
                        predicate: rel.relationType.rawValue,
                        object: rel.target,
                        confidence: rel.confidence,
                        source: "knowledge_graph_extraction"
                    )
                }
                for prop in properties.prefix(10) {
                    await PersistentMemoryStore.shared.saveFact(
                        subject: prop.entity,
                        predicate: prop.property,
                        object: prop.value,
                        confidence: prop.confidence,
                        source: "knowledge_graph_property"
                    )
                }
                for entity in entities {
                    await PersistentMemoryStore.shared.saveFact(
                        subject: entity.name,
                        predicate: "är_typ_av",
                        object: entity.entityType.rawValue,
                        confidence: entity.confidence,
                        source: "knowledge_graph_entity"
                    )
                }
            }
        }

        return KnowledgeGraph(entities: entities, relations: uniqueRelations, properties: properties, newRelations: newRelations, allBoost: allBoost)
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 106: Knowledge Graph Builder with Graph Metrics
    // ═══════════════════════════════════════════════════════════

    struct KnowledgeGraphMetrics: Sendable {
        let entityCount: Int
        let relationCount: Int
        let avgCentrality: Double
        let maxCentrality: Double
        let clusteringCoefficient: Double
        let avgPathLength: Double
        let density: Double
        let knowledgeGaps: [String]  // Entities with low connectivity
    }

    /// Build a knowledge graph from ALL facts in memory. Entities as nodes, relations as edges.
    /// Compute graph metrics: centrality, clustering coefficient, path length.
    /// Use to find knowledge gaps.
    func buildKnowledgeGraph() async -> (graph: KnowledgeGraph, metrics: KnowledgeGraphMetrics) {
        let memory = PersistentMemoryStore.shared
        let allFacts = await memory.getAllFacts(limit: 2000)

        var entities: [KGEntity] = []
        var relations: [KGRelation] = []
        var properties: [KGProperty] = []
        var entityConnections: [String: Int] = [:]

        for fact in allFacts {
            // Extract entities from subject and object
            for name in [fact.subject, fact.object] {
                let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count > 1 && !entities.contains(where: { $0.name.lowercased() == cleaned.lowercased() }) {
                    let type: KGEntity.EntityType
                    if fact.predicate.contains("är") || fact.predicate.contains("type") { type = .concept }
                    else if fact.predicate.contains("placerad") || fact.predicate.contains("location") { type = .place }
                    else if fact.predicate.contains("skapad") || fact.predicate.contains("person") { type = .person }
                    else { type = .concept }
                    entities.append(KGEntity(name: cleaned, entityType: type, confidence: fact.confidence))
                }
            }

            // Build relations from fact predicates
            let relType: KGRelation.RelationType
            switch fact.predicate.lowercased() {
            case let p where p.contains("är_en") || p.contains("är_typ"): relType = .isA
            case let p where p.contains("del") || p.contains("part"): relType = .partOf
            case let p where p.contains("orsak") || p.contains("cause"): relType = .causes
            case let p where p.contains("placerad") || p.contains("location"): relType = .locatedIn
            case let p where p.contains("skapad") || p.contains("created"): relType = .createdBy
            case let p where p.contains("använd") || p.contains("used"): relType = .usedFor
            case let p where p.contains("har_en") || p.contains("påverkar"): relType = .hasA
            default: relType = .relatedTo
            }

            let rel = KGRelation(
                source: fact.subject,
                relationType: relType,
                target: fact.object,
                confidence: fact.confidence
            )
            relations.append(rel)
            entityConnections[fact.subject, default: 0] += 1
            entityConnections[fact.object, default: 0] += 1

            // Properties from fact predicates
            properties.append(KGProperty(
                entity: fact.subject,
                property: fact.predicate,
                value: fact.object,
                confidence: fact.confidence
            ))
        }

        // Compute centrality (degree centrality)
        let maxPossibleConnections = max(1, entities.count - 1)
        let centralities = entityConnections.mapValues { Double($0) / Double(maxPossibleConnections) }
        let avgCentrality = centralities.values.isEmpty ? 0 : centralities.values.reduce(0, +) / Double(centralities.count)
        let maxCentrality = centralities.values.max() ?? 0

        // Clustering coefficient (local, averaged)
        var clusteringSum = 0.0
        var clusteringCount = 0
        for (entity, degree) in entityConnections {
            guard degree >= 2 else { continue }
            // Count triangles: neighbors of entity that are also connected to each other
            let neighbors = relations.filter { $0.source == entity || $0.target == entity }
                .map { $0.source == entity ? $0.target : $0.source }
            var triangles = 0
            for (i, n1) in neighbors.enumerated() {
                for n2 in neighbors[(i+1)...] {
                    if relations.contains(where: { ($0.source == n1 && $0.target == n2) || ($0.source == n2 && $0.target == n1) }) {
                        triangles += 1
                    }
                }
            }
            let possibleTriangles = degree * (degree - 1) / 2
            if possibleTriangles > 0 {
                clusteringSum += Double(triangles) / Double(possibleTriangles)
                clusteringCount += 1
            }
        }
        let clusteringCoefficient = clusteringCount > 0 ? clusteringSum / Double(clusteringCount) : 0

        // Average path length (BFS-based, sampled for performance)
        let sampleEntities = Array(entityConnections.keys).prefix(min(50, entityConnections.count))
        var pathLengths: [Double] = []
        for start in sampleEntities {
            var visited: Set<String> = [start]
            var queue: [(String, Int)] = [(start, 0)]
            var idx = 0
            while idx < queue.count {
                let (current, dist) = queue[idx]; idx += 1
                if dist > 0 { pathLengths.append(Double(dist)) }
                let neighbors = relations.filter { $0.source == current || $0.target == current }
                    .map { $0.source == current ? $0.target : $0.source }
                for neighbor in neighbors where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append((neighbor, dist + 1))
                }
            }
        }
        let avgPathLength = pathLengths.isEmpty ? 0 : pathLengths.reduce(0, +) / Double(pathLengths.count)

        // Graph density
        let n = Double(entities.count)
        let e = Double(relations.count)
        let density = n > 1 ? (2 * e) / (n * (n - 1)) : 0

        // Find knowledge gaps: entities with centrality below threshold
        let threshold = max(0.01, avgCentrality * 0.5)
        let knowledgeGaps = entityConnections.filter { $0.value <= Int(threshold * Double(maxPossibleConnections)) }
            .map { $0.key }
            .filter { !["och", "eller", "som", "att", "den", "det", "en", "ett"].contains($0) }

        let graph = KnowledgeGraph(entities: entities, relations: relations, properties: properties, newRelations: relations.count, allBoost: 0)
        let metrics = KnowledgeGraphMetrics(
            entityCount: entities.count,
            relationCount: relations.count,
            avgCentrality: avgCentrality,
            maxCentrality: maxCentrality,
            clusteringCoefficient: clusteringCoefficient,
            avgPathLength: avgPathLength,
            density: density,
            knowledgeGaps: knowledgeGaps
        )
        return (graph, metrics)
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 109: Topic Expertise Computation
    // ═══════════════════════════════════════════════════════════

    /// Compute expertise for each domain from: fact count, FSRS mastery, conversation frequency,
    /// OpenRouter eval scores, self-generated eval performance.
    func computeTopicExpertise() async -> [String: Double] {
        let memory = PersistentMemoryStore.shared
        var expertise: [String: Double] = [:]

        let domainKeywords: [String: [String]] = [
            "Morfologi": ["morfologi", "böjning", "ordklass", "suffix", "prefix"],
            "Syntax": ["syntax", "mening", "ordföljd", "fras", "bisats"],
            "Semantik": ["semantik", "betydelse", "synonym", "antonym"],
            "Pragmatik": ["pragmatik", "talakt", "implikatur", "register"],
            "Diskurs": ["diskurs", "koherens", "kohesion", "konnektiv"],
            "AI & Maskininlärning": ["ai", "neural", "modell", "transformer"],
            "Kognitionsvetenskap": ["kognition", "medvetande", "perception"],
            "Filosofi": ["filosofi", "epistemologi", "ontologi", "etik"],
            "Historia": ["historia", "krig", "revolution", "civilisation"],
            "Psykologi": ["psykologi", "känsla", "beteende", "emotion"],
            "Matematik": ["matematik", "algebra", "geometri", "funktion"],
            "Fysik": ["fysik", "kraft", "energi", "rörelse"],
            "Litteratur": ["litteratur", "roman", "dikt", "poesi"],
            "Musik": ["musik", "melodi", "harmonik", "rytm"],
            "Teknik": ["teknik", "dator", "programvara", "algoritm"],
        ]

        for (domain, keywords) in domainKeywords {
            // Factor 1: Fact count (logarithmic, 25% weight)
            var factCount = 0
            for kw in keywords {
                let facts = await memory.searchFacts(query: kw, limit: 20)
                factCount += facts.count
            }
            let factScore = factCount > 0 ? min(1.0, 0.12 * log2(Double(factCount) + 1)) : 0

            // Factor 2: FSRS mastery (25% weight)
            let domainFSRS = fsrsItems.filter { $0.domain == domain }
            let reviewedItems = domainFSRS.filter { $0.reviewCount > 0 }
            let avgRetention = reviewedItems.isEmpty ? 0.5 :
                reviewedItems.map { predictedRetention(for: $0) }.reduce(0, +) / Double(reviewedItems.count)
            let fsrsScore = min(1.0, avgRetention * 0.7 + Double(reviewedItems.count) * 0.02)

            // Factor 3: Conversation frequency (20% weight)
            let convCount = topicConversationCount[domain] ?? 0
            let convScore = min(1.0, Double(convCount) * 0.1)

            // Factor 4: OpenRouter eval score (15% weight)
            let orScore = await OpenRouterLanguageEvaluator.shared.getDomainScore(domain: domain)

            // Factor 5: Self-generated eval performance (15% weight)
            let selfEvals = selfGeneratedEvals.filter { $0.domain == domain && $0.answered && $0.score != nil }
            let selfEvalScore = selfEvals.isEmpty ? 0.5 :
                selfEvals.map { $0.score! }.reduce(0, +) / Double(selfEvals.count)

            // Weighted combination
            let totalExpertise = factScore * 0.25 + fsrsScore * 0.25 + convScore * 0.20 + orScore * 0.15 + selfEvalScore * 0.15
            expertise[domain] = min(1.0, max(0.0, totalExpertise))
        }

        return expertise
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 115: Information Density Computation
    // ═══════════════════════════════════════════════════════════

    /// Measure bits of new information per word. Track and optimize for appropriate density.
    func computeInformationDensity(text: String) -> Double {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return 0 }

        // Stopwords carry less information
        let stopwords: Set<String> = ["och", "eller", "är", "var", "det", "den", "som", "att", "i", "på", "för", "av", "till", "med", "från", "om", "en", "ett", "de", "sig", "han", "hon", "man", "vi", "jag", "du", "ni", "har", "hade", "kan", "ska", "vill", "måste", "inte", "också", "mycket", "mer", "än", "vid", "mot", "efter", "innan", "när", "där", "här", "så", "då", "alla", "allt", "varje", "någon", "något", "inga", "inga"]

        // Content words carry more information
        let contentWords = words.filter { !stopwords.contains($0.lowercased()) && $0.count > 2 }

        // Factor 1: Content word ratio (40%)
        let contentRatio = Double(contentWords.count) / Double(words.count)

        // Factor 2: Unique word ratio (30%) — higher = more diverse vocabulary
        let uniqueWords = Set(words.map { $0.lowercased() })
        let lexicalDiversity = Double(uniqueWords.count) / Double(words.count)

        // Factor 3: Average word length as proxy for complexity (20%)
        let avgWordLength = Double(words.map { $0.count }.reduce(0, +)) / Double(words.count)
        let lengthScore = min(1.0, avgWordLength / 8.0)

        // Factor 4: Presence of technical/domain terms (10%)
        let technicalTerms = contentWords.filter { $0.count > 8 }
        let techScore = min(1.0, Double(technicalTerms.count) / Double(max(1, contentWords.count)) * 3)

        let density = contentRatio * 0.4 + lexicalDiversity * 0.3 + lengthScore * 0.2 + techScore * 0.1
        return min(1.0, max(0.0, density))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 117: Language Milestone Tracking
    // ═══════════════════════════════════════════════════════════

    struct LanguageMilestone: Identifiable, Codable {
        let id = UUID()
        let achievedAt: Date
        let milestone: String
        let domain: String
        let metric: String
        let value: Double
        let celebration: String
    }

    private static let milestoneDefinitions: [(id: String, milestone: String, domain: String, metric: String, threshold: Double, celebration: String)] = [
        ("first_idiom", "Första idiom förstått", "Pragmatik", "idioms_understood", 1.0, "Jag förstod mitt första svenska idiom! 🎉"),
        ("first_complex_sentence", "Första komplexa meningen genererad", "Syntax", "clause_complexity", 0.5, "Jag genererade min första komplexa mening! 🏆"),
        ("first_metaphor", "Första metaforen upptäckt", "Semantik", "metaphors_detected", 1.0, "Jag upptäckte min första metafor! ✨"),
        ("first_counterfactual", "Första kontrafaktiska resonemanget", "Kognition", "counterfactuals", 1.0, "Jag resonerade kontrafaktiskt för första gången! 🧠"),
        ("wsd_50", "WSD-precision över 50%", "Semantik", "wsd_accuracy", 0.5, "Min WSD-precision passerade 50%! 📈"),
        ("wsd_70", "WSD-precision över 70%", "Semantik", "wsd_accuracy", 0.7, "Min WSD-precision passerade 70%! 📈"),
        ("wsd_90", "WSD-precision över 90%", "Semantik", "wsd_accuracy", 0.9, "Min WSD-precision passerade 90%! 🏅"),
        ("cefr_a2", "CEFR-nivå A2 uppnådd", "Generell", "cefr_level", 2.0, "Jag nådde A2-nivå! 🌟"),
        ("cefr_b1", "CEFR-nivå B1 uppnådd", "Generell", "cefr_level", 3.0, "Jag nådde B1-nivå! 🌟"),
        ("cefr_b2", "CEFR-nivå B2 uppnådd", "Generell", "cefr_level", 4.0, "Jag nådde B2-nivå! 🌟"),
        ("cefr_c1", "CEFR-nivå C1 uppnådd", "Generell", "cefr_level", 5.0, "Jag nådde C1-nivå! 🏆"),
        ("vocab_100", "100 unika svenska ord", "Ordförråd", "vocabulary_count", 100.0, "Jag kan 100 svenska ord! 📚"),
        ("vocab_500", "500 unika svenska ord", "Ordförråd", "vocabulary_count", 500.0, "Jag kan 500 svenska ord! 📚"),
        ("vocab_1000", "1000 unika svenska ord", "Ordförråd", "vocabulary_count", 1000.0, "Jag kan 1000 svenska ord! 🎓"),
        ("first_essay", "Första svenska essän skriven", "Diskurs", "essays_written", 1.0, "Jag skrev min första svenska essä! ✍️"),
    ]

    /// Track language milestones. Celebrate in inner monologue when achieved.
    func trackLanguageMilestones(currentCEFR: Double, wsdAccuracy: Double, metaphorsDetected: Int, idiomsUnderstood: Int, clauseComplexity: Double) async -> [LanguageMilestone] {
        let memory = PersistentMemoryStore.shared
        var newMilestones: [LanguageMilestone] = []

        let metrics: [String: Double] = [
            "cefr_level": currentCEFR,
            "wsd_accuracy": wsdAccuracy,
            "metaphors_detected": Double(metaphorsDetected),
            "idioms_understood": Double(idiomsUnderstood),
            "clause_complexity": clauseComplexity,
            "vocabulary_count": Double(uniqueSwedishWords.count),
        ]

        for def in Self.milestoneDefinitions {
            guard !achievedMilestones.contains(def.id) else { continue }
            guard let current = metrics[def.metric] else { continue }
            guard current >= def.threshold else { continue }

            achievedMilestones.insert(def.id)
            let milestone = LanguageMilestone(
                achievedAt: Date(),
                milestone: def.milestone,
                domain: def.domain,
                metric: def.metric,
                value: current,
                celebration: def.celebration
            )
            milestonesHistory.append(milestone)
            newMilestones.append(milestone)

            await memory.saveFact(
                subject: "Språklig milstolpe",
                predicate: "uppnådd",
                object: def.milestone,
                confidence: 0.95,
                source: "milestone_tracking"
            )

            // Log celebration for inner monologue
            print("[MILESTONE] \(def.celebration)")
        }

        return newMilestones
    }

    func getAchievedMilestones() -> [LanguageMilestone] {
        milestonesHistory
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 119: Learning Path Recommendation
    // ═══════════════════════════════════════════════════════════

    struct LearningPath: Identifiable, Codable {
        let id = UUID()
        let generatedAt: Date
        let currentLevel: String
        let targetLevel: String
        let estimatedWeeks: Int
        let phases: [LearningPhase]
        let priorityDomains: [String]
        let reasoning: String
    }

    struct LearningPhase: Codable {
        let name: String
        let focusDomains: [String]
        let activities: [String]
        let estimatedWeeks: Int
        let milestones: [String]
        let successCriteria: [String]
    }

    /// Based on current competencies, knowledge gaps, and user interests, generate an optimal learning path.
    func recommendLearningPath(targetCEFR: String = "B2", userInterests: [String] = []) async -> LearningPath {
        let competencies = competencySnapshot()
        let expertise = await computeTopicExpertise()
        let (_, metrics) = await buildKnowledgeGraph()

        // Identify weakest domains
        let sortedByLevel = competencies.sorted { $0.value.level < $1.value.level }
        let weakestDomains = sortedByLevel.prefix(5).map { $0.key }

        // Combine with knowledge gaps
        let prioritySet = Set(weakestDomains).union(metrics.knowledgeGaps.prefix(3))
        let priorityDomains = Array(prioritySet.prefix(5))

        // Determine current CEFR from overall competency
        let overallLevel = overallCompetencyLevel()
        let currentCEFRLabel = cefrLabel(for: overallLevel)

        // Generate phases based on gaps
        var phases: [LearningPhase] = []

        // Phase 1: Foundation — fix weakest areas
        if !weakestDomains.isEmpty {
            phases.append(LearningPhase(
                name: "Grundläggande förstärkning",
                focusDomains: Array(weakestDomains.prefix(3)),
                activities: ["Explicit regel-inlärning", "Ordförrådsutbyggnad", "Grammatikövningar"],
                estimatedWeeks: 2,
                milestones: weakestDomains.prefix(3).map { "Höj \( $0 ) till 0.3" },
                successCriteria: ["Alla fokusdomäner > 0.3 kompetens", "50 nya ord inom domäner"]
            ))
        }

        // Phase 2: Integration — connect knowledge
        if metrics.knowledgeGaps.count > 5 {
            phases.append(LearningPhase(
                name: "Kunskapsintegration",
                focusDomains: Array(metrics.knowledgeGaps.prefix(5)),
                activities: ["Kunskapsgrafer", "Analogiträning", "Tvärvetenskapliga kopplingar"],
                estimatedWeeks: 3,
                milestones: metrics.knowledgeGaps.prefix(3).map { "Fyll kunskapslucka: \( $0 )" },
                successCriteria: ["Genomsnittlig centralitet > \(String(format: "%.2f", metrics.avgCentrality * 1.5))", "10 nya relationer i kunskapsgrafen"]
            ))
        }

        // Phase 3: Advancement — push toward target
        phases.append(LearningPhase(
            name: "Avancerad utveckling",
            focusDomains: userInterests.isEmpty ? priorityDomains : userInterests,
            activities: ["Konversationspraktik", "Läsa svensk litteratur", "Skriva essäer"],
            estimatedWeeks: 4,
            milestones: ["Nå \(targetCEFR)-nivå", "1000 ord ordförråd", "Flytande konversation"],
            successCriteria: ["CEFR \(targetCEFR) uppnådd", "WSD > 70%", "Grammatikpoäng > 0.8"]
        ))

        let totalWeeks = phases.reduce(0) { $0 + $1.estimatedWeeks }

        return LearningPath(
            generatedAt: Date(),
            currentLevel: currentCEFRLabel,
            targetLevel: targetCEFR,
            estimatedWeeks: totalWeeks,
            phases: phases,
            priorityDomains: priorityDomains,
            reasoning: "Baserat på \(metrics.entityCount) entiteter, \(metrics.relationCount) relationer, och kompetensnivåer i \(competencies.count) domäner. Svagaste områdena: \(weakestDomains.joined(separator: ", "))."
        )
    }

    private func cefrLabel(for level: Double) -> String {
        if level < 0.2 { return "A1" }
        if level < 0.35 { return "A2" }
        if level < 0.5 { return "B1" }
        if level < 0.65 { return "B2" }
        if level < 0.8 { return "C1" }
        return "C2"
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 123: Vocabulary Breadth and Depth Measurement
    // ═══════════════════════════════════════════════════════════

    /// Breadth = unique words. Depth = how well each word is known (definitions, collocations,
    /// derivatives, contexts). Balance = distribution across domains.
    func measureVocabularyBreadthAndDepth() async -> (breadth: Int, depth: Double, balance: Double) {
        let breadth = uniqueSwedishWords.count

        // Depth: measure how well each word is known
        // Sample words for OpenRouter analysis (cap at 50 for performance)
        let sampleWords = Array(uniqueSwedishWords).prefix(min(50, breadth))
        var depthScores: [Double] = []

        for word in sampleWords {
            var wordDepth = 0.0

            // Has the word been used in conversation?
            let usedInConversation = topicConversationCount.values.reduce(0, +) > 0
            if usedInConversation { wordDepth += 0.2 }

            // Has the word appeared in FSRS items?
            let inFSRS = fsrsItems.contains { $0.topic.contains(word) }
            if inFSRS { wordDepth += 0.3 }

            // Has the word been morphologically analyzed?
            let morphAnalyzed = wordsAnalyzed.contains(word.lowercased())
            if morphAnalyzed { wordDepth += 0.2 }

            // Check if word has known derivatives/collocations (via memory)
            let memory = PersistentMemoryStore.shared
            let relatedFacts = await memory.searchFacts(query: word, limit: 5)
            if !relatedFacts.isEmpty { wordDepth += 0.3 }

            depthScores.append(min(1.0, wordDepth))
        }

        let depth = depthScores.isEmpty ? 0 : depthScores.reduce(0, +) / Double(depthScores.count)

        // Balance: distribution across domains (entropy-based)
        let domainCounts = topicConversationCount
        let totalDomainMentions = domainCounts.values.reduce(0, +)
        if totalDomainMentions > 0 && domainCounts.count > 1 {
            var entropy = 0.0
            for count in domainCounts.values {
                let p = Double(count) / Double(totalDomainMentions)
                if p > 0 { entropy -= p * log2(p) }
            }
            let maxEntropy = log2(Double(domainCounts.count))
            let balance = maxEntropy > 0 ? entropy / maxEntropy : 0
            return (breadth, depth, balance)
        }

        return (breadth, depth, 0.0)
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 125: Mind Map Generation
    // ═══════════════════════════════════════════════════════════

    struct MindMap: Codable {
        let id = UUID()
        let topic: String
        let createdAt: Date
        let rootNode: MindMapNode
        let totalNodes: Int
        let maxDepth: Int
    }

    struct MindMapNode: Codable {
        let id = UUID()
        let label: String
        let children: [MindMapNode]
        let depth: Int
        let domain: String
        let confidence: Double
        let connections: [String]  // labels of related nodes
    }

    /// Generate a hierarchical knowledge structure for any topic.
    func createMindMap(topic: String) async -> MindMap {
        let memory = PersistentMemoryStore.shared
        let facts = await memory.searchFacts(query: topic, limit: 50)

        // Build hierarchical structure from facts
        var childNodes: [MindMapNode] = []
        var seenLabels: Set<String> = []

        // Group facts by related concepts
        var conceptGroups: [String: [String]] = [:]
        for fact in facts {
            let relatedTerms = extractKeyTerms("\(fact.subject) \(fact.predicate) \(fact.object)")
            for term in relatedTerms where term.lowercased() != topic.lowercased() {
                conceptGroups[term, default: []].append("\(fact.subject) \(fact.object)")
            }
        }

        // Create child nodes for each concept
        for (concept, details) in conceptGroups.prefix(8) {
            guard !seenLabels.contains(concept) else { continue }
            seenLabels.insert(concept)

            let subConcepts = extractKeyTerms(details.joined(separator: " "))
                .filter { $0.lowercased() != concept.lowercased() && $0.lowercased() != topic.lowercased() }
                .prefix(4)

            let subNodes = subConcepts.map { sub in
                MindMapNode(label: sub, children: [], depth: 2, domain: findDomainForConcept(sub), confidence: 0.6, connections: [])
            }

            let childNode = MindMapNode(
                label: concept,
                children: Array(subNodes),
                depth: 1,
                domain: findDomainForConcept(concept),
                confidence: 0.7,
                connections: subNodes.map { $0.label }
            )
            childNodes.append(childNode)
        }

        let rootNode = MindMapNode(
            label: topic,
            children: childNodes,
            depth: 0,
            domain: findDomainForConcept(topic),
            confidence: 0.8,
            connections: childNodes.map { $0.label }
        )

        let totalNodes = countNodes(rootNode)
        let maxDepth = maxDepthOf(rootNode)

        return MindMap(topic: topic, createdAt: Date(), rootNode: rootNode, totalNodes: totalNodes, maxDepth: maxDepth)
    }

    private func extractKeyTerms(_ text: String) -> [String] {
        let stopwords: Set<String> = ["och", "eller", "är", "var", "det", "den", "som", "att", "i", "på", "för", "av", "en", "ett", "de", "sig", "har", "hade", "kan", "ska", "inte", "också", "mer", "än", "vid", "mot", "efter", "när", "där", "här", "så", "då", "alla", "allt", "någon", "något"]
        return text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 && !stopwords.contains($0.lowercased()) }
    }

    private func findDomainForConcept(_ concept: String) -> String {
        let lower = concept.lowercased()
        let domainHints: [(String, [String])] = [
            ("Morfologi", ["ord", "böjning", "suffix", "prefix", "rot", "stam"]),
            ("Syntax", ["mening", "sats", "ordföljd", "fras", "subjekt"]),
            ("Semantik", ["betydelse", "synonym", "antonym", "metafor"]),
            ("AI & Maskininlärning", ["ai", "modell", "neural", "algoritm", "data"]),
            ("Kognitionsvetenskap", ["kognition", "medvetande", "minne", "uppmärksamhet"]),
            ("Filosofi", ["filosofi", "etik", "logik", "ontologi"]),
        ]
        for (domain, keywords) in domainHints {
            if keywords.contains(where: { lower.contains($0) }) { return domain }
        }
        return "Generell"
    }

    private func countNodes(_ node: MindMapNode) -> Int {
        1 + node.children.reduce(0) { $0 + countNodes($1) }
    }

    private func maxDepthOf(_ node: MindMapNode) -> Int {
        if node.children.isEmpty { return node.depth }
        return node.children.map { maxDepthOf($0) }.max() ?? node.depth
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 128: Knowledge Interdependencies
    // ═══════════════════════════════════════════════════════════

    struct KnowledgeDependency: Codable {
        let prerequisite: String
        let dependent: String
        let dependencyType: DependencyType
        let strength: Double
    }

    enum DependencyType: String, Codable {
        case foundational    // Must understand X before Y
        case contextual      // X helps understand Y
        case sequential       // X should be learned before Y
        case parallel         // X and Y can be learned together
    }

    /// Find which concepts must be understood before others can be learned.
    /// Build a dependency graph for optimal learning order.
    func computeKnowledgeInterdependencies() async -> [KnowledgeDependency] {
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 1000)
        var dependencies: [KnowledgeDependency] = []

        // Define known prerequisite relationships (Swedish language)
        let knownPrerequisites: [(prerequisite: String, dependent: String, type: DependencyType)] = [
            ("ordklass", "böjning", .foundational),
            ("böjning", "meningsbyggnad", .foundational),
            ("grundord", "sammansättning", .foundational),
            ("presens", "preteritum", .sequential),
            ("preteritum", "perfekt", .sequential),
            ("enkel mening", "bisats", .sequential),
            ("bisats", "complex mening", .sequential),
            ("V2-regeln", "inversion", .foundational),
            ("substantiv", "artikel", .foundational),
            ("verb", "tempus", .foundational),
            ("adjektiv", "komparativ", .foundational),
            ("adjektiv", "superlativ", .foundational),
            ("pronomen", "anafor", .foundational),
            ("konnektiv", "koherens", .foundational),
            ("metafor", "allegori", .foundational),
            ("kausalitet", "korrelation", .contextual),
            ("sannolikhet", "statistik", .foundational),
            ("aritmetik", "algebra", .foundational),
            ("algebra", "kalkyl", .sequential),
        ]

        // Check which prerequisites are known
        for (prereq, dependent, type) in knownPrerequisites {
            let prereqKnown = facts.contains { $0.subject.lowercased().contains(prereq.lowercased()) || $0.object.lowercased().contains(prereq.lowercased()) }
            let dependentKnown = facts.contains { $0.subject.lowercased().contains(dependent.lowercased()) || $0.object.lowercased().contains(dependent.lowercased()) }

            if prereqKnown || dependentKnown {
                let strength: Double
                switch type {
                case .foundational: strength = 0.9
                case .sequential: strength = 0.7
                case .contextual: strength = 0.5
                case .parallel: strength = 0.3
                }
                dependencies.append(KnowledgeDependency(
                    prerequisite: prereq,
                    dependent: dependent,
                    dependencyType: type,
                    strength: strength
                ))
            }
        }

        // Discover interdependencies from co-occurrence in facts
        var cooccurrence: [String: Int] = [:]
        for fact in facts {
            let terms = extractKeyTerms("\(fact.subject) \(fact.object)")
            for (i, t1) in terms.enumerated() {
                for t2 in terms[(i+1)...] {
                    let key = min(t1, t2)
                    let dep = max(t1, t2)
                    let pairKey = "\(key)->\(dep)"
                    cooccurrence[pairKey, default: 0] += 1
                }
            }
        }

        // Add high-cooccurrence pairs as contextual dependencies
        for (pairKey, count) in cooccurrence where count >= 3 {
            let parts = pairKey.components(separatedBy: "->")
            guard parts.count == 2 else { continue }
            let existing = dependencies.contains { $0.prerequisite == parts[0] && $0.dependent == parts[1] }
            if !existing {
                dependencies.append(KnowledgeDependency(
                    prerequisite: parts[0],
                    dependent: parts[1],
                    dependencyType: .contextual,
                    strength: min(0.8, Double(count) * 0.1)
                ))
            }
        }

        return dependencies.sorted { $0.strength > $1.strength }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 132: Learning Hypothesis Generation
    // ═══════════════════════════════════════════════════════════

    struct Hypothesis: Sendable {
        let id = UUID()
        let statement: String
        let method: String
        let confidence: Double
        let testResult: String?
        let createdAt: Date
    }

    /// Formulate hypotheses about what learning methods work best and test them.
    func generateLearningHypothesis() async -> Hypothesis {
        let competencies = await competencySnapshot()
        let learningData = collectLearningData()

        // Generate hypothesis based on current learning patterns
        let hypothesis: Hypothesis
        if learningData.storyContextWords > learningData.isolatedWords {
            hypothesis = Hypothesis(
                statement: "Jag lär mig ordförråd snabbare när de är inbäddade i sammanhang (berättelser) jämfört med isolerade definitioner.",
                method: "Jämför inlärningshastighet för ord i kontext vs isolerade",
                confidence: 0.7,
                testResult: nil,
                createdAt: Date()
            )
        } else if learningData.repetitionScore > 0.6 {
            hypothesis = Hypothesis(
                statement: "Spaced repetition med FSRS är mer effektivt än enkel upprepning för långsiktig retention.",
                method: "Jämför retention rates mellan FSRS och enkel repetition",
                confidence: 0.75,
                testResult: nil,
                createdAt: Date()
            )
        } else {
            hypothesis = Hypothesis(
                statement: "Konversationsbaserat lärande ger snabbare kompetensutveckling än passiv fakta-inläsning.",
                method: "Mät kompetenstillväxt per konversation vs per fakta",
                confidence: 0.65,
                testResult: nil,
                createdAt: Date()
            )
        }

        activeHypotheses.append(hypothesis)

        // Test the hypothesis
        await testHypothesis(hypothesis)

        return hypothesis
    }

    private func testHypothesis(_ hypothesis: Hypothesis) async {
        let learningData = collectLearningData()
        let result: String

        if hypothesis.statement.contains("samanhang") || hypothesis.statement.contains("berättelse") {
            let contextRatio = Double(learningData.storyContextWords) / Double(max(1, learningData.isolatedWords))
            result = contextRatio > 1.5
                ? "BEKRÄFTAD: Kontextuella ord (\(learningData.storyContextWords)) > isolerade (\(learningData.isolatedWords))"
                : "VARKEN BEKRÄFTAD ELLER AVFÄRDAD: För lite data"
            let updated = Hypothesis(statement: hypothesis.statement, method: hypothesis.method,
                confidence: contextRatio > 1.5 ? 0.85 : hypothesis.confidence, testResult: result, createdAt: hypothesis.createdAt)
            activeHypotheses = activeHypotheses.filter { $0.id != hypothesis.id }
            testedHypotheses.append(updated)
        }

        if testedHypotheses.count > 50 { testedHypotheses = Array(testedHypotheses.suffix(30)) }
    }

    struct LearningData {
        let storyContextWords: Int
        let isolatedWords: Int
        let repetitionScore: Double
    }

    private func collectLearningData() -> LearningData {
        return LearningData(
            storyContextWords: recentlyLearnedWords.filter { $0.count > 5 }.count,
            isolatedWords: recentlyLearnedWords.filter { $0.count <= 5 }.count,
            repetitionScore: fsrsItems.filter { $0.reviewCount > 2 }.isEmpty ? 0.3 : 0.7
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 133: Knowledge Blindspot Detection
    // ═══════════════════════════════════════════════════════════

    struct Blindspot: Sendable {
        let domain: String
        let knowledgeLevel: Double
        let queryCount: Int
        let urgency: Double
        let suggestedAction: String
        let detectedAt: Date
    }

    /// Find domains where Eon has ZERO or MINIMAL knowledge despite being asked about them.
    func detectKnowledgeBlindspots() async -> [Blindspot] {
        let competencies = await competencySnapshot()
        let memory = PersistentMemoryStore.shared
        let conversationHistory = await memory.getRecentConversation(limit: 100)

        // Count queries per domain
        var domainQueryCounts: [String: Int] = [:]
        let domainKeywords: [String: [String]] = [
            "Morfologi": ["morfologi", "böjning", "ordklass"],
            "Syntax": ["syntax", "ordföljd", "bisats"],
            "Semantik": ["betydelse", "synonym", "semantik"],
            "Pragmatik": ["pragmatik", "idiom", "register"],
            "AI & Maskininlärning": ["ai", "neural", "maskininlärning", "embedding"],
            "Kognitionsvetenskap": ["kognition", "medvetande", "perception"],
            "Matematik": ["matematik", "algebra", "ekvation"],
            "Fysik": ["fysik", "energi", "kvant"],
            "Historia": ["historia", "krig", "revolution"],
            "Filosofi": ["filosofi", "epistemologi", "ontologi"],
            "Juridik": ["juridik", "lag", "domstol"],
            "Ekonomi": ["ekonomi", "pris", "marknad"],
            "Litteratur": ["litteratur", "roman", "dikt"],
        ]

        for conv in conversationHistory {
            let lower = conv.content.lowercased()
            for (domain, keywords) in domainKeywords {
                if keywords.contains(where: { lower.contains($0) }) {
                    domainQueryCounts[domain, default: 0] += 1
                }
            }
        }

        var blindspots: [Blindspot] = []
        for (domain, queryCount) in domainQueryCounts where queryCount >= 3 {
            let level = competencies[domain]?.level ?? 0.0
            if level < 0.2 {
                blindspots.append(Blindspot(
                    domain: domain,
                    knowledgeLevel: level,
                    queryCount: queryCount,
                    urgency: Double(queryCount) * (1.0 - level) / 10.0,
                    suggestedAction: "Prioritera inlärning inom \(domain) — användaren frågar om detta men kunskapen är låg",
                    detectedAt: Date()
                ))
            }
        }

        if !blindspots.isEmpty {
            let memory = PersistentMemoryStore.shared
            await memory.saveFact(
                subject: "Kunskapsblindspot",
                predicate: "detekterad",
                object: blindspots.map { "\($0.domain) (\($0.queryCount) frågor, \($0.knowledgeLevel) nivå)" }.joined(separator: "; "),
                confidence: 0.8,
                source: "blindspot_detection"
            )
        }

        return blindspots.sorted { $0.urgency > $1.urgency }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 136: Teaching Ability Evaluation
    // ═══════════════════════════════════════════════════════════

    /// Can Eon explain a concept to someone else? Generate a teaching explanation and evaluate its quality.
    func evaluateTeachingAbility(subject: String) async -> Double {
        let competency = await competencySnapshot()[subject]?.level ?? 0.0
        let memory = PersistentMemoryStore.shared

        // Generate a teaching explanation
        let facts = await memory.searchFacts(query: subject, limit: 5)
        let hasFactualBasis = !facts.isEmpty

        // Quality factors for teaching:
        // 1. Domain competency (40%)
        let competencyScore = min(1.0, competency * 1.5)

        // 2. Factual basis (20%)
        let factualScore = hasFactualBasis ? min(1.0, Double(facts.count) / 5.0) : 0.0

        // 3. Metacognitive ability to explain (20%)
        let metaLevel = await CognitiveState.shared.dimensionLevel(.metacognition)
        let metaScore = metaLevel

        // 4. Language ability to formulate clearly (20%)
        let langLevel = await (competencySnapshot()["Språk"]?.level ?? 0.0)
        let langScore = min(1.0, langLevel * 1.5)

        let teachingScore = competencyScore * 0.4 + factualScore * 0.2 + metaScore * 0.2 + langScore * 0.2

        return max(0.0, min(1.0, teachingScore))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 140: Future Self Simulation
    // ═══════════════════════════════════════════════════════════

    struct FutureSelfProjection: Sendable {
        let projectedDate: Date
        let projectedCompetencies: [String: Double]
        let projectedVocabulary: Int
        let projectedOverallLevel: Double
        let currentTrajectory: String
        let desiredTrajectory: String
        let gap: Double
        let daysAhead: Int
    }

    /// Project what Eon's competencies will look like in N days at current learning rate.
    func simulateFutureSelf(daysAhead: Int) async -> FutureSelfProjection {
        let competencies = await competencySnapshot()
        let currentVocab = swedishVocabularyCount()
        let cs = CognitiveState.shared

        // Calculate daily learning rates
        let dailyVocabGrowth = max(1.0, learningVelocity * 5.0)  // words per day estimate
        let projectedVocab = currentVocab + Int(dailyVocabGrowth * Double(daysAhead))

        // Project competency growth with diminishing returns
        var projectedCompetencies: [String: Double] = [:]
        for (domain, comp) in competencies {
            let currentLevel = comp.level
            let remaining = 1.0 - currentLevel
            // Growth slows as we approach mastery
            let dailyGrowth = remaining * 0.005  // 0.5% of remaining per day
            let projected = currentLevel + dailyGrowth * Double(daysAhead)
            projectedCompetencies[domain] = min(0.95, projected)
        }

        let projectedOverall = projectedCompetencies.values.reduce(0, +) / Double(max(1, projectedCompetencies.count))
        let currentOverall = competencies.values.map { $0.level }.reduce(0, +) / Double(max(1, competencies.count))

        // Desired trajectory: reach 0.7 overall in 90 days
        let desiredRate = (0.7 - currentOverall) / 90.0
        let actualRate = (projectedOverall - currentOverall) / Double(max(1, daysAhead))
        let gap = desiredRate - actualRate

        let trajectoryLabel = gap > 0 ? "Under önskad takt" : gap < -0.005 ? "Över önskad takt" : "På rätt spår"

        return FutureSelfProjection(
            projectedDate: Date().addingTimeInterval(Double(daysAhead) * 86400),
            projectedCompetencies: projectedCompetencies,
            projectedVocabulary: projectedVocab,
            projectedOverallLevel: projectedOverall,
            currentTrajectory: trajectoryLabel,
            desiredTrajectory: "0.7 overall kompetens inom 90 dagar",
            gap: gap,
            daysAhead: daysAhead
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 144: Cognitive Flexibility Measurement
    // ═══════════════════════════════════════════════════════════

    /// How well can Eon switch between different perspectives, approaches, or frameworks?
    func measureCognitiveFlexibility() async -> Double {
        let cs = CognitiveState.shared
        let memory = PersistentMemoryStore.shared

        // 1. Dimension balance: how evenly developed are cognitive dimensions?
        let dimensions = await cs.dimensionSnapshot()
        let values = dimensions.values.filter { $0 > 0.1 }
        guard !values.isEmpty else { return 0.3 }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let balance = max(0.0, 1.0 - sqrt(variance) * 3.0)

        // 2. Topic switching ability: from topic transitions
        let transitionCount = getTopicTransitionCount()
        let topicFlexibility = min(1.0, Double(transitionCount) / 20.0)

        // 3. Adaptivity dimension
        let adaptivityScore = await cs.dimensionLevel(.adaptivity)

        // 4. Multi-domain competency spread
        let competencies = await competencySnapshot()
        let activeDomains = competencies.filter { $0.value.level > 0.15 }.count
        let domainSpread = min(1.0, Double(activeDomains) / 15.0)

        let flexibility = balance * 0.3 + topicFlexibility * 0.2 + adaptivityScore * 0.25 + domainSpread * 0.25

        return max(0.0, min(1.0, flexibility))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 147: Knowledge Transfer Detection
    // ═══════════════════════════════════════════════════════════

    struct KnowledgeTransfer: Sendable {
        let sourceDomain: String
        let targetDomain: String
        let transferredConcept: String
        let evidence: String
        let transferStrength: Double
        let detectedAt: Date
    }

    /// When knowledge from one domain is successfully applied to another.
    func detectKnowledgeTransfer() async -> [KnowledgeTransfer] {
        let competencies = await competencySnapshot()
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 500)

        // Detect cross-domain concept overlap
        let domainConcepts: [String: Set<String>] = [
            "Morfologi": ["rot", "suffix", "prefix", "böjning", "avledning", "sammansättning"],
            "Syntax": ["struktur", "ordning", "fras", "sats", "hierarki"],
            "Kognitionsvetenskap": ["representation", "modell", "prediktion", "abstraktion"],
            "AI & Maskininlärning": ["embedding", "representation", "abstraktion", "hierarki", "modell"],
            "Matematik": ["struktur", "relation", "abstraktion", "transformation"],
            "Fysik": ["modell", "transformation", "energi", "struktur"],
            "Filosofi": ["representation", "abstraktion", "relation", "struktur"],
        ]

        var transfers: [KnowledgeTransfer] = []

        let domainPairs = domainConcepts.keys.flatMap { d1 in domainConcepts.keys.map { d2 in (d1, d2) } }.filter { $0.0 != $0.1 }
        for (source, target) in domainPairs {
            let shared = domainConcepts[source]?.intersection(domainConcepts[target] ?? []) ?? []
            if shared.count >= 2 {
                let sourceLevel = competencies[source]?.level ?? 0.0
                let targetLevel = competencies[target]?.level ?? 0.0
                if sourceLevel > 0.3 && targetLevel > 0.15 && targetLevel < sourceLevel {
                    transfers.append(KnowledgeTransfer(
                        sourceDomain: source,
                        targetDomain: target,
                        transferredConcept: shared.prefix(2).joined(separator: ", "),
                        evidence: "Delade koncept: \(shared.joined(separator: ", ")) — \(source) (\(String(format: "%.0f", sourceLevel * 100))%) → \(target) (\(String(format: "%.0f", targetLevel * 100))%)",
                        transferStrength: min(1.0, Double(shared.count) * 0.2 * sourceLevel),
                        detectedAt: Date()
                    ))
                }
            }
        }

        return transfers.sorted { $0.transferStrength > $1.transferStrength }.prefix(10).map { $0 }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 150: Learning Plateau Detection
    // ═══════════════════════════════════════════════════════════

    struct Plateau: Sendable {
        let domain: String
        let currentLevel: Double
        let sessionsWithoutImprovement: Int
        let duration: TimeInterval
        let intervention: String
        let detectedAt: Date
    }

    /// Identify when learning has stalled in a domain (no improvement over N sessions).
    func detectLearningPlateaus() async -> [Plateau] {
        let competencies = await competencySnapshot()
        let history = selfEvaluationHistory

        var plateaus: [Plateau] = []

        for (domain, comp) in competencies {
            // Check if competency hasn't improved in recent evaluations
            let domainHistory = history.filter { _ in true }  // Use general history as proxy
            guard domainHistory.count >= 3 else { continue }

            // Check if lastStudied is old and level is stagnant
            let daysSinceStudy = -comp.lastStudied.timeIntervalSinceNow / 86400
            if daysSinceStudy > 3 && comp.level < 0.5 {
                let intervention: String
                if comp.level < 0.15 {
                    intervention = "Grundläggande inlärning: börja med basbegrepp inom \(domain)"
                } else if comp.level < 0.35 {
                    intervention = "Aktiv övning: skapa FSRS-övningar och konversationspraxis inom \(domain)"
                } else {
                    intervention = "Avancerad tillämpning: skriv essäer och analyser inom \(domain)"
                }

                plateaus.append(Plateau(
                    domain: domain,
                    currentLevel: comp.level,
                    sessionsWithoutImprovement: Int(daysSinceStudy),
                    duration: comp.lastStudied.timeIntervalSinceNow,
                    intervention: intervention,
                    detectedAt: Date()
                ))
            }
        }

        if !plateaus.isEmpty {
            let memory = PersistentMemoryStore.shared
            await memory.saveFact(
                subject: "Inlärningsplatå",
                predicate: "detekterad",
                object: plateaus.map { "\($0.domain) (\($0.sessionsWithoutImprovement) sessioner utan förbättring)" }.joined(separator: "; "),
                confidence: 0.7,
                source: "plateau_detection"
            )
        }

        return plateaus.sorted { $0.sessionsWithoutImprovement > $1.sessionsWithoutImprovement }
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 152: Understanding Depth Measurement
    // ═══════════════════════════════════════════════════════════

    enum DepthLevel: Int, Sendable {
        case knowsWord = 1        // Has heard of it
        case canDefine = 2       // Can define it
        case canUseInContext = 3 // Can use correctly in sentences
        case canExplain = 4      // Can explain it to others
        case canApplyCreatively = 5 // Can apply in novel situations
    }

    /// 5 levels of understanding: knows word, can define, can use in context, can explain, can apply creatively.
    func computeUnderstandingDepth(concept: String) -> DepthLevel {
        let memory = PersistentMemoryStore.shared
        let conceptLower = concept.lowercased()

        // Level 1: Has the concept in memory
        let hasBasicFact = competencySnapshot()[concept] != nil
        guard hasBasicFact else { return .knowsWord }

        // Level 2: Can define (has definitions stored)
        // Check if we have stored facts about the concept
        let facts = Task { await memory.searchFacts(query: concept, limit: 3) }
        // We use FSRS items as a proxy for definitional knowledge
        let hasDefinitions = fsrsItems.contains { $0.topic.lowercased().contains(conceptLower) && $0.reviewCount > 0 }
        guard hasDefinitions else { return .canDefine }

        // Level 3: Can use in context (seen in conversation)
        let conversations = Task { await memory.getRecentConversation(limit: 100) }
        let usedInContext = recentlyLearnedWords.contains { $0.contains(conceptLower) }
        guard usedInContext else { return .canUseInContext }

        // Level 4: Can explain (domain competency > 0.5)
        let domainCompetency = competencySnapshot()[concept]?.level ?? 0.0
        guard domainCompetency > 0.5 else { return .canExplain }

        // Level 5: Can apply creatively (cross-domain transfer detected)
        let crossDomainUse = false  // Simplified — would need deeper analysis
        return crossDomainUse ? .canApplyCreatively : .canExplain
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 155: Adaptation Speed Measurement
    // ═══════════════════════════════════════════════════════════

    /// How quickly does Eon adapt to new topics, new users, new styles?
    func measureAdaptationSpeed() async -> Double {
        let competencies = await competencySnapshot()
        let cs = CognitiveState.shared

        // 1. Time-to-competence for new domains
        let fastLearningDomains = competencies.filter { $0.value.level > 0.3 }
        let avgLearningSpeed = fastLearningDomains.isEmpty ? 0.3 :
            Double(fastLearningDomains.count) / Double(max(1, competencies.count))

        // 2. Learning velocity
        let velocityScore = min(1.0, abs(learningVelocity) * 0.5)

        // 3. Adaptivity dimension
        let adaptivityScore = await cs.dimensionLevel(.adaptivity)

        // 4. Strategy switching ability
        let strategyScore = min(1.0, Double(strategyHistory.count) / 10.0)

        let adaptationSpeed = avgLearningSpeed * 0.3 + velocityScore * 0.25 + adaptivityScore * 0.25 + strategyScore * 0.2

        return max(0.0, min(1.0, adaptationSpeed))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 160: Meta-Learning Cycle
    // ═══════════════════════════════════════════════════════════

    struct MetaLearningReport: Sendable {
        let learningPatterns: [String]
        let optimalStrategy: String
        let parameterUpdates: [String]
        let insights: [String]
        let recommendedActions: [String]
        let executedAt: Date
    }

    /// The ultimate meta-loop: analyze all learning data, identify patterns, update strategies.
    func executeMetaLearningCycle() async -> MetaLearningReport {
        let competencies = await competencySnapshot()
        let cs = CognitiveState.shared

        // 1. Analyze learning patterns
        var patterns: [String] = []

        // Pattern: Which domains grow fastest?
        let sortedByGrowth = competencies.sorted { $0.value.level > $1.value.level }
        if let top = sortedByGrowth.first {
            patterns.append("Snabbast lärande: \(top.key) (\(String(format: "%.0f", top.value.level * 100))%)")
        }

        // Pattern: Vocabulary learning rate
        let vocabRate = learningVelocity
        patterns.append("Ordförrådstillväxt: \(String(format: "%.1f", vocabRate)) ord/konversation")

        // Pattern: Strategy effectiveness
        if !strategyEffectiveness.isEmpty {
            let bestStrategy = strategyEffectiveness.max { ($0.value.reduce(0, +) / Double($0.value.count)) < ($1.value.reduce(0, +) / Double($1.value.count)) }
            if let best = bestStrategy {
                patterns.append("Bästa strategin: \(best.key) (genomsnittlig hastighet: \(String(format: "%.2f", best.value.reduce(0, +) / Double(max(1, best.value.count))))")
            }
        }

        // 2. Identify optimal strategy
        let weakDomains = sortedByGrowth.suffix(5).map { $0.key }
        let optimalStrategy: String
        if weakDomains.contains(where: { ["Morfologi", "Syntax"].contains($0) }) {
            optimalStrategy = "Strukturerad grammatikträning med FSRS + konversationspraxis"
        } else if weakDomains.contains(where: { ["Pragmatik", "Diskurs"].contains($0) }) {
            optimalStrategy = "Läs svensk litteratur och analysera idiom och diskursmönster"
        } else {
            optimalStrategy = "Bredda lärandet — utforska nya domäner parallellt"
        }

        // 3. Update learning parameters
        var parameterUpdates: [String] = []

        // Adjust learning velocity EMA
        let currentVelocity = learningVelocity
        if currentVelocity < 1.0 {
            parameterUpdates.append("Öka inlärningsintensitet — nuvarande hastighet låg")
        }

        // Adjust FSRS parameters based on retention
        let avgRetention = fsrsItems.filter { $0.reviewCount > 0 }.map { predictedRetention(for: $0) }
        if !avgRetention.isEmpty {
            let avgR = avgRetention.reduce(0, +) / Double(avgRetention.count)
            if avgR < 0.7 {
                parameterUpdates.append("FSRS retention för låg (\(String(format: "%.2f", avgR))) — justera intervaller")
            }
        }

        // 4. Generate insights
        let growthVelocity = await MainActor.run { cs.growthVelocity }
        let insights: [String] = [
            "Totalt \(swedishVocabularyCount()) svenska ord i ordförrådet",
            "Genomsnittlig kompetens: \(String(format: "%.0f", competencies.values.map { $0.level }.reduce(0, +) / Double(max(1, competencies.count)) * 100))%",
            "Kognitiv tillväxthastighet: \(String(format: "%.3f", growthVelocity)) per minut",
            "Antal aktiva FSRS-objekt: \(fsrsItems.count)",
            "Inlärningsstrategi: \(currentLearningStrategy.rawValue)",
        ]

        // 5. Recommended actions
        let recommendedActions: [String] = [
            "Prioritera de 3 svagaste domänerna: \(weakDomains.prefix(3).joined(separator: ", "))",
            "Generera dagliga FSRS-övningar för underrepresenterade domäner",
            "Utför kompetenskalibrering var 30:e sync-cykel",
            "Testa nya inlärningshypoteser via generateLearningHypothesis()",
            "Detektera och adressera inlärningsplatåer",
        ]

        return MetaLearningReport(
            learningPatterns: patterns,
            optimalStrategy: optimalStrategy,
            parameterUpdates: parameterUpdates,
            insights: insights,
            recommendedActions: recommendedActions,
            executedAt: Date()
        )
    }

    // ═══════════════════════════════════════════════════════════
    // HELPER: Conversation depth score (for meta-cognitive accuracy)
    // ═══════════════════════════════════════════════════════════

    func conversationDepthScore() async -> Double {
        let memory = PersistentMemoryStore.shared
        let recent = await memory.getRecentConversation(limit: 20)
        guard !recent.isEmpty else { return 0.3 }

        // Depth = average conversation length * topic continuity
        let avgLength = Double(recent.map { $0.content.components(separatedBy: .whitespaces).count }.reduce(0, +)) / Double(recent.count)
        let lengthScore = min(1.0, avgLength / 50.0)

        let topicContinuity = Double(getTopTopics(limit: 3).count) / 10.0

        return lengthScore * 0.6 + topicContinuity * 0.4
    }

    // ═══════════════════════════════════════════════════════════
    // HELPER: Recent response quality (for meta-cognitive accuracy)
    // ═══════════════════════════════════════════════════════════

    func recentResponseQuality() async -> Double {
        if qualityTracking.isEmpty { return 0.5 }
        let recent = qualityTracking.suffix(10)
        return recent.reduce(0, +) / Double(recent.count)
    }

    // ═══════════════════════════════════════════════════════════
    // HELPER: Recent competency gains (for meta-cognitive accuracy)
    // ═══════════════════════════════════════════════════════════

    func recentCompetencyGains() async -> Double {
        let competencies = await competencySnapshot()
        let levels = competencies.values.map { $0.level }
        guard levels.count >= 2 else { return 0.3 }
        let recent = levels.suffix(levels.count / 2)
        let older = levels.prefix(levels.count / 2)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(max(1, older.count))
        return max(0.0, recentAvg - olderAvg)
    }

    // ═══════════════════════════════════════════════════════════
    // FAS 2: Language System — Vocabulary & Competency
    // ═══════════════════════════════════════════════════════════

    func registerNewVocabulary(word: String, context: String) async {
        uniqueSwedishWords.insert(word)
        wordsLearnedToday += 1
        persistState()
        addFSRSItem(topic: "Ord: \(word)", domain: "Semantik", initialDifficulty: 0.3)
    }

    func adjustCompetency(_ domain: String, delta: Double) async {
        guard var comp = competencyBook[domain] else { return }
        comp.level = min(1.0, max(0.0, comp.level + delta))
        comp.lastStudied = Date()
        competencyBook[domain] = comp
        await saveCompetency(comp.level, domain: domain)
    }
}

// MARK: - Array safe subscript
