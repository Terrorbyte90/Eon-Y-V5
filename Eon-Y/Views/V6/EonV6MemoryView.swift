import SwiftUI

struct EonV6MemoryView: View {
    @ObservedObject private var brain = EonBrain.shared
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Minne & tid").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white); Text("Minnen visas med källa och typ, inte som en blandad monolog.").foregroundStyle(.white.opacity(0.5)); EonV6Card(title: "Senaste spår", eyebrow: "Episodiskt", accent: EonV6Theme.cyan) { ForEach(Array(brain.innerMonologue.suffix(16).reversed().filter { !EonTextSanitizer.isRecursive($0.text) }.prefix(8))) { line in VStack(alignment: .leading, spacing: 5) { Text(line.source).font(.system(size: 10, design: .monospaced)).foregroundStyle(EonV6Theme.cyan); Text(EonTextSanitizer.clean(line.text)).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85)); Divider().overlay(.white.opacity(0.08)) } } } }.padding(20) }.background(EonV6Theme.ink.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline) } }
}
