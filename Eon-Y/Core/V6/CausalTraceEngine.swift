import Foundation

struct CausalTraceEngine: Sendable {
    func edge(from: String, to: String, contribution: Double, cycle: Int) -> EonCausalEdge {
        EonCausalEdge(id: UUID(), from: from, to: to, contribution: min(1, max(-1, contribution)), cycle: cycle)
    }
}
