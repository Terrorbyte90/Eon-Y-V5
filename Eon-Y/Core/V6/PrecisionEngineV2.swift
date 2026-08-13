import Foundation

struct PrecisionEngineV2: Sendable {
    func update(_ map: EonPrecisionMap, predictionError: Double, body: EonBodyState) -> EonPrecisionMap {
        let reliability = min(1, max(0, 1 - predictionError))
        let thermalPenalty = min(0.5, body.thermalPressure * 0.5)
        let thermallyAdjustedReliability = reliability * (1 - thermalPenalty)
        return EonPrecisionMap(sensory: thermallyAdjustedReliability, memory: min(1, map.memory * 0.95 + thermallyAdjustedReliability * 0.05), selfModel: min(1, map.selfModel * 0.95 + thermallyAdjustedReliability * 0.05), social: map.social, prediction: thermallyAdjustedReliability, interoceptive: min(1, 1 - body.thermalPressure))
    }
}
