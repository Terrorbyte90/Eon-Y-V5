
import SwiftUI

enum PerformanceMode: Int, CaseIterable {
    case maximal      = 0
    case balanced     = 1
    case sparse       = 2
    case rest         = 3
    case auto         = 4
    case adaptive     = 5
    case autonomyOff  = 6   // Ingen autonom drift — bara chatt
    case cycling      = 7   // Cyklar: 3 min Max → 2 min AutonomyOff → 5 min Vila

    var displayName: String {
        switch self {
        case .maximal:     return "Maximal"
        case .balanced:    return "Balanserat"
        case .sparse:      return "Sparsam"
        case .rest:        return "Vila"
        case .auto:        return "Auto"
        case .adaptive:    return "Adaptivt"
        case .autonomyOff: return "Autonom av"
        case .cycling:     return "Cyklande"
        }
    }

    var description: String {
        switch self {
        case .maximal:     return "Alla 18 loopar + 12 pelare aktiva"
        case .balanced:    return "Pelare 1–7 + Loop 1–2 aktiva"
        case .sparse:      return "Pelare 1–3, ingen Loop 3"
        case .rest:        return "Enbart Foundation Model"
        case .auto:        return "Maximerar prestanda, minimerar CPU/värme automatiskt"
        case .adaptive:    return "Lär sig vad som orsakar värme och sparar på det specifikt"
        case .autonomyOff: return "Inga autonoma loopar — full intelligens i chatt"
        case .cycling:     return "3 min Max → 2 min Av → 5 min Vila, upprepas"
        }
    }

    var batteryPerHour: String {
        switch self {
        case .maximal:     return "~8%/h"
        case .balanced:    return "~4%/h"
        case .sparse:      return "~2%/h"
        case .rest:        return "~1%/h"
        case .auto:        return "~3–5%/h"
        case .adaptive:    return "~2–4%/h"
        case .autonomyOff: return "~0.5%/h"
        case .cycling:     return "~3%/h"
        }
    }

    var responseTime: String {
        switch self {
        case .maximal:     return "~3s"
        case .balanced:    return "~1.5s"
        case .sparse:      return "~0.8s"
        case .rest:        return "~0.4s"
        case .auto:        return "~1–2s"
        case .adaptive:    return "~1–2s"
        case .autonomyOff: return "~0.3s"
        case .cycling:     return "~1–3s"
        }
    }

    var color: Color {
        switch self {
        case .maximal:     return Color(hex: "#EF4444")
        case .balanced:    return Color(hex: "#7C3AED")
        case .sparse:      return Color(hex: "#34D399")
        case .rest:        return Color(hex: "#3B82F6")
        case .auto:        return Color(hex: "#F59E0B")
        case .adaptive:    return Color(hex: "#A78BFA")
        case .autonomyOff: return Color(hex: "#6B7280")
        case .cycling:     return Color(hex: "#EC4899")
        }
    }

    // Skalningsfaktor för loop-intervall (högre = längre väntan = lägre CPU)
    var loopScaleFactor: Double {
        switch self {
        case .maximal:     return 1.0
        case .balanced:    return 1.5
        case .sparse:      return 3.0
        case .rest:        return 10.0
        case .auto:        return 1.0   // Dynamiskt
        case .adaptive:    return 1.0   // Dynamiskt
        case .autonomyOff: return 999.0 // Effektivt pausar alla loopar
        case .cycling:     return 1.0   // Hanteras av CyclingModeEngine
        }
    }

    // Sant om autonoma bakgrundsloopar ska pausas
    var autonomyPaused: Bool {
        self == .autonomyOff
    }
}

// MARK: - AdaptivePerformanceEngine
