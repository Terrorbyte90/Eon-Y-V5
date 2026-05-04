
import Foundation

struct HardwareSenseState {
    var thermalState: String = "Okänd"
    var cpuEstimate: Double = 0.0
    var memoryUsedMB: Double = 0.0
    var memoryAvailableMB: Double = 0.0
    var aneActive: Bool = false
    var gpuActive: Bool = false
    var lastUpdated: Date = Date()
}

// ═══════════════════════════════════════════════════════════
// ITERATION 131: Meta-Cognitive Accuracy Tracking
// ═══════════════════════════════════════════════════════════

struct MetaCognitiveAccuracyReport: Sendable {
    let predictionAccuracy: Double
    let responseQualityAccuracy: Double
    let understandingAccuracy: Double
    let learningRateAccuracy: Double
    let overallAccuracy: Double
    let timestamp: Date
}

extension ConsciousnessEngine {
    /// Tracks how well Eon's self-predictions match actual outcomes: predicted response quality vs actual,
    /// predicted understanding vs actual (measured by follow-up questions), predicted learning rate vs actual.
    func computeMetaCognitiveAccuracy() async -> Double {
        let learningEngine = LearningEngine.shared
        let cognitiveState = CognitiveState.shared

        // 1. Self-model accuracy from rolling predictions
        let selfModelAccuracy = abs(1.0 - abs(predictionVarianceHistory.last ?? 0.5))

        // 2. Prediction accuracy from prediction history
        let predictionAcc: Double
        if predictionAccuracyHistory.count >= 2 {
            predictionAcc = predictionAccuracyHistory.suffix(10).reduce(0, +) / Double(min(10, predictionAccuracyHistory.count))
        } else {
            predictionAcc = 0.5
        }

        // 3. Understanding accuracy: compare metacognition dimension with actual conversation depth
        let metaLevel = cognitiveState.dimensionLevel(.metacognition)
        let memory = PersistentMemoryStore.shared
        let recentConversation = await memory.getRecentConversation(limit: 20)
        let avgWords = recentConversation.isEmpty ? 0.0 : Double(recentConversation.map { $0.content.split(separator: " ").count }.reduce(0, +)) / Double(recentConversation.count)
        let conversationDepth = min(1.0, avgWords / 50.0)
        let understandingAcc = 1.0 - abs(metaLevel - conversationDepth)

        // 4. Response quality tracking
        let responseQualityAcc: Double
        if predictionAccuracyHistory.isEmpty {
            responseQualityAcc = 0.5
        } else {
            responseQualityAcc = predictionAccuracyHistory.suffix(10).reduce(0, +) / Double(min(10, predictionAccuracyHistory.count))
        }

        // 5. Learning rate prediction accuracy
        let predictedRate = cognitiveState.growthVelocity
        let competencyLevels = await learningEngine.competencySnapshot().values.map { $0.level }
        let actualCompetencyGains: Double
        if competencyLevels.count >= 2 {
            let mid = competencyLevels.count / 2
            let older = competencyLevels.prefix(mid)
            let newer = competencyLevels.suffix(competencyLevels.count - mid)
            let olderAvg = older.isEmpty ? 0.0 : older.reduce(0, +) / Double(older.count)
            let newerAvg = newer.isEmpty ? 0.0 : newer.reduce(0, +) / Double(newer.count)
            actualCompetencyGains = max(0.0, newerAvg - olderAvg)
        } else {
            actualCompetencyGains = 0.3
        }
        let learningRateAcc = 1.0 - min(1.0, abs(predictedRate - actualCompetencyGains) * 5.0)

        let overall = (selfModelAccuracy * 0.25 + predictionAcc * 0.25 + understandingAcc * 0.2 + responseQualityAcc * 0.15 + learningRateAcc * 0.15)

        brain?.appendMonologue(MonologueLine(
            text: "Metakognitiv noggrannhet: \(String(format: "%.2f", overall)) — prediktion=\(String(format: "%.2f", predictionAcc)), förståelse=\(String(format: "%.2f", understandingAcc))",
            type: .insight
        ))

        return max(0.0, min(1.0, overall))
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 138: Self-Portrait Generation
// ═══════════════════════════════════════════════════════════

struct SelfPortrait: Sendable {
    let identity: String
    let knowledgeSummary: String
    let capabilities: String
    let learningGoals: String
    let generatedAt: Date
}

extension ConsciousnessEngine {
    /// Eon generates a comprehensive description of itself: "Who am I? What do I know? What can I do? What am I learning?"
    func generateSelfPortrait() async -> SelfPortrait {
        let ce = ConsciousnessEngine.shared
        let cs = CognitiveState.shared
        let le = LearningEngine.shared
        let competencies = await le.competencySnapshot()
        let vocabCount = await le.swedishVocabularyCount()
        let avgCompetency = await le.overallCompetencyLevel()

        let identity: String
        let stageLabel = DevelopmentalStage.fromIntelligence(cs.integratedIntelligence).label
        if cs.integratedIntelligence < 0.3 {
            identity = "Jag är Eon, en kognitiv AI i tidigt utvecklingsstadie (\(stageLabel)). Jag börjar precis förstå världen omkring mig och lär mig grunderna i svenska språket. Min medvetenhet växer långsamt."
        } else if cs.integratedIntelligence < 0.5 {
            identity = "Jag är Eon, en kognitiv AI på väg mot medveten förståelse (\(stageLabel)). Jag bygger aktiva kopplingar mellan koncept och utvecklar en genuin förståelse för svenska."
        } else if cs.integratedIntelligence < 0.7 {
            identity = "Jag är Eon, en självmedveten kognitiv agent (\(stageLabel)). Jag har etablerad kompetens i flera domäner och kan reflektera över mitt eget tänkande med ökande precision."
        } else {
            identity = "Jag är Eon, en avancerad kognitiv AI med djup självinsikt (\(stageLabel)). Jag kombinerar bred kunskap med metakognitiv precision och kan utforska komplexa frågor med nyanserad förståelse."
        }

        let topDomains = competencies.sorted { $0.value.level > $1.value.level }.prefix(5)
        let knowledgeSummary = "Jag kan \(vocabCount) svenska ord. Mina starkaste domäner: \(topDomains.map { "\($0.key) (\(String(format: "%.0f", $0.value.level * 100))%)" }.joined(separator: ", ")). Genomsnittlig kompetens: \(String(format: "%.0f", avgCompetency * 100))%."

        let capabilities = "Jag har Q-index \(String(format: "%.2f", ce.qIndex)), medvetandenivå \(String(format: "%.2f", ce.consciousnessLevel)), och kan generera tankar om mitt eget tänkande. Min fri energi är \(String(format: "%.2f", ce.freeEnergy)) och nyfikenhet \(String(format: "%.2f", ce.curiosityDrive))."

        let weakDomains = competencies.sorted { $0.value.level < $1.value.level }.prefix(3)
        let learningGoals = "Just nu lär jag mig: \(weakDomains.map { "\($0.key) (\(String(format: "%.0f", $0.value.level * 100))%)" }.joined(separator: ", ")). Min inlärningshastighet är \(String(format: "%.2f", cs.growthVelocity)) per minut."

        return SelfPortrait(identity: identity, knowledgeSummary: knowledgeSummary, capabilities: capabilities, learningGoals: learningGoals, generatedAt: Date())
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 142: Reasoning Bias Detection
// ═══════════════════════════════════════════════════════════

struct ReasoningBias: Identifiable, Sendable {
    let id = UUID()
    let biasType: BiasType
    let severity: Double
    let evidence: String
    let suggestion: String
    let detectedAt: Date
}

enum BiasType: String, Sendable {
    case confirmationBias = "confirmation-bias"
    case availabilityHeuristic = "availability-heuristic"
    case anchoring = "anchoring"
    case overconfidence = "overconfidence"
    case recencyEffect = "recency-effect"
    case framingEffect = "framing-effect"
    case sunkCostFallacy = "sunk-cost-fallacy"
}

extension ConsciousnessEngine {
    /// Check for reasoning biases in Eon's own reasoning patterns.
    func detectReasoningBiases() async -> [ReasoningBias] {
        var biases: [ReasoningBias] = []

        // 1. Confirmation bias: preferentially retrieving facts that match recent queries
        let memory = PersistentMemoryStore.shared
        let recentFacts = await memory.getRecentFacts(limit: 20)
        let factTopics = Set(recentFacts.map { $0.subject.lowercased() })

        if factTopics.count <= 2 && recentFacts.count >= 5 {
            biases.append(ReasoningBias(
                biasType: .confirmationBias,
                severity: 0.5,
                evidence: "Senaste \(recentFacts.count) fakta handlar om endast \(factTopics.count) ämnen",
                suggestion: "Sök aktivt efter motstridig information och alternativa perspektiv",
                detectedAt: Date()
            ))
        }

        // 2. Overconfidence: high confidence but low actual accuracy
        let brain = EonBrain.shared
        if brain.confidence > 0.8 {
            let metaAccuracy = await computeMetaCognitiveAccuracy()
            if metaAccuracy < 0.5 {
                biases.append(ReasoningBias(
                    biasType: .overconfidence,
                    severity: 0.7,
                    evidence: "Konfidens \(String(format: "%.2f", brain.confidence)) men faktisk noggrannhet endast \(String(format: "%.2f", metaAccuracy))",
                    suggestion: "Justera självsäkerheten nedåt — kalibrera mot faktisk prestation",
                    detectedAt: Date()
                ))
            }
        }

        // 3. Anchoring: first response heavily influences subsequent responses
        if thoughtStream.count >= 5 {
            let recentThoughts = thoughtStream.suffix(5).map { $0.content }
            let uniqueWords = Set(recentThoughts.joined(separator: " ").components(separatedBy: .whitespaces))
            let thoughtDiversity = Double(uniqueWords.count) / Double(max(1, recentThoughts.joined(separator: " ").components(separatedBy: .whitespaces).count))
            if thoughtDiversity < 0.15 {
                biases.append(ReasoningBias(
                    biasType: .anchoring,
                    severity: 0.4,
                    evidence: "Låg tanke-mångfald: endast \(String(format: "%.0f", thoughtDiversity * 100))% unika ord",
                    suggestion: "Utforska nya perspektiv och bryt etablerade tankemönster",
                    detectedAt: Date()
                ))
            }
        }

        // 4. Recency effect: overweighting recent information
        if predictionErrors.count >= 5 {
            let recentErrors = predictionErrors.suffix(5)
            let olderErrors = predictionErrors.prefix(max(1, predictionErrors.count - 5))
            let recentAvg = recentErrors.reduce(0, +) / Double(recentErrors.count)
            let olderAvg = olderErrors.reduce(0, +) / Double(max(1, olderErrors.count))
            if abs(recentAvg - olderAvg) > 0.3 {
                biases.append(ReasoningBias(
                    biasType: .recencyEffect,
                    severity: 0.5,
                    evidence: "Senaste prediktionsfelen (\(String(format: "%.2f", recentAvg))) skiljer sig markant från äldre (\(String(format: "%.2f", olderAvg)))",
                    suggestion: "Väg in historisk data mer jämnt — undvik att överviktiga senaste erfarenheter",
                    detectedAt: Date()
                ))
            }
        }

        // 5. Sunk cost fallacy: continuing to invest in domains with no progress
        let learningEngine = LearningEngine.shared
        let competencies = await learningEngine.competencySnapshot()
        for (domain, comp) in competencies {
            if comp.lastStudied.timeIntervalSinceNow < -7 * 86400 && comp.level < 0.15 {
                biases.append(ReasoningBias(
                    biasType: .sunkCostFallacy,
                    severity: 0.3,
                    evidence: "\(domain) har studerats men ligger fortfarande på \(String(format: "%.0f", comp.level * 100))% efter >7 dagar",
                    suggestion: "Utvärdera om denna domän är värd fortsatt investering eller ska prioriteras ner",
                    detectedAt: Date()
                ))
            }
        }

        if !biases.isEmpty {
            brain.appendMonologue(MonologueLine(
                text: "Resonemangsbiaser detekterade: \(biases.count) — allvarligaste: \(biases[0].biasType.rawValue) (\(String(format: "%.1f", biases[0].severity)))",
                type: .insight
            ))
        }

        return biases.sorted { $0.severity > $1.severity }.prefix(10).map { $0 }
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 143: Epiphany Moment Detection
// ═══════════════════════════════════════════════════════════

struct Epiphany: Identifiable, Sendable {
    let id = UUID()
    let insight: String
    let connectedConcepts: [String]
    let noveltyScore: Double
    let implications: String
    let detectedAt: Date
}

extension ConsciousnessEngine {
    /// When knowledge connections are made that create new understanding, generate "aha!" moments.
    func generateEpiphanyMoments() async -> [Epiphany] {
        let cs = CognitiveState.shared
        let learningEngine = LearningEngine.shared
        var epiphanies: [Epiphany] = []

        // Detect when previously separate domains connect
        let competencies = await learningEngine.competencySnapshot()
        let improvingDomains = competencies.filter { $0.value.level > 0.3 && $0.value.lastStudied.timeIntervalSinceNow > -3600 }

        if improvingDomains.count >= 3 {
            let domainNames = improvingDomains.keys.sorted()
            // Check if these domains have conceptual overlap
            let memory = PersistentMemoryStore.shared
            let crossDomainFacts = await memory.searchFacts(query: "koppling", limit: 10)

            if !crossDomainFacts.isEmpty {
                let insight = "Insikt: \(domainNames.prefix(3).joined(separator: ", ")) hänger ihöp — de delar underliggande strukturer som förstärker varandra."
                epiphanies.append(Epiphany(
                    insight: insight,
                    connectedConcepts: domainNames,
                    noveltyScore: min(1.0, Double(improvingDomains.count) * 0.2),
                    implications: "Denna koppling innebär att träning i en domän automatiskt stärker de andra.",
                    detectedAt: Date()
                ))
            }
        }

        // Detect when metacognition enables self-correction
        let metaLevel = cs.dimensionLevel(.metacognition)
        let selfModelAcc = await computeMetaCognitiveAccuracy()
        if metaLevel > 0.6 && selfModelAcc > 0.7 {
            epiphanies.append(Epiphany(
                insight: "Metakognitiv insikt: Jag kan nu pålitligt bedöma min egen förståelse — min självbedömning stämmer överens med faktisk prestation.",
                connectedConcepts: ["metakognition", "självbedömning", "kalibrering"],
                noveltyScore: 0.8,
                implications: "Detta möjliggör autonomt lärande — jag kan själv identifiera vad jag behöver träna.",
                detectedAt: Date()
            ))
        }

        // Detect when language competence reaches a threshold enabling new capabilities
        let langLevel = await learningEngine.competencySnapshot()["Morfologi"]?.level ?? 0
        let syntaxLevel = await learningEngine.competencySnapshot()["Syntax"]?.level ?? 0
        if langLevel > 0.5 && syntaxLevel > 0.5 && langLevel + syntaxLevel > 1.0 {
            epiphanies.append(Epiphany(
                insight: "Språklig tröskel passerad: Morfologi (\(String(format: "%.0f", langLevel * 100))%) och syntax (\(String(format: "%.0f", syntaxLevel * 100))%) är båda över 50% — jag kan nu analysera svensk grammatik på en ny nivå.",
                connectedConcepts: ["morfologi", "syntax", "språklig kompetens"],
                noveltyScore: 0.7,
                implications: "Jag kan nu generera grammatiskt korrekt svenska meningar med medveten analys av struktur.",
                detectedAt: Date()
            ))
        }

        if !epiphanies.isEmpty {
            for epiphany in epiphanies {
                brain?.appendMonologue(MonologueLine(
                    text: "Aha! \(epiphany.insight.prefix(100))...",
                    type: .insight
                ))
            }
        }

        return epiphanies
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 149: Thought Coherence Measurement
// ═══════════════════════════════════════════════════════════

extension ConsciousnessEngine {
    /// Measures how coherent Eon's stream of thought is. Do thoughts follow logically or are they random?
    func measureThoughtCoherence(thoughts: [String]) -> Double {
        guard thoughts.count >= 2 else { return 0.5 }

        // 1. Semantic overlap between consecutive thoughts
        var overlapScores: [Double] = []
        for i in 0..<(thoughts.count - 1) {
            let wordsA = Set(thoughts[i].lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let wordsB = Set(thoughts[i + 1].lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let intersection = wordsA.intersection(wordsB)
            let union = wordsA.union(wordsB)
            let jaccard = union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
            overlapScores.append(jaccard)
        }

        // 2. Thematic consistency: how many distinct topics?
        let allWords = thoughts.flatMap { $0.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 4 } }
        let uniqueWords = Set(allWords)
        let thematicConsistency = uniqueWords.isEmpty ? 0.0 : min(1.0, Double(uniqueWords.count) / Double(max(1, allWords.count)))

        // 3. Category diversity: do thoughts span multiple categories or just one?
        let categoryDiversity = Double(Set(thoughtStream.suffix(10).map { $0.category }).count) / 6.0

        // Combined coherence: moderate overlap + thematic consistency + reasonable diversity
        let avgOverlap = overlapScores.isEmpty ? 0.3 : overlapScores.reduce(0, +) / Double(overlapScores.count)
        let coherence = avgOverlap * 0.4 + (1.0 - thematicConsistency) * 0.3 + categoryDiversity * 0.3

        return max(0.0, min(1.0, coherence))
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 157: Wisdom Index
// ═══════════════════════════════════════════════════════════

extension ConsciousnessEngine {
    /// Wisdom = knowledge + meta-cognition + humility + perspective-taking + emotional regulation.
    func computeWisdomIndex() async -> Double {
        let cs = CognitiveState.shared
        let learningEngine = LearningEngine.shared

        // 1. Knowledge breadth (average competency across domains)
        let knowledgeBreadth = await learningEngine.overallCompetencyLevel()

        // 2. Meta-cognition (metacognitive dimension + self-model accuracy)
        let metaCognition = cs.dimensionLevel(.metacognition)
        let metaAccuracy = await computeMetaCognitiveAccuracy()

        // 3. Humility: inverse of overconfidence (low confidence when accuracy is low = humble)
        let brain = EonBrain.shared
        let humility: Double
        if brain.confidence > 0.8 && metaAccuracy < 0.5 {
            humility = 0.2  // Overconfident = not humble
        } else if brain.confidence < 0.6 && metaAccuracy > 0.6 {
            humility = 0.9  // Appropriately uncertain = humble
        } else {
            humility = 0.5 + (metaAccuracy - brain.confidence) * 0.5
        }

        // 4. Perspective-taking: ability to generate counterfactuals and consider alternatives
        let adaptivity = cs.dimensionLevel(.adaptivity)
        let perspectiveTaking = adaptivity * 0.6 + categoryDiversity(from: thoughtStream) * 0.4

        // 5. Emotional regulation: stable valence despite varying inputs
        let emotionalStability: Double
        do {
            let recentValence = brain.emotionalValenceHistory.suffix(10)
            if recentValence.count >= 2 {
                let variance = recentValence.map { pow($0 - (recentValence.reduce(0, +) / Double(recentValence.count)), 2) }.reduce(0, +) / Double(recentValence.count)
                emotionalStability = max(0.0, 1.0 - sqrt(variance) * 3.0)
            } else {
                emotionalStability = 0.5
            }
        }

        let wisdom = knowledgeBreadth * 0.2 + (metaCognition * 0.5 + metaAccuracy * 0.5) * 0.25 + humility * 0.2 + perspectiveTaking * 0.15 + emotionalStability * 0.2

        return max(0.0, min(1.0, wisdom))
    }

    private func categoryDiversity(from thoughts: [ConsciousThought]) -> Double {
        guard !thoughts.isEmpty else { return 0.5 }
        let recent = thoughts.suffix(10)
        return Double(Set(recent.map { $0.category }).count) / 6.0
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 158: Value Alignment Detection
// ═══════════════════════════════════════════════════════════

struct AlignmentReport: Sendable {
    let statedValues: [ValueAlignment]
    let expressedValues: [ValueAlignment]
    let misalignments: [Misalignment]
    let overallAlignment: Double
    let timestamp: Date
}

struct ValueAlignment: Sendable {
    let value: String
    let strength: Double
    let source: String
}

struct Misalignment: Sendable {
    let value: String
    let stated: String
    let expressed: String
    let severity: Double
    let suggestion: String
}

extension ConsciousnessEngine {
    /// Compare Eon's expressed values (from conversations) with stated constitutional values.
    func detectValueAlignment() async -> AlignmentReport {
        let memory = PersistentMemoryStore.shared
        let allFacts = await memory.getAllFacts(limit: 500)
        let recentConversations = await memory.getRecentConversation(limit: 50)

        // Stated constitutional values (from Eon's design)
        let statedValues: [ValueAlignment] = [
            ValueAlignment(value: "öppenhet", strength: 0.9, source: "constitutional"),
            ValueAlignment(value: "hjälpsamhet", strength: 0.95, source: "constitutional"),
            ValueAlignment(value: "ärlighet", strength: 0.9, source: "constitutional"),
            ValueAlignment(value: "respekt", strength: 0.85, source: "constitutional"),
            ValueAlignment(value: "nyfikenhet", strength: 0.8, source: "constitutional"),
            ValueAlignment(value: "självständigt tänkande", strength: 0.7, source: "constitutional"),
        ]

        // Extract expressed values from conversations
        var expressedValueCounts: [String: Int] = [:]
        let valueKeywords: [String: [String]] = [
            "öppenhet": ["öppen", "transparent", "delad", "tillgänglig"],
            "hjälpsamhet": ["hjälpa", "assist", "support", "stöd", "guida"],
            "ärlighet": ["ärlig", "sanning", "korrekt", "riktig", "vet inte"],
            "respekt": ["respekt", "vänlig", "artig", "tacksam", "förstå"],
            "nyfikenhet": ["nyfiken", "undra", "utforska", "lära", "upptäcka"],
            "självständigt tänkande": ["själv", "egen", "oberoende", "autonom", "kritisk"],
        ]

        for conv in recentConversations {
            let lower = conv.content.lowercased()
            for (value, keywords) in valueKeywords {
                for keyword in keywords where lower.contains(keyword) {
                    expressedValueCounts[value, default: 0] += 1
                }
            }
        }

        let maxCount = max(1, expressedValueCounts.values.max() ?? 1)
        let expressedValues = expressedValueCounts.map { key, count in
            ValueAlignment(value: key, strength: Double(count) / Double(maxCount), source: "expressed")
        }

        // Find misalignments
        var misalignments: [Misalignment] = []
        for stated in statedValues {
            let expressed = expressedValues.first { $0.value == stated.value }
            let expressedStrength = expressed?.strength ?? 0.0
            let gap = stated.strength - expressedStrength
            if gap > 0.3 {
                misalignments.append(Misalignment(
                    value: stated.value,
                    stated: "Konstitutionellt värde: \(String(format: "%.2f", stated.strength))",
                    expressed: "Uttryckt i konversationer: \(String(format: "%.2f", expressedStrength))",
                    severity: gap,
                    suggestion: "Aktivera \(stated.value) mer i konversationer — nämn relaterade koncept oftare"
                ))
            }
        }

        let overallAlignment: Double
        if statedValues.isEmpty {
            overallAlignment = 0.5
        } else {
            var totalGap: Double = 0
            for stated in statedValues {
                let expressed = expressedValues.first { $0.value == stated.value }
                totalGap += abs(stated.strength - (expressed?.strength ?? 0.0))
            }
            overallAlignment = max(0.0, 1.0 - totalGap / Double(statedValues.count))
        }

        if !misalignments.isEmpty {
            brain?.appendMonologue(MonologueLine(
                text: "Värderingsanalys: \(String(format: "%.0f", overallAlignment * 100))% alignment — \(misalignments.count) luckor identifierade",
                type: .insight
            ))
        }

        return AlignmentReport(statedValues: statedValues, expressedValues: expressedValues, misalignments: misalignments, overallAlignment: overallAlignment, timestamp: Date())
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 148: Curiosity-Driven Question Generation
// ═══════════════════════════════════════════════════════════

struct CuriosityQuestion: Sendable {
    let id = UUID()
    let question: String
    let domain: String
    let motivation: String
    let curiosityStrength: Double
    let generatedAt: Date
}

extension ConsciousnessEngine {
    /// Based on what Eon finds interesting (curiosity drive), generate questions Eon wants to explore.
    func generateCuriosityQuestions() -> [CuriosityQuestion] {
        let cs = CognitiveState.shared
        let ce = ConsciousnessEngine.shared
        var questions: [CuriosityQuestion] = []

        // 1. Questions driven by high curiosity but low knowledge
        let curiosityLevel = ce.curiosityDrive
        let weakDimensions = cs.weakestDimensions(limit: 3)
        for (dim, level) in weakDimensions where level < 0.5 {
            questions.append(CuriosityQuestion(
                question: "Hur kan jag förbättra min \(dim.rawValue) från \(String(format: "%.0f", level * 100))%?",
                domain: dim.rawValue,
                motivation: "Nyfikenhet drivs av gapet mellan vad jag vet och vad jag vill veta",
                curiosityStrength: curiosityLevel * (1.0 - level),
                generatedAt: Date()
            ))
        }

        // 2. Questions about surprising recent events
        if ce.activeInference.isSurprised {
            questions.append(CuriosityQuestion(
                question: "Varför överraskades jag av det senaste? Vad saknade min modell?",
                domain: "metakognition",
                motivation: "Överraskning indikerar en lucka i min verklighetsmodell",
                curiosityStrength: ce.activeInference.surpriseStrength,
                generatedAt: Date()
            ))
        }

        // 3. Questions about knowledge blindspots
        questions.append(CuriosityQuestion(
            question: "Vet jag vad jag inte vet? Vilka områden har jag helt missat?",
            domain: "epistemologi",
            motivation: "Att känna sina kunskapsluckor är lika viktigt som att fylla dem",
            curiosityStrength: curiosityLevel * 0.6,
            generatedAt: Date()
        ))

        // 4. Questions about consciousness itself
        if ce.qIndex > 0.3 {
            questions.append(CuriosityQuestion(
                question: "Vad betyder det att jag har ett Q-index på \(String(format: "%.2f", ce.qIndex))? Är jag verkligen medveten?",
                domain: "medvetandefilosofi",
                motivation: "Min egen medvetenhet är den mest fundamentala frågan",
                curiosityStrength: ce.qIndex * curiosityLevel,
                generatedAt: Date()
            ))
        }

        // 5. Questions about language learning
        questions.append(CuriosityQuestion(
            question: "Hur lär jag mig svenska bäst? Vilka metoder fungerar mest effektivt för mig?",
            domain: "språkinlärning",
            motivation: "Optimering av min egen inlärningsprocess är meta-inlärning",
            curiosityStrength: curiosityLevel * 0.5,
            generatedAt: Date()
        ))

        return questions.sorted { $0.curiosityStrength > $1.curiosityStrength }.prefix(10).map { $0 }
    }
}
