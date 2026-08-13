import Foundation

enum EonNowCardMode: Equatable {
    case embodiment, status, timeline, level
}

struct EonNowCardModeController {
    private(set) var mode: EonNowCardMode = .embodiment
    private var normalIndex = 0
    private let normalModes: [EonNowCardMode] = [.embodiment, .status, .level]

    mutating func advance() {
        normalIndex = (normalIndex + 1) % normalModes.count
        mode = normalModes[normalIndex]
    }

    mutating func showTimeline() {
        mode = .timeline
    }

    mutating func restoreNormalMode() {
        mode = normalModes[normalIndex]
    }
}

enum EonPresentationEpistemic: String, Codable, Sendable {
    case observerat, härlett, hypotes, simulerat, genererat
}

enum EonActivityKind: String, Codable, CaseIterable, Sendable {
    case observerar = "Observerar"
    case predikterar = "Predikterar"
    case fokuserar = "Fokuserar"
    case lär = "Lär sig"
    case minne = "Minnesåtkomst"
    case språk = "Genererar språk"
    case återhämtning = "Återhämtar"
    case policy = "Väljer policy"
}

struct EonPresentationClaim: Identifiable, Codable, Sendable {
    let id = UUID()
    let text: String
    let kind: EonPresentationEpistemic
    let source: String
    let cycle: Int
}

struct EonPresentationActivity: Identifiable, Codable, Sendable {
    let id = UUID()
    let kind: EonActivityKind
    let title: String
    let consequence: String
    let source: String
    let cycle: Int
    let epistemic: EonPresentationEpistemic
}

struct EonStateDelta: Identifiable, Codable, Sendable {
    let id = UUID()
    let label: String
    let value: String
    let direction: String
}

struct EonPresentationSnapshot: Codable, Sendable {
    let cycle: Int
    let generatedAt: Date
    let summary: String
    let focus: String
    let goal: String
    let currentActivity: EonPresentationActivity
    let nextAction: String
    let nextActionReason: String
    let claims: [EonPresentationClaim]
    let activities: [EonPresentationActivity]
    let deltas: [EonStateDelta]
    let freshness: String

    static func make(state: EonCoreStateV2, verification: ConsciousnessVerificationResult, brain: EonBrain, previous: EonPresentationSnapshot? = nil) -> EonPresentationSnapshot {
        let focus = EonTextSanitizer.focus(state.attention.isEmpty ? "spontan intern aktivitet" : state.attention)
        let policy = state.activePolicy.isEmpty ? "observera" : state.activePolicy
        let hot = state.body.thermalPressure > 0.78
        let activityKind: EonActivityKind = hot ? .återhämtning : (state.globalBroadcast.isEmpty ? .observerar : .fokuserar)
        let activityTitle = hot ? "Systemet sänker tempo för att återhämta sig" : "Eon arbetar med \(focus)"
        let consequence = hot ? "Termisk belastning begränsar beräkningarna och skyddar tillgänglig kapacitet." : "Fokus och policy uppdateras från aktuella signaler och prediktioner."
        let activity = EonPresentationActivity(kind: activityKind, title: activityTitle, consequence: consequence, source: "EonCoreStateV2", cycle: state.cycle, epistemic: .härlett)
        let broadcastDescription = state.globalBroadcast.isEmpty ? "observerar inkommande signaler" : "har gjort en signal globalt tillgänglig"
        let summary = hot
            ? "Eon är aktiv men arbetar försiktigt eftersom kroppens termiska budget är pressad."
            : "Eon är aktiv och \(broadcastDescription). Fokus ligger på \(focus)."
        let next = hot ? "Observera och återhämta" : policy
        let reason = hot ? "Tillgänglig kapacitet prioriteras före djupare inferens." : "Policyn valdes från kroppstryck, prediktion och aktuellt fokus."
        var claims = [
            EonPresentationClaim(text: "Fokus: \(focus)", kind: .observerat, source: "EonCoreStateV2", cycle: state.cycle),
            EonPresentationClaim(text: "Nivå \(verification.level.rawValue) är funktionellt verifierad", kind: .härlett, source: "ConsciousnessVerification", cycle: state.cycle),
            EonPresentationClaim(text: "Självbeskrivningar är genererade språkspår, inte bevis på qualia", kind: .simulerat, source: "Epistemisk policy", cycle: state.cycle)
        ]
        if !brain.innerMonologue.isEmpty { claims.append(EonPresentationClaim(text: "Eon har skapat ett internt språkspår", kind: .genererat, source: "OpenRouter/Fallback", cycle: state.cycle)) }
        var deltas: [EonStateDelta] = []
        if let previous {
            let continuityDelta = state.temporalContinuity - previous.deltasValue("kontinuitet")
            deltas.append(EonStateDelta(label: "cykel", value: "\(state.cycle - previous.cycle)", direction: "+"))
            deltas.append(EonStateDelta(label: "termik", value: "\(Int(state.body.thermalPressure * 100))%", direction: state.body.thermalPressure > 0.78 ? "!" : "="))
            _ = continuityDelta
        } else {
            deltas.append(EonStateDelta(label: "termik", value: "\(Int(state.body.thermalPressure * 100))%", direction: "="))
            deltas.append(EonStateDelta(label: "kontinuitet", value: "\(Int(state.temporalContinuity * 100))%", direction: "="))
        }
        return EonPresentationSnapshot(cycle: state.cycle, generatedAt: Date(), summary: summary, focus: focus, goal: brain.selfAwarenessGoal, currentActivity: activity, nextAction: next, nextActionReason: reason, claims: claims, activities: [activity], deltas: deltas, freshness: "Aktuell cykel \(state.cycle)")
    }
}

private extension EonPresentationSnapshot {
    func deltasValue(_ label: String) -> Double { Double(deltas.first(where: { $0.label == label })?.value.replacingOccurrences(of: "%", with: "") ?? "0") ?? 0 }
}
