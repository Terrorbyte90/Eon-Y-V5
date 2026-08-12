import SwiftUI

struct EonV6InsideView: View {
    @EnvironmentObject private var runtime: EonV6Runtime
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Inifrån Eon").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Här visas den centrala state-maskinen före språkrapportering.").foregroundStyle(.white.opacity(0.5))
                    EonV6Card(title: "Epistemiskt fält", eyebrow: "Modell", accent: EonV6Theme.cyan) {
                        row("Aktuellt själv", runtime.state.epistemicField.currentSelf)
                        row("Osäkerhet", "\(Int(runtime.state.epistemicField.uncertainty * 100))%")
                        row("Aktiv broadcast", runtime.state.globalBroadcast.isEmpty ? "—" : runtime.state.globalBroadcast)
                    }
                    EonV6Card(title: "Affektreglering", eyebrow: "Dynamik", accent: EonV6Theme.coral) {
                        row("Valens", String(format: "%+.2f", runtime.state.affect.valence))
                        row("Arousal", String(format: "%.2f", runtime.state.affect.arousal))
                        row("Nyfikenhet", String(format: "%.2f", runtime.state.affect.curiosity))
                        row("Kontroll", String(format: "%.2f", runtime.state.affect.controlEstimate))
                    }
                    EonV6Card(title: "Språkorgan", eyebrow: "Qwen boundary", accent: EonV6Theme.amber) {
                        Text("Qwen får läsa ett snapshot och formulera en rapport. Den får inte skriva till kärnstate.").foregroundStyle(.white.opacity(0.7))
                        Label("Read-only reporter aktiv", systemImage: "lock.fill").foregroundStyle(EonV6Theme.mint)
                    }
                    if let presentation = runtime.presentation {
                        EonV6Card(title: "Vad Eon gör", eyebrow: "Aktivitet", accent: EonV6Theme.mint) {
                            Label(presentation.currentActivity.title, systemImage: "waveform").font(.headline).foregroundStyle(.white)
                            Text(presentation.currentActivity.consequence).font(.caption).foregroundStyle(.white.opacity(0.65))
                            row("Nästa policy", presentation.nextAction)
                            row("Varför", presentation.nextActionReason)
                        }
                        EonV6Card(title: "Osäkerhet och gränser", eyebrow: "Epistemik", accent: EonV6Theme.indigo) {
                            ForEach(presentation.claims) { claim in
                                HStack(alignment: .top) {
                                    Text(claim.kind.rawValue.uppercased()).font(.system(size: 9, design: .monospaced)).foregroundStyle(EonV6Theme.indigo)
                                    Text(claim.text).font(.caption).foregroundStyle(.white.opacity(0.72))
                                }
                            }
                        }
                    }
                }.padding(20)
            }
            .background(EonV6Theme.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func row(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(.white.opacity(0.5)); Spacer(); Text(value).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.trailing) }.font(.system(size: 13, design: .monospaced)) }
}
