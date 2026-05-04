
import Foundation

struct ParallelDrawingEngine {
    /// Domain relationship map — which domains share structural similarities
    private static let domainParallels: [String: [String: String]] = [
        "Kognitionsvetenskap": [
            "AI & Teknik": "informationsbearbetning och representationslärande",
            "Psykologi": "uppmärksamhet, minne och beslutsfattande",
            "Filosofi": "medvetandeproblemet och intentionalitet",
            "Biologi": "neurala nätverk och hjärnans arkitektur",
            "Lingvistik": "språklig kognition och mentala grammatiker",
            "Matematik": "formella modeller av tänkande och logik",
        ],
        "AI & Teknik": [
            "Kognitionsvetenskap": "lärande algoritmer inspirerade av kognition",
            "Språk": "naturlig språkbehandling och semantisk analys",
            "Matematik": "optimering och statistisk inferens",
            "Filosofi": "artificiellt medvetande och maskinetik",
            "Biologi": "evolutionära algoritmer och neuromorfa system",
            "Psykologi": "reinforcement learning och beteendemodellering",
        ],
        "Filosofi": [
            "Psykologi": "medvetande, fri vilja och moralisk intuition",
            "Historia": "idéhistoria och kunskapens utveckling",
            "Kognitionsvetenskap": "epistemologi och kunskapsrepresentation",
            "Fysik": "tidens natur, determinism och kvantmekanik",
            "Biologi": "bioetik, naturteleologi och evolutionens mening",
            "Lingvistik": "språkfilosofi, referens och mening",
        ],
        "Historia": [
            "Psykologi": "massbeteende och sociala mönster",
            "Filosofi": "idéernas inverkan på samhällsförändring",
            "Ekonomi": "ekonomiska system och maktstrukturer genom historien",
            "Lingvistik": "språkförändring och kulturell transmission",
        ],
        "Psykologi": [
            "Biologi": "neurovetenskap, hormoner och beteende",
            "Filosofi": "medvetandets natur och fenomenologi",
            "Kognitionsvetenskap": "kognitiva processer och mental arkitektur",
            "Lingvistik": "språk och tanke, psykolingvistik",
            "Historia": "socialpsykologi och historiska beteendemönster",
        ],
        "Lingvistik": [
            "Kognitionsvetenskap": "mental grammatik och språkprocessering",
            "AI & Teknik": "datadriven språkanalys och NLP",
            "Filosofi": "semantik, pragmatik och meningsteori",
            "Psykologi": "språkinlärning och kognitiv utveckling",
            "Historia": "etymologi och språkhistorisk förändring",
        ],
        "Biologi": [
            "Kognitionsvetenskap": "hjärna, perception och neurala processer",
            "Filosofi": "medvetandets biologiska grund och bioetik",
            "AI & Teknik": "bioinspierade algoritmer och neuromorfa chip",
            "Psykologi": "genetik, epigenetik och beteende",
        ],
        "Matematik": [
            "Filosofi": "logikens grund, Gödel och matematisk sanning",
            "AI & Teknik": "statistik, optimering och algoritmteori",
            "Fysik": "matematisk modellering av naturlagar",
            "Lingvistik": "formella grammatiker och beräkningslingvistik",
        ],
    ]

    static func findParallels(newFacts: [ExtractedFact], domain: String, knowledgeCount: Int) -> String? {
        guard knowledgeCount > 5, !newFacts.isEmpty else { return nil }

        // Check if we have causal facts — these are most informative for parallels
        let causalFacts = newFacts.filter { ["orsakar", "påverkar", "kräver", "möjliggör"].contains($0.predicate) }
        let identityFacts = newFacts.filter { $0.predicate == "är" }

        // Strategy 1: Causal chain detection
        if causalFacts.count >= 2 {
            let chain = causalFacts.prefix(3).map { "\($0.subject) → \($0.object)" }.joined(separator: " → ")
            return "Kausalkedja i \(domain): \(chain)"
        }

        // Strategy 2: Domain cross-reference
        if let parallelDomains = domainParallels[domain] {
            let subjects = Set(newFacts.map { $0.subject.lowercased() })
            for (targetDomain, connection) in parallelDomains {
                // Check if any fact subjects relate to the parallel domain
                let targetKeywords = targetDomain.lowercased().components(separatedBy: .whitespaces)
                if subjects.contains(where: { s in targetKeywords.contains(where: { s.contains($0) }) }) {
                    return "Domänparallell: \(domain) ↔ \(targetDomain) via \(connection)"
                }
            }
        }

        // Strategy 3: Classification facts → taxonomy insight
        if identityFacts.count >= 2 {
            let categories = identityFacts.prefix(3).map { "\($0.subject) = \($0.object)" }.joined(separator: ", ")
            return "Taxonomisk struktur i \(domain): \(categories)"
        }

        // Strategy 4: Concept density — many facts about same subject → deep topic
        let subjectCounts: [String: Int] = Dictionary(newFacts.map { ($0.subject, 1) }, uniquingKeysWith: +)
        if let (densestSubject, count) = subjectCounts.max(by: { $0.value < $1.value }), count >= 3 {
            return "Kärnbegrepp i \(domain): '\(densestSubject)' (förekommer i \(count) relationer)"
        }

        return nil
    }
}

// MARK: - Cross Article Analyzer
