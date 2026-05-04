import Foundation

// Hanterar det cyklande prestandaläget: 3 min Max → 2 min AutonomyOff → 5 min Vila

final class CyclingModeEngine {
    static let shared = CyclingModeEngine()

    // Cykelschema: (läge, varaktighet i sekunder)
    private let schedule: [(PerformanceMode, TimeInterval)] = [
        (.maximal,     3 * 60),   // 3 min max
        (.autonomyOff, 2 * 60),   // 2 min autonom av
        (.rest,        5 * 60),   // 5 min vila
    ]

    private var cycleStartTime: Date = Date()
    private var totalCycleDuration: TimeInterval

    init() {
        totalCycleDuration = schedule.reduce(0) { $0 + $1.1 }
    }

    // Returnerar det aktiva läget baserat på cykelposition
    func effectiveMode(base: PerformanceMode) -> PerformanceMode {
        guard base == .cycling else { return base }
        let elapsed = Date().timeIntervalSince(cycleStartTime).truncatingRemainder(dividingBy: totalCycleDuration)
        var accumulated: TimeInterval = 0
        for (mode, duration) in schedule {
            accumulated += duration
            if elapsed < accumulated { return mode }
        }
        // v24: Guard against empty schedule array
        return schedule.first?.0 ?? .autonomyOff
    }

    // Aktuell fas-beskrivning för UI
    func cycleStatusLabel(base: PerformanceMode) -> String {
        guard base == .cycling else { return "" }
        let elapsed = Date().timeIntervalSince(cycleStartTime).truncatingRemainder(dividingBy: totalCycleDuration)
        var accumulated: TimeInterval = 0
        for (mode, duration) in schedule {
            let phaseStart = accumulated
            accumulated += duration
            if elapsed < accumulated {
                let remaining = Int(accumulated - elapsed)
                let m = remaining / 60, s = remaining % 60
                return "\(mode.displayName) · \(m > 0 ? "\(m)m " : "")\(s)s kvar"
            }
        }
        return ""
    }

    // Starta om cykeln (vid lägesbyte)
    func reset() { cycleStartTime = Date() }
}

// MARK: - Extensions
