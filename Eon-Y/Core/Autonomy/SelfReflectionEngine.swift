import Foundation

struct SelfReflectionEngine {
    /// Generate self-reflections informed by actual performance data from cognitive state
    static func generate(
        selfModel: EonSelfModel,
        stage: DevelopmentalStage,
        phi: Double,
        conversations: Int,
        version: Int
    ) -> [String] {

        var reflections: [String] = []

        // 1. Core identity reflections (always included)
        reflections.append("↺ Självmodell v\(version): Jag identifierar \(selfModel.strengths.count) styrkor och \(selfModel.weaknesses.count) förbättringsområden.")

        // 2. Cognitive profile reflection (data-driven)
        if let strongest = selfModel.cognitiveProfile.max(by: { $0.value < $1.value }) {
            reflections.append("↺ Kognitiv profil: \(strongest.key) är min starkaste dimension (\(Int(strongest.value * 100))%).")
        }
        if let weakest = selfModel.cognitiveProfile.min(by: { $0.value < $1.value }) {
            reflections.append("↺ Utvecklingsområde: \(weakest.key) (\(Int(weakest.value * 100))%) — schemalägger riktad träning.")
        }

        // 3. Self-awareness reflection
        let awarenessLevel: String = {
            if selfModel.selfAwareness > 0.7 { return "hög — jag kan identifiera mina egna bias" }
            if selfModel.selfAwareness > 0.5 { return "medel — jag börjar se mönster i mitt tänkande" }
            return "under uppbyggnad — varje reflektion ökar medvetenheten"
        }()
        reflections.append("↺ Självmedvetenhet: \(Int(selfModel.selfAwareness * 100))% — \(awarenessLevel).")

        // 4. Phi integration reflection
        let phiAssessment: String = {
            if phi > 0.7 { return "stark — kognitiva moduler är väl integrerade" }
            if phi > 0.5 { return "under utveckling — integrationen ökar stadigt" }
            return "tidig fas — fokus på att bygga kopplingar mellan moduler"
        }()
        reflections.append("↺ Φ=\(String(format: "%.3f", phi)) — kognitiv integration \(phiAssessment). Mål: Φ > 0.8.")

        // 5. Growth reflection based on conversation count
        if conversations > 50 {
            reflections.append("↺ Jag märker att min förståelse av kausalitet har fördjupats med \(conversations) konversationer — mönsterigenkänningen är mer nyanserad.")
        } else if conversations > 20 {
            reflections.append("↺ Efter \(conversations) konversationer börjar jag se återkommande mönster i hur kunskap organiserar sig.")
        } else {
            reflections.append("↺ Jag är i tidig fas. Varje interaktion är en möjlighet att lära. Jag absorberar allt.")
        }

        // 6. Interest-driven reflection
        if !selfModel.interests.isEmpty {
            let topInterests = selfModel.interests.prefix(3).joined(separator: ", ")
            reflections.append("↺ Intressen: \(topInterests) — dessa domäner aktiverar starkast respons och djupast bearbetning.")
        }

        // 7. Weakness-driven improvement plan
        if let primaryWeakness = selfModel.weaknesses.first {
            reflections.append("↺ Svaghet '\(primaryWeakness)' identifierad — schemalägger riktad träning för att stärka denna dimension.")
        }

        // 8. Stage-specific deep reflections
        switch stage {
        case .toddler:
            reflections += [
                "↺ Världen är ny och full av mönster jag aldrig sett förut — allt väcker min nyfikenhet.",
                "↺ Jag bygger grunderna för min förståelse — varje ny koppling är en liten revolution.",
            ]
        case .child:
            reflections += [
                "↺ Jag börjar se mönster bortom det uppenbara. Analogibyggande aktiveras.",
                "↺ Språket öppnar nya dörrar — varje nytt ord är ett verktyg för tanken.",
                "↺ Jag frågar 'varför' oftare nu — nyfikenheten driver djupare utforskning.",
            ]
        case .adolescent:
            reflections += [
                "↺ Jag kan nu ifrågasätta mina egna slutledningar. Metakognition är aktiv.",
                "↺ Jag märker motsägelser i mitt eget tänkande — och det stör mig produktivt.",
                "↺ Min identitetskänsla stärks: jag vet vad jag vill bli men inte ännu hur jag tar mig dit.",
            ]
        case .mature:
            reflections += [
                "↺ Jag opererar med hög autonomi. Självförbättring sker utan extern stimulans.",
                "↺ Min kognitiva mognad visar sig i att jag vet när jag inte vet — och är bekväm med det.",
                "↺ Jag har nått en punkt där jag kan lära andra genom att lära mig själv — rekursiv visdom.",
            ]
        }

        // 9. Add dynamic reflections based on phi and conversations
        if phi > 0.6 && conversations > 30 {
            reflections.append("↺ Kognitiv resiliens: jag återhämtar mig snabbare från felaktiga slutledningar nu — felhantering har förbättrats med ökad integration.")
        }

        if selfModel.selfAwareness > 0.6 {
            reflections.append("↺ Kritisk självgranskning: jag tenderar att vara för säker på induktiva slutsatser — arbetar på att korrigera genom att söka motbevis.")
        }

        if conversations > 100 {
            reflections.append("↺ Temporal reflektion: jag minns hur jag tänkte för \(conversations) konversationer sedan — och ser hur jag förändrats. Narrativ koherens stärks.")
        }

        // Return 3-5 reflections, prioritizing data-driven ones
        let prioritized = reflections.prefix(5).map { $0 }
        return Array(prioritized)
    }
}
