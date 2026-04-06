import Foundation
import CoreGraphics

struct Ticker: Identifiable, Codable, Equatable {
    var id = UUID()
    var symbol: String        // e.g. "BTCUSDT"
    var displayName: String   // e.g. "BTC"
    var marketType: MarketType

    // Store position as plain doubles so Codable works simply
    var windowX: Double?
    var windowY: Double?

    var windowPosition: CGPoint? {
        get {
            guard let x = windowX, let y = windowY else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            windowX = newValue.map { Double($0.x) }
            windowY = newValue.map { Double($0.y) }
        }
    }

    enum MarketType: String, Codable, CaseIterable, Identifiable {
        case spot    = "Spot"
        case futures = "Futures (Perp)"

        var id: String { rawValue }

        var apiBase: String {
            switch self {
            case .spot:    return "https://api.binance.com/api/v3/ticker/24hr"
            case .futures: return "https://fapi.binance.com/fapi/v1/ticker/24hr"
            }
        }
    }
}

struct TickerPrice: Equatable {
    let price: Double
    let changePercent: Double
    let priceDisplay: String    // raw string from Binance, e.g. "95234.10"
}

/// Formats a Binance price string: strips trailing decimal zeros and adds
/// thousand separators to the integer part. No Double conversion → no precision loss.
/// e.g. "1.1900000" → "$1.19"  "95234.10" → "$95,234.1"  "0.0011575" → "$0.0011575"
func formatBinancePrice(_ raw: String) -> String {
    guard !raw.isEmpty else { return "--" }
    let parts = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let intPart = String(parts[0])
    guard let intVal = Int(intPart) else { return "$\(raw)" }
    let intFormatted = intVal.formatted()
    if parts.count == 2 {
        let trimmed = String(parts[1]).replacingOccurrences(
            of: "0+$", with: "", options: .regularExpression)
        return trimmed.isEmpty ? "$\(intFormatted)" : "$\(intFormatted).\(trimmed)"
    }
    return "$\(intFormatted)"
}
