import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var leaderboard: LeaderboardService
    @ObservedObject var store: TickerStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                section(title: "Top Gainers", entries: leaderboard.topGainers)
                Divider().padding(.vertical, 6)
                section(title: "Top Losers",  entries: leaderboard.topLosers)
            }
            .padding(.vertical, 8)
        }
        .overlay {
            if leaderboard.isLoading && leaderboard.topGainers.isEmpty {
                ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = leaderboard.errorMessage, leaderboard.topGainers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { leaderboard.fetch() }
                        .controlSize(.small)
                }
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let date = leaderboard.lastFetched {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Updated \(date, style: .relative) ago")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Section

    private func section(title: String, entries: [LeaderboardEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            ForEach(entries) { entry in
                LeaderboardRow(entry: entry, store: store)
                if entry.id != entries.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    @ObservedObject var store: TickerStore

    private var isAdded: Bool {
        store.tickers.contains {
            $0.symbol == entry.symbol && $0.marketType == .futures
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Base asset
            Text(entry.baseAsset)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 48, alignment: .leading)

            // Change %
            Text(formatChange(entry.changePercent))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(changeColor(entry.changePercent))
                .frame(width: 60, alignment: .trailing)

            // Price
            Text(formatBinancePrice(entry.priceDisplay))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            // Quick-add button
            Button {
                let t = Ticker(
                    symbol: entry.symbol,
                    displayName: entry.baseAsset,
                    marketType: .futures
                )
                store.add(t)
            } label: {
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isAdded ? .secondary : .accentColor)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    // MARK: Formatting

    private func formatChange(_ pct: Double) -> String {
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pct))%"
    }

    private func changeColor(_ pct: Double) -> Color {
        pct >= 0 ? Color(red: 0.2, green: 0.9, blue: 0.5) : Color(red: 1.0, green: 0.35, blue: 0.35)
    }
}
