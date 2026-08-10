import XCTest
@testable import Eon_Y

final class EventJournalTests: XCTestCase {
    func testJournalPreservesSequenceAndManifest() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("eon-journal-test-\(UUID().uuidString)", isDirectory: true)
        let journal = EventJournal(rootDirectory: directory, maxSegmentBytes: 1_000_000)
        await journal.startSession(sessionID: "test-session")

        await journal.append(EonObservableEvent(sessionID: "test-session", cycleID: 1, sequence: 1,
                                                source: "test", kind: .lifecycle, severity: .info,
                                                payload: ["state": "started"]))
        await journal.append(EonObservableEvent(sessionID: "test-session", cycleID: 1, sequence: 2,
                                                source: "test", kind: .measurement, severity: .info,
                                                payload: ["value": "0.5"]))
        await journal.flush()

        let manifest = await journal.manifest()
        XCTAssertEqual(manifest.sessionID, "test-session")
        XCTAssertEqual(manifest.eventCount, 2)
        XCTAssertEqual(manifest.lastSequence, 2)
        let segments = await journal.recentSegments()
        XCTAssertEqual(segments.count, 1)
    }

    func testJournalRotatesWhenSegmentReachesByteLimit() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("eon-journal-rotation-\(UUID().uuidString)", isDirectory: true)
        let journal = EventJournal(rootDirectory: directory, maxSegmentBytes: 220)
        await journal.startSession(sessionID: "rotation")

        for sequence in 1...4 {
            await journal.append(EonObservableEvent(sessionID: "rotation", cycleID: sequence,
                                                    sequence: sequence, source: "test", kind: .motor,
                                                    severity: .debug,
                                                    payload: ["data": String(repeating: "x", count: 80)]))
        }
        await journal.flush()

        let segments = await journal.recentSegments()
        XCTAssertGreaterThan(segments.count, 1)
    }
}
