import SwiftUI

struct EonV6ExperimentView: View {
    @State private var selected = "no-broadcast"
    @State private var running = false
    private let experiments = ["no-broadcast", "no-recurrence", "no-memory", "no-self-model", "no-valence"]
    var body: some View {
        List {
            Section("Ablation") {
                Picker("Intervention", selection: $selected) { ForEach(experiments, id: \.self) { Text($0).tag($0) } }
                Button(running ? "Kör experiment…" : "Kör kontrollerad perturbation") { running = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { running = false } }.disabled(running)
            }
            Section("Resultat") { Label(running ? "Experimentet körs isolerat" : "Inget experiment körs", systemImage: running ? "waveform.path.ecg" : "pause.circle"); Text("Resultatet sparas med baseline, intervention, state-delta och efterföljande policy.").font(.caption).foregroundStyle(.secondary) }
        }.scrollContentBackground(.hidden).background(EonV6Theme.ink).navigationTitle("Kausal perturbation")
    }
}

struct EonV6JournalView: View {
    var body: some View {
        List {
            Section("Livejournal") { Label("JSONL-segment aktivt", systemImage: "doc.text.fill"); Label("Snapshots exporteras periodiskt", systemImage: "arrow.up.doc.fill"); Label("Proveniens bevaras per händelse", systemImage: "link") }
            Section("Datatyper") { Text("Measurement"); Text("Prediction"); Text("Workspace"); Text("Thought trace"); Text("Causal trace") }
        }.scrollContentBackground(.hidden).background(EonV6Theme.ink).navigationTitle("Export & journal")
    }
}
