import Foundation

struct JournalManifest: Codable, Sendable {
    let schemaVersion: Int
    let sessionID: String
    let startedAt: Date
    var updatedAt: Date
    var eventCount: Int
    var snapshotCount: Int
    var lastSequence: Int
    var segmentCount: Int
}

struct JournalSegmentInfo: Codable, Sendable, Identifiable {
    let id: String
    let url: URL
    let byteCount: Int
    let eventCount: Int
}

actor EventJournal {
    static let shared = EventJournal()
    private let rootDirectory: URL
    private let maxSegmentBytes: Int
    private var sessionID = "unset"
    private var sessionDirectory: URL?
    private var currentSegmentURL: URL?
    private var currentSegmentBytes = 0
    private var currentSegmentEvents = 0
    private var manifestValue: JournalManifest?

    init(rootDirectory: URL? = nil, maxSegmentBytes: Int = 256 * 1024) {
        self.rootDirectory = rootDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EonJournal", isDirectory: true)
        self.maxSegmentBytes = max(128, maxSegmentBytes)
    }

    func startSession(sessionID: String = UUID().uuidString) {
        if self.sessionID == sessionID, sessionDirectory != nil { return }
        self.sessionID = sessionID
        let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let directory = rootDirectory
            .appendingPathComponent("events", isDirectory: true)
            .appendingPathComponent(String(day), isDirectory: true)
            .appendingPathComponent(sessionID, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sessionDirectory = directory
        manifestValue = JournalManifest(schemaVersion: 1, sessionID: sessionID, startedAt: Date(), updatedAt: Date(), eventCount: 0, snapshotCount: 0, lastSequence: 0, segmentCount: 0)
        rotateSegment()
        persistManifest()
    }

    func append(_ event: EonObservableEvent) {
        guard sessionDirectory != nil else { return }
        guard let data = try? JSONEncoder.eon.encode(event) else { return }
        let line = data + Data([0x0A])
        if currentSegmentBytes + line.count > maxSegmentBytes && currentSegmentEvents > 0 { rotateSegment() }
        guard let url = currentSegmentURL else { return }
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(line)
        try? handle.close()
        currentSegmentBytes += line.count
        currentSegmentEvents += 1
        if var manifest = manifestValue {
            manifest.eventCount += 1
            manifest.lastSequence = max(manifest.lastSequence, event.sequence)
            manifest.updatedAt = Date()
            manifestValue = manifest
        }
    }

    func append(snapshot: EonCognitiveSnapshot) {
        let event = EonObservableEvent(sessionID: snapshot.sessionID, cycleID: snapshot.cycleID, sequence: snapshot.cycleID,
                                       source: "CognitiveSnapshot", kind: .measurement, severity: .info,
                                       payload: ["schemaVersion": String(snapshot.schemaVersion), "runtimeMode": snapshot.runtimeMode])
        append(event)
        if var manifest = manifestValue {
            manifest.snapshotCount += 1
            manifestValue = manifest
        }
    }

    func flush() { persistManifest() }

    func exportBatch(maxBytes: Int = 24 * 1024, afterEventID: String? = nil) -> [EonObservableEvent] {
        guard let directory = sessionDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var result: [EonObservableEvent] = []
        var bytes = 0
        var cursorPassed = afterEventID == nil
        for file in files.filter({ $0.pathExtension == "jsonl" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                guard let data = line.data(using: .utf8), let event = try? JSONDecoder.eon.decode(EonObservableEvent.self, from: data) else { continue }
                if !cursorPassed {
                    cursorPassed = event.eventID.uuidString == afterEventID
                    continue
                }
                let lineBytes = line.utf8.count + 1
                if bytes + lineBytes > maxBytes { return result }
                result.append(event)
                bytes += lineBytes
            }
        }
        return result
    }

    // The cursor is advanced only after Hermes confirms a successful HTTP response.
    func acknowledgeExported(eventID: UUID) {
        guard let directory = sessionDirectory else { return }
        let data = Data(eventID.uuidString.utf8)
        try? data.write(to: directory.appendingPathComponent("export.cursor"), options: [.atomic])
    }

    func exportedEventID() -> String? {
        guard let directory = sessionDirectory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("export.cursor")) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func manifest() -> JournalManifest {
        manifestValue ?? JournalManifest(schemaVersion: 1, sessionID: sessionID, startedAt: Date(), updatedAt: Date(), eventCount: 0, snapshotCount: 0, lastSequence: 0, segmentCount: 0)
    }

    func recentSegments() -> [JournalSegmentInfo] {
        guard let directory = sessionDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return [] }
        return files.filter { $0.pathExtension == "jsonl" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return JournalSegmentInfo(id: url.deletingPathExtension().lastPathComponent, url: url, byteCount: size, eventCount: url == currentSegmentURL ? currentSegmentEvents : 0)
        }
    }

    private func rotateSegment() {
        guard let directory = sessionDirectory else { return }
        let index = (manifestValue?.segmentCount ?? 0) + 1
        let url = directory.appendingPathComponent(String(format: "part-%06d.jsonl", index))
        currentSegmentURL = url
        currentSegmentBytes = 0
        currentSegmentEvents = 0
        manifestValue?.segmentCount = index
    }

    private func persistManifest() {
        guard let directory = sessionDirectory, let manifestValue,
              let data = try? JSONEncoder.eon.encode(manifestValue) else { return }
        try? data.write(to: directory.appendingPathComponent("manifest.json"), options: [.atomic])
    }
}

private extension JSONEncoder {
    static let eon: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let eon: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
