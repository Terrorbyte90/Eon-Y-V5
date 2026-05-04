
struct ProcessLabels {
    static func label(for engine: String, brain: EonBrain) -> String {
        let labels: [String: [String]] = [
            "cognitive": [
                "GPT-SW3: Autonom textgenerering pågår...",
                "Resonemang: Prediktiv sekvensmodellering...",
                "Kognition: Intern monolog genereras...",
                "Tankeström: Medvetandeinnehåll bearbetas...",
                "Resonemang: Kontrafaktisk analys aktiv...",
                "Kognition: Bayesiansk inferens uppdaterar beliefs...",
                "Global Workspace: Tävlande tankar konvergerar...",
                "Kognition: Kausal kedjeanalys pågår...",
                "Tänkande: Metakognitiv utvärdering av egen process...",
            ],
            "language": [
                "KB-BERT: Semantisk embedding beräknas...",
                "Språk: Meningslikhet analyseras...",
                "Morfologi: 768-dim representation aktiv...",
                "Syntax: V2-ordföljd verifieras...",
                "Pragmatik: Kontextuell tolkning pågår...",
                "Språk: Registeranpassning justeras...",
                "Lexikon: Ordförrådsexpansion aktiv...",
                "Semantik: Disambiguering av flertydiga ord...",
                "Fonetik: Prosodiska mönster analyseras...",
            ],
            "memory": [
                "Minne: Episodisk sökning aktiv...",
                "Minne: Associationsnät aktiverat...",
                "Minne: CLS-konsolidering pågår...",
                "Minne: Semantisk åtkomst av relaterade koncept...",
                "Minne: Prospektiv planering baserad på erfarenhet...",
                "Minne: Autobiografisk tidslinje uppdateras...",
                "Minne: Mönsteravslutning från fragmentariska spår...",
                "Minne: Kontextberoende åtkomst aktiverad...",
            ],
            "learning": [
                "Inlärning: Böjningsmönster analyseras...",
                "Inlärning: Sammansättningar segmenteras...",
                "Inlärning: Lexikonuppdatering pågår...",
                "Inlärning: Grammatiska regler abstraheras...",
                "Inlärning: Transfer av insikter mellan domäner...",
                "Inlärning: Felanalys och korrigering pågår...",
                "Inlärning: Spaced repetition schemaläggs...",
                "Inlärning: Kunskapsluckor identifieras och prioriteras...",
            ],
            "autonomy": [
                "Autonomi: Självförbättring pågår...",
                "Autonomi: Rekursiv optimering...",
                "Autonomi: Kunskapsluckor identifieras...",
                "Autonomi: Autonom artikelskrivning aktiv...",
                "Autonomi: Målstyrd kunskapsexpansion...",
                "Autonomi: Självdiagnos av kognitiva processer...",
                "Autonomi: Strategisk resursallokering...",
                "Autonomi: Proaktiv nyfikenhetsdriven utforskning...",
            ],
            "hypothesis": [
                "Hypotes: Genererar och testar...",
                "Hypotes: Falsifiering pågår...",
                "Hypotes: Evidensanalys aktiv...",
                "Hypotes: Prediktion baserad på befintliga teorier...",
                "Hypotes: Kontrafaktisk simulering aktiv...",
                "Hypotes: Bayesiansk uppdatering av konfidens...",
                "Hypotes: Jämför konkurrerande förklaringsmodeller...",
                "Hypotes: Abduktiv slutledning genererar kandidater...",
            ],
            "worldModel": [
                "Världsmodell: Kausala kedjor uppdateras...",
                "Världsmodell: Domänkartläggning pågår...",
                "Världsmodell: Integration av ny kunskap...",
                "Världsmodell: Ontologisk struktur förfinas...",
                "Världsmodell: Prediktiv simulering av scenarier...",
                "Världsmodell: Korsdomänkopplingar identifieras...",
                "Världsmodell: Temporal dynamik modelleras...",
                "Världsmodell: Konceptuella gränser omförhandlas...",
            ],
        ]
        return labels[engine]?.randomElement() ?? "Kognitiv bearbetning pågår..."
    }
}

// MARK: - PerformanceMode
