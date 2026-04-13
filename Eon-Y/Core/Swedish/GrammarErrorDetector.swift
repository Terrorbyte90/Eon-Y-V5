import Foundation

actor GrammarErrorDetector {
    static let shared = GrammarErrorDetector()

    private let errorPatterns: [(pattern: String, description: String, correction: String)] = [
        ("en (hus|barn|ord|äpple|djur|hjärta|öga|öra)", "En/ett-fel: neutrum", "Använd 'ett'"),
        ("ett (bil|stol|bok|flicka|pojke|kvinna|man)", "En/ett-fel: utrum", "Använd 'en'"),
        ("^(igår|idag|imorgon|sedan|dock|dessutom|därför) [^,]+ (jag|han|hon|vi|de|du) (är|har|ska|kan|vill|måste)", "V2-regelbrott", "Flytta verbet till position 2"),
        ("den (stora|lilla|gamla|nya|fina|röda|blå) (huset|barnet|bordet)", "Inkongruens: den + neutrum", "Använd 'det'"),
    ]

    func detectErrors(in text: String) -> [GrammarError] {
        var errors: [GrammarError] = []
        let lower = text.lowercased()
        for (pattern, desc, correction) in errorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
                errors.append(GrammarError(matchedText: text.prefix(30), description: desc, suggestion: correction, severity: .medium))
            }
        }
        return errors
    }
}

struct GrammarError {
    let matchedText: String
    let description: String
    let suggestion: String
    let severity: ErrorSeverity

    enum ErrorSeverity {
        case low, medium, high
    }
}
