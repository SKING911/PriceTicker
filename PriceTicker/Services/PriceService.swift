import Foundation
import Combine
import Network

class PriceService: ObservableObject {
    @Published var prices: [UUID: TickerPrice] = [:]
    @Published var errors: [UUID: String] = [:]
    @Published var lastUpdated: [UUID: Date] = [:]
    @Published var isConnected: Bool = true

    /// Fires once per fetch cycle on the first successful ticker response.
    /// Consumers (e.g. AppDelegate) use this to trigger a heartbeat pulse.
    let fetchPulse = PassthroughSubject<Void, Never>()

    private let store: TickerStore
    private var timerCancellable: AnyCancellable?
    private var storeCancellable: AnyCancellable?
    /// One entry per ticker — assigning a new value cancels the previous in-flight request.
    private var fetchTasks: [UUID: AnyCancellable] = [:]

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.priceticker.netmonitor")

    private let session = NetworkSession.shared
    private let decoder = JSONDecoder()

    // MARK: - Backoff
    // Tracks consecutive fetch *cycles* (not individual ticker failures) that had
    // at least one failure. With N tickers, all can fail in one cycle but streak
    // only increments once. Resets to 0 on any success.
    // Interval: 2s → 4s → 8s → 16s → 30s (capped).
    private var failureStreak = 0
    private var cycleHadSuccess = false   // true if any ticker succeeded this cycle
    private var currentInterval: TimeInterval = 2
    private let minInterval: TimeInterval = 2
    private let maxInterval: TimeInterval = 30

    private func backoffInterval() -> TimeInterval {
        min(minInterval * pow(2.0, Double(min(failureStreak, 4))), maxInterval)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Init

    init(store: TickerStore) {
        self.store = store

        storeCancellable = store.$tickers
            .map { $0.map { "\($0.id)\($0.symbol)\($0.marketType.rawValue)" } }
            .removeDuplicates()
            .sink { [weak self] _ in
                guard self?.isConnected == true else { return }
                self?.fetchAll()
            }

        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let connected = path.status == .satisfied
                self?.isConnected = connected
                if connected {
                    // Reset backoff when connectivity is restored.
                    self?.failureStreak = 0
                    self?.restartTimer(interval: self?.minInterval ?? 2)
                    self?.fetchAll()
                } else {
                    self?.stopTimer()
                }
            }
        }
        monitor.start(queue: monitorQueue)
        startTimer(interval: minInterval)
    }

    // MARK: - Timer

    private func startTimer(interval: TimeInterval) {
        guard timerCancellable == nil else { return }
        currentInterval = interval
        timerCancellable = Timer
            .publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetchAll() }
    }

    /// Restart with a new interval only when the interval actually changes.
    private func restartTimer(interval: TimeInterval) {
        guard interval != currentInterval else { return }
        timerCancellable = nil
        startTimer(interval: interval)
    }

    private func stopTimer() {
        timerCancellable = nil
    }

    // MARK: - Fetch

    private func fetchAll() {
        cycleHadSuccess = false
        store.tickers.forEach { fetch($0) }
    }

    private func fetch(_ ticker: Ticker) {
        guard var components = URLComponents(string: ticker.marketType.apiBase) else { return }
        components.queryItems = [URLQueryItem(name: "symbol", value: ticker.symbol.uppercased())]
        guard let url = components.url else { return }

        fetchTasks[ticker.id] = session.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: BinanceTicker24h.self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case .failure(let err) = completion {
                        self.errors[ticker.id] = err.localizedDescription
                        // Only increment once per cycle (after all tickers have reported).
                        if !self.cycleHadSuccess {
                            self.failureStreak += 1
                            self.restartTimer(interval: self.backoffInterval())
                        }
                    }
                },
                receiveValue: { [weak self] result in
                    guard let self else { return }
                    self.errors.removeValue(forKey: ticker.id)
                    self.prices[ticker.id] = TickerPrice(
                        price: Double(result.lastPrice) ?? 0,
                        changePercent: Double(result.priceChangePercent) ?? 0,
                        priceDisplay: result.lastPrice
                    )
                    self.lastUpdated[ticker.id] = Date()
                    // First success in a cycle: fire the heartbeat pulse signal.
                    if !self.cycleHadSuccess {
                        self.fetchPulse.send()
                    }
                    self.cycleHadSuccess = true
                    if self.failureStreak > 0 {
                        self.failureStreak = 0
                        self.restartTimer(interval: self.minInterval)
                    }
                }
            )
    }
}

// MARK: - Binance Response

private struct BinanceTicker24h: Decodable {
    let lastPrice: String
    let priceChangePercent: String
}
