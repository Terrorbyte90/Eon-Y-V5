import XCTest
@testable import Eon_Y

final class QwenAutonomyTests: XCTestCase {
    func testQueueIsBoundedAndProposalIsNonMutating() async {
        let queue = QwenAutonomyQueue()
        await queue.enqueue(.make(kind: .measurementReview, reason: "test"))
        let task = await queue.next()
        XCTAssertEqual(task?.kind, .measurementReview)

        let proposal = QwenProposal(id: UUID(), taskID: task!.id, createdAt: Date(),
                                    summary: "review", evidence: ["proxy"],
                                    requiresHumanApproval: true,
                                    canMutateProduction: false,
                                    canContactHermes: false)
        await queue.recordProposal(proposal)
        let recent = await queue.recentProposals()
        XCTAssertEqual(recent.count, 1)
        XCTAssertFalse(recent[0].canMutateProduction)
        XCTAssertFalse(recent[0].canContactHermes)
    }
}
