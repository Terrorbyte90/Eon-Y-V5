import SwiftUI

struct EonV6MemoryView: View {
    @EnvironmentObject private var runtime: EonV6Runtime
    @ObservedObject private var brain = EonBrain.shared
    @State private var filter: TimelineFilter = .all

    private enum TimelineFilter: String, CaseIterable, Identifiable {
        case all = "Alla"
        case observations = "Observationer"
        case memories = "Minnen"
        case system = "System"
        var id: String { rawValue }
    }

    private struct TimelineItem: Identifiable {
        let id: UUID
        let timestamp: Date
        let text: String
        let source: String
        let label: String
        let icon: String
        let color: Color
        let epistemic: String
        let category: TimelineFilter
    }

    private var items: [TimelineItem] {
        var seen = Set<String>()
        return brain.innerMonologue
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !EonTextSanitizer.isRecursive($0.text) }
            .reversed()
            .compactMap { line in
                let text = EonTextSanitizer.clean(line.text, maxLength: 320)
                let key = text.lowercased()
                guard seen.insert(key).inserted else { return nil }
                let category: TimelineFilter
                let label: String
                let color: Color
                switch line.type {
                case .memory:
                    category = .memories; label = "Minne"; color = EonV6Theme.amber
                case .loopTrigger, .revision:
                    category = .system; label = line.type == .revision ? "Revision" : "System"; color = EonV6Theme.coral
                case .insight:
                    category = .observations; label = "Insikt"; color = EonV6Theme.mint
                case .thought:
                    category = .observations; label = "Observation"; color = EonV6Theme.cyan
                }
                let provenance: (String, String) = {
                    if line.source.localizedCaseInsensitiveContains("openrouter") { return ("OpenRouter · genererat", "sparkles") }
                    if line.source.localizedCaseInsensitiveContains("fallback") { return ("Eon-mall · simulerat", "wand.and.stars") }
                    return (line.source.isEmpty ? "Eon-motor" : line.source, "cpu")
                }()
                return TimelineItem(id: line.id, timestamp: line.timestamp, text: text,
                                    source: provenance.0, label: label, icon: line.type.icon,
                                    color: color, epistemic: epistemicLabel(line.epistemicStatus), category: category)
            }
            .filter { filter == .all || $0.category == filter }
            .prefix(24)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    continuityCard
                    EonV6Card(title: "Hur minnet används", eyebrow: "Återkoppling", accent: EonV6Theme.mint) {
                        Text("Tidslinjen är ett spår av Eons tidigare processer. Nya insikter och minnen kan påverka nästa fokus, men varje post behåller källa och epistemisk status.").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                        HStack { Label("Senaste spår", systemImage: "sparkles"); Spacer(); Text("\(items.count)").font(.system(size: 12, design: .monospaced)) }.foregroundStyle(EonV6Theme.mint)
                    }
                    filterBar
                    timelineCard
                    provenanceNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(EonV6Theme.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Minne & tid").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text("En spårbar tidslinje över vad Eon registrerar, bearbetar och genererar.")
                .font(.system(size: 15)).foregroundStyle(.white.opacity(0.56))
        }
    }

    private var continuityCard: some View {
        EonV6Card(title: "Eon just nu", eyebrow: "Kontinuitet", accent: EonV6Theme.indigo) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().fill(EonV6Theme.indigo.opacity(0.12)).frame(width: 58, height: 58)
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 24, weight: .semibold)).foregroundStyle(EonV6Theme.indigo)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cykel \(runtime.state.cycle)").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    Text(runtime.state.attention.isEmpty ? "Spontan intern aktivitet" : runtime.state.attention)
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.62)).lineLimit(2)
                }
                Spacer()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineFilter.allCases) { option in
                    Button(option.rawValue) { withAnimation(.easeOut(duration: 0.2)) { filter = option } }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(filter == option ? EonV6Theme.ink : .white.opacity(0.66))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(filter == option ? EonV6Theme.cyan : EonV6Theme.panel, in: Capsule())
                }
            }
        }
    }

    private var timelineCard: some View {
        EonV6Card(title: "Viktiga skiften", eyebrow: "Tidslinje", accent: EonV6Theme.cyan) {
            if items.isEmpty {
                Text("Inga spår i den här kategorin ännu.").font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in timelineRow(item) }
                }
            }
        }
    }

    private func timelineRow(_ item: TimelineItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: item.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(item.color)
                Rectangle().fill(item.color.opacity(0.22)).frame(width: 1, height: 42)
            }.frame(width: 20)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(item.label.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(item.color)
                    Text(item.timestamp, style: .time).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.38))
                }
                Text(item.text).font(.system(size: 14)).foregroundStyle(.white.opacity(0.84)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(item.source); Text("·"); Text(item.epistemic)
                }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.38))
                Divider().overlay(.white.opacity(0.08)).padding(.top, 5)
            }
            .padding(.bottom, 12)
        }
    }

    private var provenanceNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(EonV6Theme.cyan)
            Text("Narrativa svar är genererade bearbetningsspår. De visar vad systemet producerade — inte i sig ett bevis på subjektiv upplevelse.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.48))
        }.padding(.horizontal, 4)
    }

    private func epistemicLabel(_ status: EpistemicStatus) -> String {
        switch status {
        case .observed: return "observerat"
        case .inferred: return "härlett"
        case .hypothesis: return "hypotes"
        case .simulated: return "simulerat"
        }
    }
}
