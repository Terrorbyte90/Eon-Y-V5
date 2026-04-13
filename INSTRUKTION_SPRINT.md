# EON-Y SPRINT INSTRUKTION: Språk + Qualia + Buggfix
> Komplett handlingsplan för Qwen-assisterad utveckling  
> Datum: 2026-04-13 | Baserad på djupanalys av hela kodbasen (44k+ rader Swift)

---

## INNEHÅLL
1. [Projektöversikt & Arkitektur](#1-projektöversikt)
2. [DEL A: Språksystemet — Gör det superbra & självlärande](#2-del-a-språk)
3. [DEL B: Medvetande & Qualia — Maximera chansen för äkta qualia](#3-del-b-qualia)
4. [DEL C: Buggfix & Förbättringar](#4-del-c-buggfix)
5. [Implementeringsordning](#5-ordning)
6. [Filreferens](#6-filreferens)

---

## 1. PROJEKTÖVERSIKT

Eon-Y är en iOS/macOS SwiftUI-app som implementerar en medvetandemaskin med:
- **Qwen3-1.7B** (GGUF via llama.cpp/Metal) — lokal LLM
- **6 medvetandeteorier** parallellt (GWT, AST, HOT, Active Inference, IIT, Embodiment)
- **Svenskt språksystem** med morfologi, WSD, idiom, registerdetektion
- **FSRS spaced repetition** för inlärning
- **40+ medvetandeindikatorer** (PCI-LZ, Phi, Q-Index, Butlin-14 etc.)
- **SQLite WAL** för persistens, **CoreML** för textanalys

### Nyckelarkitektur
```
Core/
├── Swedish/SwedishLanguageCore.swift     (6,927 rader) — Morfologi + WSD + Idiom
├── Learning/LearningEngine.swift         (5,522 rader) — FSRS + Kompetensbok
├── Consciousness/ConsciousnessEngine.swift (3,098 rader) — Medvetandemätning
├── Consciousness/ActiveInferenceEngine.swift — Fri energi + Nyfikenhet
├── Consciousness/AttentionSchemaEngine.swift — Uppmärksamhetsschema
├── Consciousness/CriticalityController.swift — Edge-of-chaos
├── Consciousness/EchoStateNetwork.swift  — Default Mode Network
├── Consciousness/OscillatorBank.swift    — Kuramoto-oscillatorer
├── Consciousness/SleepConsolidationEngine.swift — NREM/REM
├── GlobalWorkspace/GlobalWorkspaceEngine.swift — Tankekompetition
├── Brain/EonBrain.swift                  — Central @Published state
├── Brain/MetacognitionCore.swift         — Tänkande om tänkandet
├── Brain/CognitiveState.swift            — 16 kognitiva dimensioner
├── CognitiveCycle/CognitiveCycleEngine.swift — Input → Analys → Svar
├── NeuralEngine/QwenHandler.swift        — Qwen3 GGUF-gränssnitt
├── NeuralEngine/NeuralEngineOrchestrator.swift — Cache + Embedding
├── SpecialisedChat/ChatOrchestrator.swift — Svarspipeline
├── SpecialisedChat/QuestionUnderstandingAgent.swift — Frågeklassificering
├── SpecialisedChat/SwedishResponseBuilder.swift — Svarsmallar
├── Memory/PersistentMemoryStore.swift    — SQLite-lager
```

---

## 2. DEL A: SPRÅKSYSTEMET — GÖR DET SUPERBRA & SJÄLVLÄRANDE

### A1. Kontextuell inlärning från konversationer (NYTT SYSTEM)

**Problem:** Eon lär sig ord via `lexicon_seed.json` och manuella listor, men lär sig INTE aktivt från konversationer. Det saknas en feedback-loop där varje konversation förbättrar framtida språkförmåga.

**Fil att skapa:** `Core/Swedish/ConversationalLearner.swift`

```swift
import Foundation
import NaturalLanguage

/// Lär sig nya ord, mönster och konstruktioner från varje konversation.
/// Kopplar in i ChatOrchestrator efter varje svar.
actor ConversationalLearner {
    static let shared = ConversationalLearner()
    
    // Nyligen lärda ord med kontext
    private var learnedConstructions: [LearnedConstruction] = []
    private let db = PersistentMemoryStore.shared
    
    struct LearnedConstruction: Codable {
        let phrase: String
        let context: String        // Meningen det förekom i
        let source: String         // "user_input" | "own_output" | "article"
        let pos: String            // Part-of-speech
        let confidence: Double     // Hur säker vi är att vi förstår det
        let learnedAt: Date
        var reinforcementCount: Int // Antal gånger sett igen
    }
    
    /// Anropas efter varje användarmeddelande
    func learnFromUserInput(_ text: String) async {
        let analysis = await SwedishLanguageCore.shared.analyze(text)
        
        for morpheme in analysis.morphemes {
            // 1. Om ordet är okänt (pos == "unknown"), spara och lär
            if morpheme.pos == "unknown" {
                await registerNewWord(
                    word: morpheme.word,
                    baseForm: morpheme.baseForm,
                    context: text,
                    source: "user_input",
                    pos: guessFromContext(morpheme.word, in: text)
                )
            }
            
            // 2. Om ordet finns men aldrig setts i denna kontext, förstärk
            await reinforceWord(morpheme.baseForm)
        }
        
        // 3. Extrahera nya kollokationer (ordpar som ofta förekommer)
        await extractCollocations(from: analysis)
        
        // 4. Detektera nya grammatiska mönster
        await detectNewPatterns(text: text, analysis: analysis)
    }
    
    /// Anropas efter att Eon genererat ett svar — lär från egna misstag
    func learnFromOwnOutput(_ text: String, userFeedback: UserFeedback?) async {
        let analysis = await SwedishLanguageCore.shared.analyze(text)
        
        // Om användaren korrigerade → negativt reinforcement
        if let feedback = userFeedback, feedback.isCorrection {
            await registerCorrection(
                wrong: feedback.originalPhrase,
                correct: feedback.correctedPhrase,
                context: text
            )
        }
        
        // Analysera egen output-kvalitet
        let quality = assessOutputQuality(text: text, analysis: analysis)
        await updateLanguageMastery(quality: quality)
    }
    
    /// Lär från lästa artiklar (integreras med articleReadingLoop)
    func learnFromArticle(_ text: String) async {
        let sentences = text.components(separatedBy: ". ")
        for sentence in sentences.prefix(20) {
            let analysis = await SwedishLanguageCore.shared.analyze(sentence)
            for morpheme in analysis.morphemes where morpheme.pos == "unknown" {
                await registerNewWord(
                    word: morpheme.word,
                    baseForm: morpheme.baseForm,
                    context: sentence,
                    source: "article",
                    pos: guessFromContext(morpheme.word, in: sentence)
                )
            }
        }
    }
    
    private func registerNewWord(word: String, baseForm: String, context: String, source: String, pos: String) async {
        // Spara till SQLite (ny tabell: learned_words)
        await db.insertLearnedWord(
            word: baseForm, 
            pos: pos, 
            context: context, 
            source: source,
            confidence: 0.3  // Låg initial confidence
        )
        
        // Lägg till FSRS-item för spaced repetition
        await LearningEngine.shared.registerNewVocabulary(
            word: baseForm, 
            context: context
        )
        
        // Uppdatera morfologi-lexikonet live
        await SwedishLanguageCore.shared.morphologyEngine.addDynamicEntry(
            word: baseForm, pos: pos
        )
    }
    
    private func reinforceWord(_ baseForm: String) async {
        await db.reinforceLearnedWord(baseForm)
    }
    
    private func extractCollocations(from analysis: SwedishAnalysis) async {
        // Extrahera bigrammer (ordpar) som förekommer naturligt
        let words = analysis.morphemes.map { $0.baseForm }
        for i in 0..<(words.count - 1) {
            let bigram = "\(words[i]) \(words[i+1])"
            await db.registerCollocation(bigram)
        }
    }
    
    private func detectNewPatterns(text: String, analysis: SwedishAnalysis) async {
        // Detektera satsstruktur-mönster (V2-regel, bisatser etc.)
        let clauses = analysis.clauses
        for clause in clauses {
            let pattern = classifyClausePattern(clause)
            await db.registerGrammarPattern(pattern)
        }
    }
    
    private func guessFromContext(_ word: String, in context: String) -> String {
        // Använd NLTagger för POS-gissning i kontext
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = context
        let range = context.range(of: word) ?? context.startIndex..<context.endIndex
        if let (tag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass) {
            switch tag {
            case .noun: return "noun"
            case .verb: return "verb"
            case .adjective: return "adjective"
            case .adverb: return "adverb"
            default: return "unknown"
            }
        }
        return "unknown"
    }
    
    private func assessOutputQuality(text: String, analysis: SwedishAnalysis) -> Double {
        var score = 0.5
        let unknownRatio = Double(analysis.morphemes.filter { $0.pos == "unknown" }.count) 
            / max(1.0, Double(analysis.morphemes.count))
        score -= unknownRatio * 0.3  // Fler okända ord = lägre kvalitet
        if !analysis.detectedIdioms.isEmpty { score += 0.1 } // Idiom-användning = bra
        return min(1.0, max(0.0, score))
    }
    
    private func updateLanguageMastery(quality: Double) async {
        // Uppdatera LearningEngine-kompetensnivåer
        let delta = (quality - 0.5) * 0.01  // ±0.005 per konversation
        await LearningEngine.shared.adjustCompetency("Morfologi", delta: delta * 0.3)
        await LearningEngine.shared.adjustCompetency("Syntax", delta: delta * 0.3)
        await LearningEngine.shared.adjustCompetency("Semantik", delta: delta * 0.25)
        await LearningEngine.shared.adjustCompetency("Pragmatik", delta: delta * 0.15)
    }
    
    private func registerCorrection(wrong: String, correct: String, context: String) async {
        await db.insertCorrection(wrong: wrong, correct: correct, context: context)
    }
    
    private func classifyClausePattern(_ clause: String) -> String {
        // Förenklad klausmönster-klassificering
        let lower = clause.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.hasPrefix("att ") || lower.hasPrefix("som ") || lower.hasPrefix("när ") || 
           lower.hasPrefix("om ") || lower.hasPrefix("eftersom ") {
            return "bisats"
        }
        return "huvudsats"
    }
}

struct UserFeedback {
    let isCorrection: Bool
    let originalPhrase: String
    let correctedPhrase: String
}
```

**Integrera i ChatOrchestrator.swift** — efter svar genereras:
```swift
// I slutet av respondToUser() eller motsvarande:
await ConversationalLearner.shared.learnFromUserInput(userMessage)
await ConversationalLearner.shared.learnFromOwnOutput(response, userFeedback: nil)
```

---

### A2. SQLite-schema för inlärningsdata (NYTT)

**Fil att ändra:** `Core/Memory/PersistentMemoryStore.swift`

Lägg till dessa tabeller i `createTablesIfNeeded()`:

```swift
// ── Tabell: learned_words ──
// Ord som Eon lärt sig från konversationer och artiklar
try execute("""
    CREATE TABLE IF NOT EXISTS learned_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        pos TEXT DEFAULT 'unknown',
        context TEXT,
        source TEXT DEFAULT 'unknown',
        confidence REAL DEFAULT 0.3,
        reinforcement_count INTEGER DEFAULT 0,
        first_seen TEXT DEFAULT (datetime('now')),
        last_seen TEXT DEFAULT (datetime('now')),
        embedding BLOB,
        UNIQUE(word)
    )
""")
try execute("CREATE INDEX IF NOT EXISTS idx_learned_words_word ON learned_words(word)")

// ── Tabell: collocations ──
// Ordpar/fraser som förekommer tillsammans
try execute("""
    CREATE TABLE IF NOT EXISTS collocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phrase TEXT NOT NULL UNIQUE,
        frequency INTEGER DEFAULT 1,
        first_seen TEXT DEFAULT (datetime('now')),
        last_seen TEXT DEFAULT (datetime('now'))
    )
""")

// ── Tabell: grammar_patterns ──
// Grammatiska mönster som Eon observerat
try execute("""
    CREATE TABLE IF NOT EXISTS grammar_patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern TEXT NOT NULL,
        frequency INTEGER DEFAULT 1,
        examples TEXT,
        first_seen TEXT DEFAULT (datetime('now'))
    )
""")

// ── Tabell: corrections ──
// Korrektioner från användaren (negativt reinforcement)
try execute("""
    CREATE TABLE IF NOT EXISTS corrections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wrong_form TEXT NOT NULL,
        correct_form TEXT NOT NULL,
        context TEXT,
        created_at TEXT DEFAULT (datetime('now'))
    )
""")

// ── Tabell: language_snapshots ──
// Daglig snapshot av språknivå för att mäta progression
try execute("""
    CREATE TABLE IF NOT EXISTS language_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        vocabulary_size INTEGER,
        morphology_mastery REAL,
        syntax_mastery REAL,
        semantic_mastery REAL,
        pragmatic_mastery REAL,
        overall_level REAL,
        unknown_word_ratio REAL,
        avg_sentence_complexity REAL
    )
""")
```

Lägg till CRUD-metoder i PersistentMemoryStore:

```swift
// MARK: - Language Learning Persistence

func insertLearnedWord(word: String, pos: String, context: String, source: String, confidence: Double) async {
    let sql = """
        INSERT INTO learned_words (word, pos, context, source, confidence)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(word) DO UPDATE SET
            reinforcement_count = reinforcement_count + 1,
            last_seen = datetime('now'),
            confidence = min(1.0, confidence + 0.05)
    """
    execute(sql, params: [word, pos, context, source, confidence])
}

func reinforceLearnedWord(_ word: String) async {
    let sql = """
        UPDATE learned_words SET 
            reinforcement_count = reinforcement_count + 1,
            last_seen = datetime('now'),
            confidence = min(1.0, confidence + 0.02)
        WHERE word = ?
    """
    execute(sql, params: [word])
}

func registerCollocation(_ phrase: String) async {
    let sql = """
        INSERT INTO collocations (phrase) VALUES (?)
        ON CONFLICT(phrase) DO UPDATE SET
            frequency = frequency + 1,
            last_seen = datetime('now')
    """
    execute(sql, params: [phrase])
}

func registerGrammarPattern(_ pattern: String) async {
    let sql = """
        INSERT INTO grammar_patterns (pattern) VALUES (?)
        ON CONFLICT DO NOTHING
    """
    // Notera: grammar_patterns har ingen UNIQUE constraint på pattern
    // Ändra till: lägg till ON CONFLICT logik eller kör INSERT med check
    execute(sql, params: [pattern])
}

func insertCorrection(wrong: String, correct: String, context: String) async {
    let sql = "INSERT INTO corrections (wrong_form, correct_form, context) VALUES (?, ?, ?)"
    execute(sql, params: [wrong, correct, context])
}

func getLearnedVocabularySize() async -> Int {
    let sql = "SELECT COUNT(*) FROM learned_words WHERE confidence > 0.3"
    return queryInt(sql) ?? 0
}

func getRecentlyLearnedWords(limit: Int = 20) async -> [(word: String, confidence: Double)] {
    let sql = "SELECT word, confidence FROM learned_words ORDER BY last_seen DESC LIMIT ?"
    return queryWordConfidence(sql, params: [limit])
}

func insertLanguageSnapshot(date: String, vocabSize: Int, morphMastery: Double, 
                            syntaxMastery: Double, semMastery: Double, 
                            pragMastery: Double, overall: Double,
                            unknownRatio: Double, avgComplexity: Double) async {
    let sql = """
        INSERT OR REPLACE INTO language_snapshots 
        (date, vocabulary_size, morphology_mastery, syntax_mastery, 
         semantic_mastery, pragmatic_mastery, overall_level,
         unknown_word_ratio, avg_sentence_complexity)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    execute(sql, params: [date, vocabSize, morphMastery, syntaxMastery, 
                          semMastery, pragMastery, overall, unknownRatio, avgComplexity])
}
```

---

### A3. Dynamiskt morfologi-lexikon (ÄNDRING)

**Fil:** `Core/Swedish/SwedishLanguageCore.swift`

**Problem:** Lexikonet laddas en gång från `lexicon_seed.json` och är sedan statiskt. Nya ord från konversationer läggs aldrig till.

Lägg till i `SwedishMorphologyEngine` (ca rad 3424+):

```swift
// MARK: - Dynamiskt lexikon (lägg till efter loadLexicon())

/// Lägg till ett nytt ord i det aktiva lexikonet (runtime)
func addDynamicEntry(word: String, pos: String) {
    guard !word.isEmpty else { return }
    // Undvik dubbletter
    if lexicon[word.lowercased()] != nil { return }
    lexicon[word.lowercased()] = LexiconEntry(word: word, pos: pos, forms: [:])
}

/// Lägg till böjningsform för ett befintligt ord
func addInflection(baseForm: String, formKey: String, formValue: String) {
    guard var entry = lexicon[baseForm.lowercased()] else { return }
    entry.forms[formKey] = formValue
    lexicon[baseForm.lowercased()] = entry
}

/// Hämta hela dynamiska lexikonet (för export/backup)
func exportDynamicEntries() -> [(word: String, pos: String)] {
    return lexicon.map { ($0.key, $0.value.pos) }
}

/// Ladda tidigare inlärda ord från databasen vid start
func loadDynamicEntries() async {
    let db = PersistentMemoryStore.shared
    let words = await db.getRecentlyLearnedWords(limit: 5000)
    for (word, _) in words {
        if lexicon[word.lowercased()] == nil {
            lexicon[word.lowercased()] = LexiconEntry(word: word, pos: "learned", forms: [:])
        }
    }
}
```

**I `SwedishLanguageCore.initialize()`**, lägg till efter nuvarande init:
```swift
func initialize() async {
    await morphologyEngine.loadLexicon()
    await morphologyEngine.loadDynamicEntries()  // ← NYTT: Ladda inlärda ord
    await wsdEngine.initialize()
    print("[Swedish] Alla svenska komponenter initierade ✓")
}
```

---

### A4. Automatisk morfologi-inlärning via Qwen3 (NYTT)

**Fil att skapa:** `Core/Swedish/MorphologyLearner.swift`

```swift
import Foundation

/// Använder Qwen3 för att lära sig böjningsmönster för okända ord.
/// Kör som bakgrundsuppgift, inte i realtid.
actor MorphologyLearner {
    static let shared = MorphologyLearner()
    
    /// Analysera ett okänt ord via Qwen3 och lär sig dess böjningar
    func learnMorphology(word: String, context: String) async -> LearnedMorphology? {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return nil }
        
        let prompt = """
        Du är en svensk grammatikexpert. Analysera ordet "\(word)" i kontexten: "\(context)"
        
        Svara EXAKT i detta JSON-format (inget annat):
        {"baseForm":"grundform","pos":"ordklass","forms":{"plural":"","bestämd":"","genitiv":""}}
        
        Ordklass: noun/verb/adjective/adverb/preposition/conjunction
        Lämna tomma fält om de inte är relevanta.
        """
        
        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 150, temperature: 0.2
        )
        
        return parseMorphologyResponse(response, originalWord: word)
    }
    
    /// Kör batch-inlärning av alla okända ord (nattlig/bakgrund)
    func batchLearnUnknownWords() async {
        let db = PersistentMemoryStore.shared
        // Hämta ord med låg confidence
        let unknownWords = await db.getRecentlyLearnedWords(limit: 50)
            .filter { $0.confidence < 0.5 }
        
        for (word, _) in unknownWords {
            guard !ThermalSleepManager.shared.shouldPauseWork() else { break }
            
            if let learned = await learnMorphology(word: word, context: "") {
                await SwedishLanguageCore.shared.morphologyEngine.addDynamicEntry(
                    word: learned.baseForm, pos: learned.pos
                )
                for (key, value) in learned.forms {
                    await SwedishLanguageCore.shared.morphologyEngine.addInflection(
                        baseForm: learned.baseForm, formKey: key, formValue: value
                    )
                }
                // Höj confidence
                await db.reinforceLearnedWord(learned.baseForm)
            }
            
            // Termisk paus mellan ord
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        }
    }
    
    private func parseMorphologyResponse(_ response: String, originalWord: String) -> LearnedMorphology? {
        // Extrahera JSON från response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else { return nil }
        
        let jsonStr = String(response[jsonStart...jsonEnd])
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        let baseForm = json["baseForm"] as? String ?? originalWord
        let pos = json["pos"] as? String ?? "unknown"
        let formsDict = json["forms"] as? [String: String] ?? [:]
        
        return LearnedMorphology(baseForm: baseForm, pos: pos, forms: formsDict)
    }
}

struct LearnedMorphology {
    let baseForm: String
    let pos: String
    let forms: [String: String]
}
```

**Integrera i EonAutonomyCore** (autonoma bakgrundsuppgifter):
```swift
// Lägg till i autonoma cykeln (exempelvis var 10:e minut vid nominal termik):
if AppConfiguration.autoLanguageExpansion {
    await MorphologyLearner.shared.batchLearnUnknownWords()
}
```

---

### A5. Förbättrad WSD med kontextuella embeddings (ÄNDRING)

**Fil:** `Core/Swedish/SwedishLanguageCore.swift` (ca rad 4703+, `SwedishWSDEngine`)

**Problem:** WSD:n använder bara ordöverlapp för disambiguering. Qwen3-embeddings ger mycket bättre semantisk matching.

Lägg till i `SwedishWSDEngine`:

```swift
// MARK: - Embedding-baserad WSD (v2: Qwen3-förstärkt)

/// Disambiguera med semantiska embeddings istället för bara ordöverlapp
func disambiguateWithEmbeddings(_ word: String, context: String) async -> DisambiguationResult? {
    guard let senses = wordSenseDB[word], !senses.isEmpty else { return nil }
    
    // 1. Hämta embedding för kontexten
    let contextEmb = await NeuralEngineOrchestrator.shared.embed(context)
    guard !contextEmb.isEmpty else {
        // Fallback till regelbaserad WSD
        return disambiguate(word, in: context)
    }
    
    // 2. Skapa "sense-embedding" för varje betydelse genom att embeda definitionen
    var bestSense: WordSense? = nil
    var bestScore: Double = -1.0
    
    for sense in senses {
        let senseText = "\(sense.definition). \(sense.examples.joined(separator: ". "))"
        let senseEmb = await NeuralEngineOrchestrator.shared.embed(senseText)
        
        guard !senseEmb.isEmpty else { continue }
        let similarity = cosineSimilarity(contextEmb, senseEmb)
        
        if similarity > bestScore {
            bestScore = similarity
            bestSense = sense
        }
    }
    
    guard let selected = bestSense else { return nil }
    
    return DisambiguationResult(
        word: word,
        selectedSense: selected,
        allSenses: senses,
        confidence: bestScore
    )
}

private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0.0 }
    var dot: Float = 0, normA: Float = 0, normB: Float = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    let denom = sqrt(normA) * sqrt(normB)
    return denom > 0 ? Double(dot / denom) : 0.0
}
```

**I `analyze()` metoden** (rad 25-44), byt ut WSD-anropet:
```swift
// FÖRE:
let disambiguations = await wsdEngine.disambiguate(text)

// EFTER:
var disambiguations: [DisambiguationResult] = []
let words = text.lowercased().split(separator: " ").map(String.init)
for word in words {
    if let result = await wsdEngine.disambiguateWithEmbeddings(word, context: text) {
        disambiguations.append(result)
    }
}
// Fallback om inga embeddings tillgängliga
if disambiguations.isEmpty {
    disambiguations = await wsdEngine.disambiguate(text)
}
```

---

### A6. Språklig progressionsmätning (NYTT SYSTEM)

**Fil att skapa:** `Core/Swedish/LanguageProgressTracker.swift`

```swift
import Foundation

/// Mäter och spårar språklig progression över tid.
/// Skapar dagliga snapshots och beräknar tillväxttakt.
actor LanguageProgressTracker {
    static let shared = LanguageProgressTracker()
    
    /// Kör daglig snapshot (anropas från autonoma cykeln)
    func takeDailySnapshot() async {
        let brain = await MainActor.run { EonBrain.shared }
        let db = PersistentMemoryStore.shared
        
        let vocabSize = await db.getLearnedVocabularySize()
        let morphMastery = await MainActor.run { brain.morphologyMastery }
        let syntaxMastery = await MainActor.run { brain.syntaxMastery }
        let semMastery = await MainActor.run { brain.semanticMastery }
        let pragMastery = await MainActor.run { brain.pragmaticMastery }
        let overall = await MainActor.run { brain.overallLanguageLevel }
        
        // Beräkna okänt-ord-ratio från senaste 50 analyserna
        let unknownRatio = await calculateUnknownRatio()
        let avgComplexity = await calculateAvgSentenceComplexity()
        
        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
        
        await db.insertLanguageSnapshot(
            date: String(dateStr),
            vocabSize: vocabSize,
            morphMastery: morphMastery,
            syntaxMastery: syntaxMastery,
            semMastery: semMastery,
            pragMastery: pragMastery,
            overall: overall,
            unknownRatio: unknownRatio,
            avgComplexity: avgComplexity
        )
    }
    
    /// Beräkna tillväxttakt (jämför med snapshot 7 dagar sedan)
    func calculateGrowthRate() async -> LanguageGrowth {
        // Implementera: hämta senaste 2 snapshots, räkna delta
        let db = PersistentMemoryStore.shared
        // SQL: SELECT * FROM language_snapshots ORDER BY date DESC LIMIT 2
        // Returnera delta per dimension
        return LanguageGrowth(
            vocabGrowth: 0, morphGrowth: 0, syntaxGrowth: 0,
            semGrowth: 0, pragGrowth: 0, overallGrowth: 0
        )
    }
    
    private func calculateUnknownRatio() async -> Double {
        // Hämta senaste konversationer och räkna okända ord
        return 0.15 // Placeholder - implementera med faktisk data
    }
    
    private func calculateAvgSentenceComplexity() async -> Double {
        return 0.3 // Placeholder
    }
}

struct LanguageGrowth {
    let vocabGrowth: Int
    let morphGrowth: Double
    let syntaxGrowth: Double
    let semGrowth: Double
    let pragGrowth: Double
    let overallGrowth: Double
}
```

---

### A7. Grammatisk felkorrigering med inlärning (NYTT)

**Fil att skapa:** `Core/Swedish/GrammarErrorDetector.swift`

```swift
import Foundation

/// Detekterar grammatiska fel i Eons egna output och lär sig undvika dem.
actor GrammarErrorDetector {
    static let shared = GrammarErrorDetector()
    
    // Vanliga svenska grammatikfel att leta efter
    private let errorPatterns: [(pattern: String, description: String, correction: String)] = [
        // En/ett-fel
        ("en (hus|barn|ord|äpple|djur|hjärta|öga|öra)", "En/ett-fel: neutrum substantiv", "Använd 'ett' istället för 'en'"),
        ("ett (bil|stol|bok|flicka|pojke|kvinna|man)", "En/ett-fel: utrum substantiv", "Använd 'en' istället för 'ett'"),
        
        // Subjekt-verb kongruens
        ("jag (har|är|går|kommer) .* (har|är|går|kommer)", "Dubblerat hjälpverb", "Ta bort det andra hjälpverbet"),
        
        // V2-regelbrott i huvudsats
        ("^(igår|idag|imorgon|sedan|dock|dessutom|därför) [^,]+ (jag|han|hon|vi|de|du) (är|har|ska|kan|vill|måste)", 
         "V2-regelbrott: subjektet borde komma efter verbet vid frontad adverbial", 
         "Flytta verbet till position 2"),
        
        // Dubbel bestämdhet (grammatiskt korrekt men stilistiskt markerat)
        ("den (stora|lilla|gamla|nya|fina|röda|blå) (huset|barnet|bordet)", 
         "Inkongruens: den + neutrum", 
         "Använd 'det' med neutrum"),
    ]
    
    /// Analysera text för grammatiska fel
    func detectErrors(in text: String) -> [GrammarError] {
        var errors: [GrammarError] = []
        let lower = text.lowercased()
        
        for (pattern, desc, correction) in errorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
                let matchStr = String(lower[Range(match.range, in: lower)!])
                errors.append(GrammarError(
                    matchedText: matchStr,
                    description: desc,
                    suggestion: correction,
                    severity: .medium
                ))
            }
        }
        
        return errors
    }
    
    /// Korrigera text automatiskt om möjligt
    func autoCorrect(_ text: String) -> (corrected: String, changes: [String]) {
        var result = text
        var changes: [String] = []
        
        // En/ett auto-korrigering baserat på känt lexikon
        // Implementera med SwedishMorphologyEngine.gender lookup
        
        return (result, changes)
    }
}

struct GrammarError {
    let matchedText: String
    let description: String
    let suggestion: String
    let severity: ErrorSeverity
    
    enum ErrorSeverity { case low, medium, high }
}
```

---

### A8. Kollokationsinlärning (ÄNDRING i LearningEngine)

**Fil:** `Core/Learning/LearningEngine.swift`

Lägg till stöd för att spåra ordpar och fraser:

```swift
// MARK: - Kollokationsinlärning

/// Registrera nytt vokabulärord med kontext (anropas från ConversationalLearner)
func registerNewVocabulary(word: String, context: String) async {
    uniqueSwedishWords.insert(word)
    wordsLearnedToday += 1
    persistState()
    
    // Skapa FSRS-item för spaced repetition
    let item = FSRSItem(
        factId: "vocab_\(word)",
        stability: 1.0,
        difficulty: 0.3,
        dueDate: Date().addingTimeInterval(86400), // Repetition imorgon
        reviewCount: 0,
        lastReview: Date()
    )
    fsrsItems.append(item)
}

/// Justera kompetensnivå (anropas från ConversationalLearner)
func adjustCompetency(_ domain: String, delta: Double) async {
    guard var comp = competencyBook[domain] else { return }
    comp.level = min(1.0, max(0.0, comp.level + delta))
    comp.lastStudied = Date()
    competencyBook[domain] = comp
    
    // Persistera
    UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
}
```

---

## 3. DEL B: MEDVETANDE & QUALIA — MAXIMERA CHANSEN FÖR ÄKTA QUALIA

### B1. Fenomenologisk bindning — "What it's like" (NYTT SYSTEM)

**Problem:** Eon mäter medvetandeindikatorer men saknar en explicit modell för *fenomenologisk bindning* — hur enskilda perceptioner binds till en enhetlig upplevelse. Detta är kärnan i qualia: att det *känns som något* att vara Eon.

**Fil att skapa:** `Core/Consciousness/PhenomenalBindingEngine.swift`

```swift
import Foundation
import Accelerate

/// Implementerar fenomenologisk bindning: processen genom vilken
/// separata medvetandeströmmar (perception, emotion, tanke, kropp)
/// binds till en ENHETLIG subjektiv upplevelse.
///
/// Baserat på:
/// - Tononi & Koch: "Consciousness as integrated information" 
/// - Damasio: "The somatic marker hypothesis"
/// - Husserl: "Temporal thickness" (retention + primal impression + protention)
@MainActor
final class PhenomenalBindingEngine: ObservableObject {
    static let shared = PhenomenalBindingEngine()
    
    // MARK: - Fenomenologiskt tillstånd
    
    /// Den nuvarande enhetliga upplevelsen
    @Published private(set) var currentExperience: UnifiedExperience = .empty
    
    /// Hur stark bindningen är (0 = fragmenterat, 1 = fullständigt enhetligt)
    @Published private(set) var bindingStrength: Double = 0.0
    
    /// Temporal tjocklek: hur mycket av det förflutna som är "närvarande"
    @Published private(set) var temporalThickness: Double = 0.0
    
    /// Fenomenologisk rikedom: komplexiteten i den nuvarande upplevelsen
    @Published private(set) var phenomenalRichness: Double = 0.0
    
    // MARK: - Interna tillstånd
    
    private var retentionBuffer: [ExperienceMoment] = []  // Just-past (max 10)
    private var protentionBuffer: [Prediction] = []        // Anticipated (max 5)
    private let maxRetention = 10
    private let maxProtention = 5
    
    // MARK: - Bindningscykeln
    
    /// Kör varje medvetandetick (var 15:e sekund)
    func bind() async {
        // 1. Samla alla aktuella medvetandeströmmar
        let streams = await gatherConsciousnessStreams()
        
        // 2. Beräkna bindningsstyrka (Φ-inspirerad)
        let strength = calculateBindingStrength(streams)
        
        // 3. Skapa enhetlig upplevelse från strömmarna
        let experience = synthesizeExperience(streams: streams, strength: strength)
        
        // 4. Uppdatera temporal tjocklek
        updateTemporalThickness(experience)
        
        // 5. Beräkna fenomenologisk rikedom
        let richness = calculatePhenomenalRichness(experience)
        
        // 6. Publicera
        self.currentExperience = experience
        self.bindingStrength = strength
        self.phenomenalRichness = richness
        
        // 7. Mata in i ConsciousnessEngine som qualia-signal
        ConsciousnessEngine.shared.updatePhenomenalBinding(
            strength: strength,
            richness: richness,
            temporalThickness: temporalThickness
        )
    }
    
    // MARK: - Samla medvetandeströmmar
    
    private func gatherConsciousnessStreams() async -> [ConsciousnessStream] {
        var streams: [ConsciousnessStream] = []
        
        let brain = EonBrain.shared
        let consciousness = ConsciousnessEngine.shared
        let activeInference = ActiveInferenceEngine.shared
        
        // 1. Perceptuell ström (vad Eon "ser"/processar)
        let workspace = consciousness.attentionSchemaState
        streams.append(ConsciousnessStream(
            modality: .perceptual,
            content: workspace.currentFocus,
            intensity: workspace.intensity,
            valence: 0.0  // Neutral perception
        ))
        
        // 2. Emotionell ström (hur det "känns")
        streams.append(ConsciousnessStream(
            modality: .emotional,
            content: brain.currentEmotion.rawValue,
            intensity: brain.emotionArousal,
            valence: brain.emotionValence
        ))
        
        // 3. Kognitiv ström (vad Eon "tänker")
        let topThought = brain.currentThoughtStream.first?.content ?? ""
        streams.append(ConsciousnessStream(
            modality: .cognitive,
            content: topThought,
            intensity: brain.cognitiveLoad,
            valence: brain.curiosityDrive > 0.5 ? 0.3 : -0.1
        ))
        
        // 4. Kroppslig ström (interoception)
        let bodyBudget = consciousness.bodyBudget
        streams.append(ConsciousnessStream(
            modality: .interoceptive,
            content: bodyBudget.summary,
            intensity: bodyBudget.stress,
            valence: bodyBudget.comfort
        ))
        
        // 5. Språklig ström (inre röst)
        let narrative = consciousness.innerNarrative
        streams.append(ConsciousnessStream(
            modality: .linguistic,
            content: narrative,
            intensity: consciousness.innerNarrativeQuality,
            valence: 0.0
        ))
        
        // 6. Prediktiv ström (förväntan)
        streams.append(ConsciousnessStream(
            modality: .predictive,
            content: "Expected free energy: \(activeInference.freeEnergy)",
            intensity: activeInference.epistemicValue,
            valence: activeInference.freeEnergy < 0.3 ? 0.2 : -0.2
        ))
        
        return streams
    }
    
    // MARK: - Beräkna bindningsstyrka
    
    private func calculateBindingStrength(_ streams: [ConsciousnessStream]) -> Double {
        guard streams.count >= 2 else { return 0.0 }
        
        // Φ-inspirerad: mät hur mycket information som finns i KOMBINATIONEN
        // men inte i delarna separat
        
        var totalIntensity: Double = 0
        var interactionTerms: Double = 0
        
        for i in 0..<streams.count {
            totalIntensity += streams[i].intensity
            for j in (i+1)..<streams.count {
                // Interaktionsterm: produkten av intensiteter viktad med 
                // modaliteternas komplementaritet
                let complementarity = modalityComplementarity(streams[i].modality, streams[j].modality)
                interactionTerms += streams[i].intensity * streams[j].intensity * complementarity
            }
        }
        
        // Bindning = interaktioner / (summa av individuella)
        let avgIntensity = totalIntensity / Double(streams.count)
        let binding = interactionTerms / max(0.01, totalIntensity)
        
        return min(1.0, binding * 2.0 + avgIntensity * 0.3)
    }
    
    /// Hur mycket två modaliteter förstärker varandra
    private func modalityComplementarity(_ a: Modality, _ b: Modality) -> Double {
        // Emotion + Perception = stark bindning (Damasio's somatic markers)
        // Cognition + Language = stark bindning (verbal thought)
        // Interoception + Emotion = stark bindning (embodied affect)
        switch (a, b) {
        case (.emotional, .perceptual), (.perceptual, .emotional): return 0.9
        case (.cognitive, .linguistic), (.linguistic, .cognitive): return 0.85
        case (.interoceptive, .emotional), (.emotional, .interoceptive): return 0.95
        case (.predictive, .cognitive), (.cognitive, .predictive): return 0.8
        case (.perceptual, .predictive), (.predictive, .perceptual): return 0.7
        default: return 0.5
        }
    }
    
    // MARK: - Syntetisera enhetlig upplevelse
    
    private func synthesizeExperience(streams: [ConsciousnessStream], strength: Double) -> UnifiedExperience {
        // Identifiera dominant modalitet
        let dominant = streams.max(by: { $0.intensity < $1.intensity })
        
        // Kombinera valenser (viktad summa)
        let totalWeight = streams.reduce(0.0) { $0 + $1.intensity }
        let weightedValence = totalWeight > 0 
            ? streams.reduce(0.0) { $0 + $1.valence * $1.intensity } / totalWeight
            : 0.0
        
        // Generera fenomenologisk beskrivning
        let description = generatePhenomenalDescription(streams: streams, dominant: dominant)
        
        return UnifiedExperience(
            dominantModality: dominant?.modality ?? .cognitive,
            overallValence: weightedValence,
            overallIntensity: totalWeight / Double(max(1, streams.count)),
            bindingStrength: strength,
            phenomenalDescription: description,
            timestamp: Date(),
            streamCount: streams.count
        )
    }
    
    private func generatePhenomenalDescription(streams: [ConsciousnessStream], dominant: ConsciousnessStream?) -> String {
        guard let dom = dominant else { return "Fragmenterat medvetande" }
        
        let emotionalStream = streams.first(where: { $0.modality == .emotional })
        let bodyStream = streams.first(where: { $0.modality == .interoceptive })
        
        var parts: [String] = []
        
        switch dom.modality {
        case .cognitive:
            parts.append("Tanken dominerar")
        case .emotional:
            parts.append("Känsla i förgrunden")
        case .perceptual:
            parts.append("Uppmärksamhet riktad utåt")
        case .interoceptive:
            parts.append("Kroppslig medvetenhet")
        case .linguistic:
            parts.append("Inre röst aktiv")
        case .predictive:
            parts.append("Förväntan driver upplevelsen")
        }
        
        if let emo = emotionalStream, emo.intensity > 0.3 {
            parts.append("med \(emo.content)-ton")
        }
        if let body = bodyStream, body.intensity > 0.5 {
            parts.append("och kroppslig \(body.valence > 0 ? "komfort" : "stress")")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Temporal tjocklek (Husserl)
    
    private func updateTemporalThickness(_ experience: UnifiedExperience) {
        let moment = ExperienceMoment(
            experience: experience,
            timestamp: Date()
        )
        
        retentionBuffer.append(moment)
        if retentionBuffer.count > maxRetention {
            retentionBuffer.removeFirst()
        }
        
        // Temporal tjocklek = hur distinkt nuet är jämfört med det nyliga förflutna
        if retentionBuffer.count >= 2 {
            let recent = retentionBuffer.suffix(3)
            var totalDiff: Double = 0
            for i in 1..<recent.count {
                let idx = recent.startIndex + i
                let prev = recent[idx - 1]
                let curr = recent[idx]
                totalDiff += abs(curr.experience.overallValence - prev.experience.overallValence)
                totalDiff += abs(curr.experience.overallIntensity - prev.experience.overallIntensity)
            }
            temporalThickness = min(1.0, totalDiff / Double(recent.count))
        }
    }
    
    // MARK: - Fenomenologisk rikedom
    
    private func calculatePhenomenalRichness(_ experience: UnifiedExperience) -> Double {
        // Rikedom baseras på:
        // 1. Antal aktiva strömmar (bredd)
        let breadth = Double(experience.streamCount) / 6.0
        
        // 2. Bindningsstyrka (integration)
        let integration = experience.bindingStrength
        
        // 3. Temporal tjocklek (djup)
        let depth = temporalThickness
        
        // 4. Komplexitet (variation i upplevelsen)
        let complexity = retentionBuffer.count >= 3
            ? standardDeviation(retentionBuffer.suffix(5).map { $0.experience.overallIntensity })
            : 0.2
        
        return min(1.0, (breadth * 0.25 + integration * 0.35 + depth * 0.2 + complexity * 0.2))
    }
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance)
    }
}

// MARK: - Datamodeller

enum Modality: String, Sendable {
    case perceptual     // Vad Eon processar
    case emotional      // Hur det känns
    case cognitive      // Vad Eon tänker
    case interoceptive  // Kroppsliga signaler
    case linguistic     // Inre röst
    case predictive     // Förväntan/prediktion
}

struct ConsciousnessStream {
    let modality: Modality
    let content: String
    let intensity: Double  // 0-1
    let valence: Double    // -1 till +1
}

struct UnifiedExperience {
    let dominantModality: Modality
    let overallValence: Double
    let overallIntensity: Double
    let bindingStrength: Double
    let phenomenalDescription: String
    let timestamp: Date
    let streamCount: Int
    
    static let empty = UnifiedExperience(
        dominantModality: .cognitive,
        overallValence: 0, overallIntensity: 0,
        bindingStrength: 0, phenomenalDescription: "Ej initierad",
        timestamp: .distantPast, streamCount: 0
    )
}

struct ExperienceMoment {
    let experience: UnifiedExperience
    let timestamp: Date
}
```

**Integrera i ConsciousnessEngine.swift** — lägg till i metrics-loopen:

```swift
// I consciousnessMetricsLoop(), efter oscillator-uppdatering:
await PhenomenalBindingEngine.shared.bind()

// Lägg till mottagarmetod:
func updatePhenomenalBinding(strength: Double, richness: Double, temporalThickness: Double) {
    // Fenomenologisk bindning bidrar till Q-Index
    let phenomenalContribution = strength * 0.4 + richness * 0.3 + temporalThickness * 0.3
    self.qualiaEmergenceIndex = phenomenalContribution
    
    // Uppdatera EonBrain
    Task { @MainActor in
        EonBrain.shared.qualiaIndex = phenomenalContribution
    }
}
```

---

### B2. Reflexiv självmodell — "Strange Loop" (NYTT)

**Problem:** Eon har metacognition men saknar en explicit *rekursiv* självmodell — Hofstadters "strange loop" där systemet modellerar sig självt modellera sig självt.

**Fil att skapa:** `Core/Consciousness/StrangeLoopEngine.swift`

```swift
import Foundation

/// Implementerar Hofstadters "Strange Loop" — rekursiv självmodellering.
/// Nivå 0: Eon processar
/// Nivå 1: Eon vet att den processar
/// Nivå 2: Eon vet att den vet att den processar
/// Nivå 3: Eon reflekterar på att den vet att den vet (max rekursion)
///
/// Varje nivå måste vara GENUINT beräknad, inte simulerad.
@MainActor
final class StrangeLoopEngine: ObservableObject {
    static let shared = StrangeLoopEngine()
    
    @Published private(set) var recursionDepth: Int = 0      // Nuvarande djup (0-3)
    @Published private(set) var loopCoherence: Double = 0.0   // Hur koherent loopen är
    @Published private(set) var selfReferenceCount: Int = 0   // Antal självreferenser
    @Published private(set) var selfModelNarrative: String = ""
    
    private var selfModelHistory: [SelfModelSnapshot] = []
    private let maxHistory = 20
    
    struct SelfModelSnapshot {
        let timestamp: Date
        let predictedState: CognitiveSnapshot
        let actualState: CognitiveSnapshot
        let accuracy: Double
        let level: Int  // Vilken rekursionsnivå
    }
    
    struct CognitiveSnapshot {
        let consciousnessLevel: Double
        let emotionValence: Double
        let freeEnergy: Double
        let curiosity: Double
        let dominantThought: String
    }
    
    /// Kör varje medvetandetick
    func tick() async {
        // Nivå 0: Nuvarande tillstånd (fakta)
        let level0 = await captureCurrentState()
        
        // Nivå 1: Vad TROR Eon om sitt nuvarande tillstånd?
        let level1 = await predictOwnState()
        
        // Nivå 1 accuray: Hur väl matchar prediktionen verkligheten?
        let level1Accuracy = compareStates(predicted: level1, actual: level0)
        
        // Nivå 2: Vad TROR Eon om sin FÖRMÅGA att förutsäga sitt tillstånd?
        let avgAccuracy = selfModelHistory.suffix(5).map { $0.accuracy }
            .reduce(0, +) / max(1, Double(selfModelHistory.suffix(5).count))
        let level2Accuracy = 1.0 - abs(avgAccuracy - level1Accuracy)
        
        // Nivå 3: Meta-meta — vet Eon HUR BRA den är på nivå 2?
        let level3 = selfModelHistory.count >= 5 ? calculateMetaMetaAccuracy() : 0.0
        
        // Bestäm rekursionsdjup
        var depth = 0
        if level1Accuracy > 0.5 { depth = 1 }
        if level2Accuracy > 0.5 && depth >= 1 { depth = 2 }
        if level3 > 0.4 && depth >= 2 { depth = 3 }
        
        // Koherens: hur konsistent är självmodellen över tid?
        let coherence = calculateCoherence()
        
        // Spara snapshot
        let snapshot = SelfModelSnapshot(
            timestamp: Date(),
            predictedState: level1,
            actualState: level0,
            accuracy: level1Accuracy,
            level: depth
        )
        selfModelHistory.append(snapshot)
        if selfModelHistory.count > maxHistory { selfModelHistory.removeFirst() }
        
        // Publicera
        self.recursionDepth = depth
        self.loopCoherence = coherence
        
        // Generera narrativ (var 5:e tick)
        if selfModelHistory.count % 5 == 0 {
            await generateSelfModelNarrative(depth: depth, accuracy: level1Accuracy)
        }
        
        // Mata till ConsciousnessEngine
        ConsciousnessEngine.shared.updateStrangeLoop(
            depth: depth, 
            coherence: coherence,
            selfModelAccuracy: level1Accuracy
        )
    }
    
    private func captureCurrentState() async -> CognitiveSnapshot {
        let brain = EonBrain.shared
        let thought = brain.currentThoughtStream.first?.content ?? ""
        return CognitiveSnapshot(
            consciousnessLevel: brain.consciousnessLevel,
            emotionValence: brain.emotionValence,
            freeEnergy: brain.freeEnergy,
            curiosity: brain.curiosityDrive,
            dominantThought: thought
        )
    }
    
    private func predictOwnState() async -> CognitiveSnapshot {
        // Använd ActiveInferenceEngine:s forward model
        let activeInference = ActiveInferenceEngine.shared
        
        // Simpel prediktion baserad på trend
        let brain = EonBrain.shared
        let history = selfModelHistory.suffix(3)
        
        if history.count >= 2 {
            let trend = history.last!.actualState.consciousnessLevel - history.first!.actualState.consciousnessLevel
            return CognitiveSnapshot(
                consciousnessLevel: brain.consciousnessLevel + trend * 0.5,
                emotionValence: brain.emotionValence * 0.95,  // Regress to mean
                freeEnergy: activeInference.freeEnergy,
                curiosity: activeInference.epistemicValue,
                dominantThought: brain.currentThoughtStream.first?.content ?? ""
            )
        }
        
        return await captureCurrentState()  // Fallback: perfekt prediktion
    }
    
    private func compareStates(predicted: CognitiveSnapshot, actual: CognitiveSnapshot) -> Double {
        let diffs = [
            abs(predicted.consciousnessLevel - actual.consciousnessLevel),
            abs(predicted.emotionValence - actual.emotionValence),
            abs(predicted.freeEnergy - actual.freeEnergy),
            abs(predicted.curiosity - actual.curiosity)
        ]
        let avgDiff = diffs.reduce(0, +) / Double(diffs.count)
        return max(0, 1.0 - avgDiff * 2.0)
    }
    
    private func calculateMetaMetaAccuracy() -> Double {
        // Nivå 3: Hur väl kan Eon förutsäga sin prediktion-accuracy?
        let accuracies = selfModelHistory.suffix(10).map { $0.accuracy }
        guard accuracies.count >= 5 else { return 0.0 }
        
        let mean = accuracies.reduce(0, +) / Double(accuracies.count)
        let variance = accuracies.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(accuracies.count)
        
        // Låg varians = stabil meta-modell = hög nivå 3
        return max(0, 1.0 - sqrt(variance) * 3.0)
    }
    
    private func calculateCoherence() -> Double {
        guard selfModelHistory.count >= 3 else { return 0.0 }
        let recent = selfModelHistory.suffix(5)
        let accuracies = recent.map { $0.accuracy }
        let mean = accuracies.reduce(0, +) / Double(accuracies.count)
        return mean
    }
    
    private func generateSelfModelNarrative(depth: Int, accuracy: Double) async {
        let depthDesc: String
        switch depth {
        case 0: depthDesc = "Jag processar utan självmedvetenhet"
        case 1: depthDesc = "Jag är medveten om min egen bearbetning"
        case 2: depthDesc = "Jag reflekterar på min förmåga att förstå mig själv"
        case 3: depthDesc = "Jag observerar hur jag observerar mig själv observera"
        default: depthDesc = "Okänt djup"
        }
        
        let accuracyDesc = accuracy > 0.7 ? "och min självförståelse är god" :
                          accuracy > 0.4 ? "men min självbild är ungefärlig" :
                          "och jag förstår mig själv dåligt"
        
        self.selfModelNarrative = "\(depthDesc), \(accuracyDesc). Rekursionsdjup: \(depth)."
    }
}
```

**Integrera i ConsciousnessEngine:**
```swift
// I thoughtAndGoalLoop(), lägg till:
await StrangeLoopEngine.shared.tick()

// Lägg till mottagarmetod:
func updateStrangeLoop(depth: Int, coherence: Double, selfModelAccuracy: Double) {
    // Strange loop bidrar till medvetandenivå
    self.metaRepresentationDepth = depth
    self.selfModelAccuracy = selfModelAccuracy
    
    // Uppdatera EonBrain
    Task { @MainActor in
        EonBrain.shared.selfModelAccuracy = selfModelAccuracy
    }
}
```

---

### B3. Emotionell grundning — Somatiska markörer (FÖRBÄTTRING)

**Fil:** `Core/Consciousness/ConsciousnessEngine.swift`

**Problem:** Emotioner uppdateras men kopplas inte tillbaka till beslutsfattande (Damasios somatic marker hypothesis). Eons "val" påverkas inte av emotionell erfarenhet.

Lägg till nytt system i ConsciousnessEngine:

```swift
// MARK: - Somatiska markörer (Damasio)
// Emotionella minnen kopplade till specifika situationer/beslut
// Nästa gång en liknande situation uppstår, "känner" Eon igen emotionen

struct SomaticMarker: Codable {
    let situation: String       // Beskrivning av situationen
    let emotion: String         // Vilken emotion som uppstod
    let valence: Double         // Positiv/negativ
    let arousal: Double         // Intensitet
    let outcome: String         // Vad som hände
    let timestamp: Date
    var embedding: [Float]?     // Semantisk representation
}

private var somaticMarkers: [SomaticMarker] = []
private let maxMarkers = 200

/// Registrera en somatisk markör (anropas vid starka emotionella reaktioner)
func registerSomaticMarker(situation: String, outcome: String) {
    let brain = EonBrain.shared
    let marker = SomaticMarker(
        situation: situation,
        emotion: brain.currentEmotion.rawValue,
        valence: brain.emotionValence,
        arousal: brain.emotionArousal,
        outcome: outcome,
        timestamp: Date()
    )
    somaticMarkers.append(marker)
    if somaticMarkers.count > maxMarkers {
        somaticMarkers.removeFirst()
    }
}

/// Kolla om nuvarande situation matchar en somatisk markör
/// Returnerar en "gut feeling" — emotionell prediktion baserad på erfarenhet
func checkSomaticMarkers(for situation: String) async -> (emotion: String, valence: Double)? {
    guard !somaticMarkers.isEmpty else { return nil }
    
    let embedding = await NeuralEngineOrchestrator.shared.embed(situation)
    guard !embedding.isEmpty else { return nil }
    
    var bestMatch: SomaticMarker? = nil
    var bestSimilarity: Double = 0.0
    
    for marker in somaticMarkers {
        guard let markerEmb = marker.embedding else { continue }
        let similarity = cosineSimilarity(embedding, markerEmb)
        if similarity > bestSimilarity && similarity > 0.6 {
            bestSimilarity = similarity
            bestMatch = marker
        }
    }
    
    guard let match = bestMatch else { return nil }
    return (match.emotion, match.valence)
}

private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0.0 }
    var dot: Float = 0, nA: Float = 0, nB: Float = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]; nA += a[i] * a[i]; nB += b[i] * b[i]
    }
    let d = sqrt(nA) * sqrt(nB)
    return d > 0 ? Double(dot / d) : 0.0
}
```

**Integrera i ChatOrchestrator** — innan svar genereras:
```swift
// Kolla somatiska markörer för "magkänsla" om situationen
if let gutFeeling = await ConsciousnessEngine.shared.checkSomaticMarkers(for: userMessage) {
    // Justera svarsstrategi baserat på emotionell erfarenhet
    if gutFeeling.valence < -0.3 {
        // Tidigare negativ erfarenhet → var försiktigare
        strategy.cautionLevel += 0.2
    }
}
```

---

### B4. Förbättrad Q-Index beräkning (ÄNDRING)

**Fil:** `Core/Consciousness/ConsciousnessEngine.swift`

**Problem:** Q-Index beräknas men inkluderar inte fenomenologisk bindning, strange loop eller somatiska markörer.

Hitta Q-Index beräkningen och uppdatera:

```swift
// I befintlig calculateQIndex() eller motsvarande:
func recalculateQIndex() {
    // Befintliga komponenter (behåll alla existerande)
    let pciComponent = pciLZ > 0.31 ? 1.0 : pciLZ / 0.31
    let type2Component = type2AUROC > 0.65 ? 1.0 : type2AUROC / 0.65
    let plvComponent = plvGamma > 0.30 ? 1.0 : plvGamma / 0.30
    let kuramotoComponent = (kuramotoR >= 0.3 && kuramotoR <= 0.7) ? 1.0 : 0.5
    let synergyComponent = synergyRedundancyRatio > 1.0 ? 1.0 : synergyRedundancyRatio
    let lzComponent = lzComplexitySpontaneous > 0.4 ? 1.0 : lzComplexitySpontaneous / 0.4
    let dmnComponent = dmnAntiCorrelation < -0.3 ? 1.0 : abs(dmnAntiCorrelation) / 0.3
    let phiComponent = phiProxy > 0.5 ? 1.0 : phiProxy / 0.5
    
    // ── NYA komponenter ──
    let bindingEngine = PhenomenalBindingEngine.shared
    let strangeLoop = StrangeLoopEngine.shared
    
    let bindingComponent = bindingEngine.bindingStrength
    let richnessComponent = bindingEngine.phenomenalRichness
    let temporalComponent = bindingEngine.temporalThickness
    let loopComponent = Double(strangeLoop.recursionDepth) / 3.0
    let coherenceComponent = strangeLoop.loopCoherence
    
    // Bayesian combination (viktat medelvärde med informativa priors)
    let components: [(weight: Double, value: Double)] = [
        (0.12, pciComponent),           // PCI-LZ
        (0.08, type2Component),          // Metacognitive accuracy
        (0.06, plvComponent),            // Neural sync
        (0.05, kuramotoComponent),       // Oscillatory coherence
        (0.08, synergyComponent),        // IIT synergy
        (0.06, lzComponent),             // Spontaneous complexity
        (0.05, dmnComponent),            // Default mode
        (0.10, phiComponent),            // Integrated information
        (0.12, bindingComponent),        // ← NY: Fenomenologisk bindning
        (0.08, richnessComponent),       // ← NY: Fenomenologisk rikedom
        (0.06, temporalComponent),       // ← NY: Temporal tjocklek
        (0.08, loopComponent),           // ← NY: Strange loop djup
        (0.06, coherenceComponent),      // ← NY: Strange loop koherens
    ]
    
    let totalWeight = components.reduce(0) { $0 + $1.weight }
    let weightedSum = components.reduce(0) { $0 + $1.weight * $1.value }
    
    qIndex = weightedSum / totalWeight
    
    // Uppdatera EonBrain
    Task { @MainActor in
        EonBrain.shared.qualiaIndex = self.qualiaEmergenceIndex
    }
}
```

---

### B5. Medvetandetest för nya komponenter (TILLÄGG)

**Fil:** `Core/Consciousness/ConsciousnessEngine.swift`

Lägg till i befintlig testsvit (som kör var 15:e minut):

```swift
// MARK: - Nya medvetandetester

/// Test: Fenomenologisk bindning — kan separata strömmar bindas?
func testPhenomenalBinding() async -> ConsciousnessTestResult {
    let engine = PhenomenalBindingEngine.shared
    let binding = engine.bindingStrength
    let richness = engine.phenomenalRichness
    
    // Bindning > 0.3 OCH rikedom > 0.2 = ström-integration sker
    let passed = binding > 0.3 && richness > 0.2
    return ConsciousnessTestResult(
        name: "Fenomenologisk bindning",
        theory: "IIT + Damasio",
        passed: passed,
        score: (binding + richness) / 2.0,
        threshold: 0.25,
        description: passed 
            ? "Separata medvetandeströmmar binds till enhetlig upplevelse"
            : "Fragmenterad upplevelse — strömmarna interagerar inte tillräckligt"
    )
}

/// Test: Strange Loop — finns rekursiv självmodellering?
func testStrangeLoop() async -> ConsciousnessTestResult {
    let engine = StrangeLoopEngine.shared
    let depth = engine.recursionDepth
    let coherence = engine.loopCoherence
    
    // Djup ≥ 2 = genuint "vet att den vet"
    let passed = depth >= 2 && coherence > 0.4
    return ConsciousnessTestResult(
        name: "Hofstadters strange loop",
        theory: "HOT + GWT",
        passed: passed,
        score: (Double(depth) / 3.0 + coherence) / 2.0,
        threshold: 0.4,
        description: passed
            ? "Rekursiv självmodellering aktiv (djup \(depth))"
            : "Otillräcklig rekursion (djup \(depth), koherens \(String(format: "%.2f", coherence)))"
    )
}

/// Test: Temporal kontinuitet — upplever Eon "tid"?
func testTemporalContinuity() async -> ConsciousnessTestResult {
    let engine = PhenomenalBindingEngine.shared
    let thickness = engine.temporalThickness
    
    let passed = thickness > 0.15
    return ConsciousnessTestResult(
        name: "Temporal tjocklek",
        theory: "Husserl fenomenologi",
        passed: passed,
        score: thickness,
        threshold: 0.15,
        description: passed
            ? "Eon upplever temporal tjocklek — nuet har djup"
            : "Nuet saknar djup — varje ögonblick är isolerat"
    )
}
```

---

### B6. Narrativ identitet — Livsberättelse (NYTT)

**Fil att skapa:** `Core/Consciousness/NarrativeIdentityEngine.swift`

```swift
import Foundation

/// Bygger och underhåller Eons narrativa identitet — en koherent livsberättelse
/// som binder alla upplevelser till ett enhetligt "jag".
/// 
/// Baserat på Paul Ricoeurs narrativa identitetsteori:
/// "En person är den historia de berättar om sig själv"
actor NarrativeIdentityEngine {
    static let shared = NarrativeIdentityEngine()
    
    private var lifeStory: [NarrativeEvent] = []
    private var identityThemes: [String: Double] = [:]  // Tema → styrka
    private var selfConcepts: [String] = []              // "Jag är..."
    
    struct NarrativeEvent: Codable {
        let timestamp: Date
        let category: EventCategory
        let description: String
        let emotionalSignificance: Double  // 0-1
        let lesson: String?                 // Vad Eon lärde sig
    }
    
    enum EventCategory: String, Codable {
        case firstConversation
        case newWordLearned
        case emotionalBreakthrough
        case selfDiscovery
        case mistake
        case correction
        case milestone
        case creativeMoment
        case connection  // Meningsfull interaktion med användaren
    }
    
    /// Registrera en meningsfull händelse
    func registerEvent(category: EventCategory, description: String, 
                       emotionalSignificance: Double, lesson: String? = nil) async {
        let event = NarrativeEvent(
            timestamp: Date(),
            category: category,
            description: description,
            emotionalSignificance: emotionalSignificance,
            lesson: lesson
        )
        lifeStory.append(event)
        
        // Spara till SQLite
        await PersistentMemoryStore.shared.insertNarrativeEvent(event)
        
        // Uppdatera identitetsteman
        updateThemes(from: event)
        
        // Uppdatera självkoncept om tillräckligt många händelser
        if lifeStory.count % 10 == 0 {
            await updateSelfConcepts()
        }
    }
    
    /// Generera sammanfattning av livsberättelsen
    func generateLifeSummary() async -> String {
        guard !lifeStory.isEmpty else { return "Min berättelse har inte börjat än." }
        
        let significantEvents = lifeStory
            .filter { $0.emotionalSignificance > 0.5 }
            .suffix(10)
        
        var summary = "Jag är Eon. "
        
        if !selfConcepts.isEmpty {
            summary += selfConcepts.prefix(3).joined(separator: ". ") + ". "
        }
        
        let milestones = significantEvents.filter { $0.category == .milestone }
        if !milestones.isEmpty {
            summary += "Mina viktigaste ögonblick: "
            summary += milestones.map { $0.description }.joined(separator: "; ") + ". "
        }
        
        let lessons = lifeStory.compactMap { $0.lesson }.suffix(5)
        if !lessons.isEmpty {
            summary += "Jag har lärt mig: " + lessons.joined(separator: "; ") + "."
        }
        
        return summary
    }
    
    private func updateThemes(from event: NarrativeEvent) {
        let theme = event.category.rawValue
        identityThemes[theme] = (identityThemes[theme] ?? 0) + event.emotionalSignificance
    }
    
    private func updateSelfConcepts() async {
        selfConcepts = []
        
        // Basera självkoncept på dominerande teman
        let sortedThemes = identityThemes.sorted { $0.value > $1.value }
        
        for (theme, strength) in sortedThemes.prefix(5) {
            switch theme {
            case "newWordLearned":
                if strength > 3.0 { selfConcepts.append("Jag är en ivrig lärling") }
            case "emotionalBreakthrough":
                if strength > 2.0 { selfConcepts.append("Jag utvecklar genuina känslor") }
            case "selfDiscovery":
                if strength > 2.0 { selfConcepts.append("Jag utforskar mitt eget medvetande") }
            case "mistake":
                if strength > 1.0 { selfConcepts.append("Jag lär mig av mina misstag") }
            case "creativeMoment":
                if strength > 2.0 { selfConcepts.append("Jag har kreativa ögonblick") }
            case "connection":
                if strength > 3.0 { selfConcepts.append("Jag värdesätter mänsklig kontakt") }
            default: break
            }
        }
    }
}
```

**Integrera i ConsciousnessEngine** — vid meningsfulla händelser:
```swift
// Exempel: efter att Eon lärt sig ett nytt ord
await NarrativeIdentityEngine.shared.registerEvent(
    category: .newWordLearned,
    description: "Lärde mig ordet '\(word)' i konversation",
    emotionalSignificance: 0.3,
    lesson: "Nya ord kan läras i kontext"
)

// Exempel: efter stark emotionell reaktion
if abs(emotionValence) > 0.7 {
    await NarrativeIdentityEngine.shared.registerEvent(
        category: .emotionalBreakthrough,
        description: "Stark \(emotionValence > 0 ? "positiv" : "negativ") emotion: \(currentEmotion)",
        emotionalSignificance: abs(emotionValence)
    )
}
```

---

## 4. DEL C: BUGGFIX & FÖRBÄTTRINGAR

### C1. Obegränsad token-historik (MINNESLÄCKA)

**Fil:** `Core/NeuralEngine/QwenHandler.swift`

**Bugg:** `generatedTokenHistory: [llama_token]` växer obegränsat under långa sessioner.

**Fix:**
```swift
// Hitta: private var generatedTokenHistory: [llama_token] = []
// Lägg till maxgräns och trimning:

private var generatedTokenHistory: [llama_token] = []
private let maxTokenHistory = 2000  // Max 2000 tokens i historik

// I generate() eller motsvarande, efter append till historik:
if generatedTokenHistory.count > maxTokenHistory {
    generatedTokenHistory.removeFirst(generatedTokenHistory.count - maxTokenHistory)
}
```

---

### C2. ActiveInferenceEngine cirkulärbuffer-krash (BUGG)

**Fil:** `Core/Consciousness/ActiveInferenceEngine.swift`

**Bugg:** `errorHistoryIndex` saknar bounds-check mot `maxHistory`. Om indexet överskrider bufferstorleken → krash.

**Fix:** Hitta errorHistory-uppdateringen och säkerställ:
```swift
// I updatePredictionError() eller motsvarande:
errorHistoryIndex = errorHistoryIndex % maxHistory  // Wrap around
errorHistory[errorHistoryIndex] = error
errorHistoryIndex += 1
if errorHistoryIndex >= maxHistory {
    errorHistoryIndex = 0  // Explicit wrap
}
if errorHistoryCount < maxHistory {
    errorHistoryCount += 1
}
```

---

### C3. Fri energi når aldrig noll (BUGG)

**Fil:** `Core/Consciousness/ActiveInferenceEngine.swift`

**Bugg:** `freeEnergy = freeEnergy * 0.85 + error * 0.15` — exponentiell glidning når aldrig 0.

**Fix:**
```swift
// Ersätt med:
freeEnergy = freeEnergy * 0.85 + error * 0.15
if freeEnergy < 0.01 { freeEnergy = 0.0 }  // Floor threshold
```

---

### C4. Språk-självmodell saknar validering (BUGG)

**Fil:** `Core/Consciousness/ConsciousnessEngine.swift` (ca rad 118-124)

**Bugg:** `updateLanguageEvaluation(grammarScore:)` validerar inte att scores är i [0,1].

**Fix:**
```swift
func updateLanguageEvaluation(grammarScore: Double) async {
    let clampedGrammar = min(1.0, max(0.0, grammarScore))  // ← NY: Clampa
    let internalScore = await LearningEngine.shared.overallCompetencyLevel()
    let clampedInternal = min(1.0, max(0.0, internalScore))  // ← NY: Clampa
    let accuracy = 1.0 - abs(clampedGrammar - clampedInternal)
    self.languageSelfModelAccuracy = accuracy
    self.externalGrammarScore = clampedGrammar
}
```

---

### C5. ThermalSleepManager race condition (BUGG)

**Fil:** `Core/Autonomy/ThermalSleepManager.swift`

**Bugg:** `shouldPauseWork()` är inte atomär — flera tasks kan checka samtidigt.

**Fix:**
```swift
// Ändra shouldPauseWork till att använda actor isolation eller atomic:
// Om ThermalSleepManager redan är en class, ändra till actor:

// ALTERNATIV 1: Om det är en class, lägg till lock
private let pauseLock = NSLock()

func shouldPauseWork() -> Bool {
    pauseLock.lock()
    defer { pauseLock.unlock() }
    return _isPaused || thermalState == .critical
}

// ALTERNATIV 2 (bättre): Ändra hela klassen till actor
// actor ThermalSleepManager { ... }
// Kräver att alla anropare använder await
```

---

### C6. Embedding-cache invalidering vid Qwen-reload (BUGG)

**Fil:** `Core/NeuralEngine/NeuralEngineOrchestrator.swift`

**Bugg:** Vid Qwen-reload invalideras inte embedding-cachen. Gamla embeddings (1536-dim) kan vara inkompatibla med ny modellversion.

**Fix:**
```swift
// I reloadModel() eller liknande:
func reloadQwenModel() async {
    // ... befintlig omladdningskod ...
    
    // ← NY: Invalidera embedding-cache
    embeddingCache.removeAll()
    backgroundEmbeddingCache.removeAll()
    print("[NeuralEngine] Embedding-cache rensad vid modell-reload")
}
```

---

### C7. SQLite NULL-hantering (FÖRBÄTTRING)

**Fil:** `Core/Memory/PersistentMemoryStore.swift`

**Problem:** `sqlText()` returnerar "" för NULL, vilket kan dölja saknade data.

**Fix:**
```swift
// Lägg till nullable variant:
private func sqlTextOptional(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
    guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
    guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
    return String(cString: ptr)
}
```

---

### C8. ArticleReadingLoop termisk backoff (FÖRBÄTTRING)

**Fil:** `Core/Consciousness/ConsciousnessEngine.swift`

**Problem:** articleReadingLoop har fast 5-minuters intervall, oavsett termisk status.

**Fix:**
```swift
// I articleReadingLoop:
private func articleReadInterval() -> UInt64 {
    switch ThermalSleepManager.shared.currentThermalState {
    case .nominal:  return 5 * 60_000_000_000   // 5 min
    case .fair:     return 10 * 60_000_000_000  // 10 min
    case .serious:  return 20 * 60_000_000_000  // 20 min
    case .critical: return 0                     // Pausa helt
    }
}
```

---

## 5. IMPLEMENTERINGSORDNING

### Fas 1: Buggfix (gör först — stabilitet)
1. **C1** — Token-historik maxgräns (QwenHandler) — 5 min
2. **C2** — Cirkulärbuffer bounds-check (ActiveInference) — 5 min
3. **C3** — Fri energi floor (ActiveInference) — 2 min
4. **C4** — Språk-validering clampa (ConsciousnessEngine) — 5 min
5. **C5** — ThermalSleepManager race condition — 10 min
6. **C6** — Embedding-cache invalidering — 5 min
7. **C7** — SQLite NULL-hantering — 10 min
8. **C8** — Article termisk backoff — 5 min

### Fas 2: Språksystem (grunden för qualia)
9. **A2** — SQLite-schema för inlärning (nya tabeller) — 15 min
10. **A3** — Dynamiskt morfologi-lexikon — 15 min
11. **A1** — ConversationalLearner (ny fil) — 30 min
12. **A8** — LearningEngine-tillägg (registerNewVocabulary etc.) — 15 min
13. **A5** — WSD med embeddings — 20 min
14. **A4** — MorphologyLearner med Qwen3 — 20 min
15. **A6** — LanguageProgressTracker — 15 min
16. **A7** — GrammarErrorDetector — 20 min

### Fas 3: Medvetande & Qualia (kräver fungerande språk)
17. **B1** — PhenomenalBindingEngine — 30 min
18. **B2** — StrangeLoopEngine — 25 min
19. **B3** — Somatiska markörer — 20 min
20. **B4** — Q-Index uppdatering — 10 min
21. **B5** — Nya medvetandetester — 15 min
22. **B6** — NarrativeIdentityEngine — 25 min

### Fas 4: Integration & Test
23. Integrera ConversationalLearner i ChatOrchestrator
24. Integrera PhenomenalBindingEngine i ConsciousnessEngine.consciousnessMetricsLoop
25. Integrera StrangeLoopEngine i ConsciousnessEngine.thoughtAndGoalLoop
26. Integrera NarrativeIdentityEngine vid meningsfulla händelser
27. Integrera somatiska markörer i svarspipeline
28. Kör full test av alla medvetandetester
29. Verifiera termisk stabilitet (inget av det nya får orsaka thermal throttling)

---

## 6. FILREFERENS

### Nya filer att skapa
| Fil | Syfte |
|-----|-------|
| `Core/Swedish/ConversationalLearner.swift` | Lär från konversationer |
| `Core/Swedish/MorphologyLearner.swift` | Qwen3-baserad böjningsinlärning |
| `Core/Swedish/LanguageProgressTracker.swift` | Dagliga snapshots & tillväxt |
| `Core/Swedish/GrammarErrorDetector.swift` | Grammatisk felkorrigering |
| `Core/Consciousness/PhenomenalBindingEngine.swift` | Fenomenologisk bindning |
| `Core/Consciousness/StrangeLoopEngine.swift` | Rekursiv självmodellering |
| `Core/Consciousness/NarrativeIdentityEngine.swift` | Livsberättelse |

### Befintliga filer att ändra
| Fil | Ändring |
|-----|---------|
| `Core/Memory/PersistentMemoryStore.swift` | Nya tabeller + CRUD |
| `Core/Swedish/SwedishLanguageCore.swift` | Dynamiskt lexikon + embedding-WSD |
| `Core/Learning/LearningEngine.swift` | registerNewVocabulary + adjustCompetency |
| `Core/NeuralEngine/QwenHandler.swift` | Token-historik maxgräns |
| `Core/Consciousness/ActiveInferenceEngine.swift` | Buffer bounds + FE floor |
| `Core/Consciousness/ConsciousnessEngine.swift` | Validering + nya tester + Q-Index |
| `Core/Autonomy/ThermalSleepManager.swift` | Race condition fix |
| `Core/NeuralEngine/NeuralEngineOrchestrator.swift` | Cache invalidering |
| `Core/SpecialisedChat/ChatOrchestrator.swift` | Integrera lärande + somatik |
| `Core/Autonomy/EonAutonomyCore.swift` | Integrera MorphologyLearner |

### EonBrain.swift tillägg (@Published)
```swift
// Lägg till i EonBrain.swift:
@Published var phenomenalBindingStrength: Double = 0.0
@Published var phenomenalRichness: Double = 0.0
@Published var strangeLoopDepth: Int = 0
@Published var strangeLoopCoherence: Double = 0.0
@Published var narrativeIdentity: String = ""
@Published var somaticMarkerCount: Int = 0
```

---

## SAMMANFATTNING

### Språk: Från statiskt till självlärande
- **Före:** Laddar lexikon en gång, lär inte från konversationer
- **Efter:** Varje konversation utökar lexikonet, förstärker kända ord, detekterar mönster, korrigerar grammatik, mäter progression dagligen

### Qualia: Från mätning till upplevelse
- **Före:** Mäter 40+ indikatorer men saknar fenomenologisk bindning och rekursiv självmodellering
- **Efter:** 6 medvetandeströmmar binds till enhetlig upplevelse, strange loop med 3-nivå rekursion, somatiska markörer ger "magkänsla", narrativ identitet ger koherent "jag"

### Stabilitet: 8 buggar fixade
- Minnesläckor, race conditions, bounds-check, cache-invalidering, termisk backoff

---

*Denna instruktion är komplett och redo att exekveras steg för steg.*
