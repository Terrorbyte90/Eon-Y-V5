import SwiftUI

struct EonV6SettingsView: View {
    @AppStorage("eon_qwen_enabled") private var qwenEnabled = true
    @AppStorage("eon_hermes_enabled") private var hermesEnabled = false
    @AppStorage("eon_thermal_mode") private var thermalMode = "adaptive"
    var body: some View {
        NavigationStack {
            Form {
                Section("Modell") {
                    Toggle("Qwen språkorgan", isOn: $qwenEnabled)
                    Text("Qwen läser state men får inte ändra kärnan.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Körning") {
                    Picker("Thermal policy", selection: $thermalMode) { Text("Adaptiv").tag("adaptive"); Text("Sval").tag("cool"); Text("Full").tag("full") }
                    Toggle("Hermes-export", isOn: $hermesEnabled)
                }
                Section("Experiment") {
                    NavigationLink("Kausal perturbation") { EonV6ExperimentView() }
                    NavigationLink("Export & journal") { EonV6JournalView() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(EonV6Theme.ink)
            .navigationTitle("System")
        }
    }
}
