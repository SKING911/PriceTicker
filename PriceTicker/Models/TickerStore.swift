import Foundation
import Combine

class TickerStore: ObservableObject {
    @Published var tickers: [Ticker] = []

    private let key     = "com.priceticker.tickers_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() { load() }

    // MARK: - CRUD

    func add(_ ticker: Ticker) {
        // Prevent exact duplicate (same symbol + market)
        let isDuplicate = tickers.contains {
            $0.symbol == ticker.symbol && $0.marketType == ticker.marketType
        }
        guard !isDuplicate else { return }
        tickers.append(ticker)
        save()
    }

    func remove(id: UUID) {
        tickers.removeAll { $0.id == id }
        save()
    }

    func updatePosition(id: UUID, to point: CGPoint) {
        guard let idx = tickers.firstIndex(where: { $0.id == id }) else { return }
        tickers[idx].windowX = Double(point.x)
        tickers[idx].windowY = Double(point.y)
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? encoder.encode(tickers) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? decoder.decode([Ticker].self, from: data)
        else { return }
        tickers = decoded
    }
}
