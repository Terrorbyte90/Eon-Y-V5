import Foundation
import Combine

/// Single runtime policy for every autonomous component. iOS does not expose
/// exact temperatures, so thermal state is authoritative and CPU/battery are
/// supporting signals only.
@MainActor
final class RuntimeThermalCoordinator: ObservableObject {
    static let shared = RuntimeThermalCoordinator()

    enum RuntimeMode: String, CaseIterable, Sendable {
        case full, balanced, conserve, recovery, manualPause
        var displayName: String {
            switch self { case .full: return "Full kognition"; case .balanced: return "Balanserad"; case .conserve: return "Sparläge"; case .recovery: return "Återhämtning"; case .manualPause: return "Manuell paus" }
        }
    }

    enum Workload: Sendable { case chat, selfModel, workspace, qwen, learning, language, knowledge, telemetry, uiAnimation }

    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var mode: RuntimeMode = .full
    @Published private(set) var throttleFactor: Double = 1
    @Published private(set) var reason: String = "Normal temperatur"
    @Published private(set) var lastTransition: Date = Date()
    @Published private(set) var isManualPause = false

    private var task: Task<Void, Never>?
    private var lastMode: RuntimeMode = .full

    private init() {}

    func start() {
        task?.cancel()
        refresh()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self?.refresh()
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    func setManualPause(_ paused: Bool) {
        isManualPause = paused
        refresh()
    }

    func refresh() {
        thermalState = ProcessInfo.processInfo.thermalState
        let next: RuntimeMode
        if isManualPause { next = .manualPause }
        else {
            switch thermalState {
            case .nominal: next = .full
            case .fair: next = .balanced
            case .serious: next = .conserve
            case .critical: next = .recovery
            @unknown default: next = .balanced
            }
        }
        mode = next
        throttleFactor = next == .full ? 1 : next == .balanced ? 0.7 : next == .conserve ? 0.3 : 0
        reason = isManualPause ? "Manuell pausad" : thermalReason(thermalState)
        if next != lastMode { lastTransition = Date(); lastMode = next }
    }

    func allows(_ workload: Workload) -> Bool {
        switch (mode, workload) {
        case (.manualPause, .chat), (.manualPause, .telemetry), (.manualPause, .uiAnimation): return true
        case (.manualPause, _): return false
        case (.recovery, .chat), (.recovery, .selfModel), (.recovery, .telemetry): return true
        case (.conserve, .chat), (.conserve, .selfModel), (.conserve, .workspace), (.conserve, .telemetry): return true
        case (.balanced, _), (.full, _): return true
        case (_, _): return false
        }
    }

    func intervalSeconds(for workload: Workload, base: Double) -> Double {
        guard allows(workload) else { return .infinity }
        let multiplier: Double
        switch mode { case .full: multiplier = 1; case .balanced: multiplier = 1.5; case .conserve: multiplier = 3; case .recovery, .manualPause: multiplier = 10 }
        return base * multiplier
    }

    private func thermalReason(_ state: ProcessInfo.ThermalState) -> String {
        switch state { case .nominal: return "Normal temperatur"; case .fair: return "Mild termisk belastning"; case .serious: return "Termisk stress — bakgrundsarbete begränsas"; case .critical: return "Kritisk värme — återhämtning"; @unknown default: return "Okänd termisk status" }
    }
}
