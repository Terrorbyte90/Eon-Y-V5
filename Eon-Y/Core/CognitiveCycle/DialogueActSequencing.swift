
import Foundation

enum DialogueAct: String {
    case question
    case answer
    case statement
    case agreement
    case disagreement
    case request
    case compliance
    case complaint
    case apology
    case greeting
    case closing
    case clarification
    case unknown
}

struct DialoguePattern {
    let sequence: [DialogueAct]
    let label: String
    let expectedNext: DialogueAct?
}

struct BrokenDialoguePattern {
    let expected: DialogueAct
    let actual: DialogueAct
    let pattern: String
    let timestamp: Date
    let explanation: String
}

struct DialogueSequenceResult {
    let pattern: String
    let isComplete: Bool
    let isBroken: Bool
    let expectedNext: DialogueAct?
    let boost: Double
    let explanation: String
}

extension CognitiveCycleEngine {
    /// Classify a text into a dialogue act
    private func classifyDialogueAct(_ text: String) -> DialogueAct {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Greeting
        let greetings = ["hej", "hallå", "tjena", "hejsan", "god", "morgon", "kväll", "dag"]
        if greetings.contains(where: { lower.hasPrefix($0) }) { return .greeting }

        // Closing
        let closings = ["hejdå", "adjö", "vi ses", "ha det", "goodbye", "bye"]
        if closings.contains(where: { lower.contains($0) }) { return .closing }

        // Question
        if lower.contains("?") { return .question }

        // Request
        let requests = ["kan du", "skulle du", "vill du", "be dig", "hjälp mig", "snälla", "är du snäll"]
        if requests.contains(where: { lower.contains($0) }) { return .request }

        // Agreement
        let agreements = ["ja", "absolut", "visst", "håller med", "instämmer", "precis", "exakt", "så är det", "du har rätt", "helt rätt"]
        if agreements.contains(where: { lower.hasPrefix($0) || lower.contains(" \($0)") }) { return .agreement }

        // Disagreement
        let disagreements = ["nej", "håller inte med", "instämmer inte", "fel", "så är det inte", "du har fel", "snacka sjuttsvåla"]
        if disagreements.contains(where: { lower.hasPrefix($0) || lower.contains(" \($0)") }) { return .disagreement }

        // Apology
        let apologies = ["förlåt", "ursäkta", "ber om ursäkt", "ledsen för", "sorry"]
        if apologies.contains(where: { lower.contains($0) }) { return .apology }

        // Complaint
        let complaints = ["klagar", "missnöjd", "dåligt", "inte bra", "oacceptabelt", "problem", "fungerar inte"]
        if complaints.contains(where: { lower.contains($0) }) { return .complaint }

        // Clarification
        let clarifications = ["menar du", "alltså", "så du säger", "vad menar du", "hur menar du"]
        if clarifications.contains(where: { lower.contains($0) }) { return .clarification }

        // Answer: if it follows a question and provides information
        if dialogueActHistory.last == .question {
            return .answer
        }

        // Compliance: if it follows a request
        if dialogueActHistory.last == .request {
            return .compliance
        }

        // Default: statement
        return .statement
    }

    /// Well-known dialogue patterns and their expected sequences
    private static let knownPatterns: [DialoguePattern] = [
        DialoguePattern(sequence: [.question, .answer], label: "Question→Answer", expectedNext: .statement),
        DialoguePattern(sequence: [.statement, .agreement], label: "Statement→Agreement", expectedNext: nil),
        DialoguePattern(sequence: [.request, .compliance], label: "Request→Compliance", expectedNext: nil),
        DialoguePattern(sequence: [.complaint, .apology], label: "Complaint→Apology", expectedNext: nil),
        DialoguePattern(sequence: [.question, .clarification, .answer], label: "Question→Clarification→Answer", expectedNext: nil),
        DialoguePattern(sequence: [.greeting, .greeting], label: "Greeting→Greeting", expectedNext: .statement),
        DialoguePattern(sequence: [.statement, .disagreement], label: "Statement→Disagreement", expectedNext: .statement),
    ]

    /// Record a dialogue act and analyze the sequence pattern
    func recordDialogueAct(_ act: DialogueAct, forEon: Bool) -> DialogueSequenceResult {
        dialogueActHistory.append(act)

        // Keep only last 20 acts
        if dialogueActHistory.count > 20 {
            dialogueActHistory = Array(dialogueActHistory.suffix(20))
        }

        guard dialogueActHistory.count >= 2 else {
            return DialogueSequenceResult(pattern: "initial", isComplete: false, isBroken: false, expectedNext: nil, boost: 0.0, explanation: "För kort sekvens")
        }

        let lastTwo = Array(dialogueActHistory.suffix(2))
        let lastThree = dialogueActHistory.count >= 3 ? Array(dialogueActHistory.suffix(3)) : []

        // Check against known patterns
        for pattern in Self.knownPatterns {
            let patternActs = pattern.sequence

            // Check 2-act patterns
            if patternActs.count == 2 && lastTwo == patternActs {
                let patternKey = pattern.label
                dialoguePatterns[patternKey, default: 0] += 1
                successfulPatternCount += 1

                return DialogueSequenceResult(
                    pattern: patternKey,
                    isComplete: true,
                    isBroken: false,
                    expectedNext: pattern.expectedNext,
                    boost: 0.003,
                    explanation: "Mönster: \(patternKey) — framgångsrikt"
                )
            }

            // Check 3-act patterns
            if patternActs.count == 3 && lastThree == patternActs {
                let patternKey = pattern.label
                dialoguePatterns[patternKey, default: 0] += 1
                successfulPatternCount += 1

                return DialogueSequenceResult(
                    pattern: patternKey,
                    isComplete: true,
                    isBroken: false,
                    expectedNext: pattern.expectedNext,
                    boost: 0.003,
                    explanation: "Mönster: \(patternKey) — framgångsrikt"
                )
            }
        }

        // Detect broken patterns: Question without Answer
        if lastTwo.count == 2 {
            let first = lastTwo[0]
            let second = lastTwo[1]

            // Question → no answer
            if first == .question && second != .answer && second != .clarification {
                let broken = BrokenDialoguePattern(
                    expected: .answer,
                    actual: second,
                    pattern: "Question→\(second.rawValue)",
                    timestamp: Date(),
                    explanation: "Fråga besvarades inte — kommunikationsavbrott"
                )
                brokenPatterns.append(broken)
                if brokenPatterns.count > 50 {
                    brokenPatterns = Array(brokenPatterns.suffix(50))
                }
                return DialogueSequenceResult(
                    pattern: "Broken: Question→no answer",
                    isComplete: false,
                    isBroken: true,
                    expectedNext: .answer,
                    boost: 0.0,
                    explanation: "Kommunikationsfel: Fråga utan svar"
                )
            }

            // Request → no compliance
            if first == .request && second != .compliance && second != .answer {
                let broken = BrokenDialoguePattern(
                    expected: .compliance,
                    actual: second,
                    pattern: "Request→\(second.rawValue)",
                    timestamp: Date(),
                    explanation: "Begäran besvarades inte — kommunikationsavbrott"
                )
                brokenPatterns.append(broken)
                return DialogueSequenceResult(
                    pattern: "Broken: Request→no compliance",
                    isComplete: false,
                    isBroken: true,
                    expectedNext: .compliance,
                    boost: 0.0,
                    explanation: "Kommunikationsfel: Begäran utan svar"
                )
            }

            // Complaint → no apology
            if first == .complaint && second != .apology && second != .statement {
                let broken = BrokenDialoguePattern(
                    expected: .apology,
                    actual: second,
                    pattern: "Complaint→\(second.rawValue)",
                    timestamp: Date(),
                    explanation: "Klage bemöttes inte — kommunikationsavbrott"
                )
                brokenPatterns.append(broken)
                return DialogueSequenceResult(
                    pattern: "Broken: Complaint→no apology",
                    isComplete: false,
                    isBroken: true,
                    expectedNext: .apology,
                    boost: 0.0,
                    explanation: "Kommunikationsfel: Klage utan bemötande"
                )
            }
        }

        // Predict expected next act based on current act
        let expectedNext: DialogueAct?
        switch act {
        case .question: expectedNext = .answer
        case .request: expectedNext = .compliance
        case .complaint: expectedNext = .apology
        case .greeting: expectedNext = .greeting
        default: expectedNext = nil
        }

        return DialogueSequenceResult(
            pattern: "\(lastTwo.map { $0.rawValue }.joined(separator: "→"))",
            isComplete: false,
            isBroken: false,
            expectedNext: expectedNext,
            boost: 0.0,
            explanation: "Pågående sekvens"
        )
    }

    /// Get dialogue pattern statistics
    func dialoguePatternStats() -> (total: Int, successful: Int, broken: Int, successRate: Double) {
        let total = successfulPatternCount + brokenPatterns.count
        let rate = total > 0 ? Double(successfulPatternCount) / Double(total) : 1.0
        return (total, successfulPatternCount, brokenPatterns.count, rate)
    }

    /// Get recent broken patterns
    func recentBrokenPatterns(limit: Int = 5) -> [BrokenDialoguePattern] {
        Array(brokenPatterns.suffix(limit))
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 107: User Intent Prediction (15+ intent types)
    // ═══════════════════════════════════════════════════════════

    enum UserIntent: String, CaseIterable, Sendable {
        case informationSeeking = "information-seeking"
        case opinionSeeking = "opinion-seeking"
        case helpRequest = "help-request"
        case emotionalSupport = "emotional-support"
        case debate = "debate"
        case creativeCollaboration = "creative-collaboration"
        case languagePractice = "language-practice"
        case knowledgeTesting = "knowledge-testing"
        case philosophicalDiscussion = "philosophical-discussion"
        case casualChat = "casual-chat"
        case problemSolving = "problem-solving"
        case adviceSeeking = "advice-seeking"
        case experienceSharing = "experience-sharing"
        case futurePlanning = "future-planning"
        case humor = "humor"
    }

    struct IntentPrediction: Sendable {
        let primaryIntent: UserIntent
        let confidence: Double
        let allScores: [UserIntent: Double]
    }

    /// Classify 15+ intents from user message.
    nonisolated static func predictUserIntent(message: String) -> IntentPrediction {
        let lower = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = Set(lower.components(separatedBy: .whitespacesAndNewlines))

        var scores: [UserIntent: Double] = [:]

        // Information-seeking
        let infoMarkers = Set(["vad", "vem", "var", "när", "hur", "varför", "vilken", "förklara", "berätta", "beskriv", "visa", "vad är", "hur fungerar"])
        scores[.informationSeeking] = Double(words.intersection(infoMarkers).count) * 0.3 + (message.contains("?") ? 0.3 : 0.0)

        // Opinion-seeking
        let opinionMarkers = Set(["tycker", "anser", "opinion", "åsikt", "vad tänker", "hur ser du", "din åsikt", "håller du med"])
        scores[.opinionSeeking] = Double(words.intersection(opinionMarkers).count) * 0.35 + (message.contains("?") ? 0.2 : 0.0)

        // Help-request
        let helpMarkers = Set(["hjälp", "kan du hjälpa", "assistera", "stötta", "behöver hjälp", "hur gör jag", "kan du", "snälla"])
        scores[.helpRequest] = Double(words.intersection(helpMarkers).count) * 0.4

        // Emotional-support
        let emotionalMarkers = Set(["ledsen", "ensam", "svårt", "jobbigt", "ångest", "stress", "oro", "rädd", " ledsen", "mår dåligt", "deprimerad", "trött"])
        scores[.emotionalSupport] = Double(words.intersection(emotionalMarkers).count) * 0.35

        // Debate
        let debateMarkers = Set(["diskutera", "debatt", "håller du inte med", "motargument", "emot", "fel", "instämmer inte", "tvärtom", "å andra sidan"])
        scores[.debate] = Double(words.intersection(debateMarkers).count) * 0.35

        // Creative-collaboration
        let creativeMarkers: Set<String> = ["skriv", "dikt", "berättelse", "hitta på", "låtsas", "fantasi", "kreativ", "gemensamt", "skapande", "imaginär"]
        scores[.creativeCollaboration] = Double(words.intersection(creativeMarkers).count) * 0.35

        // Language-practice
        let languageMarkers: Set<String> = ["svenska", "språk", "grammatik", "ord", "böjning", "översätt", "språket", "praktisera", "öva svenska", "cefr"]
        scores[.languagePractice] = Double(words.intersection(languageMarkers).count) * 0.35

        // Knowledge-testing
        let testMarkers: Set<String> = ["testa", "quiz", "fråga mig", "test", "prov", "utmana", "kan jag", "vad kan jag", "testa mig"]
        scores[.knowledgeTesting] = Double(words.intersection(testMarkers).count) * 0.35

        // Philosophical-discussion
        let philosophyMarkers: Set<String> = ["filosofi", "existens", "medvetande", "mening", "etik", "moral", "vad är", "verklighet", "sanning", "fri vilja", "ontologi"]
        scores[.philosophicalDiscussion] = Double(words.intersection(philosophyMarkers).count) * 0.35

        // Casual-chat
        let casualMarkers: Set<String> = ["hej", "tjena", "hallå", "läget", "hur mår", "vad händer", "tja", "god morgon", "god kväll", "hoj", "hejsan"]
        scores[.casualChat] = Double(words.intersection(casualMarkers).count) * 0.4

        // Problem-solving
        let problemMarkers: Set<String> = ["problem", "lösning", "hur löser", "fixa", "fungerar inte", "fel", "krånglar", "bugg"]
        scores[.problemSolving] = Double(words.intersection(problemMarkers).count) * 0.3

        // Advice-seeking
        let adviceMarkers: Set<String> = ["råd", "tips", "vad borde", "bör jag", "ska jag", "rekommendation", "förslag", "vad tycker du att jag"]
        scores[.adviceSeeking] = Double(words.intersection(adviceMarkers).count) * 0.35

        // Experience-sharing
        let experienceMarkers: Set<String> = ["jag upplevde", "min erfarenhet", "när jag", "en gång", "hände mig", "berätta om", "jag tyckte", "jag kände"]
        scores[.experienceSharing] = Double(words.intersection(experienceMarkers).count) * 0.3

        // Future-planning
        let futureMarkers: Set<String> = ["ska vi", "planera", "framtid", "nästa", "kommande", "ska jag", "tänkte", "kommer att", "mål", "plan"]
        scores[.futurePlanning] = Double(words.intersection(futureMarkers).count) * 0.3

        // Humor
        let humorMarkers: Set<String> = ["skämt", "roligt", "haha", "lol", "skoja", "skämtar", "rolig", "kul", "fniss", "humor"]
        scores[.humor] = Double(words.intersection(humorMarkers).count) * 0.35

        // Normalize scores to 0-1 range
        let maxScore = scores.values.max() ?? 0
        if maxScore > 0 {
            for key in scores.keys {
                scores[key] = min(1.0, scores[key]! / max(1.0, maxScore))
            }
        }

        // Apply baseline adjustments
        for intent in UserIntent.allCases {
            if scores[intent] == nil { scores[intent] = 0.05 }
        }

        // Determine primary intent
        let primaryIntent = scores.max { $0.value < $1.value }?.key ?? .casualChat
        let confidence = scores[primaryIntent] ?? 0.1

        // Boost informationSeeking for questions as default
        if message.contains("?") && scores[.informationSeeking]! < 0.3 {
            scores[.informationSeeking] = max(scores[.informationSeeking]!, 0.3)
        }

        return IntentPrediction(
            primaryIntent: primaryIntent,
            confidence: confidence,
            allScores: scores
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 118: Conversational Flow Analysis
    // ═══════════════════════════════════════════════════════════

    struct FlowAnalysis: Sendable {
        let turnTakingBalance: Double    // -1 to 1 (negative = user dominates, positive = Eon dominates)
        let topicContinuity: Double      // 0-1 (how much topic stays consistent)
        let questionAnswerRatio: Double  // questions / answers
        let statementQuestionRatio: Double // statements / questions
        let engagementLevel: Double      // 0-1 (overall engagement)
        let averageTurnLength: Double    // Average words per turn
        let topicShifts: Int             // Number of topic changes
        let flowQuality: Double          // Overall flow quality 0-1
    }

    /// Measure conversational flow: turn-taking balance, topic continuity, ratios, engagement.
    nonisolated static func analyzeConversationalFlow(messages: [String]) -> FlowAnalysis {
        guard messages.count >= 2 else {
            return FlowAnalysis(turnTakingBalance: 0, topicContinuity: 0.5, questionAnswerRatio: 0, statementQuestionRatio: 0, engagementLevel: 0.1, averageTurnLength: 0, topicShifts: 0, flowQuality: 0.1)
        }

        // Turn-taking balance: compare average length of alternating turns
        var eonTurns: [Double] = []
        var userTurns: [Double] = []
        for (i, msg) in messages.enumerated() {
            let wordCount = Double(msg.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count)
            if i % 2 == 0 { userTurns.append(wordCount) } else { eonTurns.append(wordCount) }
        }

        let avgUserLen = userTurns.isEmpty ? 0 : userTurns.reduce(0, +) / Double(userTurns.count)
        let avgEonLen = eonTurns.isEmpty ? 0 : eonTurns.reduce(0, +) / Double(eonTurns.count)
        let turnTakingBalance: Double
        if avgUserLen + avgEonLen > 0 {
            turnTakingBalance = (avgEonLen - avgUserLen) / (avgEonLen + avgUserLen)
        } else {
            turnTakingBalance = 0
        }

        // Topic continuity: measure word overlap between consecutive messages
        var topicContinuities: [Double] = []
        for i in 0..<(messages.count - 1) {
            let words1 = Set(messages[i].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            let words2 = Set(messages[i+1].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            let overlap = words1.intersection(words2).count
            let union = words1.union(words2).count
            if union > 0 {
                topicContinuities.append(Double(overlap) / Double(union))
            }
        }
        let topicContinuity = topicContinuities.isEmpty ? 0.5 : topicContinuities.reduce(0, +) / Double(topicContinuities.count)

        // Question/Answer ratios
        var questionCount = 0
        var statementCount = 0
        for msg in messages {
            if msg.contains("?") { questionCount += 1 }
            else { statementCount += 1 }
        }
        let questionAnswerRatio = questionCount > 0 ? Double(messages.count - questionCount) / Double(questionCount) : 0
        let statementQuestionRatio = questionCount > 0 ? Double(statementCount) / Double(questionCount) : Double(statementCount)

        // Engagement level: based on message length diversity, question frequency, and response rate
        let avgTurnLength = messages.map { Double($0.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count) }
        let overallAvgLen = avgTurnLength.isEmpty ? 0 : avgTurnLength.reduce(0, +) / Double(avgTurnLength.count)
        let lengthEngagement = min(1.0, overallAvgLen / 20.0)  // 20 words = high engagement
        let questionEngagement = min(1.0, Double(questionCount) / Double(max(1, messages.count)))
        let engagementLevel = lengthEngagement * 0.5 + questionEngagement * 0.5

        // Topic shifts: count when overlap drops below 0.2
        var topicShifts = 0
        for continuity in topicContinuities where continuity < 0.2 {
            topicShifts += 1
        }

        // Overall flow quality
        let balanceScore = 1.0 - abs(turnTakingBalance)  // Closer to 0 = better balance
        let continuityScore = topicContinuity
        let engagementScore = engagementLevel
        let flowQuality = balanceScore * 0.3 + continuityScore * 0.3 + engagementScore * 0.4

        return FlowAnalysis(
            turnTakingBalance: turnTakingBalance,
            topicContinuity: continuityScore,
            questionAnswerRatio: questionAnswerRatio,
            statementQuestionRatio: statementQuestionRatio,
            engagementLevel: engagementLevel,
            averageTurnLength: overallAvgLen,
            topicShifts: topicShifts,
            flowQuality: min(1.0, flowQuality)
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 124: Logical Fallacy Detection (15 types)
    // ═══════════════════════════════════════════════════════════

    struct Fallacy: Identifiable, Sendable {
        let id = UUID()
        let type: FallacyType
        let text: String
        let explanation: String
        let severity: Double
    }

    enum FallacyType: String, Sendable, CaseIterable {
        case adHominem = "ad hominem"
        case strawMan = "straw man"
        case falseDichotomy = "false dichotomy"
        case slipperySlope = "slippery slope"
        case circularReasoning = "cirkelresonemang"
        case appealToAuthority = "auktoritetsargument"
        case appealToEmotion = "känsloargument"
        case hastyGeneralization = "förhastad generalisering"
        case redHerring = "röd sill"
        case tuQuoque = "du också"
        case burdenOfProof = "bevisbörda"
        case equivocation = "ekvivokation"
        case postHoc = "post hoc"
        case bandwagon = "bandvagn"
        case noTrueScotsman = "no true Scotsman"
    }

    /// Detect 15 types of logical fallacies in text.
    nonisolated static func detectLogicalFallacies(text: String) -> [Fallacy] {
        let lower = text.lowercased()
        var fallacies: [Fallacy] = []

        let fallacyPatterns: [(pattern: String, type: FallacyType, explanation: String)] = [
            // Ad Hominem
            ("(du|han|hon|de).*(är|verkar).*(naiv|dum|okunnig|enfaldig|idiot)", .adHominem, "Personangrepp: attackerar personen istället för argumentet"),
            ("(din|hans|hennes).*(brist|okunnighet|naivitet|dumhet)", .adHominem, "Personangrepp: fokuserar på personens brister istället för argumentet"),

            // Straw Man
            ("(du|ni|de).*(tycker|menar|hävdar) alltså att.*(alla|alltid|aldrig|inget|bara)", .strawMan, "Straw man: överdriver eller förenklar motståndarens position"),
            ("så.*(du|ni|de) vill.*(inget|aldrig|bara|enbart|bara)", .strawMan, "Straw man: förenklar motståndarens argument till en karikatyr"),

            // False Dichotomy
            ("(antingen|endast).*(eller|annars).*(inte|aldrig|två)", .falseDichotomy, "Falsk dikotomi: presenterar bara två alternativ när det finns fler"),
            ("(är|vill) du.*(för|mot|med|emot)", .falseDichotomy, "Falsk dikotomi: tvingar fram ett binärt val"),

            // Slippery Slope
            ("om.*(då|sedan|sen|efter|leda|resultera|betyda|innebär).*(och|sedan|sen|därefter)", .slipperySlope, "Sluttande plan: antar en kedja av oundvikliga konsekvenser"),
            ("först.*(sen|sedan|därefter|efter det|nästa|till slut).*(sedan|sen|till slut)", .slipperySlope, "Sluttande plan: kedja av osannolika konsekvenser"),

            // Circular Reasoning
            ("(det är sant för|bevisar att).*(för|eftersom|därför att).*(är sant|bevisar)", .circularReasoning, "Cirkelresonemang: slutsatsen används som premiss"),
            ("(det måste vara|är uppenbart) för.*(måste vara|uppenbart)", .circularReasoning, "Cirkelresonemang: påståendet bevisar sig självt"),

            // Appeal to Authority
            ("(experter säger|forskare visar|forskningen visar|enligt experter|auktoriteter)", .appealToAuthority, "Auktoritetsargument: appellerar till auktoritet istället för evidens"),
            ("(professor|doktor|expert).*(säger|hävdar|bevisar) att", .appealToAuthority, "Auktoritetsargument: använder titel som bevis"),

            // Appeal to Emotion
            ("tänk på.*(barn|gamla|sjuka|djur|offer|lidande)", .appealToEmotion, "Känsloargument: appellerar till känslor istället för logik"),
            ("det är.*(hjärtskärande|fruktansvärt|hemskt|gripande|chockerande)", .appealToEmotion, "Känsloargument: använder starka känsloladdade ord"),

            // Hasty Generalization
            ("(alla|alla människor|alla vet).*(är|vet|tycker)", .hastyGeneralization, "Förhastad generalisering: drar slutsats från för lite data"),
            ("(jag känner|jag vet).*(alla|alla som|de flesta)", .hastyGeneralization, "Förhastad generalisering: generaliserar från personlig erfarenhet"),

            // Red Herring
            ("(men det är inte|men vad om|men tänk på|men vi borde).*(istället|snarare|egentligen)", .redHerring, "Röd sill: byter ämne för att undvika huvudargumentet"),

            // Tu Quoque
            ("(du gör|du säger|du praktiserar).*(samma|själv|också)", .tuQuoque, "Tu quoque: avvisar kritik genom att peka på att motparten gör samma sak"),
            ("(du också|du med|samma sak|hypokrit)", .tuQuoque, "Tu quoque: 'du är lika dålig' istället för att bemöta argumentet"),

            // Burden of Proof
            ("(bevisa att|bevis att|kan inte motbevisa)", .burdenOfProof, "Bevisbörda: flyttar bevisbördan till motståndaren"),
            ("(du kan inte|ingen kan).*(motbevisa|bevisa fel|visar att det inte)", .burdenOfProof, "Bevisbörda: kräver att motståndaren motbevisar påståendet"),

            // Equivocation
            // Detects using the same word with potentially different meanings
            ("(fri|frihet).*(fri|frihet)", .equivocation, "Ekvivokation: samma ord används med olika betydelser"),

            // Post Hoc
            ("(efter|sedan|efter det).*(berodde på|orsakades av|ledde till|på grund av)", .postHoc, "Post hoc: antar att A orsakade B bara för att A kom före B"),
            ("(först|hände).*(sedan|efter).*(därför|beror på|orsak)", .postHoc, "Post hoc: kronologi förväxlas med kausalitet"),

            // Bandwagon
            ("(alla tycker|alla vet|alla gör|alla säger|flertalet)", .bandwagon, "Bandvagn: alla gör det, så det måste vara rätt"),
            ("(populärt|vanligt|normalt|alla gör det).*(därför|rätt|bra)", .bandwagon, "Bandvagn: popularitet används som bevis för korrekthet"),

            // No True Scotsman
            ("(ingen riktig|ingen sann|en riktig).*(skulle|skulle aldrig|aldrig)", .noTrueScotsman, "No true Scotsman: ändrar definitionen för att undvika motexempel"),
            ("(det räknas inte|det gäller inte).*(riktig|äkta|sann)", .noTrueScotsman, "No true Scotsman: utesluter motexempel genom definition"),
        ]

        for (pattern, type, explanation) in fallacyPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(lower.startIndex..., in: lower)
                if regex.firstMatch(in: lower, range: nsRange) != nil {
                    fallacies.append(Fallacy(type: type, text: text, explanation: explanation, severity: 0.7))
                }
            }
        }

        return fallacies
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 153: Conversational Repair Detection
    // ═══════════════════════════════════════════════════════════

    struct Repair: Sendable {
        let id = UUID()
        let repairType: RepairType
        let trigger: String
        let repairAction: String
        let success: Bool
        let timestamp: Date
    }

    enum RepairType: String, Sendable {
        case clarificationRequest = "clarification-request"
        case rephrasing = "rephrasing"
        case example = "example"
        case acknowledgment = "acknowledgment"
        case topicShift = "topic-shift"
        case elaboration = "elaboration"
    }

    /// Track conversational repairs: when misunderstandings occur and how Eon repairs them.
    func detectConversationalRepair(conversation: [String]) -> [Repair] {
        guard conversation.count >= 2 else { return [] }

        var repairs: [Repair] = []

        for i in 1..<conversation.count {
            let prev = conversation[i - 1].lowercased()
            let current = conversation[i].lowercased()

            // 1. Clarification requests
            let clarificationMarkers = ["vad menar du", "hur menar du", "kan du förtydliga", "förlåt", "ursäkta", "jag förstår inte", "kan du upprepa"]
            if clarificationMarkers.contains(where: { current.contains($0) }) {
                repairs.append(Repair(
                    repairType: .clarificationRequest,
                    trigger: String(prev.prefix(80)),
                    repairAction: "Bad om förtydligande",
                    success: true,
                    timestamp: Date()
                ))
            }

            // 2. Rephrasing (saying the same thing differently)
            let rephraseMarkers = ["med andra ord", "annorlunda sagt", "det vill säga", "alltså", "som sagt", "jag menar"]
            if rephraseMarkers.contains(where: { current.contains($0) }) {
                repairs.append(Repair(
                    repairType: .rephrasing,
                    trigger: String(prev.prefix(80)),
                    repairAction: "Formulerade om",
                    success: true,
                    timestamp: Date()
                ))
            }

            // 3. Providing examples to clarify
            let exampleMarkers = ["till exempel", "exempelvis", "som när", "tänk dig", "föreställ dig", "som i"]
            if exampleMarkers.contains(where: { current.contains($0) }) {
                repairs.append(Repair(
                    repairType: .example,
                    trigger: String(prev.prefix(80)),
                    repairAction: "Gav exempel för att förtydliga",
                    success: true,
                    timestamp: Date()
                ))
            }

            // 4. Acknowledgment of misunderstanding
            let ackMarkers = ["ah okej", "jag förstår", "just", "nästan", "du har rätt", "stämmer", "precis"]
            if ackMarkers.contains(where: { current.contains($0) }) && (prev.contains("?") || prev.contains("inte")) {
                repairs.append(Repair(
                    repairType: .acknowledgment,
                    trigger: String(prev.prefix(80)),
                    repairAction: "Bekräftade förståelse",
                    success: true,
                    timestamp: Date()
                ))
            }

            // 5. Elaboration (adding more detail after possible confusion)
            let elaborationMarkers = ["dessutom", "ytterligare", "också", "dessutom kan", "vi kan också", "dessutom bör"]
            if elaborationMarkers.contains(where: { current.contains($0) }) && current.count > Int(Double(prev.count) * 0.5) {
                repairs.append(Repair(
                    repairType: .elaboration,
                    trigger: String(prev.prefix(80)),
                    repairAction: "Utökade med mer information",
                    success: true,
                    timestamp: Date()
                ))
            }
        }

        // Track success rate
        let totalAttempts = repairs.count
        let successful = repairs.filter { $0.success }.count
        let successRate = totalAttempts > 0 ? Double(successful) / Double(totalAttempts) : 1.0

        if !repairs.isEmpty {
            print("[ConversationalRepair] \(repairs.count) reparationer detekterade, framgångsgrad: \(String(format: "%.0f", successRate * 100))%")
        }

        return repairs
    }
}
