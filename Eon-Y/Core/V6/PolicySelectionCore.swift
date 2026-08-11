import Foundation

struct PolicySelectionCore: Sendable {
    func choose(candidates: [EonPolicyCandidate], body: EonBodyState, affect: EonAffectiveState) -> EonPolicyCandidate? {
        candidates.max { lhs, rhs in
            adjusted(lhs, body: body, affect: affect) < adjusted(rhs, body: body, affect: affect)
        }
    }

    private func adjusted(_ candidate: EonPolicyCandidate, body: EonBodyState, affect: EonAffectiveState) -> Double {
        candidate.score + candidate.epistemicValue * affect.curiosity - candidate.resourceCost * body.cognitiveLoad
    }
}
