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
        let focus = EonTextSanitizer.focus(state.attention.isEmpty ? "ingen särskild signal" : state.attention)
        let text = "Aktuell signal: \(focus). Belastning (Int(state.body.cognitiveLoad * 100)) procent; osäkerhet (Int(state.epistemicField.uncertainty * 100)) procent. Nästa steg väljs när signalen är bättre avgränsad."
        return EonLanguageProposal(text: text, source: "V6/ReadOnlyReporter", epistemicKind: .linguistic, stateCycle: state.cycle)
    }
}
