import SwiftUI

private enum Tab { case top5, watchlist }

struct PopoverContentView: View {
    @ObservedObject var store: TickerStore
    let panelController: FloatingPanelController
    @ObservedObject var leaderboard: LeaderboardService
    @ObservedObject var leaderboardPanel: LeaderboardPanelController

    @State private var tab: Tab = .top5
    @State private var showAdd      = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabContent
            Divider()
            footer
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showAdd) {
            AddTickerView(store: store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(.accentColor)
                .font(.system(size: 14, weight: .semibold))

            Picker("", selection: $tab) {
                Text("Top 5").tag(Tab.top5)
                Text("Watchlist").tag(Tab.watchlist)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Spacer()

            if tab == .watchlist {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add price tag")
            } else {
                HStack(spacing: 10) {
                    // Toggle floating panel
                    Button {
                        leaderboardPanel.toggle()
                    } label: {
                        Image(systemName: leaderboardPanel.isVisible
                              ? "macwindow.badge.plus" : "macwindow")
                            .font(.system(size: 13))
                            .foregroundColor(leaderboardPanel.isVisible ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(leaderboardPanel.isVisible ? "Hide floating panel" : "Show floating panel")

                    // Refresh
                    Button {
                        leaderboard.fetch()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundColor(leaderboard.isLoading ? .secondary : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(leaderboard.isLoading)
                    .help("Refresh leaderboard")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .top5:
            LeaderboardView(leaderboard: leaderboard, store: store)
        case .watchlist:
            watchlistContent
        }
    }

    private var watchlistContent: some View {
        Group {
            if store.tickers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.tickers) { ticker in
                            TickerRow(ticker: ticker) {
                                store.remove(id: ticker.id)
                            } onShow: {
                                panelController.focusPanel(id: ticker.id)
                            }
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No price tags yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Add your first tag") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Image(systemName: "arrow.clockwise")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("Price every 2 s · Top 5 every 30 s")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Settings")

            Button("Quit") { NSApp.terminate(nil) }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Ticker Row

private struct TickerRow: View {
    let ticker: Ticker
    let onRemove: () -> Void
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ticker.displayName)
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 4) {
                    Text(ticker.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(ticker.marketType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button { onShow() } label: {
                Image(systemName: "macwindow.badge.plus")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Bring to front")

            Button { onRemove() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
