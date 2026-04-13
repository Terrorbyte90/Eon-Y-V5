import Foundation
@MainActor
final class PhenomenalBindingEngine: ObservableObject {
    static let shared = PhenomenalBindingEngine()
    @Published private(set) var currentExperience: UnifiedExperience = .empty
    @Published private(set) var bindingStrength: Double = 0.0
    @Published private(set) var temporalThickness: Double = 0.0
    @Published private(set) var phenomenalRichness: Double = 0.0
    private var retentionBuffer: [ExperienceMoment] = []
    private let maxRetention = 10

    func bind() async {
        let streams = await gatherStreams()
        let strength = calculateBindingStrength(streams)
        let experience = synthesizeExperience(streams: streams, strength: strength)
        updateTemporalThickness(experience)
        let richness = calculatePhenomenalRichness(experience)
        self.currentExperience = experience
        self.bindingStrength = strength
        self.phenomenalRichness = richness
        ConsciousnessEngine.shared.updatePhenomenalBinding(strength: strength, richness: richness, temporalThickness: temporalThickness)
    }

    private func gatherStreams() async -> [ConsciousnessStream] {
        let brain = EonBrain.shared
        let consciousness = ConsciousnessEngine.shared
        return [
            ConsciousnessStream(modality: .perceptual, content: consciousness.attentionSchemaState.currentFocus, intensity: consciousness.attentionSchemaState.intensity, valence: 0.0),
            ConsciousnessStream(modality: .emotional, content: brain.currentEmotion.rawValue, intensity: brain.emotionArousal, valence: brain.emotionValence),
            ConsciousnessStream(modality: .cognitive, content: brain.currentThoughtStream.first?.content ?? "", intensity: brain.cognitiveLoad, valence: brain.curiosityDrive > 0.5 ? 0.3 : -0.1),
            ConsciousnessStream(modality: .interoceptive, content: consciousness.bodyBudget.summary, intensity: consciousness.bodyBudget.stress, valence: consciousness.bodyBudget.comfort),
            ConsciousnessStream(modality: .linguistic, content: consciousness.innerNarrative, intensity: consciousness.innerNarrativeQuality, valence: 0.0),
            ConsciousnessStream(modality: .predictive, content: "Expected free energy: \(ActiveInferenceEngine.shared.freeEnergy)", intensity: ActiveInferenceEngine.shared.epistemicValue, valence: ActiveInferenceEngine.shared.freeEnergy < 0.3 ? 0.2 : -0.2),
        ]
    }

    private func calculateBindingStrength(_ streams: [ConsciousnessStream]) -> Double {
        guard streams.count >= 2 else { return 0.0 }
        var totalIntensity: Double = 0, interactionTerms: Double = 0
        for i in 0..<streams.count {
            totalIntensity += streams[i].intensity
            for j in (i+1)..<streams.count {
                let comp = complementarity(streams[i].modality, streams[j].modality)
                interactionTerms += streams[i].intensity * streams[j].intensity * comp
            }
        }
        let avg = totalIntensity / Double(streams.count)
        return min(1.0, interactionTerms / max(0.01, totalIntensity) * 2.0 + avg * 0.3)
    }

    private func complementarity(_ a: Modality, _ b: Modality) -> Double {
        switch (a, b) {
        case (.emotional, .perceptual), (.perceptual, .emotional): return 0.9
        case (.cognitive, .linguistic), (.linguistic, .cognitive): return 0.85
        case (.interoceptive, .emotional), (.emotional, .interoceptive): return 0.95
        case (.predictive, .cognitive), (.cognitive, .predictive): return 0.8
        default: return 0.5
        }
    }

    private func synthesizeExperience(streams: [ConsciousnessStream], strength: Double) -> UnifiedExperience {
        let dom = streams.max(by: { $0.intensity < $1.intensity }) ?? streams[0]
        let totalW = streams.reduce(0) { $0 + $1.intensity }
        let wv = totalW > 0 ? streams.reduce(0) { $0 + $1.valence * $1.intensity } / totalW : 0.0
        return UnifiedExperience(dominantModality: dom.modality, overallValence: wv, overallIntensity: totalW/Double(max(1,streams.count)), bindingStrength: strength, phenomenalDescription: "Upplevelse: \(dom.modality.rawValue)", timestamp: Date(), streamCount: streams.count)
    }

    private func updateTemporalThickness(_ exp: UnifiedExperience) {
        retentionBuffer.append(ExperienceMoment(experience: exp, timestamp: Date()))
        if retentionBuffer.count > maxRetention { retentionBuffer.removeFirst() }
        if retentionBuffer.count >= 2 {
            let recent = retentionBuffer.suffix(3)
            var diff: Double = 0
            let arr = Array(recent)
            for i in 1..<arr.count { diff += abs(arr[i].experience.overallValence - arr[i-1].experience.overallValence) + abs(arr[i].experience.overallIntensity - arr[i-1].experience.overallIntensity) }
            temporalThickness = min(1.0, diff / Double(arr.count))
        }
    }

    private func calculatePhenomenalRichness(_ exp: UnifiedExperience) -> Double {
        let breadth = Double(exp.streamCount) / 6.0
        let depth = temporalThickness
        let complexity = retentionBuffer.count >= 3 ? stdDev(Array(retentionBuffer.suffix(5).map { $0.experience.overallIntensity })) : 0.2
        return min(1.0, breadth * 0.25 + exp.bindingStrength * 0.35 + depth * 0.2 + complexity * 0.2)
    }

    private func stdDev(_ v: [Double]) -> Double {
        guard v.count > 1 else { return 0.0 }
        let m = v.reduce(0,+)/Double(v.count)
        return sqrt(v.reduce(0){$0+($1-m)*($1-m)}/Double(v.count))
    }
}

enum Modality: String { case perceptual, emotional, cognitive, interoceptive, linguistic, predictive }
struct ConsciousnessStream { let modality: Modality; let content: String; let intensity: Double; let valence: Double }
struct UnifiedExperience { let dominantModality: Modality; let overallValence: Double; let overallIntensity: Double; let bindingStrength: Double; let phenomenalDescription: String; let timestamp: Date; let streamCount: Int; static let empty = UnifiedExperience(dominantModality: .cognitive, overallValence: 0, overallIntensity: 0, bindingStrength: 0, phenomenalDescription: "Ej initierad", timestamp: .distantPast, streamCount: 0) }
struct ExperienceMoment { let experience: UnifiedExperience; let timestamp: Date }
