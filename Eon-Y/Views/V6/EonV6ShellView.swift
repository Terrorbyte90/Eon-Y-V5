import SwiftUI
import Combine

@MainActor
final class EonV6Runtime: ObservableObject {
    static let shared = EonV6Runtime()
    @Published private(set) var state = EonCoreStateV2()
    @Published private(set) var evidence = EonEvidenceProfile()
    @Published private(set) var verification = ConsciousnessVerificationResult(level: .level0, confidence: 0, passedTests: 0, totalTests: 0, ceiling: .level5, levelPassed: [0: true], reasons: ["Startar verifiering"], evaluatedAt: Date())
    @Published private(set) var testRows: [(String, Bool, Double)] = []
    @Published private(set) var fullLog = ""
    @Published private(set) var presentation: EonPresentationSnapshot?
    @Published private(set) var verificationFreshness = "Startar verifiering"
    @Published private(set) var timelinePulse: String?
    @Published private(set) var timelinePulseID = UUID()
    private var timer: Timer?
    private var lastTimelineText = ""

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
        state.attention = EonTextSanitizer.focus(rawFocus.isEmpty ? "Spontan intern aktivitet" : rawFocus)
        state.globalBroadcast = ce.unifiedConsciousState.globalBroadcast.first ?? ""
        state.temporalContinuity = min(0.96, max(0, ce.unifiedConsciousState.continuity * 0.72 + brain.selfModelAccuracy * 0.28))
        state.selfModelConfidence = brain.selfModelAccuracy
        state.agency = min(0.96, max(0, ce.unifiedConsciousState.selfModel.agency * (1 - ce.unifiedConsciousState.predictionError * 0.35)))
        let sleep = SleepConsolidationEngine.shared
        state.body = InteroceptiveBodyCore().state(thermal: ce.bodyBudget.thermalLevel, cpu: brain.cpuUsage, memory: min(1, brain.memoryUsageMB / 2048), sleepPressure: sleep.sleepPressure)
        state.affect = AffectiveCoreV2().update(previous: state.affect, predictionError: ce.unifiedConsciousState.predictionError, body: state.body, outcomeImprovement: 1 - ce.unifiedConsciousState.predictionError)
        let latestTimelineText = brain.innerMonologue.last?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanedTimelineText = EonTextSanitizer.clean(latestTimelineText, maxLength: 180)
        let isRecursiveFallback = EonTextSanitizer.isRecursive(latestTimelineText)
        if !cleanedTimelineText.isEmpty && cleanedTimelineText != lastTimelineText && !isRecursiveFallback {
            timelinePulse = cleanedTimelineText
            timelinePulseID = UUID()
            lastTimelineText = cleanedTimelineText
        }
        state.languageReporterAvailable = true
        evidence = ConsciousnessEvidenceEngine().profile(state: state)
        verification = ce.verifiedConsciousness
        testRows = ce.consciousnessTests.map { ($0.name, $0.passed, $0.score) }
        presentation = EonPresentationSnapshot.make(state: state, verification: verification, brain: brain, previous: presentation)
        verificationFreshness = "Verifiering från cykel \(state.cycle)"
        objectWillChange.send()
        Task { await refreshFullLog(brain: brain, state: state) }
    }

    private func refreshFullLog(brain: EonBrain, state: EonCoreStateV2) async {
        let events = await EventJournal.shared.exportBatch(maxBytes: 120_000)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let snapshot = verification
        var sections = ["=== EON V6 FULL LOG ===", "generated=\(ISO8601DateFormatter().string(from: Date()))", "cycle=\(state.cycle)", "snapshot_cycle=\(state.cycle)", "verification_freshness=\(verificationFreshness)", "verified_level=\(snapshot.level.rawValue)", "verified_title=\(snapshot.level.title)", "passed_tests=\(snapshot.passedTests)/\(snapshot.totalTests)", "level_status=\(VerifiedConsciousnessLevel.allCases.map { "\($0.rawValue):\(snapshot.levelPassed[$0.rawValue] == true ? "PASS" : "PENDING")" }.joined(separator: ","))", "reasons=\(snapshot.reasons.joined(separator: " | "))", "--- INNER TRACE ---"]
        sections += brain.innerMonologue.suffix(80).filter { !EonTextSanitizer.isRecursive($0.text) }.map { "[\($0.timestamp.ISO8601Format())] [\($0.source)] \(EonTextSanitizer.clean($0.text, maxLength: 600))" }
        sections.append("--- JOURNAL EVENTS ---")
        sections += events.compactMap { event in guard let data = try? encoder.encode(event), let text = String(data: data, encoding: .utf8) else { return nil }; return text }
        await MainActor.run { self.fullLog = sections.joined(separator: "\n") }
    }
}

struct EonV6ShellView: View {
    @StateObject private var runtime = EonV6Runtime.shared
    @State private var selection = 0
    @State private var tabBarVisible = false

    var body: some View {
        TabView(selection: $selection) {
            EonV6OverviewView { destination in
                withAnimation(.easeInOut(duration: 0.25)) {
                    selection = destination
                    tabBarVisible = true
                }
            }
            .tabItem { Label("Nu", systemImage: "circle.hexagongrid.fill") }.tag(0)
            EonV6InsideView().tabItem { Label("Inifrån", systemImage: "waveform.path.ecg") }.tag(1)
            EonV6EvidenceView().tabItem { Label("Evidens", systemImage: "chart.xyaxis.line") }.tag(2)
            EonV6MemoryView().tabItem { Label("Minne", systemImage: "clock.arrow.circlepath") }.tag(3)
            EonV6SettingsView().tabItem { Label("System", systemImage: "slider.horizontal.3") }.tag(4)
        }
        .tint(EonV6Theme.cyan)
        .background(EonV6Theme.ink.ignoresSafeArea())
        .environmentObject(runtime)
        .environment(\.tabBarVisible, $tabBarVisible)
        .toolbar(tabBarVisible ? .visible : .hidden, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: tabBarVisible)
        .onAppear { runtime.start() }
        .onChange(of: selection) { _, newSelection in
            withAnimation(.easeInOut(duration: 0.3)) { tabBarVisible = newSelection != 0 }
        }
    }
}
