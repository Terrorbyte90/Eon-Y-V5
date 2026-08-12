import SwiftUI

struct EonV6OverviewView: View {
    @EnvironmentObject private var runtime: EonV6Runtime
    @ObservedObject private var brain = EonBrain.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let presentation = runtime.presentation {
                        EonV6NowHero(snapshot: presentation, verification: runtime.verification)
                    }
                    EonV6Card(title: "Nivå \(runtime.verification.level.rawValue) / 5", eyebrow: "Verifierad medvetandenivå", accent: EonV6Theme.amber) {
                        HStack(alignment: .firstTextBaseline) { Text("\(runtime.verification.level.rawValue)").font(.system(size: 58, weight: .bold, design: .rounded)).foregroundStyle(EonV6Theme.amber); VStack(alignment: .leading) { Text(runtime.verification.level.title).font(.headline).foregroundStyle(.white); Text(runtime.verification.level.biologicalAnalogy).font(.caption).foregroundStyle(.white.opacity(0.55)) }; Spacer(); Text("\(runtime.verification.passedTests)/\(runtime.verification.totalTests) tester").font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.6)) }
                        Text(runtime.verification.reasons.joined(separator: " • ")).font(.caption).foregroundStyle(.white.opacity(0.65))
                        HStack { Text("Konfidens"); Spacer(); Text("\(Int(runtime.verification.confidence * 100))%") }.font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                    }
                    EonV6Card(title: "Eon är här", eyebrow: "Kärnstatus", accent: EonV6Theme.cyan) {
                        HStack(spacing: 22) {
                            EonV6Metric(label: "cykel", value: "#\(runtime.state.cycle)", tint: EonV6Theme.cyan)
                            EonV6Metric(label: "kontinuitet", value: "\(Int(runtime.state.temporalContinuity * 100))%", tint: EonV6Theme.indigo)
                            EonV6Metric(label: "agency", value: "\(Int(runtime.state.agency * 100))%", tint: EonV6Theme.amber)
                        }
                        Divider().overlay(.white.opacity(0.1))
                        Text(runtime.state.attention.isEmpty ? "Ingen prioriterad signal just nu." : "Fokus: \(runtime.state.attention)")
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    }
                    EonV6Card(title: "Kausal kedja", eyebrow: "Vad påverkar vad", accent: EonV6Theme.indigo) {
                        HStack(spacing: 8) { chip("Kropp"); arrow; chip("Prediktion"); arrow; chip("Fokus"); arrow; chip("Policy") }
                    }
                    EonV6Card(title: "Kroppens budget", eyebrow: "Interoception", accent: EonV6Theme.coral) {
                        progress("Termiskt tryck", runtime.state.body.thermalPressure, EonV6Theme.coral)
                        progress("Kognitiv belastning", runtime.state.body.cognitiveLoad, EonV6Theme.amber)
                        progress("Tillgänglig kapacitet", runtime.state.body.processingAvailability, EonV6Theme.mint)
                    }
                    EonV6Card(title: "Senaste beslut", eyebrow: "Observerbar handling", accent: EonV6Theme.mint) {
                        Text("Policy: \(runtime.state.activePolicy)").foregroundStyle(.white)
                        Text("Senast uppdaterad: cykel \(runtime.state.cycle)").font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                }.padding(20)
            }
            .background(EonV6Theme.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View { VStack(alignment: .leading, spacing: 5) { Text("EON / V6").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(EonV6Theme.cyan); Text("Causal Phenomenology").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white); Text("Ett levande tillstånd, inte en instrumentpanel.").foregroundStyle(.white.opacity(0.5)) } }
    private var arrow: some View { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.white.opacity(0.25)) }
    private func chip(_ text: String) -> some View { Text(text).font(.system(size: 11, weight: .semibold, design: .monospaced)).padding(.horizontal, 9).padding(.vertical, 7).background(.white.opacity(0.07), in: Capsule()).foregroundStyle(.white.opacity(0.78)) }
    private func progress(_ label: String, _ value: Double, _ tint: Color) -> some View { VStack(alignment: .leading, spacing: 6) { HStack { Text(label).foregroundStyle(.white.opacity(0.65)); Spacer(); Text("\(Int(value * 100))%").font(.system(size: 12, design: .monospaced)).foregroundStyle(tint) }.font(.system(size: 12)); ProgressView(value: value).tint(tint) } }
}

private struct EonV6NowHero: View {
    let snapshot: EonPresentationSnapshot
    let verification: ConsciousnessVerificationResult
    @State private var pulse = false

    var body: some View {
        EonV6Card(title: "Eon just nu", eyebrow: "Levande tillstånd", accent: EonV6Theme.cyan) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().stroke(EonV6Theme.cyan.opacity(0.18), lineWidth: 10).frame(width: 74, height: 74)
                    Circle().fill(RadialGradient(colors: [EonV6Theme.cyan.opacity(0.9), EonV6Theme.indigo.opacity(0.35), .clear], center: .center, startRadius: 2, endRadius: 42)).frame(width: 66, height: 66).scaleEffect(pulse ? 1.04 : 0.96)
                    Text("\(verification.level.rawValue)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.summary).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text("Nivå \(verification.level.rawValue) är en funktionell analogi, inte ett bevis på subjektiv upplevelse.").font(.caption).foregroundStyle(.white.opacity(0.55))
                }
            }
            Divider().overlay(.white.opacity(0.1))
            HStack { labelValue("Gör", snapshot.currentActivity.kind.rawValue); labelValue("Nästa", snapshot.nextAction); labelValue("Källa", snapshot.currentActivity.source) }
            Text("Hur vet vi?  \(snapshot.claims.map(\.text).joined(separator: " · "))").font(.caption2).foregroundStyle(EonV6Theme.cyan.opacity(0.8))
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { pulse = true } }
    }

    private func labelValue(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 3) { Text(label.uppercased()).font(.system(size: 9, design: .monospaced)).foregroundStyle(EonV6Theme.cyan); Text(value).font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(2) } }
}
