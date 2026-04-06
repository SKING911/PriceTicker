import SwiftUI

struct LeaderboardPanelView: View {
    @ObservedObject var leaderboard: LeaderboardService
    /// Plain value — updated externally by replacing NSHostingController.rootView.
    var showGainers: Bool

    private var entries: [LeaderboardEntry] {
        showGainers ? leaderboard.topGainers : leaderboard.topLosers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            separator
            rows
        }
        .background(background)
        .padding(5)
        .fixedSize()
    }

    // MARK: - Sub-views

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: showGainers ? "arrow.up" : "arrow.down")
                .font(.system(size: 8, weight: .bold))
            Text("Top 5")
                .font(.system(size: 9, weight: .bold))
            Spacer()
            if leaderboard.isLoading {
                ProgressView()
                    .scaleEffect(0.4)
                    .frame(width: 10, height: 10)
            }
        }
        .foregroundColor(.white.opacity(0.4))
        .padding(.horizontal, 9)
        .padding(.top, 7)
        .padding(.bottom, 4)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, 6)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                HStack(spacing: 0) {
                    Text(entry.baseAsset)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 40, alignment: .leading)
                    Spacer()
                    Text(formatChange(entry.changePercent))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(changeColor(entry.changePercent))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
            }
        }
        .padding(.top, 3)
        .padding(.bottom, 7)
    }

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.55))
            RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }

    // MARK: - Formatting

    private func formatChange(_ pct: Double) -> String {
        "\(pct >= 0 ? "+" : "")\(String(format: "%.2f", pct))%"
    }

    private func changeColor(_ pct: Double) -> Color {
        pct >= 0
            ? Color(red: 0.2, green: 0.9, blue: 0.5)
            : Color(red: 1.0, green: 0.35, blue: 0.35)
    }
}
