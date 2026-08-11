import SwiftUI

struct EonV6LanguageView: View {
    @EnvironmentObject private var runtime: EonV6Runtime
    @State private var qwenLoaded = false
    @State private var proposal = "Ingen språkrapport genererad ännu."
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Språkmodul").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Eons språkorgan läser kärnstate och formulerar den — det skapar inte state.").foregroundStyle(.white.opacity(0.5))
            EonV6Card(title: qwenLoaded ? "Qwen aktiv" : "Reporter aktiv", eyebrow: "Modellstatus", accent: EonV6Theme.amber) { Label(qwenLoaded ? "Qwen3-1.7B laddad lokalt" : "Read-only fallback", systemImage: qwenLoaded ? "cpu" : "text.bubble.fill").foregroundStyle(qwenLoaded ? EonV6Theme.mint : EonV6Theme.amber); Text("Kärncykel #\(runtime.state.cycle) • provenance: linguistic").font(.caption).foregroundStyle(.white.opacity(0.5)) }
            EonV6Card(title: "Senaste formulering", eyebrow: "Language proposal", accent: EonV6Theme.cyan) { Text(proposal).font(.system(size: 17)).foregroundStyle(.white.opacity(0.9)); Button("Generera ny rapport") { Task { let result = await EonLanguageReporter.shared.proposal(for: runtime.state); proposal = result.text } }.buttonStyle(.borderedProminent).tint(EonV6Theme.cyan) }
            EonV6Card(title: "Pipeline", eyebrow: "Språkutveckling", accent: EonV6Theme.indigo) { Label("Observation → state → intent → formulering", systemImage: "arrow.right").foregroundStyle(.white.opacity(0.75)); Label("Svensk kvalitet och provenance kontrolleras", systemImage: "checkmark.shield").foregroundStyle(EonV6Theme.mint) }
        }.padding(20) }.background(EonV6Theme.ink.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline).task { qwenLoaded = await NeuralEngineOrchestrator.shared.isLoaded } }
    }
}
