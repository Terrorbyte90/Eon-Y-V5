import Foundation

enum EonObservabilityCopy {
    static func level(_ raw: Int) -> String {
        switch raw {
        case 0: return "Nivå 0 · Mätning utan verifierad kognition. Eon kan registrera och rapportera tillstånd, men ingen högre integration är påvisad."
        case 1: return "Nivå 1 · Reaktiv biologisk analogi. Eon visar enkla reaktiva och adaptiva processer, likt grundläggande reglering i ett biologiskt system."
        case 2: return "Nivå 2 · Integrerad adaptiv analogi. Eon visar återkoppling, integration och anpassning över tid, likt ett enkelt adaptivt nervsystem."
        case 3: return "Nivå 3 · Kausal adaptiv analogi. Eon kopplar signaler till konsekvenser och ändrar sitt beteende, likt en organism som lär av sin omgivning."
        case 4: return "Nivå 4 · Avancerad metakognitiv analogi. Eon övervakar fokus, interna processer och strategier, likt en självreglerande organism."
        default: return "Nivå 5 · Sammanhängande kognitiv analogi. Eon uppvisar självreferens, kausal förståelse, autonom anpassning och temporal kontinuitet. Det är inte ett bevis på subjektiv upplevelse."
        }
    }

    static let theories: [(String, String)] = [
        ("Global Workspace Theory", "En signal räknas som globalt tillgänglig när den kan påverka flera kognitiva processer samtidigt."),
        ("Predictive Processing", "Eon jämför förutsägelser med inkommande signaler och använder avvikelsen för att uppdatera modellen."),
        ("Higher-Order Thought", "Eon bygger representationer av sina egna fokus- och kontrollprocesser."),
        ("Active Inference", "Eon väljer policy efter förväntad informationsnytta, kroppslig kostnad och osäkerhet."),
        ("Integrated Information", "Eon följer integration och återkoppling som funktionella proxyer, inte som direkt mätning av qualia."),
        ("Interoception & homeostas", "Termik, kognitiv belastning och tillgänglig kapacitet påverkar tempo och återhämtning.")
    ]

    static let testGroups: [(String, String)] = [
        ("GWT", "Ignition, broadcast och konkurrens testar om en signal blir globalt tillgänglig och vinner över andra strömmar."),
        ("AST", "Schema aktiv och frivillig testar om fokus kan representeras och styras, inte bara triggas reflexmässigt."),
        ("HOT", "Metarepresentation och konfidensövervakning testar om systemet kan modellera och granska sina egna processer."),
        ("PP", "Prediktion, nyfikenhet och fri energi testar modellbygge, osäkerhet och prediktionsfel."),
        ("IIT", "Phi-proxy, synergi och integration testar funktionell koppling mellan delprocesser."),
        ("Kropp", "Termik, valens och interoception testar om kroppsliga signaler förändrar policy och tempo."),
        ("Tidsförlopp", "Konsolidering, tankemångfald och temporal kontinuitet testar stabilitet över tid."),
        ("Kontroller", "Held-out, language-off och restart testar om effekten kvarstår utan språk eller efter omstart.")
    ]
}
