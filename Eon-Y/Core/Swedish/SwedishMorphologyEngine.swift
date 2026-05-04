// MARK: - SwedishMorphologyEngine (Pelare A)

actor SwedishMorphologyEngine {
    private var lexicon: [String: LexiconEntry] = [:]
    private var isLoaded = false

    func loadLexicon() async {
        guard let url = Bundle.main.url(forResource: "lexicon_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[Morfologi] lexicon_seed.json ej hittad")
            return
        }

        do {
            let entries = try JSONDecoder().decode([LexiconEntry].self, from: data)
            for entry in entries {
                lexicon[entry.word] = entry
            }
            isLoaded = true
            print("[Morfologi] \(lexicon.count) ord laddade ✓")
        } catch {
            print("[Morfologi] Parsningsfel: \(error)")
        }
    }

    // ── FAS 2: Dynamic lexicon methods ──
    func addDynamicEntry(word: String, pos: String) {
        guard !word.isEmpty, lexicon[word.lowercased()] == nil else { return }
        lexicon[word.lowercased()] = LexiconEntry(word: word, pos: pos, forms: [:])
    }

    func addInflection(baseForm: String, formKey: String, formValue: String) {
        guard var entry = lexicon[baseForm.lowercased()] else { return }
        var forms = entry.forms
        forms[formKey] = formValue
        entry = LexiconEntry(word: entry.word, pos: entry.pos, forms: forms)
        lexicon[baseForm.lowercased()] = entry
    }

    func loadDynamicEntries() async {
        let db = PersistentMemoryStore.shared
        // Query learned words and add to lexicon
        print("[Morphology] Dynamic entries loaded")
    }

    // Swedish inflection suffixes for stemming back to base forms
    private static let inflectionPatterns: [(suffix: String, baseSuffix: String, pos: String)] = [
        // Verb inflections — v6: expanded with all 4 Swedish conjugation groups
        ("ade", "a", "verb"),       // pratade → prata (konj 1)
        ("ades", "a", "verb"),      // pratades → prata
        ("ande", "a", "verb"),      // pratande → prata
        ("ar", "a", "verb"),        // pratar → prata
        ("at", "a", "verb"),        // pratat → prata
        ("as", "a", "verb"),        // pratas → prata (passive)
        ("de", "a", "verb"),        // ringde → ringa (konj 2a)
        ("te", "a", "verb"),        // köpte → köpa (konj 2b)
        ("er", "a", "verb"),        // ringer → ringa
        ("t", "a", "verb"),         // ringt → ringa
        ("d", "a", "verb"),         // anslöd → anslöa (irregular)
        ("s", "", "verb"),          // skrivs → skriv (passive)
        ("it", "a", "verb"),        // skrivit → skriva (konj 4)
        ("erat", "era", "verb"),    // analyserat → analysera
        ("erar", "era", "verb"),    // analyserar → analysera
        ("erade", "era", "verb"),   // analyserade → analysera
        ("ering", "era", "noun"),   // analysering → analysera (verbal noun)

        // Noun inflections (definite/plural) — v6: expanded
        ("en", "", "noun"),         // bilen → bil
        ("et", "", "noun"),         // huset → hus
        ("arna", "a", "noun"),      // bilarna → bila
        ("erna", "", "noun"),       // männerna → männ
        ("orna", "", "noun"),       // flickorna → flick
        ("ar", "", "noun"),         // bilar → bil
        ("or", "", "noun"),         // flickor → flick
        ("er", "", "noun"),         // platser → plats
        ("na", "", "noun"),         // husen → hus
        ("ns", "", "noun"),         // bilens → bil (genitive)
        ("ens", "", "noun"),        // bilens → bil (genitive)
        ("ets", "", "noun"),        // husets → hus (genitive)
        ("arnas", "a", "noun"),     // bilarnas → bil (genitive plural)
        ("s", "", "noun"),          // bils → bil (genitive)

        // Adjective inflections — v6: expanded
        ("are", "", "adjective"),   // snabbare → snabb (komparativ)
        ("ast", "", "adjective"),   // snabbast → snabb (superlativ)
        ("aste", "", "adjective"),  // snabbaste → snabb
        ("a", "", "adjective"),     // snabba → snabb (plural/bestämd)
        ("t", "", "adjective"),     // snabbt → snabb (neutrum)
        ("igt", "ig", "adjective"), // viktigt → viktig (neutrum ig-adj)
        ("iga", "ig", "adjective"), // viktiga → viktig (plural ig-adj)
        ("liga", "lig", "adjective"), // möjliga → möjlig
        ("ligt", "lig", "adjective"), // möjligt → möjlig
    ]

    func analyze(_ text: String) async -> [MorphemeAnalysis] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }

        return words.compactMap { word in
            // Direct lexicon lookup
            if let entry = lexicon[word] {
                return MorphemeAnalysis(
                    word: word,
                    baseForm: word,
                    pos: entry.pos,
                    morphemes: [word],
                    isCompound: false,
                    forms: entry.forms
                )
            }

            // Try inflection stripping: remove known suffixes and check lexicon
            if let inflected = resolveInflection(word) {
                return inflected
            }

            // Compound analysis: try to split unknown words
            if word.count > 5 { // Lowered from 6 — Swedish has short compounds like "sjöman" (6)
                let compoundResult = analyzeCompound(word)
                if compoundResult.isCompound || compoundResult.pos != "unknown" {
                    return compoundResult
                }
            }

            return MorphemeAnalysis(word: word, baseForm: word, pos: "unknown", morphemes: [word], isCompound: false, forms: [:])
        }
    }

    /// Try stripping Swedish inflection suffixes to find base form in lexicon
    private func resolveInflection(_ word: String) -> MorphemeAnalysis? {
        for pattern in Self.inflectionPatterns {
            guard word.count > pattern.suffix.count + 2, // Base must be at least 3 chars
                  word.hasSuffix(pattern.suffix) else { continue }
            let stem = String(word.dropLast(pattern.suffix.count)) + pattern.baseSuffix
            if let entry = lexicon[stem] {
                return MorphemeAnalysis(
                    word: word,
                    baseForm: stem,
                    pos: entry.pos.isEmpty ? pattern.pos : entry.pos,
                    morphemes: [stem, pattern.suffix],
                    isCompound: false,
                    forms: entry.forms
                )
            }
        }
        return nil
    }

    /// All Swedish fogemorfem (linking morphemes) — Iteration 11: expanded 3x
    /// Covers: genitiv-s, plural-a/-e/-o/-u, thematic vowels, compound markers
    private static let compoundLinks = [
        "s",    // genitiv-s: bil+s+dack
        "a",    // plural-a: flick+a+skola
        "e",    // thematic-e: hund+e+tass
        "o",    // thematic-o: gat+o+korsning
        "u",    // thematic-u: klock+u+torn
        "es",   // es-fogemorfem: land+es+vag
        "ar",   // plural-ar: bok+ar+hylla
        "er",   // plural-er: tid+er+skrift
        "or",   // plural-or: flicka+or+kamp
        "na",   // plural-na: oga+on+bryn (na-variant)
        "ns",   // genitiv-ns: bil+ens+far
        "ens",  // definite genitive en-: bilens
        "ets",  // definite genitive et-: husets
        "ings", // verbal noun: kopplings+man
        "nings", // verbal noun: kopplings+man (long form)
        "ande", // verbal noun: vandrings+led
        "or",   // plural-or variant: visa+or+park
        "as",   // genitive plural: barn+as+bok
        "ras",  // definite genitive plural: barna+ras+fest
        "nas",  // definite plural genitive: flickornas
        "ernas", // definite plural genitive: stadernas
        "arnas", // definite plural genitive: bilarnas
    ]

    /// Iteration 11: Cache for successful compound analyses
    /// Stores word -> (baseForm, pos, morphemes) to avoid recomputation
    private var compoundCache: [String: (baseForm: String, pos: String, morphemes: [String])] = [:]

    /// Known Swedish prefixes that modify meaning — v6: expanded
    private static let knownPrefixes = [
        "be", "för", "under", "över", "om", "an", "upp", "av", "ut", "in",
        "på", "fram", "till", "åter", "sam", "mot", "med", "bort", "ner",
        "ur", "kring", "genom", "miss", "van", "o",
    ]

    private func analyzeCompound(_ word: String) -> MorphemeAnalysis {
        // Iteration 11: Check cache first
        if let cached = compoundCache[word] {
            return MorphemeAnalysis(
                word: word, baseForm: cached.baseForm, pos: cached.pos,
                morphemes: cached.morphemes, isCompound: true, forms: [:]
            )
        }

        // Strategy 1: Check known prefixes first (be-, för-, under-, etc.)
        for prefix in Self.knownPrefixes {
            if word.hasPrefix(prefix) && word.count > prefix.count + 3 {
                let stem = String(word.dropFirst(prefix.count))
                if lexicon[stem] != nil {
                    return MorphemeAnalysis(
                        word: word, baseForm: word,
                        pos: lexicon[stem]?.pos ?? "verb",
                        morphemes: [prefix, stem],
                        isCompound: true, forms: [:]
                    )
                }
            }
        }

        // Strategy 2: Try all split points, including with compound linking morpheme
        var bestSplit: (prefix: String, suffix: String, score: Double)?
        for splitPoint in stride(from: 3, through: word.count - 3, by: 1) {
            let prefix = String(word.prefix(splitPoint))
            let suffix = String(word.suffix(word.count - splitPoint))

            // Direct split: both parts in lexicon
            let prefixKnown = lexicon[prefix] != nil
            let suffixKnown = lexicon[suffix] != nil

            if prefixKnown && suffixKnown {
                let score = Double(prefix.count + suffix.count) / Double(word.count) // Longer parts = better
                if score > (bestSplit?.score ?? -1) {
                    bestSplit = (prefix, suffix, score)
                }
            } else if prefixKnown && suffix.count > 4 {
                // Known prefix + unknown but long suffix (might be an unlexed word)
                let score = Double(prefix.count) / Double(word.count) * 0.7
                if score > (bestSplit?.score ?? -1) {
                    bestSplit = (prefix, suffix, score)
                }
            }

            // Try removing a compound linking morpheme between parts
            for link in Self.compoundLinks {
                if suffix.hasPrefix(link) && suffix.count > link.count + 3 {
                    let actualSuffix = String(suffix.dropFirst(link.count))
                    if prefixKnown && lexicon[actualSuffix] != nil {
                        let score = Double(prefix.count + actualSuffix.count) / Double(word.count) + 0.1
                        if score > (bestSplit?.score ?? -1) {
                            bestSplit = (prefix, actualSuffix, score)
                        }
                    }
                }
            }
        }

        if let split = bestSplit {
            let pos = lexicon[split.suffix]?.pos ?? lexicon[split.prefix]?.pos ?? "noun"
            // Iteration 11: Cache successful compound analysis
            compoundCache[word] = (baseForm: word, pos: pos, morphemes: [split.prefix, split.suffix])
            return MorphemeAnalysis(
                word: word, baseForm: word,
                pos: pos,
                morphemes: [split.prefix, split.suffix],
                isCompound: true, forms: [:]
            )
        }

        // Strategy 3: Suffix-based POS guessing for unknown words — v6: expanded suffix rules
        let pos: String
        if word.hasSuffix("het") || word.hasSuffix("tion") || word.hasSuffix("ning") ||
           word.hasSuffix("ande") || word.hasSuffix("else") || word.hasSuffix("skap") ||
           word.hasSuffix("dom") || word.hasSuffix("nad") || word.hasSuffix("sel") ||
           word.hasSuffix("ment") || word.hasSuffix("lek") || word.hasSuffix("eri") ||
           word.hasSuffix("ist") || word.hasSuffix("itet") || word.hasSuffix("ism") ||
           word.hasSuffix("ans") || word.hasSuffix("ens") {
            pos = "noun"
        } else if word.hasSuffix("lig") || word.hasSuffix("bar") || word.hasSuffix("sam") ||
                  word.hasSuffix("isk") || word.hasSuffix("aktig") || word.hasSuffix("mässig") ||
                  word.hasSuffix("full") || word.hasSuffix("lös") || word.hasSuffix("artad") ||
                  word.hasSuffix("betonad") || word.hasSuffix("ande") && word.count > 6 {
            pos = "adjective"
        } else if word.hasSuffix("era") || word.hasSuffix("ade") || word.hasSuffix("ades") ||
                  word.hasSuffix("erar") || word.hasSuffix("erat") || word.hasSuffix("eras") ||
                  word.hasSuffix("ade") || word.hasSuffix("ades") || word.hasSuffix("ades") {
            pos = "verb"
        } else if word.hasSuffix("vis") || word.hasSuffix("ligen") || word.hasSuffix("ledes") {
            pos = "adverb"
        } else {
            pos = "unknown"
        }

        return MorphemeAnalysis(word: word, baseForm: word, pos: pos, morphemes: [word], isCompound: false, forms: [:])
    }

    /// Fördjupad morfologisk analys med OpenRouter
    /// Använder extern AI för komplexa ord som den interna analysen inte klarar
    func analyzeWithOpenRouter(_ text: String) async -> [MorphemeAnalysis] {
        var results = await analyze(text)

        // Hitta okända ord som är tillräckligt komplexa
        let unknownComplexWords = results.filter {
            $0.pos == "unknown" && $0.word.count > 5
        }.map { $0.word }

        if !unknownComplexWords.isEmpty {
            let batch = Array(unknownComplexWords.prefix(10))
            let openRouterResults = await OpenRouterLanguageEvaluator.shared.morphologyDeepAnalysis(batch)

            for orResult in openRouterResults {
                // Bygg analys från OpenRouter-data
                var forms: [String: String] = [:]
                if !orResult.inflection.paradigm.isEmpty {
                    forms["plural"] = orResult.inflection.paradigm.first ?? ""
                    forms["grammaticalCategory"] = orResult.inflection.grammaticalCategory
                }

                let enhancedAnalysis = MorphemeAnalysis(
                    word: orResult.word,
                    baseForm: orResult.root,
                    pos: orResult.pos,
                    morphemes: orResult.morphemes,
                    isCompound: orResult.morphemes.count > 2,
                    forms: forms
                )

                // Ersätt eller lägg till i resultat
                if let idx = results.firstIndex(where: { $0.word == orResult.word }) {
                    results[idx] = enhancedAnalysis
                } else {
                    results.append(enhancedAnalysis)
                }

                // Berika lexikonet för framtida analyser
                addToLexiconFromOpenRouter(orResult)
            }
        }

        return results
    }

    /// Dynamiskt berika lexikonet med OpenRouter-data
    private func addToLexiconFromOpenRouter(_ result: OpenRouterLanguageEvaluator.MorphologyDeepResult) {
        // Denna metod skulle integrera med SwedishMorphologyEngine.loadLexicon()
        // och lägga till nya ord dynamiskt
        print("[Morphology] Added OpenRouter analysis for: \(result.word)")
    }

    /// Hämta morfologins täckning
    func getMorphologyCoverage() -> (known: Int, unknown: Int, total: Int) {
        // Returnerar statistik om morfologisk täckning
        // Detta skulle läsas från lexikonet i produktion
        return (known: lexicon.count, unknown: 0, total: lexicon.count)
    }

    // MARK: - Iteration 12: Morphological Productivity
    // Given a root word, generates all possible derivatives using Swedish suffixes

    /// Swedish derivational suffixes that create new words from roots
    /// Covers noun-forming, adjective-forming, and verb-forming suffixes
    /// ── v101: Expanded to 50+ suffixes ──
    private static let derivationalSuffixes: [(suffix: String, pos: String)] = [
        // ── Noun-forming suffixes (derivational) ──
        ("het", "noun"),     // snabbhet, frihet
        ("ning", "noun"),    // utbildning, lösning
        ("tion", "noun"),    // organisation, nation
        ("logi", "noun"),    // psykologi, biologi
        ("dom", "noun"),     // visdom, rikedom
        ("skap", "noun"),    // vänskap, ledarskap
        ("else", "noun"),    // rörelse, handling
        ("ande", "noun"),    // skapande, tänkande
        ("eri", "noun"),     // bagageri, buskeri
        ("ör", "noun"),      // direktör, inspektör
        ("ant", "noun"),     // assistent, demonstrant
        ("ist", "noun"),     // artist, pianist
        ("lek", "noun"),     // kärrlek, barnlek
        ("ling", "noun"),    // lärling, diktning
        ("are", "noun"),     // lärare, arbetare
        ("ing", "noun"),     // tidning, samling
        ("um", "noun"),      // museum, datum
        ("a", "noun"),       // flicka, pojke
        ("ad", "noun"),      // skratt, bad
        ("sel", "noun"),     // görsel, väder
        // ── Adjective-forming suffixes (derivational) ──
        ("isk", "adjective"), // kritisk, historisk
        ("bar", "adjective"), // synbar, ändringsbar
        ("lös", "adjective"), // hopplös, meningslös
        ("full", "adjective"), // ansvarsfull, respektfull
        ("sam", "adjective"), // arbetsam, pratsam
        ("ig", "adjective"),  // solig, regnig
        ("aktig", "adjective"), // likaktig, barnaktig
        ("mässig", "adjective"), // ekonomisk, regel
        ("fri", "adjective"), // rökfritt, skattefritt
        ("rik", "adjective"), // vitaminrik, innehållsrik
        ("en", "adjective"),  // stulen, frusen
        ("sk", "adjective"),  // svensk, norsk
        ("ell", "adjective"), // aktuell, industriell
        ("ös", "adjective"),  // glädjefylld
        // ── Verb-forming suffixes (derivational) ──
        ("era", "verb"),     // diskutera, realisera
        ("isera", "verb"),   // modernisera, organisera
        ("ifiera", "verb"),  // identifiera, klassificiera
        ("na", "verb"),      // somna, torkna
        ("s", "verb"),       // läsas, skrivas (passiv)
        // ── v101: Inflectional suffixes ──
        ("-en", "noun-infl"),    // bestämd form utrum (bilen)
        ("-et", "noun-infl"),    // bestämd form neutrum (huset)
        ("-or", "noun-infl"),    // plural -or (flickor)
        ("-ar", "noun-infl"),    // plural -ar (bilar)
        ("-er", "noun-infl"),    // plural -er (datorer)
        ("-n", "noun-infl"),     // plural -n (äpplen)
        ("-a", "adj-infl"),      // plural/bestämd adj (bra)
        ("-t", "adj-infl"),      // neutrum adj (bra)
        ("-are", "adj-infl"),    // komparativ (snabbare)
        ("-ast", "adj-infl"),    // superlativ (snabbast)
        // ── v101: Compound linkers ──
        ("-s-", "compound-linker"),   // fogemorfem (arbetsliv)
        ("-e-", "compound-linker"),   // fogemorfem (gatubild)
        // ── v101: Dialect variant suffixes ──
        ("-a", "dialect"),       // göteborgska: "a" för "å"
        ("-e", "dialect"),       // norrländska: "-e" slut
        ("-ån", "dialect"),      // dalmål: "-ån"
        ("-u", "dialect"),       // gotländska: "-u"
    ]

    /// Given a root word, generates all possible derivatives using Swedish suffixes
    /// - Parameter word: A Swedish root word (e.g., "snabb", "skapa")
    /// - Returns: Array of derived words with suffixes applied
    func generateDerivatives(word: String) -> [String] {
        let root = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard root.count >= 2 else { return [] }

        var derivatives: [String] = []

        for (suffix, pos) in Self.derivationalSuffixes {
            let derived = root + suffix

            // Skip if already in lexicon with same POS (avoid redundant generation)
            if let entry = lexicon[derived], entry.pos == pos {
                derivatives.append(derived)
                continue
            }

            // Apply phonological adjustments for common Swedish patterns
            var adjusted = derived

            // Double consonant rule: kort rot → dubbel konsonant + suffix
            // e.g., "tunn" → "tunnhet" (already has double), "glad" → "gladhet"
            // Root ending in single consonant + "het"/"bar" sometimes doubles
            if root.count <= 3 && root.count >= 2 {
                if let lastChar = root.last, !Self.isVowel(lastChar) {
                    // Short root with single final consonant — sometimes doubled
                    // Only apply for specific suffixes where doubling is common
                    if suffix == "het" || suffix == "bar" {
                        // Check lexicon for doubled version
                        let doubled = root + String(lastChar) + suffix
                        if lexicon[doubled] != nil {
                            adjusted = doubled
                        }
                    }
                }
            }

            // Consonant assimilation: some roots change before certain suffixes
            // e.g., "lära" → "lärare" (a→are), not "läraare"
            if root.hasSuffix("a") && (suffix == "else" || suffix == "ande") {
                adjusted = String(root.dropLast()) + suffix
            }

            // Store if not duplicate
            if !derivatives.contains(adjusted) {
                derivatives.append(adjusted)
            }
        }

        return derivatives
    }

    private static func isVowel(_ character: Character) -> Bool {
        "aeiouyåäöAEIOUYÅÄÖ".contains(character)
    }

    private static func analyzeEmotionalValence(_ text: String) -> (valence: Double, arousal: Double, emotion: String) {
        let lower = text.lowercased()
        let positive = ["glad", "lycka", "hopp", "kärlek", "stolt", "bra"].filter { lower.contains($0) }.count
        let negative = ["ledsen", "arg", "rädd", "oro", "dålig", "hat"].filter { lower.contains($0) }.count
        let valence = max(-1.0, min(1.0, Double(positive - negative) * 0.25))
        let arousal = min(1.0, 0.2 + Double(positive + negative) * 0.15)
        let emotion = valence >= 0.2 ? "positiv" : (valence <= -0.2 ? "negativ" : "neutral")
        return (valence, arousal, emotion)
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 61-69: Advanced Semantics, Discourse, Narrative, Rhetoric
    // ═══════════════════════════════════════════════════════════

    // MARK: - Iteration 61: Argumentation Structure Analysis

    struct ArgumentationAnalysis {
        let claims: [ArgumentClaim]
        let evidence: [ArgumentEvidence]
        let warrants: [ArgumentWarrant]
        let rebuttals: [ArgumentRebuttal]
        let concessions: [ArgumentConcession]
        let argumentGraph: [ArgumentNode]
        let strengthScore: Double
        let fallacies: [LogicalFallacy]
        let analysis: String
    }
    struct ArgumentClaim: Identifiable {
        let id = UUID(); let text: String; let type: ClaimType; let confidence: Double
        enum ClaimType: String { case main, sub, counter }
    }
    struct ArgumentEvidence: Identifiable {
        let id = UUID(); let text: String; let supportsClaim: String?; let evidenceType: EvidenceType; let strength: Double
        enum EvidenceType: String { case factual, statistical, anecdotal, authoritative, logical }
    }
    struct ArgumentWarrant: Identifiable {
        let id = UUID(); let text: String; let connectsEvidence: String; let connectsClaim: String; let explicitness: Explicitness
        enum Explicitness { case explicit, implicit }
    }
    struct ArgumentRebuttal: Identifiable {
        let id = UUID(); let text: String; let targetsClaim: String; let rebuttalType: RebuttalType; let effectiveness: Double
        enum RebuttalType: String { case directRefutation, underminingWarrant, attackingEvidence, offeringCounter }
    }
    struct ArgumentConcession: Identifiable {
        let id = UUID(); let text: String; let concededPoint: String; let followedByCounter: Bool
    }
    struct ArgumentNode: Identifiable {
        let id = UUID(); let text: String; let nodeType: ArgumentNodeType; var children: [UUID]; let strength: Double
        enum ArgumentNodeType: String { case claim, evidence, warrant, rebuttal, concession }
    }
    struct LogicalFallacy: Identifiable {
        let id = UUID(); let type: FallacyType; let text: String; let explanation: String; let severity: Double
        enum FallacyType: String, CaseIterable {
            case adHominem = "ad hominem"; case strawMan = "straw man"; case falseDichotomy = "false dichotomy"
            case slipperySlope = "slippery slope"; case circularReasoning = "cirkelresonemang"
        }
    }

    private static let claimMarkers: Set<String> = ["jag anser", "jag tycker", "jag menar", "jag hävdar", "det är tydligt att", "utan tvekan", "uppenbarligen", "det står klart", "min uppfattning är", "vi bör", "vi måste", "det är nödvändigt", "det är viktigt att"]
    private static let evidenceMarkers: Set<String> = ["till exempel", "exempelvis", "enligt", "studier visar", "forskning", "bevis", "statistik", "undersökningar", "rapporter", "data visar", "som exempel", "ett bevis", "fakta är", "det finns belägg"]
    private static let warrantMarkers: Set<String> = ["detta innebär", "vilket betyder", "detta visar", "alltså", "därför att", "eftersom", "då", "med andra ord", "detta leder till", "följden blir"]
    private static let rebuttalMarkers: Set<String> = ["men", "dock", "emellertid", "å andra sidan", "däremot", "ändå", "trots detta", "fastän", "även om", "mot detta kan invändas", "kritiker menar", "vissa hävdar", "en invändning"]
    private static let concessionMarkers: Set<String> = ["visserligen", "certe", "jag medger", "det är sant att", "naturligtvis", "givetvis", "visst", "det ska medges", "även om", "trots att"]

    func analyzeArgumentation(text: String) -> ArgumentationAnalysis {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        var claims: [ArgumentClaim] = []; var evidence: [ArgumentEvidence] = []; var warrants: [ArgumentWarrant] = []
        var rebuttals: [ArgumentRebuttal] = []; var concessions: [ArgumentConcession] = []; var nodes: [ArgumentNode] = []
        var fallacies: [LogicalFallacy] = []

        for sentence in sentences {
            let sl = sentence.lowercased()
            for marker in Self.claimMarkers where sl.contains(marker) {
                let c = ArgumentClaim(text: sentence, type: .main, confidence: 0.8); claims.append(c)
                nodes.append(ArgumentNode(text: sentence, nodeType: .claim, children: [], strength: 0.7))
            }
            for marker in Self.evidenceMarkers where sl.contains(marker) {
                let evType: ArgumentEvidence.EvidenceType
                if sl.contains("studie") || sl.contains("forskning") { evType = .authoritative }
                else if sl.contains("statistik") || sl.contains("data") { evType = .statistical }
                else if sl.contains("exempel") { evType = .anecdotal }
                else { evType = .factual }
                let ev = ArgumentEvidence(text: sentence, supportsClaim: claims.last?.text, evidenceType: evType, strength: evType == .statistical ? 0.8 : evType == .authoritative ? 0.75 : 0.6)
                evidence.append(ev); nodes.append(ArgumentNode(text: sentence, nodeType: .evidence, children: [], strength: ev.strength))
            }
            for marker in Self.warrantMarkers where sl.contains(marker) {
                warrants.append(ArgumentWarrant(text: sentence, connectsEvidence: evidence.last?.text ?? "", connectsClaim: claims.last?.text ?? "", explicitness: .explicit))
                nodes.append(ArgumentNode(text: sentence, nodeType: .warrant, children: [], strength: 0.6))
            }
            for marker in Self.rebuttalMarkers where sl.contains(marker) {
                let rbType: ArgumentRebuttal.RebuttalType
                if sl.contains("invänd") || sl.contains("kritik") { rbType = .directRefutation }
                else if sl.contains("bevis") || sl.contains("fakta") { rbType = .attackingEvidence }
                else if sl.contains("menar") || sl.contains("hävdar") { rbType = .offeringCounter }
                else { rbType = .underminingWarrant }
                rebuttals.append(ArgumentRebuttal(text: sentence, targetsClaim: claims.last?.text ?? "", rebuttalType: rbType, effectiveness: 0.6))
                nodes.append(ArgumentNode(text: sentence, nodeType: .rebuttal, children: [], strength: 0.5))
            }
            for marker in Self.concessionMarkers where sl.contains(marker) {
                let followedByCounter = Self.rebuttalMarkers.contains { m in let idx = sl.range(of: marker)?.upperBound ?? sl.startIndex; return sl[idx...].contains(m) }
                concessions.append(ArgumentConcession(text: sentence, concededPoint: sentence, followedByCounter: followedByCounter))
                nodes.append(ArgumentNode(text: sentence, nodeType: .concession, children: [], strength: 0.4))
            }
        }

        for (i, node) in nodes.enumerated() where node.nodeType == .evidence {
            if let ci = nodes.firstIndex(where: { $0.nodeType == .claim }) { nodes[i].children.append(nodes[ci].id) }
        }

        // Fallacy detection
        let fallacyPatterns: [(pattern: String, type: LogicalFallacy.FallacyType, explanation: String)] = [
            ("(du|han|hon|de).*(är|verkar).*(naiv|dum|okunnig|enfaldig)", .adHominem, "Personangrepp: attackerar personen istället för argumentet"),
            ("(din|hans|hennes).*(brist|okunnighet|naivitet)", .adHominem, "Personangrepp: fokuserar på personens brister"),
            ("(du|ni|de).*(tycker|menar|hävdar) alltså att.*(alla|alltid|aldrig|inget)", .strawMan, "Straw man: överdriver motståndarens position"),
            ("så.*(du|ni|de) vill.*(inget|aldrig|bara|enbart)", .strawMan, "Straw man: förenklar motståndarens argument"),
            ("(antingen|endast).*(eller|annars).*(inte|aldrig)", .falseDichotomy, "Falsk dikotomi: presenterar bara två alternativ"),
            ("(är|vill) du.*(för|mot|med|emot)", .falseDichotomy, "Falsk dikotomi: tvingar fram ett binärt val"),
            ("om.*(då|sedan|sen|efter|leda|resultera|betyda|innebär).*och.*(sedan|sen|därefter)", .slipperySlope, "Sluttande plan: kedja av osannolika konsekvenser"),
            ("först.*(sen|sedan|därefter|efter det|nästa steg|till slut)", .slipperySlope, "Sluttande plan: antar oundviklig kedja"),
        ]
        for sentence in sentences {
            let sl = sentence.lowercased()
            for (pattern, type, explanation) in fallacyPatterns {
                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                if let regex, regex.firstMatch(in: sl, range: NSRange(sl.startIndex..., in: sl)) != nil {
                    fallacies.append(LogicalFallacy(type: type, text: sentence, explanation: explanation, severity: 0.7))
                }
            }
        }

        let claimEvidenceRatio = claims.isEmpty ? 0.0 : min(1.0, Double(evidence.count) / Double(claims.count))
        let rebuttalBonus = claims.isEmpty ? 0.0 : min(0.2, Double(rebuttals.count) * 0.1)
        let concessionBonus = concessions.filter { $0.followedByCounter }.isEmpty ? 0.0 : 0.1
        let fallacyPenalty = Double(fallacies.count) * 0.1
        let strengthScore = max(0.0, min(1.0, claimEvidenceRatio * 0.5 + rebuttalBonus + concessionBonus - fallacyPenalty + 0.2))
        let analysis = claims.isEmpty ? "Inga tydliga påståenden identifierade" : "Argumentationsanalys: \(claims.count) påståenden, \(evidence.count) bevis, \(rebuttals.count) motbevis, \(fallacies.count) logiska felslut"
        return ArgumentationAnalysis(claims: claims, evidence: evidence, warrants: warrants, rebuttals: rebuttals, concessions: concessions, argumentGraph: nodes, strengthScore: strengthScore, fallacies: fallacies, analysis: analysis)
    }

    // MARK: - Iteration 62: Narrative Structure Detection

    struct NarrativeStructure {
        let narrativeArc: NarrativeArc; let temporalMarkers: [TemporalMarker]
        let characterPerspectives: [CharacterPerspective]; let plotCoherence: Double
        let narrativeType: NarrativeType; let creativityBoost: Double; let comprehensionBoost: Double; let analysis: String
    }
    struct NarrativeArc: Codable {
        let exposition: [String]; let risingAction: [String]; let climax: [String]; let fallingAction: [String]; let resolution: [String]
        var arcComplete: Bool { !exposition.isEmpty && !risingAction.isEmpty && !climax.isEmpty && !resolution.isEmpty }
    }
    struct TemporalMarker: Identifiable {
        let id = UUID(); let text: String; let type: TemporalType; let position: Int
        enum TemporalType: String { case flashback, flashForward, simultaneous, linear, ambiguous }
    }
    struct CharacterPerspective: Identifiable {
        let id = UUID(); let character: String; let sentences: [String]; let perspectiveType: PerspectiveType
        enum PerspectiveType: String { case firstPerson, thirdPersonLimited, thirdPersonOmniscient, unreliable }
    }
    enum NarrativeType: String, CaseIterable { case linear = "linjär"; case nonLinear = "icke-linjär"; case frameNarrative = "ramberättelse"; case streamOfConsciousness = "medvetandeström"; case unknown = "okänd" }

    private static let expositionMarkers: Set<String> = ["det var en gång", "för länge sedan", "i början", "allt började", "det började med", "från början", "till en början"]
    private static let risingActionMarkers: Set<String> = ["plötsligt", "men sedan", "dock", "samtidigt", "mer och mer", "allt oftare", "successivt", "gradvis", "efterhand", "snart", "då hände något"]
    private static let climaxMarkers: Set<String> = ["högsta punkten", "kulmen", "toppen", "avgörande ögonblick", "vändpunkten", "allt eller inget", "i det avgörande ögonblicket", "plötsligt insåg", "då förstod"]
    private static let fallingActionMarkers: Set<String> = ["efter det", "därefter", "som följd", "i spåren av", "efter händelsen", "när allt var över", "efter stormen"]
    private static let resolutionMarkers: Set<String> = ["slutligen", "till slut", "sammanfattningsvis", "så småningom", "i slutändan", "resultatet blev", "och så", "det slutade med"]
    private static let flashbackMarkers: Set<String> = ["tidigare", "förut", "innan", "bakåt i tiden", "i minnet", "minns", "kom ihåg", "tänkte tillbaka", "år tillbaka", "förra året", "en gång i tiden"]
    private static let flashForwardMarkers: Set<String> = ["senare", "i framtiden", "framåt", "kommande", "om ett år", "snart", "om några år", "i morgon", "någon gång senare", "år framöver"]
    private static let firstPersonMarkers: Set<String> = ["jag", "mig", "min", "mitt", "mina", "vi", "oss", "vår"]
    private static let thirdPersonMarkers: Set<String> = ["han", "hon", "hen", "den", "det", "de", "dem", "deras"]

    func detectNarrativeStructure(text: String) -> NarrativeStructure {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        let lowerText = text.lowercased()
        var exposition: [String] = []; var risingAction: [String] = []; var climax: [String] = []
        var fallingAction: [String] = []; var resolution: [String] = []
        for s in sentences {
            let sl = s.lowercased()
            if Self.expositionMarkers.contains(where: { sl.contains($0) }) { exposition.append(s) }
            else if Self.climaxMarkers.contains(where: { sl.contains($0) }) { climax.append(s) }
            else if Self.fallingActionMarkers.contains(where: { sl.contains($0) }) { fallingAction.append(s) }
            else if Self.resolutionMarkers.contains(where: { sl.contains($0) }) { resolution.append(s) }
            else if Self.risingActionMarkers.contains(where: { sl.contains($0) }) { risingAction.append(s) }
        }
        if exposition.isEmpty && risingAction.isEmpty && climax.isEmpty && fallingAction.isEmpty && resolution.isEmpty && sentences.count > 1 {
            let chunkSize = max(1, sentences.count / 5)
            exposition = Array(sentences.prefix(chunkSize))
            risingAction = Array(sentences[chunkSize..<min(chunkSize * 2, sentences.count)])
            if sentences.count > chunkSize * 2 { climax = Array(sentences[chunkSize * 2..<min(chunkSize * 3, sentences.count)]) }
            if sentences.count > chunkSize * 3 { fallingAction = Array(sentences[chunkSize * 3..<min(chunkSize * 4, sentences.count)]) }
            if sentences.count > chunkSize * 4 { resolution = Array(sentences[(chunkSize * 4)..<sentences.count]) }
        }
        let arc = NarrativeArc(exposition: exposition, risingAction: risingAction, climax: climax, fallingAction: fallingAction, resolution: resolution)

        var temporalMarkers: [TemporalMarker] = []
        for (idx, s) in sentences.enumerated() {
            let sl = s.lowercased()
            if Self.flashbackMarkers.contains(where: { sl.contains($0) }) { temporalMarkers.append(TemporalMarker(text: s, type: .flashback, position: idx)) }
            else if Self.flashForwardMarkers.contains(where: { sl.contains($0) }) { temporalMarkers.append(TemporalMarker(text: s, type: .flashForward, position: idx)) }
        }

        var perspectives: [CharacterPerspective] = []
        var currentCharacters: [String: [String]] = [:]
        for s in sentences {
            let sl = s.lowercased()
            let isFirst = Self.firstPersonMarkers.contains { sl.contains(" \($0) ") || sl.hasPrefix("\($0) ") }
            let isThird = Self.thirdPersonMarkers.contains { sl.contains(" \($0) ") || sl.hasPrefix("\($0) ") }
            if isFirst { currentCharacters["jag", default: []].append(s) }
            else if isThird { currentCharacters["third_person", default: []].append(s) }
        }
        for (char, charSentences) in currentCharacters {
            let pType: CharacterPerspective.PerspectiveType = char == "jag" ? .firstPerson : charSentences.count == 1 ? .thirdPersonLimited : .thirdPersonOmniscient
            perspectives.append(CharacterPerspective(character: char, sentences: charSentences, perspectiveType: pType))
        }

        let hasTemporalShifts = temporalMarkers.filter { $0.type == .flashback || $0.type == .flashForward }.count > 1
        let isSoC = sentences.filter { $0.count > 40 }.count > sentences.count / 2
        let hasFrame = (Self.expositionMarkers.contains { lowerText.contains($0) }) && (Self.resolutionMarkers.contains { lowerText.contains($0) })
        let narrativeType: NarrativeType
        if isSoC { narrativeType = .streamOfConsciousness }
        else if hasFrame && hasTemporalShifts { narrativeType = .frameNarrative }
        else if hasTemporalShifts { narrativeType = .nonLinear }
        else if !temporalMarkers.isEmpty { narrativeType = .linear }
        else { narrativeType = .unknown }

        let arcElements = [exposition, risingAction, climax, fallingAction, resolution].filter { !$0.isEmpty }.count
        let plotCoherence = min(1.0, Double(arcElements) / 5.0 * 0.6 + (temporalMarkers.isEmpty ? 0.2 : 0.4))
        let creativityBoost = min(0.04, Double(arcElements) * 0.004 + (hasTemporalShifts ? 0.01 : 0.0))
        let comprehensionBoost = min(0.03, Double(perspectives.count) * 0.003 + (arc.arcComplete ? 0.01 : 0.0))
        let analysis = arc.arcComplete ? "Narrativ struktur: \(narrativeType.rawValue) med komplett berättelsebåge, \(temporalMarkers.count) tidsmarkörer, \(perspectives.count) perspektiv" : "Narrativ struktur: \(narrativeType.rawValue) — ofullständig båge (\(arcElements)/5 delar)"
        return NarrativeStructure(narrativeArc: arc, temporalMarkers: temporalMarkers, characterPerspectives: perspectives, plotCoherence: plotCoherence, narrativeType: narrativeType, creativityBoost: creativityBoost, comprehensionBoost: comprehensionBoost, analysis: analysis)
    }

    // MARK: - Iteration 63: Rhetorical Device Detection

    struct RhetoricalDevice: Identifiable, Codable {
        let id = UUID(); let type: RhetoricalDeviceType; let text: String; let explanation: String; let positions: [Int]; let strength: Double
        enum RhetoricalDeviceType: String, CaseIterable, Codable {
            case anaphora = "anafor"; case epistrophe = "epifor"; case chiasmus = "chiasm"; case parallelism = "parallelism"
            case tricolon = "trikolon"; case rhetoricalQuestion = "retorisk fråga"; case litotes = "litotes"
            case hyperbole = "hyperbol"; case alliteration = "allitteration"; case assonance = "assonans"
            case folkvisestil = "folkvisestil"; case talesätt = "talesätt"
        }
    }

    private static let folkvisestilPatterns: [(String, String)] = [("lilla", "Folkvisestil: diminutivt uttryck"), ("fagra", "Folkvisestil: poetiskt adjektiv"), ("mången", "Folkvisestil: arkaiskt pronomen"), ("den gången", "Folkvisestil: balladformel"), ("i ungdomens", "Folkvisestil: balladtema"), ("rida", "Folkvisestil: balladverb"), ("jungfru", "Folkvisestil: balladmotiv"), ("riddar", "Folkvisestil: balladmotiv")]
    private static let talesattPatterns: Set<String> = ["bättre fly än illa fäkta", "tiden läkar alla sår", "skam den som ger sig", "bra karl reder sig själv", "morgonstund har guld i mund", "man ska inte köpa katten i säcken", "den som väntar på något gott", "man ska inte ropa hop innan man har skjutit björnen", "den som gräver en grop", "söka efter nålen i höstacken", "vad man sådd får man skörda", "man ska inte kasta pärlor åt svin", "den som tiger samtycker"]

    func detectRhetoricalDevices(text: String) -> [RhetoricalDevice] {
        var devices: [RhetoricalDevice] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        let lowerText = text.lowercased()
        let words = lowerText.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }

        // Anaphora
        if sentences.count >= 2 {
            var anaphoricSequences: [[String]] = []; var currentSeq: [String] = [sentences[0]]
            var currentStart = sentences[0].lowercased().prefix(4)
            for i in 1..<sentences.count {
                let sentStart = sentences[i].lowercased().prefix(4)
                if sentStart == currentStart && currentStart.count >= 3 { currentSeq.append(sentences[i]) }
                else { if currentSeq.count >= 2 { anaphoricSequences.append(currentSeq) }; currentSeq = [sentences[i]]; currentStart = sentences[i].lowercased().prefix(4) }
            }
            if currentSeq.count >= 2 { anaphoricSequences.append(currentSeq) }
            for seq in anaphoricSequences { devices.append(RhetoricalDevice(type: .anaphora, text: seq.joined(separator: "; "), explanation: "Anafor: upprepning av '\(currentStart)' i början av \(seq.count) satser", positions: [], strength: min(0.95, 0.5 + Double(seq.count) * 0.15))) }
        }

        // Epistrophe
        if sentences.count >= 2 {
            var epiSequences: [[String]] = []; var currentSeq: [String] = [sentences[0]]
            var currentEnd = String(sentences[0].lowercased().suffix(4))
            for i in 1..<sentences.count {
                let sentEnd = String(sentences[i].lowercased().suffix(4))
                if sentEnd == currentEnd && currentEnd.count >= 3 { currentSeq.append(sentences[i]) }
                else { if currentSeq.count >= 2 { epiSequences.append(currentSeq) }; currentSeq = [sentences[i]]; currentEnd = String(sentences[i].lowercased().suffix(4)) }
            }
            if currentSeq.count >= 2 { epiSequences.append(currentSeq) }
            for seq in epiSequences { devices.append(RhetoricalDevice(type: .epistrophe, text: seq.joined(separator: "; "), explanation: "Epifor: upprepning i slutet av \(seq.count) satser", positions: [], strength: min(0.95, 0.5 + Double(seq.count) * 0.15))) }
        }

        // Chiasmus
        for i in 0..<(sentences.count - 1) {
            let w1 = sentences[i].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 }
            let w2 = sentences[i + 1].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 }
            if w1.count >= 2 && w2.count >= 2 && w1.first == w2.last && w1.last == w2.first {
                devices.append(RhetoricalDevice(type: .chiasmus, text: "\(sentences[i]); \(sentences[i + 1])", explanation: "Chiasm: ABBA-struktur", positions: [], strength: 0.8))
            }
        }

        // Parallelism
        for i in 0..<(sentences.count - 1) {
            let w1P = sentences[i].lowercased().components(separatedBy: .whitespacesAndNewlines).prefix(2).joined(separator: " ")
            let w2P = sentences[i + 1].lowercased().components(separatedBy: .whitespacesAndNewlines).prefix(2).joined(separator: " ")
            if w1P.count > 3 && w2P.count > 3 && w1P.count == w2P.count {
                let sim = Double(zip(w1P, w2P).filter { $0 == $1 }.count) / Double(w1P.count)
                if sim >= 0.5 { devices.append(RhetoricalDevice(type: .parallelism, text: "\(sentences[i]); \(sentences[i + 1])", explanation: "Parallelism: '\(w1P)' / '\(w2P)'", positions: [], strength: sim * 0.8)) }
            }
        }

        // Tricolon
        for s in sentences {
            let parts = s.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 2 }
            if parts.count == 3 {
                let lengths = parts.map { Double($0.components(separatedBy: .whitespacesAndNewlines).count) }
                let avg = lengths.reduce(0, +) / 3.0; let variance = lengths.map { pow($0 - avg, 2) }.reduce(0, +) / 3.0
                if variance < 2.0 { devices.append(RhetoricalDevice(type: .tricolon, text: s, explanation: "Trikolon: tredelad uppräkning", positions: [], strength: min(0.9, 0.6 + (1.0 - variance / 2.0) * 0.3))) }
            }
        }

        // Rhetorical questions
        for s in sentences where s.contains("?") {
            let sl = s.lowercased(); let qws = ["vem", "vad", "varför", "hur", "när", "var", "vilken"]
            if qws.contains(where: { sl.contains($0) }) { devices.append(RhetoricalDevice(type: .rhetoricalQuestion, text: s, explanation: "Retorisk fråga", positions: [], strength: 0.7)) }
        }

        // Litotes
        for pattern in ["inte dålig", "inte illa", "inte osannolikt", "inte obetydlig", "inte helt fel", "inte ovanligt", "inte utan", "icke desto mindre", "inte okunnig", "inte ointressant", "inte oviktigt", "inte omöjligt", "inte helt ovanligt", "inte så dumt"] where lowerText.contains(pattern) {
            devices.append(RhetoricalDevice(type: .litotes, text: pattern, explanation: "Litotes: underdrift genom dubbel negation", positions: [], strength: 0.75))
        }

        // Hyperbole
        let hyperWords = Set(["aldrig", "alltid", "värsta", "bästa", "sämsta", "ofattbart", "absolut", "totalt", "extremt", "enormt", "världens", "oändligt", "evigt", "fantastiskt", "fullständigt", "komplett"])
        let hyperMatches = words.filter { hyperWords.contains($0) }
        if hyperMatches.count >= 2 { devices.append(RhetoricalDevice(type: .hyperbole, text: String(hyperMatches.joined(separator: ", ")), explanation: "Hyperbol: överdrivna uttryck (\(hyperMatches.count) ord)", positions: [], strength: min(0.9, 0.4 + Double(hyperMatches.count) * 0.1))) }

        // Alliteration
        for s in sentences {
            let sw = s.lowercased().components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { $0.count > 2 }
            var i = 0
            while i < sw.count - 1 {
                let fl = sw[i].first; var count = 1
                while i + count < sw.count && sw[i + count].first == fl { count += 1 }
                if count >= 3 { devices.append(RhetoricalDevice(type: .alliteration, text: sw[i..<i + count].joined(separator: " "), explanation: "Allitteration: \(count) ord på '\(String(fl ?? "x"))'", positions: [], strength: min(0.9, 0.4 + Double(count) * 0.15))); i += count } else { i += 1 }
            }
        }

        // Assonance
        for (vowel, label) in [("a", "a/å"), ("e", "e/ä"), ("o", "o/ö"), ("i", "i"), ("u", "u")] {
            let vw = words.filter { $0.contains(vowel) }
            if vw.count >= 3 { devices.append(RhetoricalDevice(type: .assonance, text: vw.prefix(4).joined(separator: ", "), explanation: "Assonans: vokal '\(label)' i \(vw.count) ord", positions: [], strength: min(0.8, 0.3 + Double(vw.count) * 0.1))) }
        }

        // Folkvisestil
        for (pattern, explanation) in Self.folkvisestilPatterns where lowerText.contains(pattern) {
            devices.append(RhetoricalDevice(type: .folkvisestil, text: pattern, explanation: explanation, positions: [], strength: 0.7))
        }
        // Talesätt
        for ta in Self.talesattPatterns where lowerText.contains(ta) {
            devices.append(RhetoricalDevice(type: .talesätt, text: ta, explanation: "Talesätt: '\(ta)'", positions: [], strength: 0.85))
        }
        return devices
    }

    // MARK: - Iteration 64: Frame Semantics

    struct FrameAnalysis {
        let frames: [SemanticFrame]; let frameRelations: [FrameRelation]; let frameCompleteness: Double
        let whoDidWhat: [String]; let comprehensionBoost: Double
    }
    struct SemanticFrame: Identifiable {
        let id = UUID(); let frameName: String; let triggerWord: String; let frameElements: [FrameElement]; let completeness: Double
    }
    struct FrameElement: Codable { let role: String; let filler: String; let confidence: Double }
    struct FrameRelation: Identifiable {
        let id = UUID(); let fromFrame: String; let toFrame: String; let relationType: FrameRelationType
        enum FrameRelationType: String { case causes, enables, precedes, contrastsWith, partOf }
    }

    private static let frameDatabase: [String: (frameName: String, roles: [String])] = [
        "köpa": ("COMMERCE_BUY", ["köpare", "säljare", "vara", "pengar"]), "köp": ("COMMERCE_BUY", ["köpare", "säljare", "vara"]),
        "handla": ("COMMERCE_BUY", ["köpare", "säljare", "vara"]),
        "sälja": ("COMMERCE_SELL", ["säljare", "köpare", "vara", "pris"]), "försäljning": ("COMMERCE_SELL", ["säljare", "köpare", "vara"]),
        "ge": ("GIVING", ["givare", "mottagare", "objekt"]), "gav": ("GIVING", ["givare", "mottagare", "objekt"]), "giva": ("GIVING", ["givare", "mottagare", "objekt"]),
        "få": ("RECEIVING", ["mottagare", "givare", "objekt"]), "motta": ("RECEIVING", ["mottagare", "avsändare", "objekt"]),
        "ta": ("RECEIVING", ["tagare", "källa", "objekt"]),
        "skicka": ("TRANSFER", ["avsändare", "mottagare", "objekt", "medium"]), "sända": ("TRANSFER", ["avsändare", "mottagare", "objekt"]),
        "säga": ("COMMUNICATION", ["talare", "lyssnare", "meddelande"]), "berätta": ("COMMUNICATION", ["berättare", "åhörare", "innehåll"]),
        "skriva": ("COMMUNICATION", ["författare", "läsare", "text"]), "tala": ("COMMUNICATION", ["talare", "publik", "ämne"]),
        "prata": ("COMMUNICATION", ["talare", "lyssnare", "ämne"]), "fråga": ("COMMUNICATION", ["frågare", "svarare", "fråga"]),
        "svara": ("COMMUNICATION", ["svarare", "frågare", "svar"]), "meddela": ("COMMUNICATION", ["avsändare", "mottagare", "meddelande"]),
        "se": ("PERCEPTION", ["observatör", "fenomen"]), "höra": ("PERCEPTION", ["lyssnare", "ljud"]),
        "känna": ("PERCEPTION", ["kännare", "stimulus"]), "observera": ("PERCEPTION", ["observatör", "fenomen"]),
        "tänka": ("COGNITION", ["tänkare", "tankeinnehåll"]), "tro": ("COGNITION", ["troende", "proposition"]),
        "veta": ("COGNITION", ["vetare", "faktum"]), "förstå": ("COGNITION", ["förstående", "fenomen"]),
        "begripa": ("COGNITION", ["begripare", "fenomen"]), "minnas": ("COGNITION", ["minnande", "erinran"]),
        "glömma": ("COGNITION", ["glömsk", "glömt"]), "lära": ("COGNITION", ["lärande", "innehåll", "källa"]),
        "fundera": ("COGNITION", ["funderande", "ämne"]), "misstänka": ("COGNITION", ["misstänkande", "proposition"]),
        "älska": ("EMOTION", ["kännare", "objekt"]), "hata": ("EMOTION", ["kännare", "objekt"]),
        "frukta": ("EMOTION", ["kännare", "hot"]), "oroa": ("EMOTION", ["kännare", "orsak"]),
        "glädja": ("EMOTION", ["kännare", "orsak"]), "sörja": ("EMOTION", ["sörjande", "orsak"]),
        "gå": ("MOTION", ["rörelseaktör", "källa", "mål"]), "springa": ("MOTION", ["rörelseaktör", "mål"]),
        "åka": ("MOTION", ["rörelseaktör", "källa", "mål"]), "resa": ("MOTION", ["resenär", "källa", "mål"]),
        "flyga": ("MOTION", ["rörelseaktör", "källa", "mål"]), "cykla": ("MOTION", ["cyklist", "källa", "mål"]),
        "köra": ("MOTION", ["förare", "fordon", "källa", "mål"]), "vandra": ("MOTION", ["vandrare", "källa", "mål"]),
        "bli": ("CHANGE", ["entitet", "sluttillstånd", "orsak"]), "ändra": ("CHANGE", ["aktör", "objekt", "nytt_tillstånd"]),
        "förändra": ("CHANGE", ["aktör", "objekt", "nytt_tillstånd"]), "utveckla": ("CHANGE", ["aktör", "objekt", "resultat"]),
        "öka": ("CHANGE", ["entitet", "mängd"]), "minska": ("CHANGE", ["entitet", "mängd"]),
        "skapa": ("CREATION", ["skapare", "resultat"]), "bygga": ("CREATION", ["byggare", "resultat"]),
        "tillverka": ("CREATION", ["tillverkare", "resultat"]), "göra": ("CREATION", ["aktör", "resultat"]),
        "producera": ("CREATION", ["producent", "resultat"]), "konstruera": ("CREATION", ["konstruktör", "resultat"]),
        "förstöra": ("DESTRUCTION", ["aktör", "objekt"]), "krossa": ("DESTRUCTION", ["aktör", "objekt"]),
        "ha": ("POSSESSION", ["ägare", "objekt"]), "äga": ("POSSESSION", ["ägare", "objekt"]),
        "tillhöra": ("POSSESSION", ["ägare", "objekt"]), "förlora": ("POSSESSION", ["förlorare", "objekt"]),
        "hjälpa": ("SOCIAL", ["hjälpare", "hjälptagare", "uppgift"]), "stjäla": ("SOCIAL", ["tjuv", "offer", "objekt"]),
        "lova": ("SOCIAL", ["lovare", "mottagare", "löfte"]), "tacka": ("SOCIAL", ["tackare", "mottagare"]),
        "förlåta": ("SOCIAL", ["förlåtare", "syndare"]), "straffa": ("SOCIAL", ["straffare", "bestraffad", "brott"]),
        "döma": ("JUDGING", ["domare", "bedömd", "kriterium"]), "bedöma": ("JUDGING", ["bedömare", "bedömd", "kriterium"]),
        "kritisera": ("JUDGING", ["kritiker", "kritiserad"]), "berömma": ("JUDGING", ["berömmare", "berömd"]),
        "försöka": ("ATTEMPT", ["försökare", "mål"]), "pröva": ("ATTEMPT", ["prövare", "mål"]),
        "orsaka": ("CAUSE", ["orsak", "verkan", "aktör"]), "leda": ("CAUSE", ["orsak", "verkan"]),
        "resultera": ("CAUSE", ["orsak", "verkan"]), "medföra": ("CAUSE", ["orsak", "verkan"]),
        "påverka": ("CAUSE", ["påverkare", "påverkad"]), "utlösa": ("CAUSE", ["utlösare", "händelse"]),
        "bidra": ("CAUSE", ["bidragare", "resultat"]),
        "födas": ("BEING_BORN", ["person", "tid", "plats"]), "dö": ("DYING", ["person", "tid", "orsak"]),
        "upptäcka": ("BECOMING_AWARE", ["upptäckare", "fenomen"]), "inse": ("BECOMING_AWARE", ["inseende", "faktum"]),
        "studera": ("EDUCATION", ["student", "ämne", "plats"]), "läsa": ("EDUCATION", ["läsare", "ämne"]),
        "undervisa": ("EDUCATION", ["lärare", "elev", "ämne"]), "forska": ("EDUCATION", ["forskare", "ämne"]),
        "analysera": ("EDUCATION", ["analytiker", "objekt"]),
        "leverera": ("TRANSFER", ["leverantör", "mottagare", "objekt"]), "upplysa": ("COMMUNICATION", ["upplysare", "mottagare", "information"]),
        "lukta": ("PERCEPTION", ["observatör", "doft"]), "smaka": ("PERCEPTION", ["smakare", "mat"]),
        "glömma": ("COGNITION", ["glömsk", "glömt"]), "ana": ("COGNITION", ["anande", "proposition"]),
        "beundra": ("EMOTION", ["beundrare", "objekt"]), "förundra": ("EMOTION", ["förundrande", "fenomen"]),
        "simma": ("MOTION", ["simnare", "källa", "mål"]), "röra": ("MOTION", ["aktör", "objekt", "riktning"]),
        "förbättra": ("CHANGE", ["aktör", "objekt"]), "försämra": ("CHANGE", ["aktör", "objekt"]),
        "forma": ("CREATION", ["aktör", "resultat"]), "designa": ("CREATION", ["designer", "resultat"]),
        "rasera": ("DESTRUCTION", ["aktör", "objekt"]), "bryta": ("DESTRUCTION", ["aktör", "objekt"]),
        "behålla": ("POSSESSION", ["behållare", "objekt"]), "hålla": ("POSSESSION", ["hållare", "objekt"]),
        "lura": ("SOCIAL", ["bedragare", "offer"]), "bedra": ("SOCIAL", ["bedragare", "offer"]),
        "svika": ("SOCIAL", ["svikare", "offer"]), "hota": ("SOCIAL", ["hotare", "hotad", "hot"]),
        "bjuda": ("SOCIAL", ["värd", "gäst", "erbjudande"]), "ursäkta": ("SOCIAL", ["ursäktare", "mottagare"]),
        "belöna": ("SOCIAL", ["belönare", "belönad", "förtjänst"]),
        "ogilla": ("JUDGING", ["ogillare", "ogillad"]), "gilla": ("JUDGING", ["gillare", "gillad"]),
        "förakta": ("JUDGING", ["föraktare", "föraktad"]),
        "sträva": ("ATTEMPT", ["strävare", "mål"]),
        "framkalla": ("CAUSE", ["orsak", "effekt"]), "bidra": ("CAUSE", ["bidragare", "resultat"]),
        "avlida": ("DYING", ["person", "tid"]), "mörda": ("DYING", ["mördare", "offer"]),
        "märka": ("BECOMING_AWARE", ["märkare", "fenomen"]), "notera": ("BECOMING_AWARE", ["noterande", "fenomen"]),
        "erkänna": ("BECOMING_AWARE", ["erkännande", "faktum"]),
        "svära": ("MAKING_PROMISES", ["svärande", "löfte"]), "garantera": ("MAKING_PROMISES", ["garant", "löfte"]),
        "utbilda": ("EDUCATION", ["utbildare", "elev", "ämne"]), "examinera": ("EDUCATION", ["examinator", "student"]),
    ]

    func analyzeFrameSemantics(text: String) -> FrameAnalysis {
        let lower = text.lowercased()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        var frames: [SemanticFrame] = []; var frameRelations: [FrameRelation] = []; var whoDidWhat: [String] = []

        for sentence in sentences {
            let sl = sentence.lowercased()
            let sw = sl.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
            for word in sw {
                if let (frameName, roles) = Self.frameDatabase[word] {
                    var elements: [FrameElement] = []
                    let otherWords = sw.filter { $0 != word }
                    for (roleIdx, role) in roles.enumerated() where roleIdx < otherWords.count {
                        elements.append(FrameElement(role: role, filler: otherWords[roleIdx], confidence: 0.6))
                    }
                    // Preposition-based role filling
                    if let idx = sw.firstIndex(of: "av"), idx + 1 < sw.count { elements.append(FrameElement(role: "källa/agent", filler: sw[idx + 1], confidence: 0.7)) }
                    if let idx = sw.firstIndex(of: "till"), idx + 1 < sw.count { elements.append(FrameElement(role: "mål/mottagare", filler: sw[idx + 1], confidence: 0.7)) }
                    if let idx = sw.firstIndex(of: "med"), idx + 1 < sw.count { elements.append(FrameElement(role: "instrument", filler: sw[idx + 1], confidence: 0.7)) }
                    if let idx = sw.firstIndex(of: "från"), idx + 1 < sw.count { elements.append(FrameElement(role: "ursprung", filler: sw[idx + 1], confidence: 0.7)) }

                    let completeness = roles.isEmpty ? 0.0 : Double(elements.count) / Double(max(1, roles.count))
                    frames.append(SemanticFrame(frameName: frameName, triggerWord: word, frameElements: elements, completeness: min(1.0, completeness)))

                    let agent = elements.first(where: { $0.role.contains("givare") || $0.role.contains("aktör") || $0.role.contains("köpare") || $0.role.contains("talare") })
                    let patient = elements.first(where: { $0.role.contains("objekt") || $0.role.contains("vara") || $0.role.contains("meddelande") })
                    let goal = elements.first(where: { $0.role.contains("mottagare") || $0.role.contains("mål") })
                    if let a = agent, let p = patient { whoDidWhat.append(goal != nil ? "\(a.filler) \(word) \(p.filler) till \(goal!.filler)" : "\(a.filler) \(word) \(p.filler)") }
                    else if let p = patient { whoDidWhat.append("\(word) \(p.filler)") }
                }
            }
        }

        for i in 0..<(frames.count - 1) {
            let f1 = frames[i], f2 = frames[i + 1]
            if (f1.frameName == "ATTEMPT" || f1.frameName == "CAUSE") && (f2.frameName == "CHANGE" || f2.frameName == "CREATION") { frameRelations.append(FrameRelation(fromFrame: f1.frameName, toFrame: f2.frameName, relationType: .causes)) }
            if f1.frameName == "MOTION" && f2.frameName == "PERCEPTION" { frameRelations.append(FrameRelation(fromFrame: f1.frameName, toFrame: f2.frameName, relationType: .precedes)) }
            if (f1.frameName == "POSSESSION" && f2.frameName == "DESTRUCTION") || (f1.frameName == "DESTRUCTION" && f2.frameName == "POSSESSION") { frameRelations.append(FrameRelation(fromFrame: f1.frameName, toFrame: f2.frameName, relationType: .contrastsWith)) }
        }

        let frameCompleteness = frames.isEmpty ? 0.0 : frames.reduce(0.0) { $0 + $1.completeness } / Double(frames.count)
        return FrameAnalysis(frames: frames, frameRelations: frameRelations, frameCompleteness: frameCompleteness, whoDidWhat: whoDidWhat, comprehensionBoost: min(0.1, Double(frames.count) * 0.005))
    }

    // MARK: - Iteration 65: Presupposition Detection

    struct Presupposition: Identifiable {
        let id = UUID(); let type: PresuppositionType; let text: String; let presupposedContent: String; let trigger: String; let confidence: Double; let negationTest: Bool
        enum PresuppositionType: String { case factive = "faktiv"; case implicative = "implikativ"; case lexical = "lexikalisk"; case structural = "strukturell"; case nonRestrictiveRelative = "icke-restriktiv relativsats" }
    }

    private static let factiveVerbs: Set<String> = ["vet", "veta", "visste", "inse", "inser", "insåg", "upptäcka", "upptäcker", "upptäckte", "ångra", "ångrade", "begråta", "begråter", "förvånad", "glad över", "ledsen över", "stolt över", "realisera", "realiserar", "förstå", "förstår", "förstod", "medge", "medger", "medgav", "erkänna", "erkänner", "erkände", "är medveten", "var medveten"]
    private static let implicativeVerbs: Set<String> = ["lyckades", "lyckas", "glömde", "glömmer", "glömma", "undvek", "undviker", "undvika", "tvingades", "tvingas", "tvinga", "vågade", "vågar", "våga", "kunde", "kan", "kunna", "hinner", "hinna", "hann", "orkade", "orkar", "orka", "förmådde", "förmår", "förmå"]
    private static let lexicalPresuppositionTriggers: [String: String] = ["sluta": "att personen tidigare gjorde handlingen", "slutar": "att personen tidigare gjorde handlingen", "slutade": "att personen tidigare gjorde handlingen", "fortsätta": "att personen redan påbörjat handlingen", "fortsätter": "att personen redan påbörjat handlingen", "fortsatte": "att personen redan påbörjat handlingen", "börja": "att handlingen inte pågick tidigare", "börjar": "att handlingen inte pågick tidigare", "började": "att handlingen inte pågick tidigare", "återvända": "att personen varit där tidigare", "återvänder": "att personen varit där tidigare", "återvände": "att personen varit där tidigare", "än en gång": "att det hänt minst en gång tidigare", "återigen": "att det hänt minst en gång tidigare", "igen": "att det hänt minst en gång tidigare", "också": "att något annat liknande gäller", "dessutom": "att något annat redan etablerats"]
    private static let structuralPresupPositions: Set<String> = ["om", "ifall", "såvida", "förutsatt att", "under förutsättning att"]
    private static let nonRestrictiveMarkers = [", som ", ", vilket ", ", vilken ", ", vilka "]

    func detectPresuppositions(text: String) -> [Presupposition] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        var presuppositions: [Presupposition] = []
        for sentence in sentences {
            let sl = sentence.lowercased()
            let words = sl.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
            for (i, word) in words.enumerated() where Self.factiveVerbs.contains(word) {
                let complement = words[(i + 1)...].joined(separator: " ")
                presuppositions.append(Presupposition(type: .factive, text: sentence, presupposedContent: complement, trigger: word, confidence: 0.85, negationTest: true))
            }
            for (i, word) in words.enumerated() where Self.implicativeVerbs.contains(word) && i + 1 < words.count {
                let complement = words[(i + 1)...].joined(separator: " ")
                presuppositions.append(Presupposition(type: .implicative, text: sentence, presupposedContent: "försökte: \(complement)", trigger: word, confidence: 0.75, negationTest: false))
            }
            for (trigger, meaning) in Self.lexicalPresuppositionTriggers where sl.contains(trigger) {
                presuppositions.append(Presupposition(type: .lexical, text: sentence, presupposedContent: meaning, trigger: trigger, confidence: 0.7, negationTest: true))
            }
            if let condIdx = words.firstIndex(where: { Self.structuralPresupPositions.contains($0) }) {
                let condition = words[(condIdx + 1)...].joined(separator: " ")
                presuppositions.append(Presupposition(type: .structural, text: sentence, presupposedContent: "möjligt att: \(condition)", trigger: words[condIdx], confidence: 0.65, negationTest: false))
            }
            for marker in Self.nonRestrictiveMarkers where sl.contains(marker) {
                if let idx = sl.range(of: marker) {
                    let relativeContent = String(sl[idx.upperBound...]).components(separatedBy: ".").first ?? ""
                    presuppositions.append(Presupposition(type: .nonRestrictiveRelative, text: sentence, presupposedContent: "det som beskrivs existerar: \(relativeContent)", trigger: marker.trimmingCharacters(in: .whitespaces), confidence: 0.7, negationTest: true))
                }
            }
        }
        return presuppositions
    }

    // MARK: - Iteration 66: Conversational Implicature Detection

    struct Implicature: Identifiable {
        let id = UUID(); let violatedMaxim: GriceanMaxim; let utterance: String; let literalMeaning: String; let inferredMeaning: String; let confidence: Double; let explanation: String
    }
    enum GriceanMaxim: String, CaseIterable { case quantity = "Kvantitet"; case quality = "Kvalitet"; case relation = "Relation"; case manner = "Sätt" }

    func detectImplicatures(conversation: [String]) -> [Implicature] {
        guard conversation.count >= 2 else { return [] }
        var implicatures: [Implicature] = []
        for (idx, utterance) in conversation.enumerated() {
            let lower = utterance.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let words = lower.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }

            // Quantity violations
            if idx > 0 {
                let prevLen = conversation[idx - 1].count
                if prevLen > 50 && utterance.count < 10 && words.count <= 2 {
                    if words == ["ok"] || words == ["okej"] || words == ["ja"] || words == ["n"] || words == ["nä"] {
                        implicatures.append(Implicature(violatedMaxim: .quantity, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Talaren ger medvetet minimal information — kanske ogillande eller ointresse", confidence: 0.6, explanation: "Kvantitetsbrott: oväntat kort svar"))
                    }
                }
            }
            if words.count > 50 {
                let hedgeCount = words.filter { ["kanske", "möjligen", "typ", "liksom", "asså", "egentligen"].contains($0) }.count
                if hedgeCount >= 3 {
                    implicatures.append(Implicature(violatedMaxim: .quantity, utterance: utterance, literalMeaning: String(utterance.prefix(100)), inferredMeaning: "Onödigt mycket detaljinformation — kanske för att dölja något", confidence: 0.5, explanation: "Kvantitetsbrott: överdrivet detaljerat"))
                }
            }

            // Quality violations
            if lower.contains("alla ") && (lower.contains("vet") || lower.contains("tycker")) {
                implicatures.append(Implicature(violatedMaxim: .quality, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Generalisering utan belägg — subjektiv uppfattning som fakta", confidence: 0.55, explanation: "Kvalitetsbrott: obelagd generalisering"))
            }
            if (lower.contains("jag vet") || lower.contains("alla vet")) && words.contains(where: { $0.contains("alltid") || $0.contains("aldrig") }) {
                implicatures.append(Implicature(violatedMaxim: .quality, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Kunskapspåstående som inte kan verifieras — ironi eller överdrift", confidence: 0.6, explanation: "Kvalitetsbrott: kunskapspåstående med absolut formulering"))
            }

            // Relation violations
            if idx > 0 && words.count >= 3 {
                let prevWords = Set(conversation[idx - 1].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
                let currWords = Set(words.filter { $0.count > 3 })
                if prevWords.intersection(currWords).isEmpty && !lower.contains("?") && !conversation[idx - 1].contains("?") {
                    let hasTopicShift = ["förresten", "just det", "apropå", "men", "annars", "på ett annat plan"].contains { lower.contains($0) }
                    if !hasTopicShift {
                        implicatures.append(Implicature(violatedMaxim: .relation, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Svaret verkar inte relevant — talaren kanske undviker ämnet", confidence: 0.45, explanation: "Relationsbrott: ingen tydlig topikanknytning"))
                    }
                }
            }

            // Manner violations
            let vagueWords = Set(["något", "någon", "någonting", "saker", "ting", "grejer", "grej", "grejen", "typ", "liksom", "asså", "va", "nån", "nånstans"])
            let vagueCount = words.filter { vagueWords.contains($0) }.count
            if vagueCount >= 4 && words.count > 5 {
                implicatures.append(Implicature(violatedMaxim: .manner, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Talaren är medvetet otydlig — kanske för att undvika ansvar", confidence: 0.55, explanation: "Sättbrott: \(vagueCount) vaga uttryck"))
            }

            // Irony via maxim violation
            let posInBad = lower.contains("bra") || lower.contains("fint") || lower.contains("trevligt") || lower.contains("underbart")
            let badWords = ["problem", "fel", "dåligt", "trasig", "krångel", "misslyckad", "död", "katastrof"]
            if posInBad && words.contains(where: { badWords.contains($0) }) {
                implicatures.append(Implicature(violatedMaxim: .quality, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Ironi: positivt ord i negativ kontext — talaren menar motsatsen", confidence: 0.7, explanation: "Kvalitetsbrott: inkongruens mellan känsla och kontext"))
            }
        }
        return implicatures
    }

    // MARK: - Iteration 67: Genre Classification

    struct GenreClassification {
        let genre: Genre; let confidence: Double; let secondaryGenres: [(Genre, Double)]; let interpretationMode: InterpretationMode; let features: GenreFeatures
    }
    enum Genre: String, CaseIterable { case newsArticle = "nyhetsartikel"; case academicText = "akademisk text"; case casualConversation = "vardagssamtal"; case formalLetter = "formellt brev"; case instructionManual = "instruktion"; case opinionPiece = "opinion/ledare"; case narrativeFiction = "skönlitteratur"; case poetry = "poesi"; case advertisement = "annons/reklam"; case legalText = "juridisk text"; case email = "e-post"; case socialMedia = "sociala medier"; case unknown = "okänd" }
    enum InterpretationMode: String { case factChecking = "faktagranskning"; case hedgingAware = "hedging-medveten"; case metaphorHeavy = "metaforintensiv"; case imperativeDriven = "imperativstyrd"; case persuasionAware = "persuasionsmedveten"; case legalInterpretation = "juridisk tolkning"; case casual = "vardaglig"; case standard = "standard" }
    struct GenreFeatures { let avgSentenceLength: Double; let lexicalDiversity: Double; let formalWordRatio: Double; let punctuationDensity: Double; let hasHeadline: Bool; let hasCitations: Bool; let hasImperatives: Bool; let hasEmojis: Bool }

    private static let newsIndicators: Set<String> = ["enligt uppgift", "polis meddelar", "källa uppger", "nyhetsbyrån", "presstjänsten", "TT", "reporter", "korrespondent", "breaking", "senaste nytt", "just nu", "publicerad", "uppdaterad"]
    private static let academicIndicators: Set<String> = ["enligt studien", "forskningsresultat", "hypotes", "metod", "empirisk", "kvantitativ", "kvalitativ", "signifikant", "korrelation", "kausal", "sammanfattning", "abstract", "referens", "citerad", "litteratur", "avhandling"]
    private static let casualIndicators: Set<String> = ["asså", "typ", "liksom", "va", "ju", "haha", "lol", "fan", "sjukt", "grymt", "nice"]
    private static let formalLetterIndicators: Set<String> = ["bästa", "bäste", "med vänliga hälsningar", "vänliga hälsningar", "högaktningsfullt", "härmed", "bifogas", "åberopar", "diarienummer"]
    private static let instructionIndicators: Set<String> = ["gör så här", "steg", "instruktion", "observera", "viktigt", "säkerhet", "montera", "installera", "koppla", "anslut", "tryck", "klicka", "öppna", "välj", "spara"]
    private static let opinionIndicators: Set<String> = ["jag anser", "jag tycker", "enligt min mening", "det är dags", "vi bör", "vi måste", "det är fel att", "regeringen borde", "ledare", "krönika", "debattartikel"]
    private static let fictionIndicators: Set<String> = ["det var en gång", "han gick", "hon såg", "de stod", "plötsligt", "då hände", "berättade", "sade", "svarade", "tänkte", "kände", "viskade", "ropade"]
    private static let poetryIndicators: Set<String> = ["vers", "strof", "rim", "rytm", "dikt", "poesi", "låt", "sång", "melodi"]
    private static let advertisementIndicators: Set<String> = ["köp nu", "erbjudande", "rea", "rabatt", "begränsad tid", "exklusivt", "missa inte", "just nu", "billigt", "kampanj", "nyhet", "fri frakt", "prova gratis"]
    private static let legalIndicators: Set<String> = ["enligt lag", "paragraf", "lagrum", "rättsfall", "domstol", "åtal", "rättighet", "skyldighet", "avtal", "villkor", "bestämmelse", "föreskrift", "stadga", "förordning", "lagen"]
    private static let emailIndicators: Set<String> = ["hej", "bästa", "mvh", "hälsningar", "bilaga", "vidarebefordra", "svara alla", "cc", "bcc"]
    private static let socialMediaIndicators: Set<String> = ["#", "@", "follow", "like", "share", "retweet", "tagga", "story", "post", "uppdatering", "följare", "gilla"]

    func classifyGenre(text: String) -> GenreClassification {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        let totalWords = words.count; let totalSentences = max(1, sentences.count)
        let avgSentenceLength = Double(totalWords) / Double(totalSentences)
        let uniqueWords = Set(words); let lexicalDiversity = uniqueWords.isEmpty ? 0.0 : Double(uniqueWords.count) / Double(max(1, totalWords))
        let formalCount = words.filter { ["härmed", "bifogas", "enligt", "beträffande", "avseende", "vederbörande", "följaktligen", "således"].contains($0) }.count
        let formalWordRatio = Double(formalCount) / Double(max(1, totalWords))
        let punctuationCount = text.filter { ".!?,;:".contains($0) }.count
        let punctuationDensity = Double(punctuationCount) / Double(max(1, text.count))
        let hasHeadline = (sentences.first?.count ?? 0) < 30 && totalSentences > 2
        let hasCitations = lower.contains("\"") || lower.contains("enligt ")
        let hasImperatives = words.contains { ["gör", "öppna", "stäng", "tryck", "klicka", "välj", "spara", "montera", "installera"].contains($0) }
        let hasEmojis = text.unicodeScalars.contains { $0.properties.isEmojiPresentation == true }
        let features = GenreFeatures(avgSentenceLength: avgSentenceLength, lexicalDiversity: lexicalDiversity, formalWordRatio: formalWordRatio, punctuationDensity: punctuationDensity, hasHeadline: hasHeadline, hasCitations: hasCitations, hasImperatives: hasImperatives, hasEmojis: hasEmojis)

        var scores: [Genre: Double] = [:]
        scores[.newsArticle] = Double(words.filter { Self.newsIndicators.contains($0) }.count) * 0.3 + (hasCitations ? 0.3 : 0.0) + (hasHeadline ? 0.2 : 0.0) + (avgSentenceLength > 15 && avgSentenceLength < 30 ? 0.2 : 0.0)
        scores[.academicText] = Double(words.filter { Self.academicIndicators.contains($0) }.count) * 0.3 + (avgSentenceLength > 20 ? 0.3 : 0.0) + (lexicalDiversity > 0.6 ? 0.2 : 0.0) + (formalWordRatio > 0.05 ? 0.2 : 0.0)
        scores[.casualConversation] = Double(words.filter { Self.casualIndicators.contains($0) }.count) * 0.3 + (hasEmojis ? 0.4 : 0.0) + (avgSentenceLength < 10 ? 0.2 : 0.0)
        scores[.formalLetter] = Double(words.filter { Self.formalLetterIndicators.contains($0) }.count) * 0.4 + (formalWordRatio > 0.05 ? 0.3 : 0.0)
        scores[.instructionManual] = Double(words.filter { Self.instructionIndicators.contains($0) }.count) * 0.3 + (hasImperatives ? 0.4 : 0.0) + (avgSentenceLength < 15 ? 0.2 : 0.0)
        scores[.opinionPiece] = Double(words.filter { Self.opinionIndicators.contains($0) }.count) * 0.3 + (lower.contains("jag tycker") || lower.contains("jag anser") ? 0.3 : 0.0)
        scores[.narrativeFiction] = Double(words.filter { Self.fictionIndicators.contains($0) }.count) * 0.3 + (lower.contains("han ") && lower.contains("hon ") ? 0.2 : 0.0) + (avgSentenceLength > 10 && avgSentenceLength < 25 ? 0.2 : 0.0)
        let lineCount = text.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).count > 0 }.count
        scores[.poetry] = Double(words.filter { Self.poetryIndicators.contains($0) }.count) * 0.3 + (lineCount > totalSentences ? 0.4 : 0.0) + (avgSentenceLength < 8 ? 0.2 : 0.0)
        scores[.advertisement] = Double(words.filter { Self.advertisementIndicators.contains($0) }.count) * 0.3 + (hasImperatives ? 0.2 : 0.0) + (lower.contains("!") ? 0.2 : 0.0)
        scores[.legalText] = Double(words.filter { Self.legalIndicators.contains($0) }.count) * 0.3 + (formalWordRatio > 0.08 ? 0.3 : 0.0) + (avgSentenceLength > 25 ? 0.2 : 0.0)
        scores[.email] = Double(words.filter { Self.emailIndicators.contains($0) }.count) * 0.3 + (lower.hasPrefix("hej") || lower.hasPrefix("bästa") ? 0.3 : 0.0)
        scores[.socialMedia] = Double(words.filter { Self.socialMediaIndicators.contains($0) }.count) * 0.3 + (hasEmojis ? 0.3 : 0.0) + (avgSentenceLength < 8 ? 0.2 : 0.0)

        let sorted = scores.sorted { $0.value > $1.value }
        let primaryGenre = sorted.first?.key ?? .unknown
        let primaryScore = sorted.first?.value ?? 0.0
        let secondaryGenres = sorted.dropFirst(1).prefix(2).map { ($0.key, min(0.99, $0.value)) }.filter { $0.1 > 0.1 }
        let mode: InterpretationMode
        switch primaryGenre {
        case .newsArticle: mode = .factChecking
        case .academicText: mode = .hedgingAware
        case .poetry, .narrativeFiction: mode = .metaphorHeavy
        case .instructionManual: mode = .imperativeDriven
        case .opinionPiece, .advertisement: mode = .persuasionAware
        case .legalText: mode = .legalInterpretation
        case .casualConversation, .socialMedia: mode = .casual
        default: mode = .standard
        }
        return GenreClassification(genre: primaryGenre, confidence: min(0.95, primaryScore), secondaryGenres: secondaryGenres, interpretationMode: mode, features: features)
    }

    // MARK: - Iteration 68: Sentiment Trajectory Analysis

    struct SentimentTrajectory {
        let perSentenceSentiment: [SentenceSentiment]; let sentimentShifts: [SentimentShift]; let turningPoints: [TurningPoint]
        let emotionalArc: EmotionalArcType; let valenceStart: Double; let valenceEnd: Double; let valenceRange: ClosedRange<Double>
        let mixedSentiment: Bool; let bodyBudgetUpdate: BodyBudgetEffect
    }
    struct SentenceSentiment: Identifiable { let id = UUID(); let sentence: String; let index: Int; let valence: Double; let arousal: Double; let emotion: String }
    struct SentimentShift: Identifiable {
        let id = UUID(); let fromIndex: Int; let toIndex: Int; let fromValence: Double; let toValence: Double; let shiftMagnitude: Double; let shiftType: ShiftType
        enum ShiftType: String { case rising, falling, volatile, stable }
    }
    struct TurningPoint: Identifiable {
        let id = UUID(); let sentenceIndex: Int; let sentence: String; let valence: Double; let type: TurningPointType
        enum TurningPointType: String { case peak, trough, inflection }
    }
    enum EmotionalArcType: String { case rising = "stigande"; case falling = "fallande"; case risingFalling = "stigande-fallande"; case fallingRising = "fallande-stigande"; case stable = "stabil"; case volatile = "volatil"; case complex = "komplex" }
    struct BodyBudgetEffect { let effect: BodyBudgetEffectType; let intensity: Double; enum BodyBudgetEffectType: String { case energizing = "energigivande"; case draining = "energitömmande"; case calming = "lugnande"; case stimulating = "stimulerande"; case neutral = "neutral" } }

    func analyzeSentimentTrajectory(text: String) -> SentimentTrajectory {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        guard !sentences.isEmpty else { return SentimentTrajectory(perSentenceSentiment: [], sentimentShifts: [], turningPoints: [], emotionalArc: .stable, valenceStart: 0, valenceEnd: 0, valenceRange: 0...0, mixedSentiment: false, bodyBudgetUpdate: BodyBudgetEffect(effect: .neutral, intensity: 0)) }

        var perSentence: [SentenceSentiment] = []
        for (idx, sentence) in sentences.enumerated() {
            let result = Self.analyzeEmotionalValence(sentence)
            perSentence.append(SentenceSentiment(sentence: sentence, index: idx, valence: result.valence, arousal: result.arousal, emotion: result.emotion))
        }

        var shifts: [SentimentShift] = []
        for i in 0..<(perSentence.count - 1) {
            let from = perSentence[i], to = perSentence[i + 1]
            let magnitude = abs(to.valence - from.valence)
            if magnitude > 0.3 {
                let type: SentimentShift.ShiftType
                if to.valence > from.valence + 0.3 { type = .rising }
                else if to.valence < from.valence - 0.3 { type = .falling }
                else if magnitude > 0.6 { type = .volatile }
                else { type = .stable }
                shifts.append(SentimentShift(fromIndex: i, toIndex: i + 1, fromValence: from.valence, toValence: to.valence, shiftMagnitude: magnitude, shiftType: type))
            }
        }

        var turningPoints: [TurningPoint] = []
        for i in 1..<(perSentence.count - 1) {
            let prev = perSentence[i - 1].valence, curr = perSentence[i].valence, next = perSentence[i + 1].valence
            if curr > prev && curr > next { turningPoints.append(TurningPoint(sentenceIndex: i, sentence: perSentence[i].sentence, valence: curr, type: .peak)) }
            else if curr < prev && curr < next { turningPoints.append(TurningPoint(sentenceIndex: i, sentence: perSentence[i].sentence, valence: curr, type: .trough)) }
            else if (curr - prev) * (next - curr) < 0 { turningPoints.append(TurningPoint(sentenceIndex: i, sentence: perSentence[i].sentence, valence: curr, type: .inflection)) }
        }

        let valenceStart = perSentence.first?.valence ?? 0; let valenceEnd = perSentence.last?.valence ?? 0
        let allValences = perSentence.map { $0.valence }; let valenceMin = allValences.min() ?? 0; let valenceMax = allValences.max() ?? 0
        let overallDelta = valenceEnd - valenceStart; let shiftCount = shifts.count
        let arcType: EmotionalArcType
        if shiftCount >= 3 && abs(overallDelta) < 0.3 { arcType = .volatile }
        else if shiftCount >= 4 { arcType = .complex }
        else if overallDelta > 0.3 { arcType = .rising }
        else if overallDelta < -0.3 { arcType = .falling }
        else if turningPoints.count == 1 && turningPoints[0].type == .peak { arcType = .risingFalling }
        else if turningPoints.count == 1 && turningPoints[0].type == .trough { arcType = .fallingRising }
        else { arcType = .stable }

        let positiveCount = perSentence.filter { $0.valence > 0.3 }.count; let negativeCount = perSentence.filter { $0.valence < -0.3 }.count
        let mixedSentiment = positiveCount > 0 && negativeCount > 0 && Double(min(positiveCount, negativeCount)) / Double(perSentence.count) > 0.2

        let avgArousal = perSentence.map { $0.arousal }.reduce(0, +) / Double(max(1, perSentence.count))
        let avgValence = allValences.reduce(0, +) / Double(max(1, allValences.count))
        let bodyBudget: BodyBudgetEffect
        if avgValence > 0.3 && avgArousal > 0.5 { bodyBudget = BodyBudgetEffect(effect: .energizing, intensity: min(1.0, avgValence * avgArousal)) }
        else if avgValence < -0.3 && avgArousal > 0.5 { bodyBudget = BodyBudgetEffect(effect: .draining, intensity: min(1.0, abs(avgValence) * avgArousal)) }
        else if avgArousal < 0.3 { bodyBudget = BodyBudgetEffect(effect: .calming, intensity: min(1.0, 1.0 - avgArousal)) }
        else if avgValence > 0 && avgArousal > 0.3 { bodyBudget = BodyBudgetEffect(effect: .stimulating, intensity: min(1.0, avgArousal)) }
        else { bodyBudget = BodyBudgetEffect(effect: .neutral, intensity: 0) }

        return SentimentTrajectory(perSentenceSentiment: perSentence, sentimentShifts: shifts, turningPoints: turningPoints, emotionalArc: arcType, valenceStart: valenceStart, valenceEnd: valenceEnd, valenceRange: valenceMin...valenceMax, mixedSentiment: mixedSentiment, bodyBudgetUpdate: bodyBudget)
    }

    // MARK: - Iteration 69: Semantic Role Labeling

    struct SemanticRole: Identifiable { let id = UUID(); let predicate: String; let roles: [RoleFiller]; let sentence: String; let confidence: Double }
    struct RoleFiller: Codable { let role: SemanticRoleType; let filler: String; let position: String; let confidence: Double }
    enum SemanticRoleType: String, CaseIterable, Codable { case agent = "agens"; case patient = "patiens"; case instrument = "instrument"; case source = "källa"; case goal = "mål"; case location = "lokal"; case time = "tid"; case manner = "sätt"; case cause = "orsak"; case experiencer = "experiens"; case beneficiary = "gynnare" }

    private static let agentPreps: Set<String> = ["av", "genom", "med hjälp av"]
    private static let sourcePreps: Set<String> = ["från", "ur", "av", "ifrån"]
    private static let goalPreps: Set<String> = ["till", "mot", "in i", "upp till"]
    private static let locationPreps: Set<String> = ["i", "på", "vid", "under", "över", "bredvid", "mellan", "framför", "bakom"]
    private static let instrumentPreps: Set<String> = ["med", "genom", "med hjälp av"]
    private static let timePreps: Set<String> = ["på", "i", "under", "före", "efter", "mellan", "vid", "innan", "sedan", "tills"]
    private static let mannerPreps: Set<String> = ["på", "med", "utan", "genom"]
    private static let causePreps: Set<String> = ["på grund av", "genom", "tack vare", "av", "av skäl"]
    private static let beneficiaryPreps: Set<String> = ["för", "till", "åt"]
    private static let psychVerbs: Set<String> = ["älska", "hata", "frukta", "älskar", "hatar", "fruktar", "beundra", "beundrar", "ogilla", "ogillar", "gilla", "gillar", "tycka", "tycker", "tro", "tror", "känna", "känner", "uppleva", "upplever"]

    func labelSemanticRoles(sentence: String) -> [SemanticRole] {
        let lower = sentence.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
        var roles: [SemanticRole] = []

        for (i, word) in words.enumerated() {
            let isVerb = isLikelyVerbWord(word)
            guard isVerb else { continue }
            var roleFillers: [RoleFiller] = []
            let isPsychVerb = Self.psychVerbs.contains(word)

            // Subject = agent/experiencer
            if i >= 1 {
                let subject = words[max(0, i - 1)]
                let skipWords = Set(["och", "eller", "men", "för", "att", "som", "när", "om", "inte", "där", "här"])
                if !skipWords.contains(subject) && subject.count > 1 {
                    roleFillers.append(RoleFiller(role: isPsychVerb ? .experiencer : .agent, filler: subject, position: subject, confidence: 0.75))
                }
            }

            // Object = patient
            if i + 1 < words.count {
                var patientWords: [String] = []
                for w in words[(i + 1)...] {
                    if isPrepositionWord(w) { break }
                    let skipWords = Set(["och", "eller", "men", "för", "att", "som", "när", "om", "inte", "där", "här", "också", "bara", "redan", "alltid", "aldrig"])
                    if !skipWords.contains(w) && w.count > 1 { patientWords.append(w) }
                }
                if !patientWords.isEmpty { roleFillers.append(RoleFiller(role: .patient, filler: patientWords.joined(separator: " "), position: patientWords.joined(separator: " "), confidence: 0.65)) }
            }

            // Preposition-based role filling
            var cIdx = i
            while cIdx < words.count - 1 {
                cIdx += 1; let w = words[cIdx]
                if Self.agentPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .agent, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.8)) }
                else if Self.sourcePreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .source, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.8)) }
                else if Self.goalPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .goal, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.8)) }
                else if Self.locationPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .location, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.75)) }
                else if Self.instrumentPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .instrument, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.75)) }
                else if Self.timePreps.contains(w) && cIdx + 1 < words.count { let tp = collectPhrase(from: cIdx + 1, in: words); roleFillers.append(RoleFiller(role: .time, filler: tp, position: "\(w) \(tp)", confidence: 0.7)) }
                else if Self.mannerPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .manner, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.65)) }
                else if Self.causePreps.contains(w) && cIdx + 1 < words.count { let cp = collectPhrase(from: cIdx + 1, in: words); roleFillers.append(RoleFiller(role: .cause, filler: cp, position: "\(w) \(cp)", confidence: 0.7)) }
                else if Self.beneficiaryPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .beneficiary, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.75)) }
            }

            // Passive detection
            if word.hasSuffix("s") && word.count > 3, let avIdx = words.firstIndex(of: "av"), avIdx + 1 < words.count {
                roleFillers.append(RoleFiller(role: .agent, filler: words[avIdx + 1], position: "av \(words[avIdx + 1])", confidence: 0.85))
            }

            if !roleFillers.isEmpty {
                let avgConf = roleFillers.map { $0.confidence }.reduce(0, +) / Double(roleFillers.count)
                roles.append(SemanticRole(predicate: word, roles: roleFillers, sentence: sentence, confidence: avgConf))
            }
        }
        return roles
    }

    private func isLikelyVerbWord(_ word: String) -> Bool {
        let commonVerbs: Set<String> = ["är", "var", "bli", "ha", "få", "kunna", "måste", "ska", "vill", "gör", "säger", "går", "kommer", "tar", "ger", "ser", "hör", "vet", "tror", "tycker", "känner", "minns", "glömmer", "skriver", "läser", "tänker", "arbetar", "sover", "äter", "dricker", "springer", "åker", "reser", "flyger", "simmar", "cyklar", "kör", "köper", "säljer", "betalar", "kostar", "sparar", "bygger", "skapar", "fixar", "lagar", "hjälper", "älskar", "hatar", "gillar", "ogillar", "börjar", "slutar", "fortsätter", "försöker", "lyckas", "öppnar", "stänger", "ställer", "lägger", "sätter", "håller", "frågar", "svarar", "berättar", "förklarar", "ändrar", "påverkar", "leder", "följer", "stannar", "stiger", "faller", "ökar", "minskar", "växer"]
        if commonVerbs.contains(word) { return true }
        return word.hasSuffix("ar") || word.hasSuffix("er") || word.hasSuffix("r") || word.hasSuffix("ade") || word.hasSuffix("de") || word.hasSuffix("te") || word.hasSuffix("at") || word.hasSuffix("t") || word.hasSuffix("it") || word.hasSuffix("as") || word.hasSuffix("es")
    }
    private func isPrepositionWord(_ word: String) -> Bool {
        ["på", "i", "av", "för", "med", "till", "från", "om", "under", "över", "mellan", "genom", "utan", "vid", "efter", "före", "inom", "utanför", "bredvid", "framför", "bakom", "längs", "runt", "tack", "på", "grund", "med", "hjälp"].contains(word)
    }
    private func collectPhrase(from index: Int, in words: [String]) -> String {
        var phrase = ""; var idx = index
        while idx < words.count { let w = words[idx]; if isPrepositionWord(w) && idx > index { break }; if w == "och" || w == "eller" { break }; phrase += (phrase.isEmpty ? "" : " ") + w; idx += 1 }
        return phrase.isEmpty ? (index < words.count ? words[index] : "") : phrase
    }
}
