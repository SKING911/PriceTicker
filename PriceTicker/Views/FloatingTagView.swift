import SwiftUI

struct FloatingTagView: View {
    let ticker: Ticker
    @ObservedObject var priceService: PriceService

    private var price: TickerPrice?    { priceService.prices[ticker.id] }
    private var lastUpdated: Date?     { priceService.lastUpdated[ticker.id] }
    private var hasError: Bool         { priceService.errors[ticker.id] != nil }

    // MARK: - Staleness

    /// Seconds since last successful update.
    private var dataAge: TimeInterval {
        guard let t = lastUpdated else { return .infinity }
        return Date().timeIntervalSince(t)
    }

    /// Opacity dims when data hasn't refreshed in a while.
    private var contentOpacity: Double {
        if !priceService.isConnected { return 0.45 }
        if dataAge > 12 { return 0.5 }
        return 1.0
    }

    // MARK: - Body

    var body: some View {
        // Refresh the view every second so staleness indicators stay current
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            pillContent
        }
    }

    private var pillContent: some View {
        HStack(spacing: 5) {
            if let p = price {
                Text(formatBinancePrice(p.priceDisplay))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text(formatChange(p.changePercent))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(changeColor(p.changePercent))

            } else if hasError {
                Text("--")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))

            } else {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
            }
        }
        .opacity(contentOpacity)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tagBackground)
        .padding(5)
        .fixedSize()
    }

    // MARK: - Background

    private var tagBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.55))
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }

    // MARK: - Formatting

    private func formatChange(_ pct: Double) -> String {
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pct))%"
    }

    private func changeColor(_ pct: Double) -> Color {
        if pct > 0 { return Color(red: 0.2, green: 0.9, blue: 0.5) }
        if pct < 0 { return Color(red: 1.0, green: 0.35, blue: 0.35) }
        return .gray
    }
}
