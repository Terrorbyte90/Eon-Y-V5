import SwiftUI

struct EonV6EvidenceView: View {
    @EnvironmentObject private var runtime: EonV6Runtime
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Evidens").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("Den konkreta verifieringen, test för test.").foregroundStyle(.white.opacity(0.5))
            EonV6Card(title: "Profil", eyebrow: "Multi-theory", accent: EonV6Theme.indigo) {
                EonV6Metric(label: "samlad profil", value: "\(Int(runtime.evidence.mean * 100))%", tint: EonV6Theme.indigo)
                ForEach(EonEvidenceFamily.allCases, id: \.self) { family in HStack { Text(family.rawValue.capitalized).foregroundStyle(.white.opacity(0.7)); Spacer(); ProgressView(value: runtime.evidence.scores[family] ?? 0).frame(width: 110).tint(EonV6Theme.cyan) }.font(.system(size: 12)) }
            }
            EonV6Card(title: "\(runtime.verification.passedTests)/\(runtime.verification.totalTests) godkända", eyebrow: "Verifieringsfönster", accent: EonV6Theme.cyan) {
                ForEach(Array(runtime.testRows.enumerated()), id: \.offset) { _, row in HStack { Image(systemName: row.1 ? "checkmark.circle.fill" : "circle").foregroundStyle(row.1 ? EonV6Theme.mint : .white.opacity(0.3)); Text(row.0).foregroundStyle(.white.opacity(0.75)); Spacer(); Text("\(Int(row.2 * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.5)) }.font(.system(size: 12)) }
            }
            EonV6Card(title: "Laboratorium", eyebrow: "Kontroller", accent: EonV6Theme.amber) { status("Held-out", runtime.evidence.heldOutPassed); status("Language-off", runtime.evidence.languageOffPassed); status("Restart", runtime.evidence.restartPassed); Text("Ablationer rapporteras med baseline, intervention och state-delta.").foregroundStyle(.white.opacity(0.5)) }
        }.padding(20) }.background(EonV6Theme.ink.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline) }
    }
    private func status(_ label: String, _ passed: Bool) -> some View { Label(label, systemImage: passed ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(passed ? EonV6Theme.mint : .white.opacity(0.45)) }
}
