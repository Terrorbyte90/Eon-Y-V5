import Foundation

/// Exports structured journal events only. It has no inbound command path.
actor HermesExportCoordinator {
    static let shared = HermesExportCoordinator()

    private let session: URLSession
    private let endpoint: URL?
    private let token: String?
    private var started = false
    private var lastAttemptAt: Date?

    private init() {
        let values = Bundle.main.infoDictionary ?? [:]
        endpoint = (values["EON_BACKGROUND_JOURNAL_URL"] as? String).flatMap(URL.init(string:))
        token = KeychainTokenStore.value()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func startIfConfigured() async {
        guard !started, endpoint != nil else { return }
        started = true
        await flush()
    }

    func flush() async {
        guard let endpoint else { return }
        // Normal cognition can produce many events; batch the background channel.
        if let lastAttemptAt, Date().timeIntervalSince(lastAttemptAt) < 60 { return }
        lastAttemptAt = Date()
        let cursor = await EventJournal.shared.exportedEventID()
        let events = await EventJournal.shared.exportBatch(maxBytes: 24 * 1024, afterEventID: cursor)
        guard !events.isEmpty else { return }
        let payload = HermesJournalEnvelope(version: 1, type: "journal", sessionID: events[0].sessionID, events: events)
        guard let body = try? JSONEncoder().encode(payload) else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            if let lastEventID = events.last?.eventID {
                await EventJournal.shared.acknowledgeExported(eventID: lastEventID)
            }
            await EventJournal.shared.flush()
        } catch {
            // Never append transport failures to this same queue: that creates a
            // self-feeding loop and obscures the original event stream.
        }
    }
}

private struct HermesJournalEnvelope: Codable, Sendable {
    let version: Int
    let type: String
    let sessionID: String
    let events: [EonObservableEvent]
}
