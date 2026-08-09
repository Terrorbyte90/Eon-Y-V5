import Foundation

/// User-controlled policy for the optional local GGUF model.
enum LocalModelMode: String, CaseIterable, Identifiable {
    case automatic
    case onDemand
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatiskt"
        case .onDemand: return "Vid behov"
        case .disabled: return "Avstängd"
        }
    }

    var description: String {
        switch self {
        case .automatic: return "Kan laddas när termiken tillåter det och avlastas efter inaktivitet."
        case .onDemand: return "Laddas först när en funktion faktiskt behöver lokal inferens."
        case .disabled: return "Laddas aldrig. Eon använder tillgänglig fallback och språkmoduler."
        }
    }
}
