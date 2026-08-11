import Foundation
import Combine

struct EonActionTrace: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let attention: String
    let observation: String
    let interpretation: String
    let goal: String
    let action: String
    let result: String
    let selfModelRevision: String
    let source: String
}

@MainActor
final class EonInnerState: ObservableObject {
    static let shared = EonInnerState()
    @Published private(set) var latest: EonActionTrace?
    @Published private(set) var history: [EonActionTrace] = []

    func record(attention: String, observation: String, interpretation: String, goal: String, action: String, result: String, selfModelRevision: String, source: String = "ConsciousnessEngine") {
        let trace = EonActionTrace(timestamp: Date(), attention: attention, observation: observation, interpretation: interpretation, goal: goal, action: action, result: result, selfModelRevision: selfModelRevision, source: source)
        latest = trace
        history.append(trace)
        if history.count > 40 { history.removeFirst(history.count - 40) }
    }
}
