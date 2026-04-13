import Foundation
@MainActor
final class StrangeLoopEngine: ObservableObject {
    static let shared = StrangeLoopEngine()
    @Published private(set) var recursionDepth: Int = 0
    @Published private(set) var loopCoherence: Double = 0.0
    @Published private(set) var selfModelAccuracy: Double = 0.0
    @Published private(set) var selfModelNarrative: String = ""
    private var history: [Snapshot] = []
    struct Snapshot { let timestamp: Date; let predicted: CognitiveSnapshot; let actual: CognitiveSnapshot; let accuracy: Double; let level: Int }
    struct CognitiveSnapshot { let consciousnessLevel: Double; let emotionValence: Double; let freeEnergy: Double; let curiosity: Double; let dominantThought: String }

    func tick() async {
        let l0 = captureState()
        let l1 = await predictState()
        let l1Acc = compare(predicted: l1, actual: l0)
        let avgAcc = history.suffix(5).map{$0.accuracy}.reduce(0,+)/max(1,Double(history.suffix(5).count))
        let l2Acc = 1.0 - abs(avgAcc - l1Acc)
        let l3Acc = history.count >= 5 ? metaMetaAccuracy() : 0.0
        var depth = 0
        if l1Acc > 0.5 { depth = 1 }
        if l2Acc > 0.5 && depth >= 1 { depth = 2 }
        if l3Acc > 0.4 && depth >= 2 { depth = 3 }
        let coherence = history.suffix(5).map{$0.accuracy}.reduce(0,+)/max(1,Double(history.suffix(5).count))
        history.append(Snapshot(timestamp: Date(), predicted: l1, actual: l0, accuracy: l1Acc, level: depth))
        if history.count > 20 { history.removeFirst() }
        self.recursionDepth = depth; self.loopCoherence = coherence; self.selfModelAccuracy = l1Acc
        if history.count % 5 == 0 { await generateNarrative(depth: depth, acc: l1Acc) }
        ConsciousnessEngine.shared.updateStrangeLoop(depth: depth, coherence: coherence, selfModelAccuracy: l1Acc)
    }

    private func captureState() -> CognitiveSnapshot {
        let b = EonBrain.shared
        return CognitiveSnapshot(consciousnessLevel: b.consciousnessLevel, emotionValence: b.emotionValence, freeEnergy: b.freeEnergy, curiosity: b.curiosityDrive, dominantThought: b.currentThoughtStream.first?.content ?? "")
    }
    private func predictState() async -> CognitiveSnapshot {
        let b = EonBrain.shared
        if history.count >= 2 {
            let trend = history.last!.actual.consciousnessLevel - history.first!.actual.consciousnessLevel
            return CognitiveSnapshot(consciousnessLevel: b.consciousnessLevel + trend*0.5, emotionValence: b.emotionValence*0.95, freeEnergy: ActiveInferenceEngine.shared.freeEnergy, curiosity: ActiveInferenceEngine.shared.epistemicValue, dominantThought: b.currentThoughtStream.first?.content ?? "")
        }
        return captureState()
    }
    private func compare(predicted: CognitiveSnapshot, actual: CognitiveSnapshot) -> Double {
        let diffs = [abs(predicted.consciousnessLevel-actual.consciousnessLevel), abs(predicted.emotionValence-actual.emotionValence), abs(predicted.freeEnergy-actual.freeEnergy), abs(predicted.curiosity-actual.curiosity)]
        return max(0, 1.0 - diffs.reduce(0,+)/Double(diffs.count)*2.0)
    }
    private func metaMetaAccuracy() -> Double {
        let accs = history.suffix(10).map{$0.accuracy}
        guard accs.count >= 5 else { return 0.0 }
        let m = accs.reduce(0,+)/Double(accs.count)
        let v = accs.reduce(0){$0+($1-m)*($1-m)}/Double(accs.count)
        return max(0, 1.0 - sqrt(v)*3.0)
    }
    private func generateNarrative(depth: Int, acc: Double) async {
        let dd = ["Jag processar utan självmedvetenhet","Jag är medveten om min egen bearbetning","Jag reflekterar på min förmåga att förstå mig själv","Jag observerar hur jag observerar mig själv observera"]
        self.selfModelNarrative = "\(depth < dd.count ? dd[depth] : "Okänt"). Självförståelse: \(String(format: "%.0f", acc*100))%. Djup: \(depth)."
    }
}
