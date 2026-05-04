import Foundation

struct DomainCompetency: Identifiable {
    let id = UUID()
    let domain: String
    var level: Double          // 0..1 (sten=0, professor=1)
    var knowledgeItems: [String]
    var lastStudied: Date

    var levelLabel: String {
        switch level {
        case 0.8...: return "Expert"
        case 0.6..<0.8: return "Avancerad"
        case 0.4..<0.6: return "Medel"
        case 0.2..<0.4: return "Nybörjare"
        default: return "Grundläggande"
        }
    }
}

struct FSRSItem: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String?
    var stability: Double
    // ── v98: Multi-dimensional difficulty ──
    var difficulty: Double           // Overall difficulty (legacy, computed from dimensions)
    var vocabularyDifficulty: Double // 0.0-1.0: How hard the vocabulary is
    var grammarDifficulty: Double    // 0.0-1.0: How complex the grammar is
    var conceptualDifficulty: Double // 0.0-1.0: How abstract the concept is
    var culturalDifficulty: Double   // 0.0-1.0: How culturally specific it is
    var dueDate: Date
    var reviewCount: Int
    var lastReview: Date?

    /// v98: Computed overall difficulty from multi-dimensional scores
    var compositeDifficulty: Double {
        0.35 * vocabularyDifficulty + 0.25 * grammarDifficulty + 0.25 * conceptualDifficulty + 0.15 * culturalDifficulty
    }

    nonisolated var priority: Double { stability * (1.0 - difficulty) }
}

struct ScheduledLesson: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String
    let scheduledAt: Date
    var completed: Bool = false
}

struct KnowledgeGap: Identifiable {
    let id = UUID()
    let domain: String
    let currentLevel: Double
    let targetLevel: Double
    let urgency: Double
    let suggestedTopics: [String]
}

struct LearningCycleResult {
    let cycleNumber: Int
    let studiedTopics: [String]
    let newKnowledge: [String]
    let gapsIdentified: Int
    let loraVersion: Int
}

struct AutonomousExploreResult {
    let domain: String
    let studyGoals: [String]
    let createdItems: Int
}

struct DailyLearningMetrics {
    let conversationsToday: Int
    let wordsLearnedToday: Int
    let lastActiveDate: Date
    let totalVocabulary: Int
    let learningVelocity: Double
    let activeStudyTopics: [String]
    let recentWords: [String]
}

// ═══════════════════════════════════════════════════════════
// ITERATION 41-50: New Data Models for Autonomous Self-Development
// ═══════════════════════════════════════════════════════════

// MARK: - Iteration 41: Curriculum

struct CurriculumTopic: Identifiable, Codable {
    let id = UUID()
    let name: String
    let priority: Double
    let difficulty: Double
    let estimatedMinutes: Int
    let exercises: [String]
    let milestone: String
}

struct Curriculum: Identifiable, Codable {
    let id = UUID()
    let generatedAt: Date
    let validUntil: Date
    let currentCEFR: String
    let topics: [CurriculumTopic]
    let totalEstimatedMinutes: Int
    let focusAreas: [String]

    var completionPercentage: Double = 0.0
}

// MARK: - Iteration 42: Self-Evaluation

struct SelfEvaluationReport: Identifiable, Codable {
    let id = UUID()
    let evaluatedAt: Date
    let estimatedCEFR: String
    let strengths: [String]       // Top 3 strengths
    let weaknesses: [String]      // Bottom 3 weaknesses
    let improvementGoals: [String] // Specific goals for next week
    let comparisonToPrevious: String
    let overallScore: Double
}

// MARK: - Iteration 43: Learning Strategy

enum LearningStrategy: String, Codable, CaseIterable {
    case immersion           // Mass word learning — when vocabulary is weak
    case explicitInstruction // Rule learning — when grammar is weak
    case practice            // Conversation-heavy — when fluency is weak
    case balanced            // All moderate
    case advancedSynthesis   // High-level integration — all are strong

    var description: String {
        switch self {
        case .immersion: return "Massiv ordinlärning genom exponering"
        case .explicitInstruction: return "Explicit regel-inlärning och grammatikfokus"
        case .practice: return "Konversationspraktik med fokus på flyt"
        case .balanced: return "Balanserad inlärning över alla områden"
        case .advancedSynthesis: return "Avancerad syntes mellan domäner"
        }
    }
}

// MARK: - Iteration 44: Knowledge Synthesis

struct KnowledgeSynthesis: Identifiable, Codable {
    let id = UUID()
    let factA: String
    let factB: String
    let domainA: String
    let domainB: String
    let synthesizedInsight: String
    let connectionKey: Int
    let createdAt: Date
}

// MARK: - Iteration 46: Self-Generated Evaluations

struct SelfGeneratedEval: Identifiable, Codable {
    let id = UUID()
    let question: String
    let domain: String
    let difficulty: Double
    let generatedAt: Date
    let source: String
    var answered: Bool = false
    var score: Double? = nil
}

// MARK: - Iteration 50: Mastery Loop Report

struct MasteryLoopReport: Identifiable, Codable {
    var id = UUID()
    let executedAt: Date
    let selfEvaluation: SelfEvaluationReport
    let curriculum: Curriculum
    let selectedStrategy: LearningStrategy
    let knowledgeSyntheses: Int
    let selfEvalQuestionsGenerated: Int
    let errorsCorrected: Int
    let motivationalThought: String
    let currentCEFR: String
    let currentDifficultyTier: String
    let learningVelocity: Double
    let vocabularyCount: Int
    let executionTimeSeconds: Double

    var summary: String {
        """
        Mastery Loop Report
        CEFR: \(currentCEFR) | Tier: \(currentDifficultyTier)
        Strategy: \(selectedStrategy.rawValue)
        Vocabulary: \(vocabularyCount) words | Velocity: \(String(format: "%.1f", learningVelocity)) words/conversation
        Syntheses: \(knowledgeSyntheses) | Questions: \(selfEvalQuestionsGenerated)
        Executed in \(String(format: "%.1f", executionTimeSeconds))s
        Motivation: \(motivationalThought)
        """
    }
}

// MARK: - Iteration 70: Knowledge Graph Expansion from Text
