import Foundation
import Combine

struct LeaderboardEntry: Identifiable {
    var id: String { symbol }   // stable — prevents full SwiftUI re-render every 30 s
    let symbol: String          // "BTCUSDT"
    let baseAsset: String       // "BTC"
    let price: Double
    let changePercent: Double
    let quoteVolume: Double     // 24 h turnover in USDT
    let priceDisplay: String    // raw string from Binance, e.g. "95234.10"
}

class LeaderboardService: ObservableObject {
    @Published var topGainers: [LeaderboardEntry] = []
    @Published var topLosers:  [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var lastFetched: Date?
    @Published var errorMessage: String?

    private var timerCancellable: AnyCancellable?
    private var fetchTask: AnyCancellable?
    private let decoder = JSONDecoder()
    /// Symbols currently in TRADING status according to exchangeInfo.
    private var tradingSymbols: Set<String> = []

    // Backoff: 30s normal, up to 5 min on consecutive failures.
    private var failureStreak = 0
    private var currentInterval: TimeInterval = 30
    private let minInterval: TimeInterval = 30
    private let maxInterval: TimeInterval = 300

    private func backoffInterval() -> TimeInterval {
        min(minInterval * pow(2.0, Double(min(failureStreak, 3))), maxInterval)
    }

    // MARK: - Lifecycle

    /// Call once; refreshes automatically with adaptive backoff.
    func start() {
        fetchExchangeInfo { [weak self] in
            self?.fetch()
        }
        startTimer(interval: minInterval)
    }

    func stop() {
        timerCancellable = nil
    }

    private func startTimer(interval: TimeInterval) {
        guard interval != currentInterval || timerCancellable == nil else { return }
        currentInterval = interval
        timerCancellable = Timer
            .publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetch() }
    }

    // MARK: - exchangeInfo (trading status whitelist)

    private var exchangeInfoTask: AnyCancellable?

    private func fetchExchangeInfo(completion: @escaping () -> Void) {
        let url = URL(string: "https://fapi.binance.com/fapi/v1/exchangeInfo")!
        exchangeInfoTask = NetworkSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: BinanceExchangeInfo.self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure = result { completion() }
                },
                receiveValue: { [weak self] info in
                    self?.tradingSymbols = Set(
                        info.symbols
                            .filter { $0.status == "TRADING" && $0.symbol.hasSuffix("USDT") }
                            .map { $0.symbol }
                    )
                    completion()
                }
            )
    }

    // MARK: - Fetch

    func fetch() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // No symbol param → returns all USDT-M futures pairs (~300+ rows, ~120 KB)
        let url = URL(string: "https://fapi.binance.com/fapi/v1/ticker/24hr")!

        fetchTask = NetworkSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [BinanceAllTicker].self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.isLoading = false
                    if case .failure(let err) = completion {
                        self.errorMessage = err.localizedDescription
                        self.failureStreak += 1
                        self.startTimer(interval: self.backoffInterval())
                    }
                },
                receiveValue: { [weak self] tickers in
                    guard let self else { return }
                    self.isLoading = false
                    self.lastFetched = Date()
                    self.process(tickers)
                    if self.failureStreak > 0 {
                        self.failureStreak = 0
                        self.startTimer(interval: self.minInterval)
                    }
                }
            )
    }

    // MARK: - Processing

    /// Minimum 24 h USDT turnover to be included in the leaderboard.
    private let minVolume: Double = 10_000_000   // $10 M

    private func process(_ raw: [BinanceAllTicker]) {
        // Keep only actively-trading USDT perpetuals with meaningful volume.
        // If exchangeInfo hasn't loaded yet, fall back to volume filter only.
        let entries = raw
            .filter { $0.symbol.hasSuffix("USDT") }
            .filter { tradingSymbols.isEmpty || tradingSymbols.contains($0.symbol) }
            .compactMap { t -> LeaderboardEntry? in
                guard let price  = Double(t.lastPrice),
                      let change = Double(t.priceChangePercent),
                      let vol    = Double(t.quoteVolume),
                      vol >= minVolume
                else { return nil }
                let base = String(t.symbol.dropLast(4))
                return LeaderboardEntry(
                    symbol: t.symbol, baseAsset: base,
                    price: price, changePercent: change, quoteVolume: vol,
                    priceDisplay: t.lastPrice
                )
            }

        // Sort by change %, take top / bottom 5
        let sorted = entries.sorted { $0.changePercent > $1.changePercent }
        topGainers = Array(sorted.prefix(5))
        topLosers  = Array(sorted.suffix(5).reversed())
    }
}

// MARK: - Binance DTOs

private struct BinanceAllTicker: Decodable {
    let symbol: String
    let lastPrice: String
    let priceChangePercent: String
    let quoteVolume: String
}

private struct BinanceExchangeInfo: Decodable {
    let symbols: [BinanceSymbolInfo]
}

private struct BinanceSymbolInfo: Decodable {
    let symbol: String
    let status: String
}
