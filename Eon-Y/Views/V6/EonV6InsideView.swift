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
                    EonV6Card(title: "Kärnflöde", eyebrow: "Arkitektur", accent: EonV6Theme.indigo) {
                        flowRow("1", "Signal", "sensorer, journal och intern aktivitet")
                        flowRow("2", "Prediktion", "förväntning jämförs med inkommande data")
                        flowRow("3", "Policy", "fokus väljs efter nytta, osäkerhet och kroppskostnad")
                        flowRow("4", "State", "resultat återkopplas till nästa cykel")
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
                        EonV6Card(title: "Aktuellt tillstånd", eyebrow: "Nu", accent: EonV6Theme.cyan) {
                            Text(presentation.summary).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            Text("Aktuellt fokus").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(EonV6Theme.cyan).padding(.top, 4)
                            Text(presentation.focus).foregroundStyle(.white.opacity(0.72))
                            HStack(spacing: 8) {
                                statePill("Stabilitet", runtime.state.body.thermalPressure < 0.78 ? EonV6Theme.mint : EonV6Theme.coral, runtime.state.body.thermalPressure < 0.78 ? "Integrerad" : "Pressad")
                                statePill("Nästa", EonV6Theme.cyan, presentation.nextAction)
                            }
                        }
                        EonV6Card(title: "Kroppens budget", eyebrow: "Interoception", accent: EonV6Theme.amber) {
                            progress("Termiskt tryck", runtime.state.body.thermalPressure, EonV6Theme.coral)
                            progress("Kognitiv belastning", runtime.state.body.cognitiveLoad, EonV6Theme.amber)
                            progress("Tillgänglig kapacitet", runtime.state.body.processingAvailability, EonV6Theme.mint)
                        }
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
    private func statePill(_ label: String, _ color: Color, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(label.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(color); Text(value).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.82)).lineLimit(1) }
            .padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    private func progress(_ label: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.62)); Spacer(); Text("\(Int(value * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(tint) }
            ProgressView(value: value).tint(tint)
        }
    }
    private func row(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(.white.opacity(0.5)); Spacer(); Text(value).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.trailing) }.font(.system(size: 13, design: .monospaced)) }
    private func flowRow(_ number: String, _ title: String, _ detail: String) -> some View { HStack(alignment: .top, spacing: 10) { Text(number).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(EonV6Theme.cyan); VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white); Text(detail).font(.caption).foregroundStyle(.white.opacity(0.55)) } } }
}
