import SwiftUI

// =============================================================================
// KUNSKAPSBANKEN — ARTIKELBIBLIOTEK
// =============================================================================
//
// Artiklarna är uppdelade per kategori i separata filer under Articles/-mappen.
// Varje fil är en extension på KnowledgeArticle med en static let för sin kategori.
// Huvudarrayen `library` kombinerar alla kategorier.
//
// LÄGG TILL NY ARTIKEL:
//   1. Gå till rätt kategori-fil i Articles/-mappen
//   2. Lägg till din KnowledgeArticle i arrayen
//   3. Om en ny kategori behövs: skapa en ny fil och lägg till den i `library` nedan
//
// ARTIKELFORMAT — följ detta exakt:
//
//   KnowledgeArticle(
//       title: "Artikelns rubrik",
//       content: """
//       Brödtext. Använd tre citattecken (""") för flerradigt innehåll.
//       """,
//       summary: "1–2 meningar som sammanfattar artikeln.",
//       domain: "Kategorinamn",
//       source: "Källa 1; Källa 2",
//       date: Date().addingTimeInterval(-86400),
//       isAutonomous: false
//   ),
//
// =============================================================================

// MARK: - Artikelbibliotek

extension KnowledgeArticle {

    /// Alla manuellt skrivna seed-artiklar, sammanslagna från alla kategorifiler.
    static let library: [KnowledgeArticle] = {
        ArticlesAIArticles +
        ArticlesCodingArticles +
        ArticlesHistoryArticles +
        ArticlesInventionsArticles +
        ArticlesGeologyArticles +
        ArticlesPhilosophyArticles +
        ArticlesLanguageArticles +
        ArticlesHumanArticles +
        ArticlesHealthArticles +
        ArticlesPsychologyArticles +
        ArticlesWorldArticles +
        ArticlesConflictArticles +
        ArticlesCrimeArticles +
        ArticlesFlashbackArticles
    }()
}
