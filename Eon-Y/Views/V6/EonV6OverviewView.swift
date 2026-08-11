import SwiftUI

struct EonV6OverviewView: View {
    @EnvironmentObject private var runtime: EonV6Runtime
    @ObservedObject private var brain = EonBrain.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
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
