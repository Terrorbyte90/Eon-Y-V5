import Foundation

actor KnowledgeStore {
    enum StoreError: Error { case resourceNotFound }

    private let loader: KnowledgeResourceLoader
    private var records: [KnowledgeRecord] = []
    private var loaded = false

    init(loader: KnowledgeResourceLoader = KnowledgeResourceLoader()) {
        self.loader = loader
    }

    func load(from url: URL, batchSize: Int = 64) async throws {
        guard !loaded else { return }
        for try await batch in loader.stream(from: url, batchSize: batchSize) {
            records.append(contentsOf: batch)
        }
        loaded = true
    }

    func search(query: String, language: String? = nil, limit: Int = 20) -> [KnowledgeRecord] {
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return records.lazy.filter { record in
            (language == nil || record.language == language) &&
            (needle.isEmpty || record.title.localizedCaseInsensitiveContains(needle) || record.text.localizedCaseInsensitiveContains(needle))
        }.prefix(max(0, limit)).map { $0 }
    }

    func recordCount() -> Int { records.count }
}
