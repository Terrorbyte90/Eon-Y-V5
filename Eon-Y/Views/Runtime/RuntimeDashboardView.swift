import SwiftUI

/// Single operational dashboard. It deliberately reports observed runtime
/// state and theory proxies separately from any claim about phenomenal qualia.
struct RuntimeDashboardView: View {
    @EnvironmentObject private var brain: EonBrain
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var runtime = RuntimeThermalCoordinator.shared
    @ObservedObject private var consciousness = ConsciousnessEngine.shared

    var body: some View {
        ZStack {
            Color(hex: "#07050F").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    runtimeCard
                    consciousnessCard
                    motorCard
                    evidenceCard
                    Text("Mätvärdena är funktionella proxies och experimentdata — inte bevis på fenomenellt medvetande.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.38))
                        .padding(.horizontal, 4)
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("EON / RUNTIME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: "#A78BFA"))
                Text("Drift och självmodell")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
    }

    private var runtimeCard: some View {
        card(tint: Color(hex: "#F59E0B")) {
            label("RUNTIME-LÄGE", icon: "gauge.with.dots.needle.67percent", color: Color(hex: "#F59E0B"))
            HStack(alignment: .firstTextBaseline) {
                Text(runtime.mode.displayName).font(.system(size: 21, weight: .bold, design: .rounded))
                Spacer()
                Text("\(Int(runtime.throttleFactor * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#FBBF24"))
            }
            Text(runtime.reason).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 6) {
                statePill("Chat", allowed: runtime.allows(.chat))
                statePill("Självmodell", allowed: runtime.allows(.selfModel))
                statePill("Qwen", allowed: runtime.allows(.qwen))
                statePill("Lärande", allowed: runtime.allows(.learning))
            }
        }
    }

    private var consciousnessCard: some View {
        card(tint: Color(hex: "#F472B6")) {
            label("SJÄLVMODELL", icon: "person.crop.circle.dashed", color: Color(hex: "#F472B6"))
            metric("Kontinuitet", consciousness.unifiedConsciousState.selfModel.autobiographicalContinuity)
            metric("Interoceptiv koppling", consciousness.unifiedConsciousState.selfModel.interoceptiveCoupling)
            metric("Global tillgänglighet", consciousness.unifiedConsciousState.metrics.globalAvailability)
            metric("Metakognitiv kalibrering", consciousness.unifiedConsciousState.metrics.metacognitiveCalibration)
        }
    }

    private var motorCard: some View {
        card(tint: Color(hex: "#38BDF8")) {
            label("MOTORER", icon: "circle.grid.3x3.fill", color: Color(hex: "#38BDF8"))
            let motors: [(String, RuntimeThermalCoordinator.Workload)] = [("Workspace", .workspace), ("Qwen", .qwen), ("Språk", .language), ("Kunskap", .knowledge), ("Telemetry", .telemetry)]
            ForEach(motors, id: \.0) { name, workload in
                HStack {
                    Circle().fill(runtime.allows(workload) ? Color(hex: "#34D399") : Color.white.opacity(0.18)).frame(width: 7, height: 7)
                    Text(name).font(.system(size: 12, design: .rounded))
                    Spacer()
                    Text(runtime.allows(workload) ? "Tillåten" : "Pausad").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private var evidenceCard: some View {
        card(tint: Color(hex: "#14B8A6")) {
            label("EVIDENS", icon: "waveform.path.ecg", color: Color(hex: "#14B8A6"))
            HStack {
                Text("Cykel")
                Spacer()
                Text("#\(consciousness.unifiedConsciousState.cycleIndex)")
            }
            HStack {
                Text("Prediction error")
                Spacer()
                Text(String(format: "%.3f", consciousness.unifiedConsciousState.predictionError))
            }
            HStack {
                Text("Senaste övergång")
                Spacer()
                Text(runtime.lastTransition, style: .time)
            }
            .foregroundStyle(.white.opacity(0.55))
            .font(.system(size: 11, design: .monospaced))
        }
    }

    private func card<Content: View>(tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.055)).overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.22), lineWidth: 1)))
    }

    private func label(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(color)
    }

    private func metric(_ name: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(name).font(.system(size: 11, design: .rounded)); Spacer(); Text(String(format: "%.0f%%", value * 100)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5)) }
            ProgressView(value: value).tint(Color(hex: "#F472B6"))
        }
    }

    private func statePill(_ name: String, allowed: Bool) -> some View {
        Text(name).font(.system(size: 9, weight: .medium, design: .rounded)).padding(.horizontal, 8).padding(.vertical, 5).background(Capsule().fill((allowed ? Color(hex: "#34D399") : Color.white).opacity(allowed ? 0.14 : 0.06))).foregroundStyle(allowed ? Color(hex: "#6EE7B7") : .white.opacity(0.4))
    }
}
