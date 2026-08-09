import Foundation

struct KnowledgeResourceLoader: Sendable {
    enum LoaderError: Error { case invalidUTF8, invalidRecord }

    func stream(from url: URL, batchSize: Int = 64) -> AsyncThrowingStream<[KnowledgeRecord], Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    var buffer = Data()
                    var batch: [KnowledgeRecord] = []
                    while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                        buffer.append(chunk)
                        while let newline = buffer.firstIndex(of: 10) {
                            let line = buffer[..<newline]
                            buffer.removeSubrange(...newline)
                            if line.isEmpty { continue }
                            guard let text = String(data: line, encoding: .utf8) else { throw LoaderError.invalidUTF8 }
                            guard let data = text.data(using: .utf8), let record = try? JSONDecoder().decode(KnowledgeRecord.self, from: data) else {
                                throw LoaderError.invalidRecord
                            }
                            batch.append(record)
                            if batch.count >= batchSize {
                                continuation.yield(batch)
                                batch.removeAll(keepingCapacity: true)
                            }
                        }
                    }
                    if !buffer.isEmpty {
                        guard let record = try? JSONDecoder().decode(KnowledgeRecord.self, from: buffer) else { throw LoaderError.invalidRecord }
                        batch.append(record)
                    }
                    if !batch.isEmpty { continuation.yield(batch) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
