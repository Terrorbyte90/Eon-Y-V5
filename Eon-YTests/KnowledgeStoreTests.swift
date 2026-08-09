import Foundation
import Testing
@testable import Eon_Y

struct KnowledgeStoreTests {
    @Test func loaderStreamsRecordsInBoundedBatches() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("knowledge-\(UUID().uuidString).jsonl")
        let lines = [
            KnowledgeRecord(id: "1", language: "sv", domain: "mind", title: "Medvetande", text: "Kognition", source: nil),
            KnowledgeRecord(id: "2", language: "en", domain: "mind", title: "Consciousness", text: "Awareness", source: nil)
        ].compactMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }.joined(separator: "\n")
        try lines.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let store = KnowledgeStore()
        try await store.load(from: url, batchSize: 1)
        #expect(await store.recordCount() == 2)
        #expect(await store.search(query: "medvetande", language: "sv", limit: 5).count == 1)
    }
}
