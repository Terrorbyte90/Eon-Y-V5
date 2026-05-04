import Foundation

actor MorphologyLearner {
    static let shared = MorphologyLearner()

    // MARK: - Configuration
    private let maxConcurrentTasks = 4
    private let minConfidenceThreshold = 0.5

    // MARK: - Pattern Extraction State
    private var observedSuffixes: [String: Int] = [:]  // suffix → count
    private var observedPrefixes: [String: Int] = [:]  // prefix → count
    private var commonPatterns: [String: (pos: String, confidence: Double)] = [:]

    // MARK: - Public API

    /// Learn morphology for a single word with context
    func learnMorphology(word: String, context: String) async -> LearnedMorphology? {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return nil }

        let prompt = """
        Du är en svensk grammatikexpert. Analysera ordet "\(word)" i kontexten: "\(context)"
        Svara EXAKT i JSON: {"baseForm":"","pos":"","forms":{"plural":"","bestämd":"","preteritum":"","supinum":"","komparativ":"","superlativ":""}}
        """
        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt,
            maxTokens: 200,
            temperature: 0.2
        )
        return parseResponse(response, originalWord: word)
    }

    /// Batch-learn unknown words concurrently with confidence-weighted prioritization
    func batchLearnUnknownWords() async {
        guard !ThermalSleepManager.shared.shouldPauseWork() else { return }

        let words = await PersistentMemoryStore.shared.getRecentlyLearnedWords(limit: 50)
            .filter { $0.confidence < minConfidenceThreshold }
            .sorted { $0.confidence < $1.confidence }  // lowest confidence first

        guard !words.isEmpty else { return }

        // Adaptive batch size based on thermal state
        let batchSize: Int = {
            if ThermalSleepManager.shared.shouldPauseWork() { return 0 }
            let thermal = ProcessInfo.processInfo.thermalState
            switch thermal {
            case .nominal: return min(maxConcurrentTasks, words.count)
            case .fair: return min(3, words.count)
            case .serious: return min(2, words.count)
            case .critical: return 1
            @unknown default: return min(2, words.count)
            }
        }()

        guard batchSize > 0 else { return }

        let batch = Array(words.prefix(batchSize * 3))  // process in waves of batchSize
        var learnedCount = 0
        var errorCount = 0

        // Process in waves using TaskGroup for concurrency
        for waveStart in stride(from: 0, to: batch.count, by: batchSize) {
            guard !ThermalSleepManager.shared.shouldPauseWork() else { break }

            let wave = Array(batch[waveStart..<min(waveStart + batchSize, batch.count)])

            await withTaskGroup(of: (String, LearnedMorphology?).self) { group in
                for (word, _) in wave {
                    group.addTask {
                        // Retrieve context from memory store for better analysis
                        let context = await PersistentMemoryStore.shared.getContextForWord(word) ?? ""
                        let learned = await self.learnMorphology(word: word, context: context)
                        return (word, learned)
                    }
                }

                for await (word, learned) in group {
                    guard let learned = learned else {
                        errorCount += 1
                        continue
                    }

                    // Register base form
                    await SwedishLanguageCore.shared.morphologyEngine.addDynamicEntry(
                        word: learned.baseForm,
                        pos: learned.pos
                    )

                    // Register inflections
                    for (formKey, formValue) in learned.forms where !formValue.isEmpty {
                        await SwedishLanguageCore.shared.morphologyEngine.addInflection(
                            baseForm: learned.baseForm,
                            formKey: formKey,
                            formValue: formValue
                        )
                    }

                    // Extract morphological patterns from the learned data
                    await extractPatterns(from: learned)

                    // Reinforce the learned word with a higher boost
                    await PersistentMemoryStore.shared.reinforceLearnedWord(learned.baseForm)
                    learnedCount += 1
                }
            }

            // Brief pause between waves to allow thermal recovery
            if waveStart + batchSize < batch.count {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s between waves
            }
        }

        // Log learning session summary
        if learnedCount > 0 || errorCount > 0 {
            let summary = """
            MorphologyLearner: Learned \(learnedCount)/\(batch.count) words \
            (\(errorCount) errors, \(observedSuffixes.count) suffix patterns, \
            \(observedPrefixes.count) prefix patterns)
            """
            print(summary)
        }
    }

    /// Get observed morphological patterns for use by other components
    func getCommonSuffixes() -> [(suffix: String, count: Int)] {
        observedSuffixes.sorted { $0.value > $1.value }.prefix(10).map { (suffix: $0.key, count: $0.value) }
    }

    func getCommonPrefixes() -> [(prefix: String, count: Int)] {
        observedPrefixes.sorted { $0.value > $1.value }.prefix(10).map { (prefix: $0.key, count: $0.value) }
    }

    func getCommonPatterns() -> [String: (pos: String, confidence: Double)] {
        commonPatterns
    }

    // MARK: - Private Helpers

    private func parseResponse(_ response: String, originalWord: String) -> LearnedMorphology? {
        guard let s = response.firstIndex(of: "{"),
              let e = response.lastIndex(of: "}"),
              let data = String(response[s...e]).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return LearnedMorphology(
            baseForm: json["baseForm"] as? String ?? originalWord,
            pos: json["pos"] as? String ?? "unknown",
            forms: json["forms"] as? [String: String] ?? [:]
        )
    }

    /// Extract common Swedish morphological patterns from learned data
    private func extractPatterns(from morphology: LearnedMorphology) async {
        let baseForm = morphology.baseForm.lowercased()

        // Extract common suffixes (last 2-4 characters)
        for length in [2, 3, 4] {
            guard baseForm.count > length else { continue }
            let suffix = String(baseForm.suffix(length))
            observedSuffixes[suffix, default: 0] += 1
        }

        // Extract common prefixes (first 2-4 characters)
        for length in [2, 3, 4] {
            guard baseForm.count > length else { continue }
            let prefix = String(baseForm.prefix(length))
            observedPrefixes[prefix, default: 0] += 1
        }

        // Build pattern → POS mapping with confidence
        for (formKey, formValue) in morphology.forms where !formValue.isEmpty {
            let pattern = "\(morphology.pos):\(formKey):\(formValue)"
            let existing = commonPatterns[pattern]?.confidence ?? 0
            commonPatterns[pattern] = (
                pos: morphology.pos,
                confidence: min(1.0, existing + 0.1)
            )
        }
    }
}

struct LearnedMorphology: Sendable {
    let baseForm: String
    let pos: String
    let forms: [String: String]
}
