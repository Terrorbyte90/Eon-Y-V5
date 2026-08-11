import Foundation

enum EonTextSanitizer {
    static func clean(_ input: String, maxLength: Int = 220) -> String {
        var text = input.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        let marker = "Jag riktar uppmärksamheten mot"
        while text.lowercased().components(separatedBy: marker.lowercased()).count > 2 {
            if let range = text.range(of: marker, options: [.caseInsensitive, .backwards]) {
                text.removeSubrange(range)
            } else { break }
        }
        text = text.replacingOccurrences(of: "  ", with: " ")
        if text.count > maxLength { text = String(text.prefix(maxLength - 1)) + "…" }
        return text
    }

    static func isRecursive(_ input: String) -> Bool {
        input.lowercased().components(separatedBy: "jag riktar uppmärksamheten mot").count > 2
    }
}
