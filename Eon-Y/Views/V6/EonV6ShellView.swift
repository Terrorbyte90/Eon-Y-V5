import SwiftUI
import Combine

@MainActor
final class EonV6Runtime: ObservableObject {
    static let shared = EonV6Runtime()
    @Published private(set) var state = EonCoreStateV2()
    @Published private(set) var evidence = EonEvidenceProfile()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.sample() }
    }

    private func sample() {
        let brain = EonBrain.shared
        let ce = ConsciousnessEngine.shared
        state.cycle = ce.unifiedConsciousState.cycleIndex
        state.monotonicTimestamp = Date()
        let rawFocus = brain.attentionFocus.isEmpty ? brain.currentWorkspaceFocus : brain.attentionFocus
        state.attention = EonTextSanitizer.clean(rawFocus.isEmpty ? "Spontan intern aktivitet" : rawFocus, maxLength: 100)
        state.globalBroadcast = ce.unifiedConsciousState.globalBroadcast.first ?? ""
        state.temporalContinuity = min(0.96, max(0, ce.unifiedConsciousState.continuity * 0.72 + brain.selfModelAccuracy * 0.28))
        state.selfModelConfidence = brain.selfModelAccuracy
        state.agency = min(0.96, max(0, ce.unifiedConsciousState.selfModel.agency * (1 - ce.unifiedConsciousState.predictionError * 0.35)))
        state.body = InteroceptiveBodyCore().state(thermal: ce.bodyBudget.thermalLevel, cpu: brain.cpuUsage, memory: min(1, brain.memoryUsageMB / 2048))
        state.affect = AffectiveCoreV2().update(previous: state.affect, predictionError: ce.unifiedConsciousState.predictionError, body: state.body, outcomeImprovement: 1 - ce.unifiedConsciousState.predictionError)
        state.languageReporterAvailable = true
        evidence = ConsciousnessEvidenceEngine().profile(state: state)
        objectWillChange.send()
    }
}

struct EonV6ShellView: View {
    @StateObject private var runtime = EonV6Runtime.shared
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            EonV6OverviewView().tabItem { Label("Nu", systemImage: "circle.hexagongrid.fill") }.tag(0)
            EonV6InsideView().tabItem { Label("Inifrån", systemImage: "waveform.path.ecg") }.tag(1)
            EonV6EvidenceView().tabItem { Label("Evidens", systemImage: "chart.xyaxis.line") }.tag(2)
            EonV6MemoryView().tabItem { Label("Minne", systemImage: "clock.arrow.circlepath") }.tag(3)
            EonV6SettingsView().tabItem { Label("System", systemImage: "slider.horizontal.3") }.tag(4)
        }
        .tint(EonV6Theme.cyan)
        .background(EonV6Theme.ink.ignoresSafeArea())
        .environmentObject(runtime)
        .onAppear { runtime.start() }
    }
}
