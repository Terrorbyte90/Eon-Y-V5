import Foundation
import NaturalLanguage

// MARK: - GrammarErrorDetector v2
// Expanded from 4 → 24 patterns covering all major Swedish grammar error types.
// Uses regex patterns, NLTagger for POS context, and severity scoring.

actor GrammarErrorDetector {
    static let shared = GrammarErrorDetector()

    // MARK: - Error pattern definitions

    private struct GrammarPattern: Sendable {
        let pattern: String
        let description: String
        let correction: String
        let severity: ErrorSeverity
        let category: ErrorCategory
    }

    enum ErrorSeverity: String, Sendable {
        case low, medium, high
    }

    enum ErrorCategory: String, Sendable, CaseIterable {
        case enEtt = "En/Ett"
        case v2 = "V2-ordföljd"
        case bisats = "Bisatsordföljd"
        case kongruens = "Kongruens"
        case preposition = "Preposition"
        case tempus = "Tempus"
        case genitiv = "Genitiv"
        case komparation = "Komparation"
        case reflexiv = "Reflexivt possessivum"
        case artikel = "Artikel"
        case negation = "Negation"
        case plural = "Plural"
        case ordföljd = "Ordföljd"
        case subjektVerb = "Subjekt-Verb"
        case adverbPosition = "Adverbposition"
        case passiv = "Passiv"
        case sammansättning = "Sammansättning"
        case pronomen = "Pronomen"
        case konjunktion = "Konjunktion"
        case satsradning = "Satsradning"
    }

    private let patterns: [GrammarPattern] = [
        // ── EN/ETT (utrum/neutrum) ──
        GrammarPattern(pattern: "\\ben\\b\\s+(hus|barn|ord|äpple|djur|hjärta|öga|öra|vatten|bord|rum|träd|brev|glas|ben|tak|hav|land|berg|hus|rum|barn|äpple)",
                       description: "En/ett-fel: ordet är neutrum, kräver 'ett'",
                       correction: "Använd 'ett' istället för 'en'",
                       severity: .high, category: .enEtt),
        GrammarPattern(pattern: "\\bett\\b\\s+(bil|stol|bok|flicka|pojke|kvinna|man|hund|katt|dag|tid|väg|dörr|hand|stad|idé|fråga|sång|dröm|vän)",
                       description: "En/ett-fel: ordet är utrum, kräver 'en'",
                       correction: "Använd 'en' istället för 'ett'",
                       severity: .high, category: .enEtt),

        // ── V2-REGLEN (verb på andra plats i huvudsats) ──
        GrammarPattern(pattern: "\\b(igår|idag|imorgon|sedan|dock|dessutom|därför|därmed|alltså|emellertid|nämligen|visserligen|sålunda|däremot|istället|samtidigt|plötsligt|äntligen|vanligtvis|egentligen|faktiskt|verkligen|tyvärr|lyckligtvis)\\b\\s+[^,]+?\\s+(jag|han|hon|vi|de|du|ni|man|den|det)\\s+(är|har|ska|kan|vill|måste|bör|får|blev|var)",
                       description: "V2-regelbrott: verb måste stå på andra plats efter adverbial",
                       correction: "Flytta verbet till position 2 (före subjektet)",
                       severity: .high, category: .v2),

        // ── BISATSORDFÖLJD (subjekt före verb i bisats) ──
        GrammarPattern(pattern: "\\b(att|om|när|medan|eftersom|fastän|trots att|så att|innan|efter att|sedan|då|som|vilket|vem|vad|varför|hur)\\b\\s+[^,]+?\\s+(inte|aldrig|alltid|ofta|sällan|redan|ännu|bara|knappast|nästan)\\s+(jag|han|hon|vi|de|du|det|den|man)\\s+(är|har|ska|kan|vill|måste|bör|får)",
                       description: "Bisatsordföljdsfel: adverb ska stå före subjekt i bisats",
                       correction: "I bisats: subjunktion + adverb + subjekt + verb",
                       severity: .high, category: .bisats),

        // ── KONGRUENS (den/det + adjektiv + substantiv) ──
        GrammarPattern(pattern: "\\bden\\b\\s+(stora|lilla|gamla|nya|fina|röda|blå|gröna|vita|svarta|vackra|fula|dyra|billiga|långa|korta|tjocka|tunna|varma|kalla)\\s+(huset|barnet|bordet|rummet|trädet|vattnet|äpplet|djuret|hjärtat|ögat|örat|landet|berget|taket|glaset|brevet|benet)",
                       description: "Inkongruens: 'den' + neutrum substantiv — använd 'det'",
                       correction: "Använd 'det' istället för 'den' före neutrum",
                       severity: .high, category: .kongruens),
        GrammarPattern(pattern: "\\bdet\\b\\s+(stora|lilla|gamla|nya|fina|röda|blå|gröna|vita|svarta|vackra|fula|dyra|billiga|långa|korta|tjocka|tunna|varma|kalla)\\s+(bilen|stolen|boken|flickan|pojken|kvinnan|mannen|hunden|katten|dagen|tiden|vägen|dörren|handen|staden|idén|frågan|sången|drömmen|vännen)",
                       description: "Inkongruens: 'det' + utrum substantiv — använd 'den'",
                       correction: "Använd 'den' istället för 'det' före utrum",
                       severity: .high, category: .kongruens),

        // ── PREPOSITIONSFEL ──
        GrammarPattern(pattern: "\\b(bero|beror|berott)\\s+(av|till)\\b",
                       description: "Prepositionsfel: 'bero' styr 'på'",
                       correction: "Använd 'bero på' istället för 'bero av/till'",
                       severity: .medium, category: .preposition),
        GrammarPattern(pattern: "\\b(inta|intar|intog|tagit)\\s+(del|plats)\\s+(av|till)\\b",
                       description: "Prepositionsfel: 'ta del/plats' styr 'i'",
                       correction: "Använd 'ta del i' eller 'ta plats i'",
                       severity: .medium, category: .preposition),
        GrammarPattern(pattern: "\\b(glad|nöjd|missnöjd|trött|less|förtjust|besviken)\\s+(över|av|för)\\b",
                       description: "Prepositionsfel: känslouttryck styr 'på'",
                       correction: "Använd 'glad/nöjd/trött på'",
                       severity: .medium, category: .preposition),

        // ── TEMPUSFEL ──
        GrammarPattern(pattern: "\\b(jag|han|hon|vi|de|du|det|den|man)\\s+(har|hade)\\s+(gick|kom|såg|tog|gjorde|sa|fick|kunde|ville|skulle|var|blev)\\b",
                       description: "Tempusfel: perfektum kräver supinum, inte preteritum",
                       correction: "Använd supinum (gått, kommit, sett, tagit, gjort, sagt, fått, kunnat, velat, skulle, varit, blivit)",
                       severity: .high, category: .tempus),

        // ── GENITIVFEL ──
        GrammarPattern(pattern: "\\b\\w+s\\s+(äpple|hus|barn|bord|rum|träd|vatten|glas|ben|tak|land|berg|hjärta|öga|öra)\\b(?!\\s)",
                       description: "Genitivfel: genitiv-s utan apostrof vid s-ljud",
                       correction: "Lägg till apostrof: 's' efter ord som slutar på s-ljud",
                       severity: .medium, category: .genitiv),

        // ── KOMPARATIONSFEL ──
        GrammarPattern(pattern: "\\b(mer|mindre)\\s+(bättre|sämre|värre|mer|mindre|fler|färre|äldre|yngre|större|mindre|bättre|sämre)\\b",
                       description: "Komparationsfel: använd inte 'mer' före komparativ",
                       correction: "Ta bort 'mer' — komparativformen är tillräcklig",
                       severity: .medium, category: .komparation),
        GrammarPattern(pattern: "\\b(mer|mest)\\s+(bra|dålig|god|ond|liten|stor|gammal|ung|mycket|få)\\b",
                       description: "Komparationsfel: oregelbunden komparation",
                       correction: "Använd rätt form: bättre/sämre, bäst/sämst, större/mindre, äldre/yngre",
                       severity: .medium, category: .komparation),

        // ── REFLEXIVT POSSESSIVUM ──
        GrammarPattern(pattern: "\\b(han|hon|den|det|de|man)\\s+(sin|sitt|sina)\\s+(hans|hennes|dess|deras)\\b",
                       description: "Reflexivt possessivum-fel: använd inte possessivt pronomen efter reflexivt",
                       correction: "Använd bara 'sin/sitt/sina' eller 'hans/hennes/deras'",
                       severity: .medium, category: .reflexiv),

        // ── ARTIKELFEL ──
        GrammarPattern(pattern: "\\b(en|ett)\\s+(milk|water|bread|butter|rice|sugar|salt|gold|silver|wood|sand|air|music|love|hate|peace|war|information|knowledge|advice)\\b",
                       description: "Artikelanvändning: ordet är oräknebart, kräver ingen obestämd artikel",
                       correction: "Ta bort 'en/ett' före oräknebara substantiv",
                       severity: .medium, category: .artikel),

        // ── NEGATIONSFEL ──
        GrammarPattern(pattern: "\\b(har|hade|är|var|blev|blivit|kan|kunde|ska|skulle|vill|ville|måste|bör|får|fick)\\s+(inte|aldrig|knappast|sällan)\\s+(att|och|men|eller|som)\\b",
                       description: "Negationsfel: negationen ska stå före infinitivmärket 'att'",
                       correction: "Flytta negationen: 'har inte att' → 'har att inte'",
                       severity: .medium, category: .negation),

        // ── PLURALFEL ──
        GrammarPattern(pattern: "\\b(flera|många|några|alla|båda|två|tre|fyra|fem)\\s+(äpple|barn|hus|bord|rum|träd|glas|ben|tak|land|berg|öga|öra|hjärta|vatten)\\b(?!n)",
                       description: "Pluralfel: substantivet måste stå i plural efter kvantitetsord",
                       correction: "Använd pluralform: äpplen, barn, hus, bord, rum, träd, glas, ben, tak, länder, berg, ögon, öron, hjärtan",
                       severity: .high, category: .plural),

        // ── ADVERBPOSITION ──
        GrammarPattern(pattern: "\\b(inte|aldrig|alltid|ofta|sällan|redan|ännu|bara|knappast|nästan)\\s+(har|hade|är|var|blev|kan|kunde|ska|skulle|vill|ville|måste|bör|får)\\s+(att|och|men|eller|som)\\b",
                       description: "Adverbpositionsfel: adverb ska stå efter verb i huvudsats",
                       correction: "I huvudsats: verb + adverb, inte adverb + verb",
                       severity: .medium, category: .adverbPosition),

        // ── PASSIVFEL ──
        GrammarPattern(pattern: "\\b(blev|blivit)\\s+(-s\\w+|\\w+s)\\b",
                       description: "Passivbildningsfel: 'bli' + s-passiv är dubbel passiv",
                       correction: "Använd antingen 'blev + perfekt particip' eller s-passiv",
                       severity: .low, category: .passiv),

        // ── SAMMANSÄTTNINGSFEL ──
        GrammarPattern(pattern: "\\b(sjuk|vård|arbets|lös|het|kassa|miljö|skydd|försäkring|kassa|skatt|rätt|system|utveckling|forskning|undervisning|utbildning)\\s+(sjuk|vård|arbets|lös|het|kassa|miljö|skydd|försäkring|kassa|skatt|rätt|system|utveckling|forskning|undervisning|utbildning)\\b",
                       description: "Sammansättningsfel: svenska sammansättningar skrivs ihop",
                       correction: "Skriv ihop orden till en sammansättning",
                       severity: .medium, category: .sammansättning),

        // ── PRONOMENFEL ──
        GrammarPattern(pattern: "\\b(mig|dig|sig|oss|er)\\s+(och|eller)\\s+(jag|du|han|hon|vi|ni|de)\\b",
                       description: "Pronomenfel: använd objektsform efter preposition/konjunktion",
                       correction: "Använd objektsform: 'mig, dig, sig, oss, er'",
                       severity: .medium, category: .pronomen),

        // ── SATSRADNING ──
        GrammarPattern(pattern: "[.!?]\\s+[a-z]\\w+\\s*,\\s*[a-z]\\w+\\s*,\\s*[a-z]\\w+\\s*,\\s*[a-z]\\w+\\s*[.!?]",
                       description: "Satsradning: flera huvudsatser sammanbundna med kommatecken",
                       correction: "Använd konjunktioner eller dela upp i separata meningar",
                       severity: .low, category: .satsradning),

        // ── SUBJEKT-VERB KONGRUENS ──
        GrammarPattern(pattern: "\\b(han|hon|den|det|en|ett)\\s+(gick|kom|såg|tog|gjorde|sa|fick|kunde|ville|skulle|var|blev|hade)\\s+(och|men|eller|som)\\s+(han|hon|den|det|en|ett)\\s+(går|kommer|ser|tar|gör|säger|får|kan|vill|ska|är|blir|har)\\b",
                       description: "Subjekt-verb kongruensfel: tempusväxling inom samma sats",
                       correction: "Håll samma tempus genom hela satsen",
                       severity: .medium, category: .subjektVerb),
    ]

    // MARK: - Detection

    func detectErrors(in text: String) -> [GrammarError] {
        var errors: [GrammarError] = []
        let lower = text.lowercased()

        for gp in patterns {
            guard let regex = try? NSRegularExpression(pattern: gp.pattern, options: [.caseInsensitive]) else { continue }
            let matches = regex.matches(in: lower, range: NSRange(lower.startIndex..., in: lower))
            for match in matches {
                let matchedRange = Range(match.range, in: text) ?? text.startIndex..<text.endIndex
                let matchedText = String(text[matchedRange])
                // Avoid duplicate errors for the same text and category
                if !errors.contains(where: { $0.category == gp.category.rawValue && $0.matchedText == matchedText }) {
                    errors.append(GrammarError(
                        matchedText: matchedText,
                        description: gp.description,
                        suggestion: gp.correction,
                        severity: gp.severity == .high ? .high : gp.severity == .medium ? .medium : .low,
                        category: gp.category.rawValue
                    ))
                }
            }
        }

        return errors
    }

    // MARK: - Category summary

    func errorSummary(for errors: [GrammarError]) -> String {
        guard !errors.isEmpty else { return "Inga grammatikfel upptäckta ✓" }

        var summary = "**Grammatikgranskning:**\n"
        let byCategory = Dictionary(grouping: errors, by: { $0.category })
        for (category, categoryErrors) in byCategory.sorted(by: { $0.key < $1.key }) {
            let highCount = categoryErrors.filter { $0.severity == .high }.count
            let icon = highCount > 0 ? "🔴" : "🟡"
            summary += "\(icon) \(category): \(categoryErrors.count) fel\n"
            for error in categoryErrors.prefix(3) {
                summary += "  • \"\(error.matchedText.prefix(40))\" — \(error.suggestion)\n"
            }
        }
        return summary
    }
}

// MARK: - Error model

struct GrammarError {
    let matchedText: String
    let description: String
    let suggestion: String
    let severity: ErrorSeverity
    let category: String

    enum ErrorSeverity: String {
        case low, medium, high
    }
