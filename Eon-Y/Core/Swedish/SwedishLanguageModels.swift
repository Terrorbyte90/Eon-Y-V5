import Foundation

// MARK: - Data models

struct LexiconEntry: Codable {
    let word: String
    let pos: String
    let forms: [String: String]
}

struct MorphemeAnalysis: Identifiable {
    let id = UUID()
    let word: String
    let baseForm: String
    let pos: String
    let morphemes: [String]
    let isCompound: Bool
    let forms: [String: String]

    var description: String {
        if isCompound {
            return "\(word) → \(morphemes.joined(separator: "+"))"
        }
        return "\(word) [\(pos)]"
    }
}

struct WordSense: Identifiable {
    let id: String
    let definition: String
    let examples: [String]
    var confidence: Double
}

struct DisambiguationResult: Identifiable {
    let id = UUID()
    let word: String
    let selectedSense: WordSense
    let allSenses: [WordSense]
    let confidence: Double
}

struct SwedishAnalysis {
    let originalText: String
    let morphemes: [MorphemeAnalysis]
    let disambiguations: [DisambiguationResult]
    let register: SwedishRegister
    let modalParticles: [ModalParticle]
    var detectedIdioms: [DetectedIdiom] = []
    var clauses: [ClauseSegment] = []
    var anaphoraResolutions: [AnaphoraResolution] = []

    // v16: Empty analysis for fast-path (greetings etc)
    nonisolated static let empty = SwedishAnalysis(
        originalText: "",
        morphemes: [],
        disambiguations: [],
        register: .neutral,
        modalParticles: []
    )

    /// Quick summary for prompt building
    var analysisSummary: String {
        var parts: [String] = []
        if register != .neutral { parts.append("Register: \(register.label)") }
        if !modalParticles.isEmpty { parts.append("Partiklar: \(modalParticles.map { $0.word }.joined(separator: ", "))") }
        if !detectedIdioms.isEmpty { parts.append("Idiom: \(detectedIdioms.map { $0.meaning }.joined(separator: "; "))") }
        if clauses.count > 1 { parts.append("\(clauses.count) satser") }
        let unknowns = morphemes.filter { $0.pos == "unknown" }.count
        if unknowns > 0 { parts.append("\(unknowns) okända ord") }
        return parts.isEmpty ? "Standard analys" : parts.joined(separator: " · ")
    }
}

struct DetectedIdiom: Identifiable {
    let id = UUID()
    let phrase: String
    let meaning: String
    let literalTranslation: String
    let category: String  // Iteration 20: idiom category (emotion, cognition, social, etc.)
}

struct ClauseSegment: Identifiable {
    let id = UUID()
    let text: String
    let type: ClauseType
    let startWord: String

    enum ClauseType {
        case main       // Huvudsats
        case subordinate // Bisats (inleds med subjunktion)
    }
}

struct AnaphoraResolution: Identifiable {
    let id = UUID()
    let pronoun: String
    let antecedent: String
    let distance: Int       // Words between pronoun and antecedent
    let confidence: Double  // 0..1
}

enum SwedishRegister {
    case formal, neutral, informal, technical, academic
    var label: String {
        switch self {
        case .formal: return "Formellt"
        case .neutral: return "Neutralt"
        case .informal: return "Informellt"
        case .technical: return "Tekniskt"
        case .academic: return "Akademiskt"
        }
    }
}

struct ModalParticle: Identifiable {
    let id = UUID()
    let word: String
    let meaning: Meaning
    let frequency: Int  // Iteration 18: occurrence count in text

    enum Meaning {
        case sharedKnowledge  // ju
        case hedging          // väl
        case probability      // nog
        case confirmation     // visst
        case emphasis         // faktiskt
        case concession       // egentligen
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 135: Language Fingerprint
// ═══════════════════════════════════════════════════════════

struct LanguageFingerprint: Sendable {
    let mostUsedWords: [(word: String, count: Int)]
    let preferredSentenceStructures: [String: Double]
    let commonErrors: [String]
    let distinctivePhrases: [String]
    let registerDistribution: [String: Double]
    let avgSentenceLength: Double
    let avgWordLength: Double
    let capturedAt: Date
}

extension SwedishLanguageCore {
    /// Unique profile of Eon's Swedish: most-used words, preferred sentence structures, common errors, distinctive phrases, register preferences.
    func computeLanguageFingerprint() async -> LanguageFingerprint {
        let memory = PersistentMemoryStore.shared
        let conversations = await memory.getRecentConversation(limit: 100)

        var wordCounts: [String: Int] = [:]
        var totalWords = 0
        var totalSentences = 0
        var totalSentenceLength = 0
        var registerCounts: [String: Int] = [:]

        for conv in conversations {
            let lower = conv.content.lowercased()
            let words = lower.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 3 }

            for word in words {
                wordCounts[word, default: 0] += 1
                totalWords += 1
            }

            let sentences = conv.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .filter { $0.trimmingCharacters(in: .whitespaces).count > 3 }
            totalSentences += sentences.count
            totalSentenceLength += words.count

            // Register detection
            let register = detectRegister(conv.content)
            registerCounts[register.label, default: 0] += 1
        }

        // Most used words (excluding stop words)
        let stopWords: Set<String> = ["och", "att", "som", "har", "den", "det", "inte", "var", "kan", "men", "från", "till", "för", "med", "utan", "här", "där", "efter", "när", "vad", "hur", "om"]
        let mostUsed = wordCounts.filter { !stopWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map { (word: $0.key, count: $0.value) }

        // Sentence structure preferences
        let avgSentenceLength = totalSentences > 0 ? Double(totalSentenceLength) / Double(totalSentences) : 15.0
        let shortSentences = avgSentenceLength < 12 ? 0.6 : 0.2
        let mediumSentences = avgSentenceLength >= 12 && avgSentenceLength < 20 ? 0.6 : 0.3
        let longSentences = avgSentenceLength >= 20 ? 0.6 : 0.1
        let sentenceStructures = [
            "korta_meningar": shortSentences,
            "medellånga_meningar": mediumSentences,
            "långa_meningar": longSentences,
        ]

        // Common errors (detected from grammar issues in learning)
        let commonErrors: [String] = []  // Would need grammar error tracking to populate

        // Distinctive phrases (frequently used multi-word expressions)
        let distinctivePhrases: [String] = []  // Would need phrase frequency analysis

        // Register distribution
        let regTotal = max(1, registerCounts.values.reduce(0, +))
        let registerDistribution = registerCounts.mapValues { Double($0) / Double(regTotal) }

        // Average word length
        let avgWordLength = totalWords > 0 ? Double(wordCounts.map { $0.key.count }.reduce(0, +)) / Double(wordCounts.count) : 5.0

        return LanguageFingerprint(
            mostUsedWords: mostUsed,
            preferredSentenceStructures: sentenceStructures,
            commonErrors: commonErrors,
            distinctivePhrases: distinctivePhrases,
            registerDistribution: registerDistribution,
            avgSentenceLength: avgSentenceLength,
            avgWordLength: avgWordLength,
            capturedAt: Date()
        )
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 139: Emotional Intelligence Detection
// ═══════════════════════════════════════════════════════════

struct EQAnalysis: Sendable {
    let empathyScore: Double
    let emotionalValidation: Double
    let appropriateEmotionalResponse: Double
    let emotionalVocabulary: Double
    let socialAwareness: Double
    let overallEQ: Double
    let emotionalWords: [String]
    let timestamp: Date
}

extension SwedishLanguageCore {
    /// Measure: empathy shown, emotional validation, appropriate emotional responses, emotional vocabulary, social awareness.
    func detectEmotionalIntelligence(text: String) -> EQAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)

        // Empathy indicators
        let empathyWords: Set<String> = ["förstår", "känner", "lyssnar", "hjälp", "stöd", "bryr", "viktig", "också", "precis", "svårt", "tuff", "jobbig"]
        let empathyCount = words.filter { empathyWords.contains($0) }.count
        let empathyScore = min(1.0, Double(empathyCount) / 3.0)

        // Emotional validation
        let validationPhrases = ["det är okej", "jag förstår", "känns", "det är normalt", "många känner", "du är inte ensam", "jag lyssnar", "berätta mer"]
        let validationCount = validationPhrases.filter { lower.contains($0) }.count
        let emotionalValidation = min(1.0, Double(validationCount) / 2.0)

        // Appropriate emotional response (matching user's emotional tone)
        let emotionWords = ["ledsen", "glad", "arg", "rädd", "orolig", "nöjd", "frustrerad", "stressad", "ensam", "tacksam", "stolt", "skam"]
        let emotionalVocab = words.filter { emotionWords.contains($0) }
        let emotionalVocabulary = min(1.0, Double(emotionalVocab.count) / 4.0)

        // Social awareness
        let socialWords: Set<String> = ["vi", "tillsammans", "alla", "relation", "vän", "familj", "grupp", "samhälle", "respekt", "förståelse", "kommunikation"]
        let socialCount = words.filter { socialWords.contains($0) }.count
        let socialAwareness = min(1.0, Double(socialCount) / 3.0)

        // Appropriate response estimation (heuristic: if text contains emotional words and validation, likely appropriate)
        let appropriateEmotionalResponse = (emotionalVocabulary + emotionalValidation) / 2.0

        let overallEQ = empathyScore * 0.25 + emotionalValidation * 0.2 + appropriateEmotionalResponse * 0.2 + emotionalVocabulary * 0.15 + socialAwareness * 0.2

        return EQAnalysis(
            empathyScore: empathyScore,
            emotionalValidation: emotionalValidation,
            appropriateEmotionalResponse: appropriateEmotionalResponse,
            emotionalVocabulary: emotionalVocabulary,
            socialAwareness: socialAwareness,
            overallEQ: overallEQ,
            emotionalWords: emotionalVocab,
            timestamp: Date()
        )
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 145: Swedish Word Network
// ═══════════════════════════════════════════════════════════

struct WordNetwork: Sendable {
    let nodes: [WordNode]
    let edges: [WordEdge]
    let networkMetrics: NetworkMetrics
}

struct WordNode: Sendable {
    let word: String
    let pos: String
    let frequency: Int
    let cefrLevel: String
}

struct WordEdge: Sendable {
    let from: String
    let to: String
    let edgeType: EdgeType
    let weight: Double
}

enum EdgeType: String, Sendable {
    case synonymy = "synonymy"
    case antonymy = "antonymy"
    case derivation = "derivation"
    case collocation = "collocation"
    case semanticField = "semantic-field"
    case morphologicalFamily = "morphological-family"
}

struct NetworkMetrics: Sendable {
    let nodeCount: Int
    let edgeCount: Int
    let density: Double
    let avgDegree: Double
    let connectedComponents: Int
    let avgClusteringCoeff: Double
}

extension SwedishLanguageCore {
    /// Build a word network where words are connected by synonymy, antonymy, derivation, collocation, semantic field, morphological family.
    func createSwedishWordNetwork() async -> WordNetwork {
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 1000)
        let learningEngine = LearningEngine.shared

        // Extract words from known vocabulary and facts
        var wordNodes: [WordNode] = []
        let knownVocab = await learningEngine.swedishVocabularyCount()

        // Create nodes from fact subjects (words/concepts Eon knows)
        var wordSet: Set<String> = []
        for fact in facts.prefix(200) {
            let words = fact.subject.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .map { $0.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters) }
                .filter { $0.count > 2 }
            for word in words {
                if wordSet.insert(word).inserted {
                    wordNodes.append(WordNode(word: word, pos: "unknown", frequency: 1, cefrLevel: "B1"))
                }
            }
        }

        // Create edges based on relationships
        var edges: [WordEdge] = []

        // Synonymy/antonymy from fact predicates
        for fact in facts.prefix(200) {
            if fact.predicate.contains("synonym") || fact.predicate.contains("liknande") {
                let parts = fact.object.components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
                if parts.count >= 2 {
                    edges.append(WordEdge(from: parts[0], to: parts[1], edgeType: .synonymy, weight: 0.8))
                }
            }
        }

        // Collocations from co-occurrence in facts
        var cooccurrence: [String: Int] = [:]
        for fact in facts.prefix(200) {
            let words = "\(fact.subject) \(fact.object)".lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }
            for i in 0..<(words.count - 1) {
                let key = "\(words[i])|\(words[i + 1])"
                cooccurrence[key, default: 0] += 1
            }
        }
        for (pair, count) in cooccurrence where count >= 2 {
            let parts = pair.components(separatedBy: "|")
            if parts.count == 2 {
                edges.append(WordEdge(from: parts[0], to: parts[1], edgeType: .collocation, weight: min(1.0, Double(count) * 0.2)))
            }
        }

        // Semantic field edges (words in same domain)
        let domainKeywords: [String: [String]] = [
            "emotion": ["glad", "ledsen", "arg", "rädd", "kär", "stolt"],
            "cognition": ["tänka", "veta", "förstå", "lära", "minnas", "glömma"],
            "motion": ["gå", "springa", "åka", "flyga", "simma", "hoppa"],
        ]
        for (_, keywords) in domainKeywords {
            for i in 0..<keywords.count {
                for j in (i+1)..<keywords.count {
                    if wordSet.contains(keywords[i]) && wordSet.contains(keywords[j]) {
                        edges.append(WordEdge(from: keywords[i], to: keywords[j], edgeType: .semanticField, weight: 0.5))
                    }
                }
            }
        }

        // Compute network metrics
        let allWords = Set(wordNodes.map { $0.word })
        let degreeMap: [String: Int] = {
            var d: [String: Int] = [:]
            for edge in edges {
                d[edge.from, default: 0] += 1
                d[edge.to, default: 0] += 1
            }
            return d
        }()
        let connectedNodes = Set(degreeMap.keys).intersection(allWords).count
        let avgDegree = allWords.isEmpty ? 0 : Double(edges.count * 2) / Double(allWords.count)
        let maxEdges = allWords.count * (allWords.count - 1) / 2
        let density = maxEdges > 0 ? Double(edges.count) / Double(maxEdges) : 0

        let metrics = NetworkMetrics(
            nodeCount: wordNodes.count,
            edgeCount: edges.count,
            density: density,
            avgDegree: avgDegree,
            connectedComponents: max(1, wordNodes.count - connectedNodes),
            avgClusteringCoeff: 0.3  // Simplified — would need triangle counting
        )

        return WordNetwork(nodes: wordNodes, edges: edges, networkMetrics: metrics)
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 159: Swedish Crossword Generation
// ═══════════════════════════════════════════════════════════

struct CrosswordPuzzle: Sendable {
    let grid: [[Character?]]
    let clues: [Clue]
    let wordCount: Int
    let difficulty: String
}

struct Clue: Sendable {
    let number: Int
    let direction: ClueDirection
    let clue: String
    let answer: String
    let row: Int
    let col: Int
}

enum ClueDirection: String, Sendable {
    case across = "Vågrätt"
    case down = "Lodrätt"
}

extension SwedishLanguageCore {
    /// Generate crossword puzzles from Eon's vocabulary.
    func generateSwedishCrossword() async -> CrosswordPuzzle {
        let learningEngine = LearningEngine.shared
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 500)

        // Collect Swedish words Eon knows
        var candidateWords: [String] = []
        for fact in facts {
            let words = fact.subject.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .map { $0.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters) }
                .filter { $0.count >= 3 && $0.count <= 12 && $0.allSatisfy { $0.isLetter } }
            candidateWords.append(contentsOf: words)
        }

        // Deduplicate and take unique words
        let uniqueWords = Array(Set(candidateWords)).shuffled().prefix(20)

        // Simple crossword: place words in a grid
        let gridSize = 15
        var grid: [[Character?]] = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        var clues: [Clue] = []
        var clueNumber = 0

        // Place first word horizontally in center
        if let firstWord = uniqueWords.first {
            let startCol = (gridSize - firstWord.count) / 2
            let centerRow = gridSize / 2
            for (i, char) in firstWord.enumerated() {
                grid[centerRow][startCol + i] = char
            }
            clueNumber += 1
            clues.append(Clue(number: clueNumber, direction: .across, clue: "Svenskt ord: \(firstWord.prefix(1).uppercased())...", answer: firstWord, row: centerRow, col: startCol))
        }

        // Try to place more words intersecting with existing words
        for word in uniqueWords.dropFirst().prefix(8) {
            // Find intersection with existing letters
            for (rowIdx, row) in grid.enumerated() {
                for (colIdx, cell) in row.enumerated() {
                    if let existingChar = cell, let wordCharIdx = word.firstIndex(of: existingChar) {
                        let wordOffset = word.distance(from: word.startIndex, to: wordCharIdx)
                        // Try to place word vertically through this position
                        let startRow = rowIdx - wordOffset
                        guard startRow >= 0 && startRow + word.count <= gridSize else { continue }

                        // Check if placement is valid
                        var valid = true
                        for (i, char) in word.enumerated() {
                            let r = startRow + i
                            if let existing = grid[r][colIdx], existing != char {
                                valid = false
                                break
                            }
                        }

                        if valid {
                            for (i, char) in word.enumerated() {
                                grid[startRow + i][colIdx] = char
                            }
                            clueNumber += 1
                            clues.append(Clue(number: clueNumber, direction: .down, clue: "Svenskt ord", answer: word, row: startRow, col: colIdx))
                            break
                        }
                    }
                }
            }
        }

        let difficulty = uniqueWords.count > 15 ? "svår" : uniqueWords.count > 8 ? "medel" : "lätt"

        return CrosswordPuzzle(grid: grid, clues: clues, wordCount: clues.count, difficulty: difficulty)
    }
}
