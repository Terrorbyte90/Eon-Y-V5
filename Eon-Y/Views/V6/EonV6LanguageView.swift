import SwiftUI

struct EonV6LanguageView: View {
    @EnvironmentObject private var runtime: EonV6Runtime
    @ObservedObject private var brain = EonBrain.shared
    @State private var openRouterConfigured = false
    @State private var proposal = "Ingen språkrapport genererad ännu."
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Språkmodul").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Eons språkorgan läser kärnstate och formulerar den — det skapar inte state.").foregroundStyle(.white.opacity(0.5))
            EonV6Card(title: openRouterConfigured ? "OpenRouter aktiv" : "Reporter aktiv", eyebrow: "Modellstatus", accent: EonV6Theme.amber) { Label(openRouterConfigured ? "DeepSeek V4 Flash · fjärrmodell" : "Regelbaserad fallback", systemImage: openRouterConfigured ? "cloud.fill" : "text.bubble.fill").foregroundStyle(openRouterConfigured ? EonV6Theme.mint : EonV6Theme.amber); Text("Kärncykel #\(runtime.state.cycle) • max 1 000 tecken • read-only").font(.caption).foregroundStyle(.white.opacity(0.5)) }
            EonV6Card(title: "Senaste formulering", eyebrow: "Language proposal", accent: EonV6Theme.cyan) { Text(proposal).font(.system(size: 17)).foregroundStyle(.white.opacity(0.9)); Button("Generera ny rapport") { Task { let result = await EonLanguageReporter.shared.proposal(for: runtime.state); proposal = result.text } }.buttonStyle(.borderedProminent).tint(EonV6Theme.cyan) }
            EonV6Card(title: "Pipeline", eyebrow: "Språkutveckling", accent: EonV6Theme.indigo) { Label("Observation → state → intent → formulering", systemImage: "arrow.right").foregroundStyle(.white.opacity(0.75)); Label("Svensk kvalitet och provenance kontrolleras", systemImage: "checkmark.shield").foregroundStyle(EonV6Theme.mint) }
            EonV6Card(title: "Svensk språkprofil", eyebrow: "Kvalitet", accent: EonV6Theme.mint) {
                metricRow("Morfologi", "\(Int(brain.morphologyMastery * 100))%")
                metricRow("Syntax", "\(Int(brain.syntaxMastery * 100))%")
                metricRow("Semantik", "\(Int(brain.semanticMastery * 100))%")
                Text("Värdena beskriver språkmodulens aktuella arbetsprofil — inte en generell intelligenspoäng.").font(.caption).foregroundStyle(.white.opacity(0.45))
            }
            EonV6Card(title: "Gräns mot kärnan", eyebrow: "Säkerhet", accent: EonV6Theme.coral) {
                Label("Språket läser state", systemImage: "lock.open.fill").foregroundStyle(EonV6Theme.mint)
                Label("Språket skriver inte state", systemImage: "lock.fill").foregroundStyle(EonV6Theme.cyan)
                Text("Alla formuleringar märks som genererade språkspår och används inte som bevis på upplevelse.").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
        }.padding(20) }.background(EonV6Theme.ink.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline).task { openRouterConfigured = await OpenRouterProvider.shared.isConfigured } }
    }
    private func metricRow(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(.white.opacity(0.65)); Spacer(); Text(value).font(.system(size: 12, design: .monospaced)).foregroundStyle(EonV6Theme.mint) }.font(.system(size: 13)) }
}
