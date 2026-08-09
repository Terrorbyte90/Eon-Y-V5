import Foundation

struct ModelLocator {
    let fileName: String

    nonisolated func locate() -> URL? {
        let bundleName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        if let url = Bundle.main.url(forResource: bundleName, withExtension: "gguf") { return url }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let candidates = [
            appSupport.appendingPathComponent("Eon/Models/\(fileName).gguf"),
            appSupport.appendingPathComponent("Eon-Y/Models/\(fileName).gguf"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Models/\(fileName).gguf")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    nonisolated var installationHint: String {
        "Lägg \(fileName).gguf i ~/Library/Application Support/Eon/Models/ på Mac, eller inkludera den i appens modellbundle."
    }
}
