import Foundation

// MARK: - Typed Snapshot

struct LanguageSnapshot: Sendable, Codable {
    let date: String
    let vocabSize: Int
    let morphMastery: Double
    let syntaxMastery: Double
    let semMastery: Double
    let pragMastery: Double
    let overall: Double
    let unknownRatio: Double
    let avgComplexity: Double
}

// MARK: - Growth Report

struct LanguageGrowth: Sendable {
    let vocabGrowth: Int               // absolute growth over window
    let vocabGrowthPct: Double         // percentage growth (if previous > 0)
    let morphGrowth: Double
    let syntaxGrowth: Double
    let semGrowth: Double
    let pragGrowth: Double
    let overallGrowth: Double
    let dailyVocabLearned: Double      // vocabGrowth per day
}

// MARK: - Trend Direction

enum LanguageTrendDirection: String, Sendable {
    case accelerating  // growth rate is increasing
    case steady        // growth rate is consistent
    case decelerating  // growth rate is slowing
    case plateau       // no significant growth
}

struct TrendReport: Sendable {
    let direction: LanguageTrendDirection
    let growthRate: Double          // smoothed growth rate per day
    let daysOfData: Int
    let isPlateaued: Bool
    let plateauDurationDays: Int
    let recommendedFocus: String    // which dimension needs most attention
    let eqScore: Double?            // overall EQ from latest conversation
    let growthStreak: Int           // consecutive days with positive growth
}

// MARK: - Actor

actor LanguageProgressTracker {
    static let shared = LanguageProgressTracker()

    // MARK: - Configuration
    private let emaAlpha: Double = 0.3        // EMA smoothing factor (lower = smoother)
    private let plateauThreshold: Double = 0.02  // max daily change before considered plateau
    private let plateauMinDays: Int = 5          // minimum days before declaring plateau
    private let growthWindow: Int = 7            // days for growth rate calculation

    // MARK: - Smoothed State
    private var smoothedMorphMastery: Double = 0
    private var smoothedSyntaxMastery: Double = 0
    private var smoothedSemMastery: Double = 0
    private var smoothedPragMastery: Double = 0
    private var smoothedOverall: Double = 0
    private var smoothedUnknownRatio: Double = 0
    private var smoothedAvgComplexity: Double = 0
    private var hasInitialSmooth: Bool = false

    // MARK: - Snapshot History (in-memory cache)
    private var snapshotCache: [LanguageSnapshot] = []
    private var lastCacheRefresh: Date = .distantPast

    // MARK: - Public API

    /// Take a daily snapshot with real data from the brain and memory store
    func takeDailySnapshot() async {
        let brain = await MainActor.run { EonBrain.shared }
        let db = PersistentMemoryStore.shared

        let vocabSize = await db.getLearnedVocabularySize()

        // Get actual mastery values from brain state
        let morphM = await MainActor.run { brain.morphologyMastery }
        let syntaxM = await MainActor.run { brain.syntaxMastery }
        let semM = await MainActor.run { brain.semanticMastery }
        let pragM = await MainActor.run { brain.pragmaticMastery }
        let overall = await MainActor.run { brain.overallLanguageLevel }

        // Calculate actual unknown ratio from vocabulary data
        let totalWords = await db.getTotalWordCount()
        let unknownRatio: Double = totalWords > 0
            ? 1.0 - (Double(vocabSize) / Double(totalWords))
            : 0.15  // fallback

        // Calculate actual average complexity from recent conversations
        let avgComplexity = await calculateAvgComplexity(from: db)

        let dateStr = String(Date().description.prefix(10))

        // Insert typed snapshot into DB
        await db.insertLanguageSnapshot(
            date: dateStr,
            vocabSize: vocabSize,
            morphMastery: morphM,
            syntaxMastery: syntaxM,
            semMastery: semM,
            pragMastery: pragM,
            overall: overall,
            unknownRatio: unknownRatio,
            avgComplexity: avgComplexity
        )

        // Update smoothed values
        updateSmoothedValues(
            morph: morphM, syntax: syntaxM, sem: semM,
            prag: pragM, overall: overall,
            unknownRatio: unknownRatio, avgComplexity: avgComplexity
        )

        // Invalidate cache so next growth calculation re-fetches
        lastCacheRefresh = .distantPast
    }

    /// Calculate growth rates using typed snapshots with EMA smoothing
    func calculateGrowthRate() async -> LanguageGrowth {
        let snapshots = await getTypedSnapshots(count: growthWindow)
        guard snapshots.count >= 2 else {
            return LanguageGrowth(
                vocabGrowth: 0, vocabGrowthPct: 0, morphGrowth: 0, syntaxGrowth: 0,
                semGrowth: 0, pragGrowth: 0, overallGrowth: 0, dailyVocabLearned: 0
            )
        }
    
        let latest = snapshots[0]
        let previous = snapshots[1]
        let days = Double(max(1, snapshots.count - 1))
        let vocabGrowth = latest.vocabSize - previous.vocabSize
        let vocabGrowthPct = previous.vocabSize > 0 ? Double(vocabGrowth) / Double(previous.vocabSize) : 0
        let dailyVocab = Double(vocabGrowth) / days
    
        return LanguageGrowth(
            vocabGrowth: vocabGrowth,
            vocabGrowthPct: vocabGrowthPct,
            morphGrowth: applySmoothing(raw: latest.morphMastery - previous.morphMastery),
            syntaxGrowth: applySmoothing(raw: latest.syntaxMastery - previous.syntaxMastery),
            semGrowth: applySmoothing(raw: latest.semMastery - previous.semMastery),
            pragGrowth: applySmoothing(raw: latest.pragMastery - previous.pragMastery),
            overallGrowth: applySmoothing(raw: latest.overall - previous.overall),
            dailyVocabLearned: dailyVocab
        )
    }

    /// Generate a comprehensive trend report with plateau detection
    func analyzeTrends() async -> TrendReport {
        let snapshots = await getTypedSnapshots(count: max(growthWindow, plateauMinDays + 1))
        guard snapshots.count >= 3 else {
            return TrendReport(
                direction: LanguageTrendDirection.steady, growthRate: 0, daysOfData: snapshots.count,
                isPlateaued: false, plateauDurationDays: 0,
                recommendedFocus: "samla in mer data",
                eqScore: nil, growthStreak: 0
            )
        }
    
        // Calculate growth rates over the window
        let recentGrowth = calculateDimensionGrowth(snapshots: snapshots)
    
        // Determine overall direction
        let direction = classifyDirection(growth: recentGrowth.overallGrowth)
    
        // Detect plateaus per dimension
        let plateauDays = detectPlateauDuration(snapshots: snapshots)
    
        // Find which dimension needs most focus
        let focus = recommendFocus(growth: recentGrowth)
    
        // Compute growth streak (consecutive days with positive overall growth)
        var streak = 0
        for i in 1..<snapshots.count {
            if snapshots[i].overall > snapshots[i-1].overall {
                streak += 1
            } else { break }
        }
    
        // EQ score from latest conversation (if available)
        let db = PersistentMemoryStore.shared
        let recentConv = await db.getRecentConversation(limit: 1)
        var eqScore: Double? = nil
        if let conv = recentConv.first {
            let analysis = await SwedishLanguageCore.shared.detectEmotionalIntelligence(text: conv.content)
            eqScore = analysis.overallEQ
        }
    
        return TrendReport(
            direction: direction,
            growthRate: recentGrowth.overallGrowth,
            daysOfData: snapshots.count,
            isPlateaued: plateauDays >= plateauMinDays,
            plateauDurationDays: plateauDays,
            recommendedFocus: focus,
            eqScore: eqScore,
            growthStreak: streak
        )
    }

    /// Get smoothed mastery values for display
    func getSmoothedMastery() async -> (morph: Double, syntax: Double, sem: Double, prag: Double, overall: Double) {
        if !hasInitialSmooth {
            let brain = await MainActor.run { EonBrain.shared }
            let morph = await MainActor.run { brain.morphologyMastery }
            let syntax = await MainActor.run { brain.syntaxMastery }
            let sem = await MainActor.run { brain.semanticMastery }
            let prag = await MainActor.run { brain.pragmaticMastery }
            let overall = await MainActor.run { brain.overallLanguageLevel }
            return (morph, syntax, sem, prag, overall)
        }
        return (smoothedMorphMastery, smoothedSyntaxMastery, smoothedSemMastery, smoothedPragMastery, smoothedOverall)
    }

    // MARK: - Private Helpers

    /// Fetch typed snapshots from DB, caching them for efficiency
    private func getTypedSnapshots(count: Int) async -> [LanguageSnapshot] {
        // Refresh cache if stale
        if Date().timeIntervalSince(lastCacheRefresh) > 60 {
            let db = PersistentMemoryStore.shared
            let raw = await db.getLatestLanguageSnapshots(count: count)
            snapshotCache = raw.compactMap { row in
                guard row.count >= 9 else { return nil }
                return LanguageSnapshot(
                    date: "",
                    vocabSize: (row[0] as? Int) ?? 0,
                    morphMastery: (row[1] as? Double) ?? 0,
                    syntaxMastery: (row[2] as? Double) ?? 0,
                    semMastery: (row[3] as? Double) ?? 0,
                    pragMastery: (row[4] as? Double) ?? 0,
                    overall: (row[5] as? Double) ?? 0,
                    unknownRatio: (row[6] as? Double) ?? 0,
                    avgComplexity: (row[7] as? Double) ?? 0
                )
            }
            lastCacheRefresh = Date()
        }
        return Array(snapshotCache.prefix(count))
    }

    /// Update EMA-smoothed values
    private func updateSmoothedValues(
        morph: Double, syntax: Double, sem: Double,
        prag: Double, overall: Double,
        unknownRatio: Double, avgComplexity: Double
    ) {
        if !hasInitialSmooth {
            smoothedMorphMastery = morph
            smoothedSyntaxMastery = syntax
            smoothedSemMastery = sem
            smoothedPragMastery = prag
            smoothedOverall = overall
            smoothedUnknownRatio = unknownRatio
            smoothedAvgComplexity = avgComplexity
            hasInitialSmooth = true
        } else {
            smoothedMorphMastery = ema(current: smoothedMorphMastery, raw: morph)
            smoothedSyntaxMastery = ema(current: smoothedSyntaxMastery, raw: syntax)
            smoothedSemMastery = ema(current: smoothedSemMastery, raw: sem)
            smoothedPragMastery = ema(current: smoothedPragMastery, raw: prag)
            smoothedOverall = ema(current: smoothedOverall, raw: overall)
            smoothedUnknownRatio = ema(current: smoothedUnknownRatio, raw: unknownRatio)
            smoothedAvgComplexity = ema(current: smoothedAvgComplexity, raw: avgComplexity)
        }
    }

    /// EMA: new = alpha * raw + (1 - alpha) * current
    private func ema(current: Double, raw: Double) -> Double {
        emaAlpha * raw + (1 - emaAlpha) * current
    }

    /// Apply smoothing to a raw growth delta
    private func applySmoothing(raw: Double) -> Double {
        raw  // raw deltas are already small; smoothing happens at the snapshot level
    }

    /// Calculate average growth per dimension over the snapshot window
    private func calculateDimensionGrowth(snapshots: [LanguageSnapshot]) -> LanguageGrowth {
        guard snapshots.count >= 2 else {
            return LanguageGrowth(vocabGrowth: 0, vocabGrowthPct: 0, morphGrowth: 0, syntaxGrowth: 0, semGrowth: 0, pragGrowth: 0, overallGrowth: 0, dailyVocabLearned: 0)
        }
    
        let first = snapshots.last!
        let last = snapshots.first!
        let days = max(1, snapshots.count - 1)
        let vocabGrowth = last.vocabSize - first.vocabSize
        let vocabGrowthPct = first.vocabSize > 0 ? Double(vocabGrowth) / Double(first.vocabSize) : 0
        let dailyVocab = Double(vocabGrowth) / Double(days)
    
        return LanguageGrowth(
            vocabGrowth: vocabGrowth,
            vocabGrowthPct: vocabGrowthPct,
            morphGrowth: (last.morphMastery - first.morphMastery) / Double(days),
            syntaxGrowth: (last.syntaxMastery - first.syntaxMastery) / Double(days),
            semGrowth: (last.semMastery - first.semMastery) / Double(days),
            pragGrowth: (last.pragMastery - first.pragMastery) / Double(days),
            overallGrowth: (last.overall - first.overall) / Double(days),
            dailyVocabLearned: dailyVocab
        )
    }

    /// Classify the trend direction based on growth rate
    private func classifyDirection(growth: Double) -> LanguageTrendDirection {
        let absGrowth = abs(growth)
        if absGrowth < plateauThreshold {
            return .plateau
        } else if growth > 0.05 {
            return .accelerating
        } else if growth > 0.01 {
            return .steady
        } else if growth > -0.01 {
            return .plateau
        } else {
            return .decelerating
        }
    }

    /// Detect how many days the overall level has been in a plateau
    private func detectPlateauDuration(snapshots: [LanguageSnapshot]) -> Int {
        guard snapshots.count >= 3 else { return 0 }
        var plateauDays = 0
        for i in 1..<snapshots.count {
            let change = abs(snapshots[i-1].overall - snapshots[i].overall)
            if change < plateauThreshold {
                plateauDays += 1
            } else {
                plateauDays = 0  // reset if we see growth
            }
        }
        return plateauDays
    }

    /// Recommend which language dimension needs most focus
    private func recommendFocus(growth: LanguageGrowth) -> String {
        let dimensions: [(name: String, rate: Double)] = [
            ("morfologi", growth.morphGrowth),
            ("syntax", growth.syntaxGrowth),
            ("semantik", growth.semGrowth),
            ("pragmatik", growth.pragGrowth)
        ]
        guard let min = dimensions.min(by: { $0.rate < $1.rate }) else {
            return "alla dimensioner"
        }
        if min.rate < plateauThreshold {
            return "\(min.name) (tillväxt: \(String(format: "%.3f", min.rate))/dag)"
        }
        return "balanserad utveckling"
    }

    /// Calculate average sentence complexity from recent conversations
    private func calculateAvgComplexity(from db: PersistentMemoryStore) async -> Double {
        // Use the last 20 learned words' confidence as a proxy for complexity
        let recentWords = await db.getRecentlyLearnedWords(limit: 20)
        guard !recentWords.isEmpty else { return 0.3 }
        let avgConfidence = recentWords.map(\.confidence).reduce(0, +) / Double(recentWords.count)
        // Map confidence 0.0-1.0 to complexity 0.1-0.9
        return 0.1 + avgConfidence * 0.8
    }
    
    // MARK: - User Report & Export
    
    /// Human‑readable progress report (Swedish)
    func generateUserReport() async -> String {
        let report = await analyzeTrends()
        var lines: [String] = []
        lines.append("🗓️ Trend: \(report.direction.rawValue)")
        lines.append("📈 Tillväxt per dag: \(String(format: "%.3f", report.growthRate))")
        if report.growthStreak > 0 {
            lines.append("💪 Positiv tillväxt‑streak: \(report.growthStreak) dagar")
        }
        if let eq = report.eqScore {
            lines.append("❤️ EQ‑poäng: \(String(format: "%.2f", eq))")
        }
        lines.append("🔧 Fokus: \(report.recommendedFocus)")
        // Simple motivational tip pool
        let tips = ["Fortsätt så här!", "Bra jobbat!", "Fokusera på svagheter!", "Var nyfiken varje dag!"]
        lines.append("💡 Tips: \(tips.randomElement() ?? "Lycka till!")")
        return lines.joined(separator: "\n")
    }
    
    /// Time‑series data for UI charts
    struct LanguageMetricsSeries: Sendable {
        let date: String
        let smoothedOverall: Double
        let vocabSize: Int
        let eqScore: Double?
    }
    
    func exportMetricsSeries() async -> [LanguageMetricsSeries] {
        let snapshots = await getTypedSnapshots(count: 30) // last 30 days
        var series: [LanguageMetricsSeries] = []
        for snap in snapshots {
            // Placeholder for EQ – could be populated via additional DB query
            let eq: Double? = nil
            series.append(LanguageMetricsSeries(date: snap.date, smoothedOverall: snap.overall, vocabSize: snap.vocabSize, eqScore: eq))
        }
        return series
    }
}
