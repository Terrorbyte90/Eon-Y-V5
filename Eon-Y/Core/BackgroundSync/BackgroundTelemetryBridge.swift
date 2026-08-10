import CryptoKit
import Foundation
import Security

/// One-way diagnostic transport. It deliberately has no command, prompt,
/// tool-call, or shell interfaces. Remote input is accepted only as signed,
/// schema-limited data and never enters Eon's reasoning prompt.
actor BackgroundTelemetryBridge {
    static let shared = BackgroundTelemetryBridge()

    private let session: URLSession
    private let configuration: Configuration
    private var sequence: UInt64 = 0
    private var pending: [TelemetryEnvelope] = []

    struct Configuration: Sendable {
        let ingestURL: URL?
        let dataURL: URL?
        let token: String?
        let publicKeyData: Data?
        let keyID: String

        static var bundled: Configuration {
            let values = Bundle.main.infoDictionary ?? [:]
            let url = (values["EON_BACKGROUND_INGEST_URL"] as? String).flatMap(URL.init(string:))
            let dataURL = (values["EON_BACKGROUND_DATA_URL"] as? String).flatMap(URL.init(string:))
            let key: Data? = (values["EON_BACKGROUND_SIGNING_PUBLIC_KEY"] as? String).flatMap { Data(base64Encoded: $0) }
            return Configuration(ingestURL: url, dataURL: dataURL, token: KeychainTokenStore.value(), publicKeyData: key, keyID: values["EON_BACKGROUND_KEY_ID"] as? String ?? "unset")
        }
    }

    private init(configuration: Configuration = .bundled) {
        self.configuration = configuration
        // Background URLSession configurations only support uploadTask/downloadTask
        // with file-backed transfers. Calling dataTask on one throws an Objective-C
        // exception in CFNetwork (and aborts the app), as seen in the crash report.
        // These small signed JSON messages are scheduled from the live engine, so use
        // a normal session and let the actor serialize/retry delivery safely.
        let urlConfiguration = URLSessionConfiguration.default
        urlConfiguration.waitsForConnectivity = false
        urlConfiguration.httpShouldUsePipelining = true
        urlConfiguration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: urlConfiguration)
    }

    func enqueue(snapshot: UnifiedConsciousState) {
        guard configuration.ingestURL != nil else { return }
        sequence &+= 1
        let telemetry = EonTelemetrySnapshot(sequence: sequence, state: snapshot)
        pending.append(TelemetryEnvelope(telemetry: telemetry))
        if pending.count > 8 { pending.removeFirst(pending.count - 8) }
        sendNext()
        if sequence % 5 == 0 { pollSignedData() }
    }

    private func sendNext() {
        guard let url = configuration.ingestURL, let item = pending.first else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let token = configuration.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try? JSONEncoder().encode(item)
        let task = session.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }
            Task {
                guard error == nil, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
                await self.didDeliver()
            }
        }
        task.resume()
    }

    private func didDeliver() {
        guard !pending.isEmpty else { return }
        pending.removeFirst()
        if !pending.isEmpty { sendNext() }
    }

    private func pollSignedData() {
        guard let url = configuration.dataURL, let publicKeyData = configuration.publicKeyData else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let token = configuration.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self, error == nil, let data,
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let envelopes = try? JSONDecoder().decode([SignedKnowledgeEnvelope].self, from: data) else { return }
            Task {
                for envelope in envelopes where envelope.verified(using: publicKeyData, expectedKeyID: self.configuration.keyID) {
                    await self.store(envelope.payload)
                }
            }
        }
        task.resume()
    }

    private func store(_ payload: Data) {
        guard let decoded = try? JSONDecoder().decode(SafeRemotePayload.self, from: payload) else { return }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BackgroundData", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("verified-\(UUID().uuidString).json")
        guard let data = try? JSONEncoder().encode(decoded) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

enum KeychainTokenStore {
    static func value() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.eon.background-sync",
            kSecAttrAccount as String: "ingest-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct EonTelemetrySnapshot: Codable, Sendable {
    let sequence: UInt64
    let sentAt: Date
    let cycleIndex: Int
    let continuity: Double
    let predictionError: Double
    let broadcastCount: Int
    let proxyMetrics: ConsciousnessProxyMetrics
    let bodyBudget: Double
    let affectiveValence: Double
    let metacognitiveConfidence: Double

    init(sequence: UInt64, state: UnifiedConsciousState, sentAt: Date = Date()) {
        self.sequence = sequence
        self.sentAt = sentAt
        self.cycleIndex = state.cycleIndex
        self.continuity = state.continuity
        self.predictionError = state.predictionError
        self.broadcastCount = state.globalBroadcast.count
        self.proxyMetrics = state.metrics
        self.bodyBudget = state.selfModel.bodyBudget
        self.affectiveValence = state.affectiveState.valence
        self.metacognitiveConfidence = state.metacognitiveState.confidence
    }
}

private struct TelemetryEnvelope: Codable, Sendable {
    let version: Int
    let type: String
    let telemetry: EonTelemetrySnapshot

    init(telemetry: EonTelemetrySnapshot) {
        self.version = 1
        self.type = "telemetry"
        self.telemetry = telemetry
    }
}

/// Validates data-only update envelopes. There is intentionally no Codable
/// representation for commands, executable code, prompts, URLs or tool calls.
struct SignedKnowledgeEnvelope: Codable, Sendable {
    let version: Int
    let keyID: String
    let payload: Data
    let signature: Data

    func verified(using publicKeyData: Data, expectedKeyID: String) -> Bool {
        guard version == 1, keyID == expectedKeyID,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else { return false }
        return key.isValidSignature(signature, for: payload)
    }
}

enum SafeRemotePayload: Codable, Sendable {
    case knowledge([RemoteKnowledgeRecord])
    case experiment(RemoteExperimentProposal)

    private enum CodingKeys: String, CodingKey { case type, records, proposal }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "knowledge": self = .knowledge(try container.decode([RemoteKnowledgeRecord].self, forKey: .records))
        case "experiment": self = .experiment(try container.decode(RemoteExperimentProposal.self, forKey: .proposal))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "unsupported data type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .knowledge(let records):
            try container.encode("knowledge", forKey: .type); try container.encode(records, forKey: .records)
        case .experiment(let proposal):
            try container.encode("experiment", forKey: .type); try container.encode(proposal, forKey: .proposal)
        }
    }
}

struct RemoteKnowledgeRecord: Codable, Sendable { let id: String; let language: String; let domain: String; let title: String; let text: String; let source: String }

struct RemoteExperimentProposal: Codable, Sendable {
    let id: String
    let strategyVersion: String
    let parameters: [String: Double]
    let rationale: String
    let benchmarkIDs: [String]
}
