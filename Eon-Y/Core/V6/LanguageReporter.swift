import Foundation

struct EonLanguageProposal: Codable, Sendable {
    let text: String
    let source: String
    let epistemicKind: EonEpistemicKind
    let stateCycle: Int
}

actor EonLanguageReporter {
    static let shared = EonLanguageReporter()

    func proposal(for state: EonCoreStateV2, requestedStyle: String = "kort och tydlig") async -> EonLanguageProposal {
        // The v6 boundary returns a deterministic report until the existing
        // Qwen adapter is explicitly given a read-only state snapshot.
        let focus = state.attention.isEmpty ? "ingen särskild signal" : state.attention
        let text = "Jag fokuserar på \(focus). Belastning \(Int(state.body.cognitiveLoad * 100)) procent och osäkerhet \(Int(state.epistemicField.uncertainty * 100)) procent."
        return EonLanguageProposal(text: text, source: "V6/ReadOnlyReporter", epistemicKind: .linguistic, stateCycle: state.cycle)
    }
}
