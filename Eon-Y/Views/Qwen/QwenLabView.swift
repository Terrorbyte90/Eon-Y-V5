import SwiftUI

struct QwenLabView: View {
    @EnvironmentObject private var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @State private var modelMode: LocalModelMode = .onDemand
    @State private var isLoaded = false
    @State private var output = "Välj en auditerad Qwen-uppgift."
    @State private var isRunning = false

    var body: some View {
        ZStack {
            EonColor.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    modelCard
                    taskCard
                    resultCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 32)
                .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
            }
            .coordinateSpace(name: "scrollSpace")
        }
        .task { await refreshStatus() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Qwen Lab", systemImage: "brain.head.profile")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Auditerade bidrag till Eon")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text("Qwen kan föreslå förbättringar, men ändrar aldrig produktionsbeteende direkt.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(hex: "#FBBF24").opacity(0.8))
        }
    }

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MODELL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Circle().fill(isLoaded ? Color.green : Color.gray).frame(width: 8, height: 8)
                Text(isLoaded ? "Laddad" : "Urladdad")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text("Qwen3 1.7B · Metal · lazy load")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Picker("Modelläge", selection: $modelMode) {
                ForEach(LocalModelMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: modelMode) { _, mode in
                Task { await NeuralEngineOrchestrator.shared.setModelMode(mode); await refreshStatus() }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
    }

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AUDITERADE UPPGIFTER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            taskButton("Förbättra svenska", kind: .languageExpansion, icon: "textformat.abc", prompt: "Analysera Eons senaste språkprestanda och föreslå tre testbara svenska språkförbättringar med evidens.")
            taskButton("Granska mätvärden", kind: .measurementReview, icon: "waveform.path.ecg", prompt: "Granska de senaste kognitiva proxy-mätningarna. Separera observationer, härledningar och hypoteser.")
            taskButton("Föreslå optimering", kind: .optimizationProposal, icon: "slider.horizontal.3", prompt: "Föreslå en termiskt säker optimering av Eons nästa kognitiva cykel. Ändra ingenting direkt.")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
    }

    private func taskButton(_ title: String, kind: QwenTaskKind, icon: String, prompt: String) -> some View {
        Button {
            run(prompt, kind: kind)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 11)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "#F59E0B").opacity(0.8))
        .disabled(isRunning)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RESULTAT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if isRunning { ProgressView().tint(.white) }
            }
            Text(output)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .textSelection(.enabled)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
    }

    private func refreshStatus() async {
        modelMode = await NeuralEngineOrchestrator.shared.modelMode
        isLoaded = await NeuralEngineOrchestrator.shared.isLoaded
    }

    private func run(_ prompt: String, kind: QwenTaskKind) {
        isRunning = true
        output = "Qwen analyserar…"
        Task {
            await QwenAutonomyQueue.shared.enqueue(.make(kind: kind, reason: "Manuell auditerad uppgift"))
            let result = await NeuralEngineOrchestrator.shared.generate(prompt: prompt, maxTokens: 180, temperature: 0.4, enableThinking: false)
            await MainActor.run {
                output = result
                isRunning = false
            }
            await refreshStatus()
        }
    }
}
