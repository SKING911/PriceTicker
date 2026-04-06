import SwiftUI

struct AddTickerView: View {
    @ObservedObject var store: TickerStore
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var symbol = ""
    @State private var marketType: Ticker.MarketType = .spot

    // MARK: - Presets

    private struct Preset: Identifiable {
        var id: String { symbol + market.rawValue }
        let name: String
        let symbol: String
        let market: Ticker.MarketType
    }

    private let presets: [Preset] = [
        Preset(name: "BTC",      symbol: "BTCUSDT",  market: .spot),
        Preset(name: "ETH",      symbol: "ETHUSDT",  market: .spot),
        Preset(name: "SOL",      symbol: "SOLUSDT",  market: .spot),
        Preset(name: "BNB",      symbol: "BNBUSDT",  market: .spot),
        Preset(name: "DOGE",     symbol: "DOGEUSDT", market: .spot),
        Preset(name: "XRP",      symbol: "XRPUSDT",  market: .spot),
        Preset(name: "BTC",      symbol: "BTCUSDT",  market: .futures),
        Preset(name: "ETH",      symbol: "ETHUSDT",  market: .futures),
        Preset(name: "SOL",      symbol: "SOLUSDT",  market: .futures),
    ]

    private var canAdd: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !symbol.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func isSelected(_ preset: Preset) -> Bool {
        symbol == preset.symbol && marketType == preset.market
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Price Tag")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Presets grid
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Quick Add", systemImage: "bolt.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 82), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(presets) { preset in
                                PresetButton(
                                    name: preset.name,
                                    badge: preset.market == .futures ? "PERP" : "SPOT",
                                    selected: isSelected(preset)
                                ) {
                                    displayName = preset.name
                                    symbol = preset.symbol
                                    marketType = preset.market
                                }
                            }
                        }
                    }

                    Divider()

                    // Custom form
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Custom Symbol", systemImage: "pencil")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        FormRow(label: "Name") {
                            TextField("e.g. BTC", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                        }

                        FormRow(label: "Symbol") {
                            TextField("e.g. BTCUSDT", text: $symbol)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: symbol) { newVal in
                                    symbol = newVal.uppercased()
                                }
                        }

                        FormRow(label: "Market") {
                            Picker("", selection: $marketType) {
                                ForEach(Ticker.MarketType.allCases) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                if canAdd {
                    // Preview badge
                    HStack(spacing: 5) {
                        Text(displayName)
                            .font(.system(size: 11, weight: .bold))
                        Text(symbol)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                }
                Spacer()
                Button("Add Tag") {
                    let t = Ticker(
                        symbol: symbol.uppercased().trimmingCharacters(in: .whitespaces),
                        displayName: displayName.trimmingCharacters(in: .whitespaces),
                        marketType: marketType
                    )
                    store.add(t)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 340, height: 500)
    }
}

// MARK: - Helper Views

private struct PresetButton: View {
    let name: String
    let badge: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                Text(badge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(selected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(
                                selected ? Color.accentColor.opacity(0.7) : Color(NSColor.separatorColor),
                                lineWidth: selected ? 1.5 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FormRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.callout)
                .frame(width: 60, alignment: .trailing)
                .foregroundColor(.primary.opacity(0.75))
            content()
        }
    }
}
