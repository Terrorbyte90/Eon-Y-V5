
import Foundation

struct EonWorldModel {
    var domains: [String: Double] = [
        "Naturvetenskap": 0.4, "Humaniora": 0.5, "Teknik": 0.6,
        "Filosofi": 0.55, "Psykologi": 0.5, "Historia": 0.45
    ]
    var causalChains: [[String]] = []
    var version: Int = 0

    mutating func update(knowledgeCount: Int, phi: Double, hypotheses: [EonHypothesis], stage: DevelopmentalStage) {
        version += 1
        for key in domains.keys {
            domains[key] = min(0.99, (domains[key] ?? 0.5) + Double(knowledgeCount) * 0.00002 + phi * 0.001)
        }
        for h in hypotheses.suffix(3) where h.domain != nil {
            if let domain = h.domain {
                domains[domain] = min(0.99, (domains[domain] ?? 0.5) + 0.003)
            }
        }
    }

    func generateInsight() -> String {
        let topDomain = domains.max(by: { $0.value < $1.value })
        let insights = [
            "Kausala mönster identifierade i \(topDomain?.key ?? "okänd domän") (konfidens: \(Int((topDomain?.value ?? 0.5) * 100))%)",
            "Domänöverskridande kopplingar: \(domains.filter { $0.value > 0.6 }.count) starka noder",
            "Världsmodell v\(version): \(String(format: "%.0f", domains.values.reduce(0, +) / Double(max(domains.count, 1)) * 100))% täckning",
        ]
        return insights.randomElement() ?? "Världsmodell uppdaterad"
    }
}

// MARK: - EonHypothesis
