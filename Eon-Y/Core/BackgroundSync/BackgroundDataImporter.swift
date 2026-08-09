import Foundation

/// Imports only files produced after signature verification by the background
/// transport. It has no networking, prompt, command, or executable-content API.
actor BackgroundDataImporter {
    static let shared = BackgroundDataImporter()

    func importVerifiedKnowledge() async {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BackgroundData", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let payload = try? JSONDecoder().decode(SafeRemotePayload.self, from: data) else { continue }
            switch payload {
            case .knowledge(let records):
                for record in records {
                    let article = KnowledgeArticle(
                        title: record.title,
                        content: record.text,
                        summary: String(record.text.prefix(180)) + "…",
                        domain: record.domain,
                        source: record.source,
                        date: Date(),
                        isAutonomous: true
                    )
                    await PersistentMemoryStore.shared.saveArticle(article)
                }
            case .experiment:
                // Experiments are deliberately not imported into knowledge.
                continue
            }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
