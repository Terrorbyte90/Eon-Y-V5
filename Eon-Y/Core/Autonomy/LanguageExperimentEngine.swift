import Foundation

struct LanguageExperiment {
    let baseWord: String
    let derivedForm: String
    let rule: String
    let testSentence: String
    let isValid: Bool
    let isNovel: Bool
}

struct LanguageExperimentEngine {
    private static let morphRules: [(rule: String, suffixes: [String])] = [
        ("Plural obestämd", ["-ar", "-er", "-or", "-n"]),
        ("Diminutiv", ["-ling"]),
        ("Agentiv", ["-are"]),
        ("Abstrakt substantiv", ["-het", "-skap", "-ning", "-ande", "-else"]),
        ("Bestämd singular", ["-en", "-et", "-n"]),
        ("Komparativ", ["-are"]),
        ("Superlativ", ["-ast"]),
        ("Passiv", ["-s"]),
        ("Negation prefix", ["o-", "miss-", "van-"]),
        ("Adverbderivation", ["-ligen", "-t"]),
        ("Abstrakt mått", ["-lek"]),
        ("Abstrakt relation", ["-skap"]),
        ("Verbal substantiv", ["-ning", "-ande"]),
        ("Adj. från verb", ["-lig", "-bar"]),
    ]

    /// Generate a language experiment using dynamic word selection from vocabulary
    static func generate(stage: DevelopmentalStage, existingExperiments: [LanguageExperiment]) async -> LanguageExperiment {
        // Try to use a word from the learned vocabulary for dynamic experiments
        let memory = PersistentMemoryStore.shared
        let learnedWords = await memory.getRecentlyLearnedWords(limit: 30)

        // Filter out words already used in experiments
        let usedWords = Set(existingExperiments.map { $0.baseWord })
        let availableWords = learnedWords.filter { !usedWords.contains($0.word) }

        // Select word: prefer vocabulary words, fall back to static pairs
        if let selectedWord = availableWords.randomElement() {
            return await generateDynamicExperiment(
                baseWord: selectedWord.word,
                stage: stage,
                existingExperiments: existingExperiments
            )
        }

        // Fall back to static word pairs
        return generateStaticExperiment(stage: stage, existingExperiments: existingExperiments)
    }

    // MARK: - Dynamic Experiment Generation

    /// Generate an experiment using a word from the learned vocabulary
    private static func generateDynamicExperiment(
        baseWord: String,
        stage: DevelopmentalStage,
        existingExperiments: [LanguageExperiment]
    ) async -> LanguageExperiment {
        // Select an appropriate morphological rule based on stage
        let availableRules: [(rule: String, suffixes: [String])] = {
            switch stage {
            case .toddler:
                return morphRules.filter { ["Bestämd singular", "Plural obestämd"].contains($0.rule) }
            case .child:
                return morphRules.filter { ["Bestämd singular", "Plural obestämd", "Komparativ", "Agentiv"].contains($0.rule) }
            case .adolescent:
                return morphRules.filter { !$0.rule.contains("Negation") }
            case .mature:
                return morphRules
            }
        }()

        guard let rule = availableRules.randomElement() else {
            return generateStaticExperiment(stage: stage, existingExperiments: existingExperiments)
        }

        // Ask the neural engine to derive the form
        let prompt = """
        Du är en svensk grammatikexpert. Ord: "\(baseWord)"
        Tillämpa regeln "\(rule.rule)" med suffix \(rule.suffixes.joined(separator: ", ")).
        Svara EXAKT i JSON: {"derivedForm":"","testSentence":"","isValid":true}
        """
        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt,
            maxTokens: 100,
            temperature: 0.3
        )

        // Parse response
        if let data = extractJSON(from: response),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let derivedForm = json["derivedForm"] as? String,
           let testSentence = json["testSentence"] as? String,
           let isValid = json["isValid"] as? Bool {

            let isNovel = existingExperiments.filter { $0.baseWord == baseWord }.isEmpty

            return LanguageExperiment(
                baseWord: baseWord,
                derivedForm: derivedForm,
                rule: rule.rule,
                testSentence: testSentence,
                isValid: isValid,
                isNovel: isNovel
            )
        }

        // Fallback: use static generation
        return generateStaticExperiment(stage: stage, existingExperiments: existingExperiments)
    }

    // MARK: - Static Experiment Generation (fallback)

    private static func generateStaticExperiment(
        stage: DevelopmentalStage,
        existingExperiments: [LanguageExperiment]
    ) -> LanguageExperiment {
        let wordPairs: [(String, String, String, String)] = [
            ("springa", "springer", "Presens", "Hen springer snabbt."),
            ("kärlek", "kärleken", "Bestämd form", "Kärleken är stark."),
            ("glad", "gladare", "Komparativ", "Hon är gladare idag."),
            ("arbeta", "arbetare", "Agentiv", "Arbetaren jobbar hårt."),
            ("fri", "frihet", "Abstrakt substantiv", "Friheten är ovärderlig."),
            ("lära", "lärande", "Gerundium", "Lärandet sker kontinuerligt."),
            ("stor", "storlek", "Abstrakt mått", "Storleken varierar."),
            ("vän", "vänskap", "Abstrakt relation", "Vänskapen varar länge."),
            ("skriva", "skrivning", "Verbal substantiv", "Skrivningen tar tid."),
            ("tänka", "tänkande", "Kognitiv process", "Tänkandet är komplext."),
            ("stark", "starkast", "Superlativ", "Det var det starkaste argumentet."),
            ("bygga", "byggdes", "Passiv preteritum", "Huset byggdes förra året."),
            ("snabb", "snabbt", "Adverb", "Bilen körde snabbt förbi."),
            ("ung", "ungdom", "Abstrakt derivation", "Ungdomen är kort men intensiv."),
            ("veta", "visste", "Preteritum irreg.", "Han visste svaret direkt."),
            ("se", "synlig", "Adj. från verb", "Stjärnorna är synliga i natt."),
            ("sluta", "slutligen", "Adverbderivation", "Slutligen nådde vi målet."),
            ("möjlig", "omöjlig", "Negationsprefix", "Det verkade omöjligt att lösa."),
            ("kraft", "kraftfull", "Adj. suffixering", "En kraftfull förklaring."),
            ("tanke", "tankefull", "Sammansättning+adj", "Hon var tankefull och tyst."),
        ]

        let pair = wordPairs.randomElement() ?? ("", "", "", "")
        let isNovel = existingExperiments.filter { $0.baseWord == pair.0 }.isEmpty

        return LanguageExperiment(
            baseWord: pair.0,
            derivedForm: pair.1,
            rule: pair.2,
            testSentence: pair.3,
            isValid: true,
            isNovel: isNovel
        )
    }

    // MARK: - Helper

    private static func extractJSON(from response: String) -> Data? {
        guard let s = response.firstIndex(of: "{"),
              let e = response.lastIndex(of: "}") else { return nil }
        return String(response[s...e]).data(using: .utf8)
    }
}
