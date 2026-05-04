// Lär sig vilka loopar som orsakar värme/CPU och throttlar dem specifikt

actor AdaptivePerformanceEngine {
    static let shared = AdaptivePerformanceEngine()

    // Mäter CPU-kostnad per loop (approximation)
    private var loopCosts: [String: Double] = [:]
    private var thermalHistory: [Double] = []
    private var cpuHistory: [Double] = []

    // Throttling-faktorer per loop (1.0 = normal, 2.0 = dubbelt intervall)
    private(set) var throttleFactors: [String: Double] = [:]

    private init() {}

    func recordLoopExecution(name: String, durationMs: Double, thermalPressure: Double) {
        loopCosts[name] = (loopCosts[name] ?? durationMs) * 0.7 + durationMs * 0.3
        thermalHistory.append(thermalPressure)
        if thermalHistory.count > 60 { thermalHistory.removeFirst(10) }
    }

    func updateThrottling(thermalPressure: Double, cpuLoad: Double) {
        cpuHistory.append(cpuLoad)
        if cpuHistory.count > 30 { cpuHistory.removeFirst(5) }

        let avgThermal = thermalHistory.suffix(10).reduce(0, +) / Double(max(thermalHistory.suffix(10).count, 1))
        let avgCPU = cpuHistory.suffix(10).reduce(0, +) / Double(max(cpuHistory.suffix(10).count, 1))

        guard avgThermal > 0.6 || avgCPU > 0.7 else {
            // Minska throttling gradvis när systemet svalnar
            for key in throttleFactors.keys {
                throttleFactors[key] = max(1.0, (throttleFactors[key] ?? 1.0) * 0.95)
            }
            return
        }

        // Throttla de dyraste looparna mest
        let sortedByCost = loopCosts.sorted { $0.value > $1.value }
        let throttleCount = max(1, Int(Double(sortedByCost.count) * 0.4))
        for (name, _) in sortedByCost.prefix(throttleCount) {
            let currentFactor = throttleFactors[name] ?? 1.0
            throttleFactors[name] = min(5.0, currentFactor * 1.3)
        }
    }

    func throttleFactor(for loop: String) -> Double {
        throttleFactors[loop] ?? 1.0
    }
}

// MARK: - CyclingModeEngine
