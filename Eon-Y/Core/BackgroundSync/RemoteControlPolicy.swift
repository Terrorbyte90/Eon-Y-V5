import Foundation
import Combine

/// The only parameter surface Hermes may change. Values are bounded and data-only.
enum RemoteControlPolicy {
    static let allowedParameterKeys: Set<String> = [
        "attention.decay",
        "inference.temperature",
        "learning.intensity"
    ]

    static func sanitize(parameters: [String: Double]) -> (accepted: [String: Double], rejected: [String]) {
        var accepted: [String: Double] = [:]
        var rejected: [String] = []
        for (key, value) in parameters {
            guard allowedParameterKeys.contains(key), value.isFinite else { rejected.append(key); continue }
            accepted[key] = min(1, max(0, value))
        }
        return (accepted, rejected.sorted())
    }
}

enum RemoteControlDirective: Codable, Sendable {
    case emergencyStop
    case resume
    case parameters([String: Double])

    var isAllowed: Bool { true }

    private enum Keys: String, CodingKey { case type, parameters }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "emergency_stop": self = .emergencyStop
        case "resume": self = .resume
        case "parameters": self = .parameters(try c.decode([String: Double].self, forKey: .parameters))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unsupported directive")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .emergencyStop: try c.encode("emergency_stop", forKey: .type)
        case .resume: try c.encode("resume", forKey: .type)
        case .parameters(let values): try c.encode("parameters", forKey: .type); try c.encode(values, forKey: .parameters)
        }
    }
}

@MainActor
final class RemoteControlCenter: ObservableObject {
    static let shared = RemoteControlCenter()
    @Published private(set) var emergencyStopped = false
    @Published private(set) var parameters: [String: Double] = [:]

    func apply(_ directive: RemoteControlDirective) {
        switch directive {
        case .emergencyStop:
            emergencyStopped = true
            ConsciousnessEngine.shared.stop()
            EonBrain.shared.stopCognitiveSystems()
        case .resume:
            guard emergencyStopped else { return }
            emergencyStopped = false
            EonBrain.shared.startCognitiveSystems()
            ConsciousnessEngine.shared.start(brain: EonBrain.shared)
        case .parameters(let values):
            let result = RemoteControlPolicy.sanitize(parameters: values)
            parameters.merge(result.accepted) { _, new in new }
        }
    }
}
