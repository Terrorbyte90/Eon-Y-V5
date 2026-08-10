import SwiftUI

/// Shared explanation for all cognitive and consciousness-related dashboards.
/// Keeps the UI from presenting derived proxies as phenomenal measurements.
struct MeasurementProvenanceLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("MÄTNINGARNAS STATUS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Color(hex: "#38BDF8"))
            Text("Observerat = direkt systemsignal. Proxy = beräknat mått på intern organisation. Hypotes = tolkning som måste testas. Inget värde visar subjektiv upplevelse eller qualia.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#38BDF8").opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#38BDF8").opacity(0.18), lineWidth: 0.7))
    }
}
