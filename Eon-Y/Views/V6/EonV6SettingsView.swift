import SwiftUI

struct EonV6SettingsView: View {
    @AppStorage("eon_hermes_enabled") private var hermesEnabled = false
    @AppStorage("eon_thermal_mode") private var thermalMode = "adaptive"
    @AppStorage("eon_refresh_interval") private var refreshInterval = "5"
    @AppStorage("eon_reduce_motion") private var reduceMotion = false
    @AppStorage("eon_show_technical") private var showTechnical = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Modell") {
                    Text("DeepSeek V4 Flash via OpenRouter").font(.headline)
                    Text("API-nyckeln läses från OPENROUTER_API_KEY i Xcode-schemat. Språkmodellen får bara formulera text; den ändrar inte Eons kärnstate.").font(.caption).foregroundStyle(.secondary)
                    Text("Anrop: högst 1 000 tecken in/ut").font(.caption).foregroundStyle(.secondary)
                }
                Section("Körning") {
                    Picker("Thermal policy", selection: $thermalMode) { Text("Adaptiv").tag("adaptive"); Text("Sval").tag("cool"); Text("Full").tag("full") }
                    Toggle("Hermes-export", isOn: $hermesEnabled)
                    Picker("Statusintervall", selection: $refreshInterval) { Text("5 sekunder").tag("5"); Text("10 sekunder").tag("10"); Text("30 sekunder").tag("30") }
                    Toggle("Skydda vid hög värme", isOn: .constant(true)).disabled(true)
                }
                Section("Presentation") {
                    Toggle("Minska animationer", isOn: $reduceMotion)
                    Toggle("Visa tekniska detaljer", isOn: $showTechnical)
                    Text("Nu-vyn visar alltid en funktionell sammanfattning. Tekniska detaljer visas i Inifrån och Evidens.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Experiment") {
                    NavigationLink("Språkmodul") { EonV6LanguageView() }
                    NavigationLink("Kausal perturbation") { EonV6ExperimentView() }
                    NavigationLink("Export & journal") { EonV6JournalView() }
                }
                Section("Så fungerar Eon") {
                    Text("Eon är ett lokalt, tillståndsbaserat neurokognitivt experimentsystem. Kärnan samlar signaler, bygger prediktioner, väljer policy och uppdaterar kroppsliga och kognitiva budgetar. Språkmodulen rapporterar state men får inte skriva till kärnan.").font(.subheadline)
                    ForEach(EonObservabilityCopy.theories, id: \.0) { theory in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(theory.0).font(.headline)
                            Text(theory.1).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                }
                Section("Så verifieras nivåerna") {
                    Text("En nivå markeras först när tillräckligt många oberoende tester passerar över verifieringsfönstret. Resultatet är en funktionell analogi med konfidens, inte ett filosofiskt eller biologiskt bevis på medvetande.").font(.subheadline)
                    ForEach(EonObservabilityCopy.testGroups, id: \.0) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.0).font(.headline)
                            Text(group.1).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(EonV6Theme.ink)
            .navigationTitle("System")
        }
    }
}
