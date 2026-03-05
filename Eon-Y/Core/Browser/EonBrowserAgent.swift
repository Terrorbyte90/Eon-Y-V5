import Foundation
import Combine
import NaturalLanguage

// MARK: - Models

enum BrowseMode: String, CaseIterable {
    case research = "Forskning"
    case article = "Skapa artikel"
    case action = "Utför uppgift"
}

struct BrowseStep: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let icon: String
    let message: String
    let detail: String
    let type: StepType

    enum StepType { case thinking, navigating, reading, extracting, writing, acting, waiting, done, error }
}

// MARK: - Action Plan for multi-step tasks

struct ActionPlan: Sendable {
    let steps: [ActionStep]
    let requiresLogin: Bool
    let targetURL: String?
}

struct ActionStep: Sendable, Identifiable {
    let id = UUID()
    let order: Int
    let description: String
    let type: ActionType
    let selector: String?
    let value: String?
    let url: String?

    enum ActionType: String, Sendable {
        case navigate       // Go to a URL
        case search         // Search on Google or site
        case fillInput      // Fill a text field
        case click          // Click a button/link
        case select         // Select from dropdown
        case scroll         // Scroll to find content
        case wait           // Wait for page load
        case extract        // Extract specific info
        case compare        // Compare items/prices
        case submitForm     // Submit a form
        case login          // Login with credentials
        case typeText       // Type text into active element
        case screenshot     // Capture current state
    }
}

struct BrowseResult {
    let title: String
    let summary: String
    let sources: [String]
    let fullContent: String
    let articleDomain: String?
}

struct PageContent: Sendable {
    let url: String
    let title: String
    let bodyText: String
    let headings: [String]
    let links: [(text: String, href: String)]
    let metaDescription: String
    let tableData: [String]
    let listItems: [String]

    var isEmpty: Bool {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20
    }

    var readableText: String {
        var parts: [String] = []
        if !headings.isEmpty {
            parts.append(headings.joined(separator: " — "))
        }
        parts.append(bodyText)
        if !listItems.isEmpty {
            parts.append(listItems.prefix(10).joined(separator: ". "))
        }
        if !tableData.isEmpty {
            parts.append(tableData.prefix(5).joined(separator: " | "))
        }
        return parts.joined(separator: "\n")
    }
}

struct SearchResult: Sendable {
    let title: String
    let snippet: String
    let url: String
    let index: Int
}

// MARK: - EonBrowserAgent: Autonomous web browsing powered by Qwen3

@MainActor
class EonBrowserAgent: ObservableObject {
    @Published var goal: String = ""
    @Published var mode: BrowseMode = .research
    @Published var articleDomain: String = "AI & Teknik"
    @Published var isBrowsing = false
    @Published var isPaused = false
    @Published var userTookOver = false
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
    @Published var steps: [BrowseStep] = []
    @Published var result: BrowseResult?
    @Published var progress: Double = 0
    @Published var statusLabel: String = "Redo"
    @Published var humanBehavior: Bool = true
    @Published var actionPlan: ActionPlan?
    @Published var currentActionStep: Int = 0

    var onNavigate: ((URL) -> Void)?
    var onExtractContent: ((@escaping (PageContent) -> Void) -> Void)?
    var onRunJS: ((String, @escaping (String?) -> Void) -> Void)?
    var onGoBack: (() -> Void)?

    var pageLoadContinuation: CheckedContinuation<Void, Never>?

    private var collectedContent: [(url: String, title: String, text: String)] = []
    private var visitedURLs: Set<String> = []
    private var failedExtractions = 0
    private var maxPages = 10
    private var pagesVisited = 0
    private var retryCount = 0
    private var maxRetries = 3
    private var extractedPrices: [(item: String, price: String, url: String)] = []
    private var obstacleCount = 0

    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])

    // MARK: - Public API

    func startBrowsing() {
        guard !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isBrowsing = true
        isPaused = false
        userTookOver = false
        result = nil
        steps.removeAll()
        collectedContent.removeAll()
        visitedURLs.removeAll()
        failedExtractions = 0
        pagesVisited = 0
        progress = 0
        retryCount = 0
        extractedPrices.removeAll()
        obstacleCount = 0
        actionPlan = nil
        currentActionStep = 0

        addStep(.thinking, "Analyserar ditt mål", "Förstår vad du vill ha...")

        if mode == .action {
            Task { await planAndExecuteAction() }
        } else {
            Task { await planAndExecute() }
        }
    }

    func stopBrowsing() {
        isBrowsing = false
        isPaused = false
        userTookOver = false
        statusLabel = "Avbruten"
        addStep(.done, "Stoppat av användaren", "")
        pageLoadContinuation?.resume()
        pageLoadContinuation = nil
    }

    func takeOver() {
        userTookOver = true
        isPaused = true
        statusLabel = "Du styr"
        addStep(.thinking, "Användaren tar över", "Eon pausad — du kan surfa fritt")
    }

    func handBack() {
        userTookOver = false
        isPaused = false
        statusLabel = "Eon fortsätter..."
        addStep(.thinking, "Eon tar tillbaka kontrollen", "Läser nuvarande sida...")
    }

    // MARK: - Core browsing loop

    private func planAndExecute() async {
        let searchQuery = await generateSearchQuery()
        guard !searchQuery.isEmpty else {
            addStep(.error, "Kunde inte förstå målet", "Försök formulera om din förfrågan.")
            isBrowsing = false
            return
        }

        addStep(.thinking, "Sökstrategi klar", "Söker: \"\(searchQuery)\"")
        statusLabel = "Söker..."

        let searchURL = buildSearchURL(query: searchQuery)
        await navigateAndWaitForLoad(url: searchURL)
        await dismissPageOverlays()

        var searchResults = await extractSearchResults()

        if !searchResults.isEmpty {
            addStep(.extracting, "Hittade \(searchResults.count) sökresultat",
                    searchResults.prefix(3).map(\.title).joined(separator: ", "))
            await browseSearchResults(searchResults)
        } else {
            addStep(.thinking, "Använder länkanalys", "Extraherar relevanta länkar...")
            await browseLinkBased()
        }

        if collectedContent.count < 2 && pagesVisited < maxPages && isBrowsing {
            let altQuery = await generateAlternativeQuery(original: searchQuery)
            if !altQuery.isEmpty && altQuery.lowercased() != searchQuery.lowercased() {
                addStep(.thinking, "Provar alternativ sökning", "Söker: \"\(altQuery)\"")
                let altURL = buildSearchURL(query: altQuery)
                await navigateAndWaitForLoad(url: altURL)
                await dismissPageOverlays()

                searchResults = await extractSearchResults()
                if !searchResults.isEmpty {
                    await browseSearchResults(searchResults)
                } else {
                    await browseLinkBased()
                }
            }
        }

        guard isBrowsing else { return }

        if !collectedContent.isEmpty {
            await generateFinalResult()
            await saveDiscoveredKnowledge()
        } else {
            addStep(.error, "Kunde inte samla tillräckligt med information",
                    "Prova att formulera om din fråga.")
            isBrowsing = false
        }
    }

    // MARK: - Browse structured search results

    private func browseSearchResults(_ results: [SearchResult]) async {
        let ranked = await rankSearchResults(results)

        for sr in ranked {
            guard pagesVisited < maxPages, isBrowsing, failedExtractions < 4 else { break }
            await waitWhilePaused()
            guard isBrowsing else { break }

            let totalChars = collectedContent.map(\.text).joined().count
            if totalChars > 8000 && collectedContent.count >= 3 {
                addStep(.thinking, "Tillräckligt med material (\(collectedContent.count) sidor)", "Sammanställer...")
                break
            }

            guard let url = URL(string: sr.url), !visitedURLs.contains(sr.url) else { continue }

            statusLabel = "Besöker: \(sr.title.prefix(30))..."
            progress = Double(pagesVisited) / Double(maxPages)
            addStep(.navigating, "Öppnar: \(sr.title.prefix(50))", url.host ?? sr.url)

            await navigateAndWaitForLoad(url: url)
            await dismissPageOverlays()
            await expandCollapsedContent()
            await scrollPageDown()
            await humanDelay(min: 0.3, max: 0.8)

            guard let pageContent = await extractWithRetry() else {
                failedExtractions += 1
                addStep(.error, "Kunde inte läsa sidan (\(failedExtractions))", "Hoppar till nästa...")
                // Handle obstacle if repeated failures
                if failedExtractions >= 2 {
                    _ = await handleObstacle(step: ActionStep(order: 0, description: "Läsa sida", type: .extract, selector: nil, value: nil, url: nil))
                }
                continue
            }

            visitedURLs.insert(sr.url)
            if !pageContent.url.isEmpty { visitedURLs.insert(pageContent.url) }

            if pageContent.isEmpty {
                failedExtractions += 1
                addStep(.reading, "Sidan hade lite innehåll", "Nästa resultat...")
                continue
            }

            failedExtractions = max(0, failedExtractions - 1)
            let text = String(pageContent.readableText.prefix(4000))
            let preview = String(text.prefix(90)).replacingOccurrences(of: "\n", with: " ")
            addStep(.reading, "Läste: \(pageContent.title.prefix(50))", "\(preview)...")

            if !isDuplicateContent(text) {
                collectedContent.append((url: pageContent.url, title: pageContent.title, text: text))
            }
            pagesVisited += 1

            // Extract prices if goal suggests price comparison
            if goal.lowercased().contains("pris") || goal.lowercased().contains("billig") || goal.lowercased().contains("köp") || goal.lowercased().contains("bäst") {
                await extractPricesFromPage()
            }

            if pagesVisited < maxPages && collectedContent.map(\.text).joined().count < 6000 {
                await followDeepLink(on: pageContent)
            }

            await humanDelay(min: 0.2, max: 0.6)
        }
    }

    private func followDeepLink(on page: PageContent) async {
        let filtered = filterLinks(page.links)
        guard !filtered.isEmpty else { return }

        if let deepLink = await selectBestLink(from: filtered) {
            guard let deepURL = URL(string: deepLink.href), !visitedURLs.contains(deepLink.href) else { return }

            addStep(.navigating, "Följer djuplänk: \(deepLink.text.prefix(40))", deepURL.host ?? deepLink.href)
            await navigateAndWaitForLoad(url: deepURL)
            await dismissPageOverlays()
            await expandCollapsedContent()
            await scrollPageDown()

            if let deepContent = await extractWithRetry(), !deepContent.isEmpty {
                let deepText = String(deepContent.readableText.prefix(3000))
                if !isDuplicateContent(deepText) {
                    collectedContent.append((url: deepContent.url, title: deepContent.title, text: deepText))
                    addStep(.reading, "Djuplänk: \(deepContent.title.prefix(40))", "")
                }
            }
            visitedURLs.insert(deepLink.href)
            pagesVisited += 1
        }
    }

    // MARK: - Browse link-based (fallback)

    private func browseLinkBased() async {
        while pagesVisited < maxPages && isBrowsing && failedExtractions < 4 {
            await waitWhilePaused()
            guard isBrowsing else { break }

            progress = Double(pagesVisited) / Double(maxPages)
            statusLabel = "Läser sida \(pagesVisited + 1)/\(maxPages)..."

            guard let pageContent = await extractWithRetry() else {
                failedExtractions += 1
                if failedExtractions >= 4 { break }
                continue
            }

            if !pageContent.isEmpty {
                failedExtractions = max(0, failedExtractions - 1)
                let text = String(pageContent.readableText.prefix(4000))
                let preview = String(text.prefix(90)).replacingOccurrences(of: "\n", with: " ")
                addStep(.reading, "Läser: \(pageContent.title.prefix(50))", "\(preview)...")

                if !isDuplicateContent(text) {
                    collectedContent.append((url: pageContent.url, title: pageContent.title, text: text))
                }
                visitedURLs.insert(pageContent.url)
                pagesVisited += 1
            } else {
                failedExtractions += 1
                if failedExtractions >= 4 { break }
            }

            let totalChars = collectedContent.map(\.text).joined().count
            if totalChars > 6000 && pagesVisited >= 3 { break }

            let filtered = filterLinks(pageContent.links)
            guard !filtered.isEmpty else { break }

            if let nextLink = await selectBestLink(from: filtered) {
                addStep(.navigating, "Följer: \(nextLink.text.prefix(40))", nextLink.href)
                if let url = URL(string: nextLink.href) {
                    await navigateAndWaitForLoad(url: url)
                    await dismissPageOverlays()
                    await expandCollapsedContent()
                    await scrollPageDown()
                }
            } else {
                break
            }

            await humanDelay(min: 0.3, max: 0.8)
        }
    }

    // MARK: - Action Mode: Multi-step task execution

    private func planAndExecuteAction() async {
        addStep(.thinking, "Planerar uppgiftssteg", "Analyserar: \(goal)")
        statusLabel = "Planerar..."

        let plan = await generateActionPlan()
        actionPlan = plan

        if plan.steps.isEmpty {
            addStep(.error, "Kunde inte skapa en plan", "Försök formulera om din uppgift.")
            isBrowsing = false
            return
        }

        addStep(.thinking, "Plan klar: \(plan.steps.count) steg", plan.steps.prefix(3).map(\.description).joined(separator: " → "))

        for (index, step) in plan.steps.enumerated() {
            guard isBrowsing else { break }
            await waitWhilePaused()
            guard isBrowsing else { break }

            currentActionStep = index
            progress = Double(index) / Double(plan.steps.count)
            statusLabel = "Steg \(index + 1)/\(plan.steps.count): \(step.description.prefix(30))..."

            let success = await executeActionStep(step)
            if !success {
                obstacleCount += 1
                addStep(.error, "Steg \(index + 1) misslyckades", step.description)

                // Try to handle the obstacle
                let resolved = await handleObstacle(step: step)
                if !resolved {
                    if obstacleCount >= 3 {
                        addStep(.error, "För många hinder", "Avbryter efter \(obstacleCount) misslyckade försök.")
                        break
                    }
                    continue
                }
            }

            await humanDelay(min: 0.3, max: 1.2)
        }

        // Collect results
        if !collectedContent.isEmpty || !extractedPrices.isEmpty {
            await generateActionResult()
        } else {
            // Try to extract current page as result
            if let content = await extractWithRetry(), !content.isEmpty {
                collectedContent.append((url: content.url, title: content.title, text: String(content.readableText.prefix(4000))))
                await generateActionResult()
            } else {
                addStep(.done, "Uppgift utförd", "Alla steg genomförda.")
                result = BrowseResult(title: "Uppgift: \(String(goal.prefix(40)))", summary: "Eon utförde alla steg i uppgiften.", sources: Array(visitedURLs), fullContent: "", articleDomain: nil)
                isBrowsing = false
                progress = 1.0
            }
        }
    }

    private func generateActionPlan() async -> ActionPlan {
        let prompt = """
        Du planerar steg för en webbläsarrobot. Uppgiften är:
        \(goal)

        Skriv en steg-för-steg plan. Varje steg ska vara ETT av:
        - NAVIGATE:url (gå till URL)
        - SEARCH:sökord (sök på Google)
        - FILL:css-selector|värde (fyll i fält)
        - CLICK:css-selector (klicka på element)
        - SELECT:css-selector|värde (välj i dropdown)
        - SCROLL (scrolla ner)
        - WAIT (vänta på laddning)
        - EXTRACT:vad (extrahera specifik info)
        - COMPARE (jämför insamlad data)
        - SUBMIT (skicka formulär)
        - LOGIN:url (navigera till login-sida)
        - TYPE:text (skriv text i aktivt fält)

        Svara med EN rad per steg. Inga förklaringar. Max 15 steg.
        """

        let raw = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 300, temperature: 0.3, enableThinking: true
        )

        var steps: [ActionStep] = []
        var requiresLogin = false
        var targetURL: String?

        let lines = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 3 }

        for (i, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.hasPrefix("NAVIGATE:") {
                let url = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if targetURL == nil { targetURL = url }
                steps.append(ActionStep(order: i, description: "Navigera till \(url)", type: .navigate, selector: nil, value: nil, url: url))
            } else if upper.hasPrefix("SEARCH:") {
                let query = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                steps.append(ActionStep(order: i, description: "Sök: \(query)", type: .search, selector: nil, value: query, url: nil))
            } else if upper.hasPrefix("FILL:") {
                let parts = String(line.dropFirst(5)).components(separatedBy: "|")
                let selector = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                steps.append(ActionStep(order: i, description: "Fyll i: \(selector.prefix(30))", type: .fillInput, selector: selector, value: value, url: nil))
            } else if upper.hasPrefix("CLICK:") {
                let selector = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                steps.append(ActionStep(order: i, description: "Klicka: \(selector.prefix(30))", type: .click, selector: selector, value: nil, url: nil))
            } else if upper.hasPrefix("SELECT:") {
                let parts = String(line.dropFirst(7)).components(separatedBy: "|")
                let selector = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                steps.append(ActionStep(order: i, description: "Välj: \(value)", type: .select, selector: selector, value: value, url: nil))
            } else if upper.hasPrefix("SCROLL") {
                steps.append(ActionStep(order: i, description: "Scrolla ner", type: .scroll, selector: nil, value: nil, url: nil))
            } else if upper.hasPrefix("WAIT") {
                steps.append(ActionStep(order: i, description: "Väntar på laddning", type: .wait, selector: nil, value: nil, url: nil))
            } else if upper.hasPrefix("EXTRACT:") {
                let what = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                steps.append(ActionStep(order: i, description: "Extrahera: \(what)", type: .extract, selector: nil, value: what, url: nil))
            } else if upper.hasPrefix("COMPARE") {
                steps.append(ActionStep(order: i, description: "Jämför resultat", type: .compare, selector: nil, value: nil, url: nil))
            } else if upper.hasPrefix("SUBMIT") {
                steps.append(ActionStep(order: i, description: "Skicka formulär", type: .submitForm, selector: nil, value: nil, url: nil))
            } else if upper.hasPrefix("LOGIN:") {
                let url = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                requiresLogin = true
                steps.append(ActionStep(order: i, description: "Logga in", type: .login, selector: nil, value: nil, url: url))
            } else if upper.hasPrefix("TYPE:") {
                let text = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                steps.append(ActionStep(order: i, description: "Skriv text", type: .typeText, selector: nil, value: text, url: nil))
            }
        }

        // Fallback: If Qwen failed, create basic plan from goal analysis
        if steps.isEmpty {
            steps = buildFallbackActionPlan()
        }

        return ActionPlan(steps: steps, requiresLogin: requiresLogin, targetURL: targetURL)
    }

    private func buildFallbackActionPlan() -> [ActionStep] {
        let lower = goal.lowercased()
        var steps: [ActionStep] = []

        // Detect intent from goal keywords
        if lower.contains("logga in") || lower.contains("login") {
            steps.append(ActionStep(order: 0, description: "Sök inloggningssida", type: .search, selector: nil, value: goal, url: nil))
            steps.append(ActionStep(order: 1, description: "Vänta", type: .wait, selector: nil, value: nil, url: nil))
        } else if lower.contains("billig") || lower.contains("pris") || lower.contains("bästa pris") || lower.contains("köp") {
            steps.append(ActionStep(order: 0, description: "Sök produkter", type: .search, selector: nil, value: goal, url: nil))
            steps.append(ActionStep(order: 1, description: "Extrahera priser", type: .extract, selector: nil, value: "priser", url: nil))
            steps.append(ActionStep(order: 2, description: "Jämför", type: .compare, selector: nil, value: nil, url: nil))
        } else if lower.contains("skapa") || lower.contains("skriv") || lower.contains("posta") || lower.contains("inlägg") {
            steps.append(ActionStep(order: 0, description: "Sök sida", type: .search, selector: nil, value: goal, url: nil))
            steps.append(ActionStep(order: 1, description: "Extrahera", type: .extract, selector: nil, value: "formulär", url: nil))
        } else {
            // Generic: search + extract
            steps.append(ActionStep(order: 0, description: "Sök", type: .search, selector: nil, value: goal, url: nil))
            steps.append(ActionStep(order: 1, description: "Extrahera info", type: .extract, selector: nil, value: "relevant information", url: nil))
        }

        return steps
    }

    private func executeActionStep(_ step: ActionStep) async -> Bool {
        switch step.type {
        case .navigate:
            guard let urlStr = step.url, let url = URL(string: urlStr) else { return false }
            addStep(.navigating, "Navigerar till \(url.host ?? urlStr)", urlStr)
            await navigateAndWaitForLoad(url: url)
            await humanDelay(min: 0.5, max: 1.5)
            await dismissPageOverlays()
            return true

        case .search:
            let query = step.value ?? goal
            addStep(.thinking, "Söker", query)
            let searchURL = buildSearchURL(query: query)
            await navigateAndWaitForLoad(url: searchURL)
            await humanDelay(min: 0.3, max: 1.0)
            await dismissPageOverlays()
            // Browse top results
            let searchResults = await extractSearchResults()
            if !searchResults.isEmpty {
                await browseSearchResults(Array(searchResults.prefix(5)))
            }
            return true

        case .fillInput:
            guard let selector = step.selector, let value = step.value else { return false }
            addStep(.acting, "Fyller i fält", "\(selector.prefix(30)): \(value.prefix(20))")
            if humanBehavior {
                return await typeWithHumanBehavior(selector: selector, text: value)
            } else {
                return await fillInputField(selector: selector, value: value)
            }

        case .click:
            guard let selector = step.selector else {
                // Try smart click: use Qwen to find the right element
                return await smartClick(description: step.description)
            }
            addStep(.acting, "Klickar", selector.prefix(40).description)
            let success = await clickElement(selector)
            await humanDelay(min: 0.3, max: 0.8)
            return success

        case .select:
            guard let selector = step.selector, let value = step.value else { return false }
            addStep(.acting, "Väljer", "\(value) i \(selector.prefix(20))")
            return await selectOption(selector: selector, value: value)

        case .scroll:
            addStep(.navigating, "Scrollar ner", "")
            if humanBehavior {
                await humanScroll()
            } else {
                await scrollPageDown()
            }
            return true

        case .wait:
            addStep(.waiting, "Väntar på laddning", "")
            await humanDelay(min: 1.0, max: 3.0)
            return true

        case .extract:
            addStep(.extracting, "Extraherar information", step.value ?? "")
            if let content = await extractWithRetry(), !content.isEmpty {
                let text = String(content.readableText.prefix(4000))
                if !isDuplicateContent(text) {
                    collectedContent.append((url: content.url, title: content.title, text: text))
                }
                // Extract prices if looking for deals
                if goal.lowercased().contains("pris") || goal.lowercased().contains("billig") || goal.lowercased().contains("köp") {
                    await extractPricesFromPage()
                }
                return true
            }
            return false

        case .compare:
            addStep(.thinking, "Jämför insamlad data", "\(collectedContent.count) sidor, \(extractedPrices.count) priser")
            // Comparison is done during result generation
            return true

        case .submitForm:
            addStep(.acting, "Skickar formulär", "")
            return await submitCurrentForm()

        case .login:
            guard let urlStr = step.url, let url = URL(string: urlStr) else { return false }
            addStep(.acting, "Navigerar till inloggning", urlStr)
            await navigateAndWaitForLoad(url: url)
            await humanDelay(min: 0.5, max: 1.5)
            await dismissPageOverlays()
            // User needs to fill in credentials - pause for takeover
            addStep(.waiting, "Väntar på att du fyller i inloggningsuppgifter", "Ta över och logga in, sedan lämna tillbaka kontrollen")
            isPaused = true
            statusLabel = "Väntar på din inloggning..."
            await waitWhilePaused()
            return true

        case .typeText:
            guard let text = step.value else { return false }
            addStep(.acting, "Skriver text", String(text.prefix(40)))
            if humanBehavior {
                return await typeIntoActiveElement(text: text)
            } else {
                _ = await runJS("document.activeElement.value = '\(text.replacingOccurrences(of: "'", with: "\\'"))'")
                return true
            }

        case .screenshot:
            addStep(.reading, "Registrerar sidans tillstånd", "")
            return true
        }
    }

    // MARK: - Obstacle Detection & Handling

    private func handleObstacle(step: ActionStep) async -> Bool {
        addStep(.thinking, "Analyserar hinder", "Försöker lösa problemet...")

        // Detect what kind of obstacle we hit
        let obstacleType = await detectObstacleType()

        switch obstacleType {
        case .cookieBanner:
            addStep(.acting, "Hanterar cookie-banner", "")
            await dismissPageOverlays()
            return true

        case .loginWall:
            addStep(.waiting, "Inloggningsvägg detekterad", "Ta över för att logga in")
            isPaused = true
            statusLabel = "Logga in och lämna tillbaka kontrollen"
            await waitWhilePaused()
            return true

        case .captcha:
            addStep(.waiting, "CAPTCHA detekterad", "Ta över och lös CAPTCHA")
            isPaused = true
            statusLabel = "Lös CAPTCHA och lämna tillbaka kontrollen"
            await waitWhilePaused()
            return true

        case .paywall:
            addStep(.thinking, "Betalvägg detekterad", "Försöker hitta alternativ källa...")
            // Try going back and finding alternative
            await goBack()
            await humanDelay(min: 0.5, max: 1.0)
            return true

        case .rateLimit:
            addStep(.waiting, "Hastighetsbegränsning", "Väntar innan nästa försök...")
            try? await Task.sleep(nanoseconds: humanBehavior ? UInt64.random(in: 3_000_000_000...8_000_000_000) : 2_000_000_000)
            return true

        case .pageNotFound:
            addStep(.thinking, "Sidan hittades inte", "Försöker alternativ väg...")
            await goBack()
            return true

        case .popupBlock:
            await dismissPageOverlays()
            await expandCollapsedContent()
            return true

        case .unknown:
            // Try generic recovery: dismiss overlays, scroll, retry
            await dismissPageOverlays()
            await humanDelay(min: 0.3, max: 0.8)
            await expandCollapsedContent()
            return retryCount < maxRetries
        }
    }

    private enum ObstacleType {
        case cookieBanner, loginWall, captcha, paywall, rateLimit, pageNotFound, popupBlock, unknown
    }

    private func detectObstacleType() async -> ObstacleType {
        let pageInfo = await runJS("""
        (function() {
            var body = document.body ? document.body.innerText.toLowerCase() : '';
            var url = window.location.href.toLowerCase();
            if (body.indexOf('captcha') >= 0 || body.indexOf('recaptcha') >= 0 || body.indexOf('hcaptcha') >= 0 || document.querySelector('iframe[src*="captcha"]')) return 'captcha';
            if (body.indexOf('log in') >= 0 || body.indexOf('logga in') >= 0 || body.indexOf('sign in') >= 0 || url.indexOf('login') >= 0 || url.indexOf('signin') >= 0) {
                var inputs = document.querySelectorAll('input[type="password"]');
                if (inputs.length > 0) return 'login';
            }
            if (body.indexOf('subscribe') >= 0 || body.indexOf('premium') >= 0 || body.indexOf('prenumerera') >= 0 || body.indexOf('paywall') >= 0) {
                var payIndicators = document.querySelectorAll('[class*="paywall"], [class*="premium"], [class*="subscribe"]');
                if (payIndicators.length > 0) return 'paywall';
            }
            if (body.indexOf('rate limit') >= 0 || body.indexOf('too many requests') >= 0 || body.indexOf('429') >= 0) return 'ratelimit';
            if (body.indexOf('404') >= 0 || body.indexOf('not found') >= 0 || body.indexOf('hittades inte') >= 0) return 'notfound';
            var overlays = document.querySelectorAll('[class*="cookie"], [class*="consent"], [role="dialog"]');
            for (var i = 0; i < overlays.length; i++) {
                if (window.getComputedStyle(overlays[i]).display !== 'none') return 'cookie';
            }
            var fixedEls = document.querySelectorAll('[class*="modal"], [class*="popup"], [class*="overlay"]');
            for (var j = 0; j < fixedEls.length; j++) {
                var style = window.getComputedStyle(fixedEls[j]);
                if (style.position === 'fixed' && style.display !== 'none') return 'popup';
            }
            return 'unknown';
        })()
        """)

        switch pageInfo {
        case "captcha": return .captcha
        case "login": return .loginWall
        case "paywall": return .paywall
        case "ratelimit": return .rateLimit
        case "notfound": return .pageNotFound
        case "cookie": return .cookieBanner
        case "popup": return .popupBlock
        default: return .unknown
        }
    }

    // MARK: - Human Behavior Simulation

    private func humanDelay(min: Double, max: Double) async {
        guard humanBehavior else {
            try? await Task.sleep(nanoseconds: UInt64(min * 1_000_000_000))
            return
        }
        let delay = Double.random(in: min...max)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func humanScroll() async {
        // Vary scroll amount and add random pauses
        let scrollAmount = Int.random(in: 50...100)
        _ = await runJS("window.scrollBy({top: window.innerHeight * \(scrollAmount) / 100, behavior: 'smooth'})")
        await humanDelay(min: 0.4, max: 1.2)

        // Sometimes scroll back up a tiny bit (human behavior)
        if Bool.random() && humanBehavior {
            _ = await runJS("window.scrollBy({top: -\(Int.random(in: 30...80)), behavior: 'smooth'})")
            await humanDelay(min: 0.2, max: 0.5)
        }

        // Simulate random mouse movement
        if humanBehavior {
            let x = Int.random(in: 50...350)
            let y = Int.random(in: 100...600)
            _ = await runJS("document.elementFromPoint(\(x), \(y))")
        }
    }

    private func typeWithHumanBehavior(selector: String, text: String) async -> Bool {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")

        // Focus the element first
        let focused = await runJS("(function(){ var el = document.querySelector('\(escaped)'); if(!el) return 'false'; el.focus(); el.click(); el.value = ''; return 'true'; })()")
        guard focused == "true" else { return false }
        await humanDelay(min: 0.2, max: 0.5)

        // Type each character with realistic delays
        for char in text {
            let charEscaped = String(char).replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\\", with: "\\\\")
            _ = await runJS("""
            (function(){
                var el = document.querySelector('\(escaped)');
                if(!el) return;
                el.value += '\(charEscaped)';
                el.dispatchEvent(new Event('input', {bubbles: true}));
                el.dispatchEvent(new KeyboardEvent('keydown', {key: '\(charEscaped)', bubbles: true}));
                el.dispatchEvent(new KeyboardEvent('keyup', {key: '\(charEscaped)', bubbles: true}));
            })()
            """)
            // Human typing speed: 50-150ms per character
            let charDelay = UInt64.random(in: 40_000_000...150_000_000)
            try? await Task.sleep(nanoseconds: charDelay)
        }

        // Final input event
        _ = await runJS("(function(){ var el = document.querySelector('\(escaped)'); if(el){ el.dispatchEvent(new Event('change', {bubbles: true})); } })()")
        return true
    }

    private func typeIntoActiveElement(text: String) async -> Bool {
        // Type into whatever element is currently focused
        for char in text {
            let charEscaped = String(char).replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\\", with: "\\\\")
            _ = await runJS("""
            (function(){
                var el = document.activeElement;
                if(!el) return;
                if(el.isContentEditable) {
                    document.execCommand('insertText', false, '\(charEscaped)');
                } else {
                    el.value = (el.value || '') + '\(charEscaped)';
                    el.dispatchEvent(new Event('input', {bubbles: true}));
                }
            })()
            """)
            if humanBehavior {
                let charDelay = UInt64.random(in: 40_000_000...150_000_000)
                try? await Task.sleep(nanoseconds: charDelay)
            }
        }
        return true
    }

    // MARK: - Form Interaction

    private func fillInputField(selector: String, value: String) async -> Bool {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        let valueEscaped = value.replacingOccurrences(of: "'", with: "\\'")
        let result = await runJS("""
        (function(){
            var el = document.querySelector('\(escaped)');
            if(!el) {
                // Try by name, id, placeholder, aria-label
                el = document.querySelector('input[name*="\(escaped)"], input[id*="\(escaped)"], input[placeholder*="\(escaped)"], input[aria-label*="\(escaped)"], textarea[name*="\(escaped)"], textarea[placeholder*="\(escaped)"]');
            }
            if(!el) return 'false';
            el.focus();
            el.value = '\(valueEscaped)';
            el.dispatchEvent(new Event('input', {bubbles: true}));
            el.dispatchEvent(new Event('change', {bubbles: true}));
            return 'true';
        })()
        """)
        return result == "true"
    }

    private func selectOption(selector: String, value: String) async -> Bool {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        let valueEscaped = value.replacingOccurrences(of: "'", with: "\\'")
        let result = await runJS("""
        (function(){
            var el = document.querySelector('\(escaped)');
            if(!el) el = document.querySelector('select[name*="\(escaped)"]');
            if(!el || el.tagName !== 'SELECT') return 'false';
            for(var i = 0; i < el.options.length; i++) {
                if(el.options[i].text.toLowerCase().indexOf('\(valueEscaped)'.toLowerCase()) >= 0 ||
                   el.options[i].value.toLowerCase().indexOf('\(valueEscaped)'.toLowerCase()) >= 0) {
                    el.selectedIndex = i;
                    el.dispatchEvent(new Event('change', {bubbles: true}));
                    return 'true';
                }
            }
            return 'false';
        })()
        """)
        return result == "true"
    }

    private func submitCurrentForm() async -> Bool {
        let result = await runJS("""
        (function(){
            // Try submit button first
            var submit = document.querySelector('button[type="submit"], input[type="submit"], button.submit, [class*="submit"]');
            if(submit) { submit.click(); return 'clicked'; }
            // Try finding a form and submitting it
            var form = document.querySelector('form');
            if(form) { form.submit(); return 'submitted'; }
            // Try Enter key on active element
            var active = document.activeElement;
            if(active) {
                active.dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true}));
                return 'enter';
            }
            return 'false';
        })()
        """)
        await humanDelay(min: 1.0, max: 2.5)
        return result != "false"
    }

    private func smartClick(description: String) async -> Bool {
        // Use Qwen to find the right element on the page
        guard let content = await extractWithRetry() else { return false }

        let clickableElements = content.links.prefix(20).enumerated().map { i, link in
            "\(i+1). [\(link.text.prefix(40))]"
        }.joined(separator: "\n")

        let prompt = """
        Uppgift: \(description)
        Klickbara element på sidan:
        \(clickableElements)
        Vilket nummer ska klickas? Svara BARA med ett nummer.
        """

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 5, temperature: 0.1, enableThinking: false
        )

        let digits = result.filter(\.isNumber)
        if let num = Int(digits), num > 0, num <= content.links.count {
            let link = content.links[num - 1]
            if let url = URL(string: link.href) {
                await navigateAndWaitForLoad(url: url)
                await humanDelay(min: 0.3, max: 1.0)
                await dismissPageOverlays()
                return true
            }
        }
        return false
    }

    // MARK: - Price Extraction

    private func extractPricesFromPage() async {
        let priceJSON = await runJS("""
        (function(){
            var results = [];
            // Common price patterns
            var priceRegex = /(?:kr|SEK|\\$|€|USD|EUR|:-)[\\s]?[\\d\\s,.]+|[\\d\\s,.]+[\\s]?(?:kr|SEK|\\$|€|USD|EUR|:-)/gi;
            var priceElements = document.querySelectorAll('[class*="price"], [class*="pris"], [class*="cost"], [class*="amount"], [data-price], [itemprop="price"]');

            for(var i = 0; i < Math.min(priceElements.length, 20); i++) {
                var text = (priceElements[i].innerText || '').trim();
                if(text.length > 0 && text.length < 50) {
                    var parent = priceElements[i].closest('article, [class*="product"], [class*="item"], [class*="card"], li');
                    var name = '';
                    if(parent) {
                        var titleEl = parent.querySelector('h2, h3, h4, a[class*="title"], [class*="name"], [class*="titel"]');
                        if(titleEl) name = (titleEl.innerText || '').trim().substring(0, 80);
                    }
                    if(!name) name = 'Produkt ' + (i+1);
                    results.push({item: name, price: text});
                }
            }

            // Fallback: scan body text for prices
            if(results.length === 0) {
                var bodyText = document.body ? document.body.innerText : '';
                var matches = bodyText.match(priceRegex);
                if(matches) {
                    for(var m = 0; m < Math.min(matches.length, 10); m++) {
                        results.push({item: 'Pris ' + (m+1), price: matches[m].trim()});
                    }
                }
            }

            return JSON.stringify(results);
        })()
        """)

        guard let jsonString = priceJSON,
              let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return }

        let currentURL = self.currentURL?.absoluteString ?? ""
        for item in array {
            if let itemName = item["item"], let price = item["price"] {
                extractedPrices.append((item: itemName, price: price, url: currentURL))
            }
        }

        if !extractedPrices.isEmpty {
            addStep(.extracting, "Hittade \(extractedPrices.count) priser", extractedPrices.prefix(3).map { "\($0.item): \($0.price)" }.joined(separator: ", "))
        }
    }

    // MARK: - Action Result Generation

    private func generateActionResult() async {
        addStep(.writing, "Sammanställer resultat", "\(collectedContent.count) sidor, \(extractedPrices.count) priser")
        statusLabel = "Skriver resultat..."
        progress = 0.9

        var resultText = ""

        if !extractedPrices.isEmpty {
            // Price comparison result
            let priceList = extractedPrices.prefix(15).map { "\($0.item): \($0.price)" }.joined(separator: "\n")
            let prompt = """
            Du är en prisexpert. Analysera dessa priser och ge en rekommendation:
            MÅL: \(goal)

            HITTADE PRISER:
            \(priceList)

            Ge en tydlig sammanfattning: Vilken är billigast? Bäst valuta för pengarna? Rekommendation?
            Skriv på svenska, max 300 ord.
            """
            resultText = await generateWithQwen(prompt: prompt, maxTokens: 500)
        }

        if resultText.isEmpty && !collectedContent.isEmpty {
            let combinedContent = collectedContent.map { "[\($0.title)]\n\($0.text)" }.joined(separator: "\n---\n")
            let prompt = """
            UPPGIFT: \(goal)
            RESULTAT: Sammanfatta vad som gjordes och hittades.

            INSAMLAD DATA:
            \(String(combinedContent.prefix(3000)))

            Skriv en tydlig rapport om resultaten. Svenska, max 400 ord.
            """
            resultText = await generateWithQwen(prompt: prompt, maxTokens: 600)
        }

        if resultText.isEmpty {
            resultText = "Uppgiften utförd. \(collectedContent.count) sidor besökta, \(extractedPrices.count) priser hittade."
        }

        let title = await generateTitle() ?? "Resultat: \(String(goal.prefix(30)))"
        let sources = Array(visitedURLs)

        result = BrowseResult(title: title, summary: resultText, sources: sources,
                              fullContent: collectedContent.map(\.text).joined(separator: "\n"), articleDomain: nil)
        addStep(.done, "Uppgift slutförd!", "\(collectedContent.count) sidor, \(sources.count) källor")
        statusLabel = "Klar"
        progress = 1.0
        isBrowsing = false
    }

    // MARK: - JS Action Helpers

    private func runJS(_ script: String) async -> String? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let resumeOnce: (String?) -> Void = { value in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            guard let onRunJS else {
                resumeOnce(nil)
                return
            }

            onRunJS(script) { result in
                resumeOnce(result)
            }

            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                resumeOnce(nil)
            }
        }
    }

    @discardableResult
    private func clickElement(_ selector: String) async -> Bool {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\\", with: "\\\\")
        let result = await runJS("window.eonClickElement('\(escaped)')")
        return result == "true"
    }

    private func scrollPageDown() async {
        if humanBehavior {
            await humanScroll()
        } else {
            _ = await runJS("window.eonScrollDown()")
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }

    private func dismissPageOverlays() async {
        _ = await runJS("window.eonDismissOverlays()")
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    private func expandCollapsedContent() async {
        _ = await runJS("window.eonExpandContent()")
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    private func extractSearchResults() async -> [SearchResult] {
        guard let jsonString = await runJS("window.eonExtractSearchResults()") else { return [] }
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return array.compactMap { dict -> SearchResult? in
            guard let title = dict["title"] as? String,
                  let url = dict["url"] as? String,
                  let index = dict["index"] as? Int else { return nil }
            let snippet = dict["snippet"] as? String ?? ""
            return SearchResult(title: title, snippet: snippet, url: url, index: index)
        }
    }

    private func goBack() async {
        onGoBack?()
        try? await Task.sleep(nanoseconds: 1_200_000_000)
    }

    // MARK: - Search result ranking with Qwen

    private func rankSearchResults(_ results: [SearchResult]) async -> [SearchResult] {
        guard results.count > 3 else { return results }
        let top = Array(results.prefix(10))
        let listing = top.enumerated().map { i, r in
            "\(i+1). \(r.title) — \(r.snippet.prefix(80))"
        }.joined(separator: "\n")

        let prompt = """
        MÅL: \(goal)
        
        Sökresultat:
        \(listing)
        
        Ranka de 5 BÄSTA resultaten för målet i prioritetsordning.
        Svara BARA med siffrorna separerade med komma. Exempel: 3,1,5,2,7
        """

        let raw = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 20, temperature: 0.1, enableThinking: false
        )

        let indices = raw.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
            .filter { $0 > 0 && $0 <= top.count }

        guard indices.count >= 2 else { return results }

        var ranked: [SearchResult] = []
        var seen = Set<Int>()
        for idx in indices {
            let zeroIdx = idx - 1
            if !seen.contains(zeroIdx) {
                ranked.append(top[zeroIdx])
                seen.insert(zeroIdx)
            }
        }
        for (i, r) in top.enumerated() where !seen.contains(i) {
            ranked.append(r)
        }
        return ranked
    }

    // MARK: - Smart link selection

    private func selectBestLink(from links: [(text: String, href: String)]) async -> (text: String, href: String)? {
        if let qwenChoice = await selectLinkWithQwen(links: links) {
            return qwenChoice
        }
        return selectLinkWithKeywords(links: links)
    }

    private func selectLinkWithQwen(links: [(text: String, href: String)]) async -> (text: String, href: String)? {
        let top = Array(links.prefix(12))
        let linkList = top.enumerated().map { i, link in
            "\(i+1). [\(link.text.prefix(60))] → \(URL(string: link.href)?.host?.replacingOccurrences(of: "www.", with: "") ?? String(link.href.prefix(40)))"
        }.joined(separator: "\n")

        let prompt = """
        MÅL: \(goal)
        Redan insamlat: \(collectedContent.count) sidor (\(collectedContent.map(\.text).joined().count) tecken)
        
        Tillgängliga länkar:
        \(linkList)
        
        Vilken länk (1-\(top.count)) är MEST relevant för att hitta NY, unik information om målet?
        Undvik sidor som troligen liknar redan besökta.
        Svara med BARA ett nummer (1-\(top.count)), eller 0 om ingen.
        """

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 8, temperature: 0.1, enableThinking: false
        )

        let digits = result.filter(\.isNumber)
        if let num = Int(digits), num > 0, num <= top.count {
            return top[num - 1]
        }
        return nil
    }

    private func selectLinkWithKeywords(links: [(text: String, href: String)]) -> (text: String, href: String)? {
        let goalWords = Set(goal.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
        guard !goalWords.isEmpty else { return links.first }

        var bestLink: (text: String, href: String)?
        var bestScore = 0

        for link in links {
            let linkWords = Set(link.text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            let hrefWords = Set(link.href.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 })
            let score = goalWords.intersection(linkWords).count * 3 + goalWords.intersection(hrefWords).count
            if score > bestScore {
                bestScore = score
                bestLink = link
            }
        }

        return bestScore > 0 ? bestLink : links.first
    }

    // MARK: - Search query generation

    private func generateSearchQuery() async -> String {
        let qwenQuery = await generateSearchQueryWithQwen()
        if !qwenQuery.isEmpty && qwenQuery.split(separator: " ").count >= 2 {
            return qwenQuery
        }
        return generateSearchQueryWithNL()
    }

    private func generateSearchQueryWithQwen() async -> String {
        let modeHint: String = {
            switch mode {
            case .article: return "kunskapsartikel"
            case .action: return "webbsida för att utföra uppgiften"
            case .research: return "information"
            }
        }()
        let prompt = """
        UPPGIFT: Skriv en Google-sökfråga (max 8 ord) för att hitta \(modeHint) om: \(goal)
        REGLER: Svara BARA med sökorden. Inga meningar. Inga förklaringar.
        Sökfråga:
        """

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 20, temperature: 0.2, enableThinking: false
        )

        let cleaned = result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Validate: if Qwen returned a conversational response instead of search terms, fall back
        let invalidPhrases = ["spännande", "fascinerande", "intressant", "jag", "du är", "vad roligt",
                              "det du", "som jag", "berätta", "kan analyseras", "gärna"]
        let lower = cleaned.lowercased()
        if invalidPhrases.contains(where: { lower.contains($0) }) || cleaned.split(separator: " ").count > 12 {
            return "" // Fall back to NL-based query generation
        }

        return cleaned
    }

    private func generateAlternativeQuery(original: String) async -> String {
        let prompt = """
        Sökningen "\(original)" gav inte tillräckligt med resultat om: \(goal)
        UPPGIFT: Skriv en ALTERNATIV sökfråga (max 8 ord) med andra nyckelord.
        REGLER: Svara BARA med sökorden. Inga meningar.
        Alternativ sökfråga:
        """

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 20, temperature: 0.4, enableThinking: false
        )

        let cleaned = result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Validate: reject conversational responses
        let invalidPhrases = ["spännande", "fascinerande", "intressant", "jag", "du är", "vad roligt",
                              "det du", "som jag", "berätta", "gärna"]
        let lower = cleaned.lowercased()
        if invalidPhrases.contains(where: { lower.contains($0) }) || cleaned.split(separator: " ").count > 12 {
            return ""
        }

        return cleaned
    }

    private func generateSearchQueryWithNL() -> String {
        tagger.string = goal
        var nouns: [String] = []
        var entities: [String] = []

        tagger.enumerateTags(in: goal.startIndex..<goal.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(goal[range])
            if tag == .noun && word.count > 2 { nouns.append(word) }
            return true
        }

        tagger.enumerateTags(in: goal.startIndex..<goal.endIndex, unit: .word,
                             scheme: .nameType, options: [.omitWhitespace, .joinNames]) { tag, range in
            if tag != nil { entities.append(String(goal[range])) }
            return true
        }

        let keywords = (entities + nouns).prefix(5)
        return keywords.isEmpty ? String(goal.prefix(60)) : keywords.joined(separator: " ")
    }

    // MARK: - Navigation with page load wait

    private func navigateAndWaitForLoad(url: URL) async {
        addStep(.navigating, "Navigerar", url.host ?? url.absoluteString)
        currentURL = url
        onNavigate?(url)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.pageLoadContinuation = continuation
            Task {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                if self.pageLoadContinuation != nil {
                    self.pageLoadContinuation?.resume()
                    self.pageLoadContinuation = nil
                }
            }
        }

        // Human-like wait after page load
        await humanDelay(min: 0.5, max: 1.5)
    }

    // MARK: - Extraction with retry

    private func extractWithRetry() async -> PageContent? {
        for attempt in 1...3 {
            if let content = await extractWithTimeout() {
                return content
            }
            if attempt < 3 {
                await scrollPageDown()
                await dismissPageOverlays()
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
        return nil
    }

    private func extractWithTimeout() async -> PageContent? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let resumeOnce: (PageContent?) -> Void = { content in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: content)
            }

            onExtractContent? { content in
                resumeOnce(content)
            }

            Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                resumeOnce(nil)
            }
        }
    }

    // MARK: - Link filtering

    private static let blockedDomains: Set<String> = [
        "facebook.com", "twitter.com", "instagram.com", "tiktok.com", "youtube.com",
        "linkedin.com", "pinterest.com", "reddit.com/r/", "accounts.google",
        "play.google.com", "apps.apple.com", "maps.google", "x.com",
        "snapchat.com", "whatsapp.com", "discord.com", "spotify.com"
    ]

    private static let blockedPaths: Set<String> = [
        "login", "signup", "register", "signin", "auth", "oauth", "cookie", "privacy",
        "terms", "gdpr", "consent", "subscribe", "newsletter", "cart", "checkout",
        "account", "password", "forgot", "#", "javascript:", "mailto:", "tel:",
        "download", "install", "app-store", "play-store"
    ]

    private func filterLinks(_ links: [(text: String, href: String)]) -> [(text: String, href: String)] {
        let isActionMode = mode == .action
        return links.filter { link in
            guard !visitedURLs.contains(link.href),
                  link.href.hasPrefix("http"),
                  link.text.count > 3,
                  link.text.count < 200 else { return false }

            let hrefLower = link.href.lowercased()
            let textLower = link.text.lowercased()

            // In action mode, allow auth-related paths (login, signup etc.)
            let effectiveBlockedPaths: Set<String> = isActionMode
                ? Self.blockedPaths.subtracting(["login", "signup", "register", "signin", "auth", "oauth", "account", "password"])
                : Self.blockedPaths

            for blocked in Self.blockedDomains {
                if hrefLower.contains(blocked) { return false }
            }
            for blocked in effectiveBlockedPaths {
                if hrefLower.contains(blocked) { return false }
            }

            var navWords: Set<String> = ["menu", "meny", "hem", "home", "about", "om oss", "kontakt",
                                          "contact", "cookie", "acceptera",
                                          "share", "dela", "print", "skriv ut", "previous", "next",
                                          "föregående", "nästa"]
            // In action mode, don't block login-related navigation
            if !isActionMode {
                navWords.insert("logga in")
                navWords.insert("log in")
                navWords.insert("sign in")
            }
            if navWords.contains(where: { textLower == $0 || textLower.hasPrefix($0 + " ") }) { return false }

            return true
        }
    }

    // MARK: - Deduplication

    private func isDuplicateContent(_ text: String) -> Bool {
        let newWords = Set(text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 4 })
        guard newWords.count > 5 else { return false }

        for existing in collectedContent {
            let existingWords = Set(existing.text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 4 })
            let overlap = Double(newWords.intersection(existingWords).count) / Double(max(newWords.count, 1))
            if overlap > 0.6 { return true }
        }
        return false
    }

    // MARK: - Result generation

    private func generateFinalResult() async {
        addStep(.writing, "Sammanställer resultat",
                "Analyserar \(collectedContent.count) sidor med \(collectedContent.map(\.text).joined().count) tecken...")
        statusLabel = "Skriver resultat..."
        progress = 0.9

        let combinedContent = collectedContent.map { "[\($0.title)]\n\($0.text)" }.joined(separator: "\n---\n")
        let sources = collectedContent.map(\.url)

        switch mode {
        case .research:
            await generateResearchResult(content: combinedContent, sources: sources)
        case .article:
            await generateArticleResult(content: combinedContent, sources: sources)
        case .action:
            await generateResearchResult(content: combinedContent, sources: sources)
        }
    }

    private func generateResearchResult(content: String, sources: [String]) async {
        var extraContext = ""
        if !extractedPrices.isEmpty {
            let priceList = extractedPrices.prefix(15).map { "\($0.item): \($0.price)" }.joined(separator: "\n")
            extraContext = "\n\nHITTADE PRISER:\n\(priceList)\n"
        }

        let qwenResult = await generateWithQwen(
            prompt: """
            Du är en erfaren forskare. Besvara på svenska med fakta och substans:

            FRÅGA: \(goal)

            INSAMLAD DATA (\(collectedContent.count) källor):
            \(String(content.prefix(3000)))
            \(extraContext)
            Instruktioner:
            - Sammanfatta de viktigaste fynden med konkreta fakta
            - Strukturera med tydliga stycken
            - Nämn specifika siffror, namn, datum om tillgängligt
            - Om priser hittades: rangordna från billigast till dyrast och ge rekommendation
            - Skriv max 500 ord, varmt och engagerande
            """,
            maxTokens: 700
        )

        let summary = qwenResult.isEmpty ? buildNLSummary(from: content) : qwenResult
        let title = await generateTitle() ?? "Resultat: \(String(goal.prefix(30)))"

        result = BrowseResult(title: title, summary: summary, sources: sources,
                              fullContent: content, articleDomain: nil)
        addStep(.done, "Forskning klar!", "\(collectedContent.count) sidor, \(sources.count) källor\(extractedPrices.isEmpty ? "" : ", \(extractedPrices.count) priser")")
        statusLabel = "Klar"
        progress = 1.0
        isBrowsing = false
    }

    private func generateArticleResult(content: String, sources: [String]) async {
        let qwenResult = await generateWithQwen(
            prompt: """
            Skriv en professionell kunskapsartikel på svenska:
            
            ÄMNE: \(goal)
            KATEGORI: \(articleDomain)
            
            KÄLLMATERIAL (\(collectedContent.count) sidor):
            \(String(content.prefix(3000)))
            
            Format:
            - 400-600 ord
            - Välstrukturerad med inledning, huvudinnehåll och sammanfattning
            - Faktagrundad med konkreta detaljer
            - Pedagogisk och engagerande
            - BARA brödtext, inga rubriker med #
            """,
            maxTokens: 900
        )

        let articleContent = qwenResult.isEmpty ? buildNLSummary(from: content) : qwenResult
        let title = await generateTitle() ?? "\(String(goal.prefix(40)))"
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourcesStr = sources.prefix(4).joined(separator: "; ")

        let article = KnowledgeArticle(
            title: cleanTitle,
            content: articleContent,
            summary: String(articleContent.prefix(140)) + "...",
            domain: articleDomain,
            source: sourcesStr,
            date: Date(),
            isAutonomous: true
        )

        let saved = await PersistentMemoryStore.shared.saveArticle(article)

        result = BrowseResult(title: cleanTitle, summary: articleContent, sources: sources,
                              fullContent: content, articleDomain: articleDomain)
        addStep(.done, saved ? "Artikel sparad i \(articleDomain)!" : "Artikel skapad",
                "\(collectedContent.count) källor")
        statusLabel = "Klar"
        progress = 1.0
        isBrowsing = false
    }

    // MARK: - Save key findings to persistent memory

    private func saveDiscoveredKnowledge() async {
        guard !collectedContent.isEmpty else { return }

        let subject = String(goal.prefix(80))
        for item in collectedContent.prefix(3) {
            let factSnippet = String(item.text.prefix(200))
            await PersistentMemoryStore.shared.saveFact(
                subject: subject,
                predicate: "web_research_found",
                object: "[\(item.title)] \(factSnippet)",
                confidence: 0.6,
                source: item.url
            )
        }
    }

    // MARK: - Qwen wrapper

    private func generateWithQwen(prompt: String, maxTokens: Int) async -> String {
        let thermalState = ProcessInfo.processInfo.thermalState
        guard thermalState != .critical else { return "" }

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: maxTokens, temperature: 0.5, enableThinking: true
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateTitle() async -> String? {
        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: "Skriv en kort och beskrivande rubrik (max 8 ord) för: \(goal)\nSvara BARA med rubriken.",
            maxTokens: 20, temperature: 0.3
        )
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count > 2 ? cleaned : nil
    }

    // MARK: - NL Fallback summary

    private func buildNLSummary(from content: String) -> String {
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 && $0.count < 300 }

        let goalWords = Set(goal.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })

        let scored = sentences.map { sentence -> (String, Int) in
            let words = Set(sentence.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            return (sentence, goalWords.intersection(words).count)
        }

        let topSentences = scored.sorted { $0.1 > $1.1 }.prefix(8).map(\.0)

        if topSentences.isEmpty {
            return "Eon hittade information men kunde inte sammanfatta den automatiskt. Rådata finns tillgängligt."
        }

        return topSentences.joined(separator: ". ") + "."
    }

    // MARK: - Helpers

    private func buildSearchURL(query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)&hl=sv")!
    }

    private func addStep(_ type: BrowseStep.StepType, _ message: String, _ detail: String) {
        steps.append(BrowseStep(icon: type.icon, message: message, detail: detail, type: type))
    }

    private func waitWhilePaused() async {
        while isPaused && isBrowsing {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }
}

extension BrowseStep.StepType {
    var icon: String {
        switch self {
        case .thinking:   return "brain.head.profile"
        case .navigating: return "globe"
        case .reading:    return "doc.text.magnifyingglass"
        case .extracting: return "text.magnifyingglass"
        case .writing:    return "pencil.line"
        case .acting:     return "hand.tap.fill"
        case .waiting:    return "hourglass"
        case .done:       return "checkmark.circle.fill"
        case .error:      return "exclamationmark.triangle.fill"
        }
    }
}
