import Foundation

struct PrecisionEngineV2: Sendable {
    func update(_ map: EonPrecisionMap, predictionError: Double, body: EonBodyState) -> EonPrecisionMap {
        let reliability = min(1, max(0, 1 - predictionError))
        let thermalPenalty = min(0.5, body.thermalPressure * 0.5)
        return EonPrecisionMap(sensory: reliability, memory: min(1, map.memory * 0.95 + reliability * 0.05), selfModel: min(1, map.selfModel * 0.95 + reliability * 0.05), social: map.social, prediction: reliability, interoceptive: min(1, 1 - body.thermalPressure))
    }
}
