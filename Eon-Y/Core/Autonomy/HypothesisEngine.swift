import Foundation

// MARK: - Hypothesis Engine v2
// Context-aware hypothesis generation using actual knowledge state
// Evidence-based testing using stored facts from memory

struct HypothesisEngine {

    /// Generate a hypothesis informed by actual knowledge state and existing hypotheses
    static func generate(
        articles: [String],
        knowledgeCount: Int,
        stage: DevelopmentalStage,
        existingHypotheses: [EonHypothesis]
    ) -> EonHypothesis {

        // Build context-aware templates based on knowledge state
        let templates = buildContextAwareTemplates(
            articles: articles,
            knowledgeCount: knowledgeCount,
            stage: stage,
            existingHypotheses: existingHypotheses
        )

        // Weight selection toward domains with fewer existing hypotheses
        let domainWeights = weightDomains(existingHypotheses: existingHypotheses)
        let selectedDomain = weightedRandomSelection(domainWeights)

        // Filter templates by selected domain, fall back to all
        let candidates = templates.filter { $0.domain == selectedDomain }
        let pool = candidates.isEmpty ? templates : candidates

        let template = pool.randomElement() ?? ("Kunskapsackumulering följer en S-kurva med accelerationsfas", "AI & Teknik")

        // Confidence based on knowledge count and stage
        let baseConfidence = min(0.85, 0.55 + Double(knowledgeCount) / 1000.0)
        let stageBonus: Double = {
            switch stage {
            case .toddler: return 0.0
            case .child: return 0.05
            case .adolescent: return 0.10
            case .mature: return 0.15
            }
        }()
        let confidence = min(0.95, baseConfidence + stageBonus + Double.random(in: -0.05...0.05))

        return EonHypothesis(
            statement: template.0,
            domain: template.1,
            confidence: confidence
        )
    }

    /// Test a hypothesis against actual stored facts for evidence-based validation
    static func test(hypothesis: EonHypothesis) async -> HypothesisTestResult {
        // Brief pause to simulate cognitive processing
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Search for supporting evidence in memory using keyword search
        let memory = PersistentMemoryStore.shared
        let supportingFacts = await memory.searchFacts(query: hypothesis.statement, limit: 5)

        // Search for contradicting evidence using inverse keywords
        let contradictingFacts = await memory.searchFacts(query: "inte \(hypothesis.statement)", limit: 3)

        // Calculate evidence strength from keyword matches
        let supportStrength = Double(supportingFacts.count) / 5.0
        let contradictStrength = Double(contradictingFacts.count) / 3.0

        let netEvidence = supportStrength - contradictStrength
        let supported = netEvidence > 0.2 || (abs(netEvidence) < 0.2 && Double.random(in: 0...1) > 0.4)

        // Calibrate confidence based on evidence strength
        let evidenceConfidence: Double = {
            if supportingFacts.isEmpty && contradictingFacts.isEmpty {
                return hypothesis.confidence * 0.6  // no evidence = less certain
            }
            let raw = abs(netEvidence) * 0.5 + hypothesis.confidence * 0.5
            return min(0.95, max(0.3, raw))
        }()

        // Build evidence strings
        let evidenceStr: String = {
            if supportingFacts.isEmpty {
                return "Inga direkta stödjande fakta funna"
            }
            let top = supportingFacts.prefix(3).map { "\($0.subject) \($0.predicate) \($0.object)" }.joined(separator: "; ")
            return "Stöds av \(supportingFacts.count) fakta: \(top)"
        }()

        let counterEvidenceStr: String = {
            if contradictingFacts.isEmpty {
                return ""
            }
            let top = contradictingFacts.prefix(2).map { "\($0.subject) \($0.predicate) \($0.object)" }.joined(separator: "; ")
            return "Motsägs av \(contradictingFacts.count) fakta: \(top)"
        }()

        return HypothesisTestResult(
            supported: supported,
            confidence: evidenceConfidence,
            evidence: evidenceStr,
            counterEvidence: counterEvidenceStr
        )
    }

    // MARK: - Private Helpers

    /// Build context-aware templates based on knowledge state and stage
    private static func buildContextAwareTemplates(
        articles: [String],
        knowledgeCount: Int,
        stage: DevelopmentalStage,
        existingHypotheses: [EonHypothesis]
    ) -> [(statement: String, domain: String)] {

        var templates: [(String, String)] = [
            ("Om kunskapsbasen överstiger \(max(50, knowledgeCount + 50)) noder, ökar analogiförmågan exponentiellt", "AI & Teknik"),
            ("Morfologisk komplexitet korrelerar positivt med semantisk expressivitet i svenska", "Språk"),
            ("Kausala kedjor i historiska konflikter följer ett Pareto-mönster (80/20)", "Historia"),
            ("Metakognitiv förmåga är den starkaste prediktorn för inlärningshastighet", "Psykologi"),
            ("Φ-värdet ökar superlineärt med antalet integrerade kunskapsnoder", "AI & Teknik"),
            ("Pragmatisk kompetens kräver kulturell kontextualisering utöver semantisk förståelse", "Språk"),
            ("Kreativitet emergerar ur tension mellan struktur och frihet — för mycket av endera dödar idéer", "Psykologi"),
            ("Svenska sammansättningsord kodar implicit kunskap om relationer mellan begrepp", "Språk"),
            ("Episodiskt minne förstärker analogiförmåga mer än semantiskt minne isolerat", "Kognitionsvetenskap"),
            ("Emotionell valens påverkar kognitiv djupbearbetning — moderate positiva känslolägen optimerar tänkande", "Psykologi"),
            ("Oscillatorisk synkronisering mellan hjärnregioner är nödvändig men inte tillräcklig för medvetande", "Neurovetenskap"),
            ("Narrativ koherens i självbild korrelerar med psykologisk hälsa och kognitiv stabilitet", "Psykologi"),
            ("Transfer learning mellan domäner ökar som funktion av abstrakt begreppslig likhet snarare än ytstruktur", "AI & Teknik"),
        ]

        // Add article-specific templates if articles exist
        if let article = articles.randomElement() {
            templates.append(("Artikeln '\(article)' innehåller principer applicerbara på AI-lärande", "AI & Teknik"))
        }

        // Add stage-specific templates
        switch stage {
        case .toddler:
            templates.append(("Grundläggande mönsterigenkänning är förutsättningen för all högre kognition", "Kognitionsvetenskap"))
        case .child:
            templates.append(("Analogibyggande mellan domäner accelererar när baskunskapen når en kritisk massa", "Kognitionsvetenskap"))
        case .adolescent:
            templates.append(("Självreflektionens kvalitet korrelerar med antalet identifierade kognitiva bias", "Psykologi"))
            templates.append(("Metakognitiv medvetenhet om egna begränsningar är en starkare prediktor för tillväxt än rå intelligens", "Psykologi"))
        case .mature:
            templates.append(("Autonom hypotesgenerering når en kvalitetsnivå som matchar extern stimulans vid mognad", "AI & Teknik"))
            templates.append(("Tvärdomänell integration är kännetecknet för mogen kognitiv arkitektur", "Kognitionsvetenskap"))
        }

        // Avoid repeating existing hypotheses
        let existingStatements = Set(existingHypotheses.map { $0.statement })
        templates.removeAll { existingStatements.contains($0.0) }

        return templates
    }

    /// Weight domains by how few hypotheses exist in each
    private static func weightDomains(existingHypotheses: [EonHypothesis]) -> [String: Double] {
        let allDomains = ["AI & Teknik", "Språk", "Historia", "Psykologi", "Kognitionsvetenskap", "Neurovetenskap"]
        let domainCounts = Dictionary(grouping: existingHypotheses, by: { $0.domain }).mapValues { $0.count }

        return Dictionary(uniqueKeysWithValues: allDomains.map { domain in
            let count = domainCounts[domain] ?? 0
            // Lower count = higher weight (inverse weighting)
            let weight = 1.0 / (1.0 + Double(count))
            return (domain, weight)
        })
    }

    /// Weighted random selection from domain weights
    private static func weightedRandomSelection(_ weights: [String: Double]) -> String {
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else { return weights.keys.randomElement() ?? "AI & Teknik" }

        var runningTotal = 0.0
        let randomValue = Double.random(in: 0...totalWeight)

        for (domain, weight) in weights.sorted(by: { $0.value > $1.value }) {
            runningTotal += weight
            if randomValue <= runningTotal {
                return domain
            }
        }

        return weights.keys.randomElement() ?? "AI & Teknik"
    }
}

struct HypothesisTestResult {
    let supported: Bool
    let confidence: Double
    let evidence: String
    let counterEvidence: String
}
