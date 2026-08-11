import SwiftUI

enum EonV6Theme {
    static let ink = Color(hex: "#080A12")
    static let panel = Color(hex: "#111625")
    static let panelRaised = Color(hex: "#182034")
    static let cyan = Color(hex: "#6DE7F5")
    static let indigo = Color(hex: "#9C8CFF")
    static let amber = Color(hex: "#F7C66B")
    static let coral = Color(hex: "#FF8D82")
    static let mint = Color(hex: "#74E1B2")
}

struct EonV6Card<Content: View>: View {
    let title: String
    let eyebrow: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(eyebrow.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(accent)
                Spacer()
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            }
            content
        }
        .padding(18)
        .background(EonV6Theme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(accent.opacity(0.16), lineWidth: 1))
    }
}

struct EonV6Metric: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.48))
        }
    }
}
