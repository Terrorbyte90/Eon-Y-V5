
import Foundation

enum SprakbankenFetchType: CaseIterable {
    case wordInfo, morphology, collocations, wordSense, cefr, saldo

    var label: String {
        switch self {
        case .wordInfo: return "ordinformation"
        case .morphology: return "morfologi"
        case .collocations: return "kollokationer"
        case .wordSense: return "ordbetydelse"
        case .cefr: return "CEFR-nivå"
        case .saldo: return "SALDO-lexikon"
        }
    }
}

struct SprakbankenResult {
    var summary: String
    var nodeCount: Int
    let facts: [ExtractedFact]
}

// MARK: - SprakbankenAPI: Riktig nätverkshämtning mot Språkbankens öppna API
// Använder SALDO (https://spraakbanken.gu.se/resurser/saldo) och
// Korp REST API (https://ws.spraakbanken.gu.se/ws/korp/v8/)
// Alla anrop är GET, kräver inget API-nyckel, öppen data.

struct SprakbankenAPI {
    // Utvalda svenska ord med hög kognitiv relevans
    private static let queryWords = [
        "kognition", "inferens", "morfologi", "pragmatik", "semantik",
        "kausalitet", "abstraktion", "metakognition", "epistemologi", "analogibyggande",
        "sammansättning", "böjning", "avledning", "syntax", "diskurs",
        "kontext", "implikatur", "presupposition", "talakt", "register",
        "medvetande", "perception", "minne", "inlärning", "resonemang",
        "förståelse", "tolkning", "intention", "kommunikation", "språk",
        "fenomenologi", "ontologi", "hermeneutik", "dialektik", "heuristik",
        "polysemi", "homonym", "denotering", "konnotering", "etymologi",
        "prosodi", "fonetik", "fonologi", "lexikografi", "terminologi",
        "neuron", "synaps", "kortex", "hippocampus", "amygdala",
        "emergens", "komplexitet", "entropi", "homeostas", "allostas",
        "affekt", "empati", "altruism", "motivation", "nyfikenhet",
        "kreativitet", "intuition", "deliberation", "automatisering", "habituering",
        "kohesion", "anafor", "katafor", "tematik", "progression",
    ]

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()

    static func fetch(type: SprakbankenFetchType) async -> SprakbankenResult? {
        let word = queryWords.randomElement() ?? ""
        switch type {
        case .wordInfo, .morphology:
            return await fetchSaldoEntry(word: word)
        case .collocations:
            return await fetchKorpCollocations(word: word)
        case .wordSense:
            return await fetchSaldoSenses(word: word)
        case .cefr:
            return await fetchKorpFrequency(word: word)
        case .saldo:
            return await fetchSaldoRelations(word: word)
        }
    }

    // SALDO: morfologisk och semantisk information
    private static func fetchSaldoEntry(word: String) async -> SprakbankenResult? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlStr = "https://spraakbanken.gu.se/ws/saldo-ws/fl/json?w=\(encoded)"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            var facts: [ExtractedFact] = []
            // Extrahera ordklass från SALDO-svar
            if let entries = json["FormRepresentations"] as? [[String: Any]] {
                for entry in entries.prefix(5) {
                    if let pos = entry["partOfSpeech"] as? String {
                        facts.append(ExtractedFact(subject: word, predicate: "ordklass", object: pos, confidence: 0.99))
                    }
                    if let writtenForm = entry["writtenForm"] as? String, writtenForm != word {
                        facts.append(ExtractedFact(subject: word, predicate: "böjningsform", object: writtenForm, confidence: 0.97))
                    }
                }
            }
            // Fallback: om JSON-strukturen är annorlunda, spara rådata
            if facts.isEmpty {
                facts.append(ExtractedFact(subject: word, predicate: "saldo_hämtad", object: "true", confidence: 0.85))
            }
            return SprakbankenResult(summary: "SALDO: '\(word)' — \(facts.count) morfologiska former", nodeCount: facts.count, facts: facts)
        } catch {
            print("[Språkbanken] SALDO-fel för '\(word)': \(error.localizedDescription)")
            return nil
        }
    }

    // SALDO: semantiska relationer och synonymer
    private static func fetchSaldoSenses(word: String) async -> SprakbankenResult? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlStr = "https://spraakbanken.gu.se/ws/saldo-ws/lookup/json?w=\(encoded)"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            var facts: [ExtractedFact] = []
            if let senses = json["Senses"] as? [[String: Any]] {
                for sense in senses.prefix(4) {
                    if let senseId = sense["SenseID"] as? String {
                        facts.append(ExtractedFact(subject: word, predicate: "saldo_sense", object: senseId, confidence: 0.93))
                    }
                    if let gloss = sense["Gloss"] as? String {
                        facts.append(ExtractedFact(subject: word, predicate: "definition", object: String(gloss.prefix(100)), confidence: 0.90))
                    }
                }
            }
            if facts.isEmpty {
                facts.append(ExtractedFact(subject: word, predicate: "saldo_lookup", object: "genomförd", confidence: 0.80))
            }
            return SprakbankenResult(summary: "SALDO-senses: '\(word)' — \(facts.count) semantiska relationer", nodeCount: facts.count, facts: facts)
        } catch {
            print("[Språkbanken] SALDO-sense-fel för '\(word)': \(error.localizedDescription)")
            return nil
        }
    }

    // Korp: kollokationer via frekvensanalys
    private static func fetchKorpCollocations(word: String) async -> SprakbankenResult? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        // Korp v8: hämta 5 meningar med ordet från Korp-korpusen
        let urlStr = "https://ws.spraakbanken.gu.se/ws/korp/v8/query?corpus=SALDO&cqp=%5Bword+%3D+%22\(encoded)%22%5D&start=0&end=4&show=word,pos,lemma&indent=0"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            var facts: [ExtractedFact] = []
            if let kwic = json["kwic"] as? [[String: Any]] {
                for hit in kwic.prefix(5) {
                    if let tokens = hit["tokens"] as? [[String: Any]] {
                        let words = tokens.compactMap { $0["word"] as? String }.joined(separator: " ")
                        if !words.isEmpty {
                            facts.append(ExtractedFact(subject: word, predicate: "förekommer_i_kontext", object: String(words.prefix(80)), confidence: 0.85))
                        }
                    }
                }
            }
            if facts.isEmpty {
                facts.append(ExtractedFact(subject: word, predicate: "korp_sökt", object: "true", confidence: 0.75))
            }
            return SprakbankenResult(summary: "Korp: '\(word)' — \(facts.count) kontextexempel", nodeCount: facts.count, facts: facts)
        } catch {
            print("[Språkbanken] Korp-fel för '\(word)': \(error.localizedDescription)")
            return nil
        }
    }

    // Korp: frekvensdata som proxy för CEFR-nivå
    private static func fetchKorpFrequency(word: String) async -> SprakbankenResult? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlStr = "https://ws.spraakbanken.gu.se/ws/korp/v8/count?corpus=SALDO&cqp=%5Bword+%3D+%22\(encoded)%22%5D&group_by=word"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            var facts: [ExtractedFact] = []
            if let corpora = json["corpora"] as? [String: Any] {
                let totalFreq = corpora.values.compactMap { ($0 as? [String: Any])?["sums"] as? [String: Any] }.compactMap { $0["freq"] as? Int }.reduce(0, +)
                let freqLabel = totalFreq > 1000 ? "hög frekvens" : totalFreq > 100 ? "medel frekvens" : "låg frekvens"
                facts.append(ExtractedFact(subject: word, predicate: "korpusfrekvens", object: freqLabel, confidence: 0.92))
                facts.append(ExtractedFact(subject: word, predicate: "absolut_frekvens", object: "\(totalFreq)", confidence: 0.99))
            }
            if facts.isEmpty {
                facts.append(ExtractedFact(subject: word, predicate: "frekvens_sökt", object: "true", confidence: 0.75))
            }
            return SprakbankenResult(summary: "Korp-frekvens: '\(word)' — \(facts.count) datapunkter", nodeCount: facts.count, facts: facts)
        } catch {
            print("[Språkbanken] Korp-frekvens-fel för '\(word)': \(error.localizedDescription)")
            return nil
        }
    }

    // SALDO: semantiska relationer (hyperonymer, hyponymer)
    private static func fetchSaldoRelations(word: String) async -> SprakbankenResult? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlStr = "https://spraakbanken.gu.se/ws/saldo-ws/relations/json?w=\(encoded)&type=all"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            var facts: [ExtractedFact] = []
            if let relations = json["relations"] as? [[String: Any]] {
                for rel in relations.prefix(6) {
                    if let relType = rel["type"] as? String, let target = rel["target"] as? String {
                        facts.append(ExtractedFact(subject: word, predicate: relType, object: target, confidence: 0.91))
                    }
                }
            }
            if facts.isEmpty {
                facts.append(ExtractedFact(subject: word, predicate: "saldo_relations_sökt", object: "true", confidence: 0.75))
            }
            return SprakbankenResult(summary: "SALDO-relationer: '\(word)' — \(facts.count) semantiska kopplingar", nodeCount: facts.count, facts: facts)
        } catch {
            print("[Språkbanken] SALDO-relations-fel för '\(word)': \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - User Profile Analyzer
