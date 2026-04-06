import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private lazy var popover: NSPopover = makePopover()
    private var statusCancellable: AnyCancellable?
    private var sparklineCancellable: AnyCancellable?
    private var pulseCancellable: AnyCancellable?
    private var heartbeatTimer: AnyCancellable?
    private var beatPhase: Double = 0
    private var isHeartbeating = false

    let store                   = TickerStore()
    lazy var priceService       = PriceService(store: store)
    let leaderboardService      = LeaderboardService()
    let btcSparkline            = BtcSparklineService()
    var panelController: FloatingPanelController!
    var leaderboardPanelController: LeaderboardPanelController!

    // Latest state — both observers write here and call redrawIcon()
    private var dotColor: NSColor?
    private var sparklinePrices: [Double] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = FloatingPanelController(store: store, priceService: priceService)
        leaderboardService.start()
        leaderboardPanelController = LeaderboardPanelController(leaderboard: leaderboardService)
        btcSparkline.start()
        setupStatusBar()
        observeStatus()
        observeSparkline()
        observePulse()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        redrawIcon()   // initial state: no dot, no sparkline yet
    }

    /// Redraws the menu bar icon: BTC sparkline + connectivity dot.
    /// Canvas is wider (44 pt) to accommodate the line chart.
    private func redrawIcon() {
        guard let button = statusItem.button else { return }

        let canvas = NSSize(width: 44, height: 18)
        let image = NSImage(size: canvas, flipped: false) { [weak self] rect in
            guard let self else { return true }
            let prices = self.sparklinePrices

            if prices.count >= 2 {
                let minP = prices.min()!
                let maxP = prices.max()!
                let range = maxP - minP

                let padX: CGFloat = 2
                let padY: CGFloat = 3.5
                let w = rect.width  - padX * 2
                let h = rect.height - padY * 2

                let path = NSBezierPath()
                path.lineWidth = 1.2
                path.lineCapStyle  = .round
                path.lineJoinStyle = .round

                for (i, price) in prices.enumerated() {
                    let x = padX + CGFloat(i) / CGFloat(prices.count - 1) * w
                    let norm: CGFloat = range > 0 ? CGFloat((price - minP) / range) : 0.5
                    let y = padY + norm * h
                    i == 0 ? path.move(to: CGPoint(x: x, y: y))
                           : path.line(to: CGPoint(x: x, y: y))
                }

                // Green if trending up, red if down, label-color if flat
                let lineColor: NSColor
                if prices.last! > prices.first! {
                    lineColor = NSColor(red: 0.08, green: 0.72, blue: 0.35, alpha: 1)
                } else if prices.last! < prices.first! {
                    lineColor = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)
                } else {
                    lineColor = .labelColor
                }
                lineColor.setStroke()
                path.stroke()

            } else {
                // Not enough data yet — draw placeholder SF symbol
                let cfg = NSImage.SymbolConfiguration(paletteColors: [.labelColor])
                let symRect = NSRect(x: rect.midX - 9, y: rect.minY, width: 18, height: 18)
                NSImage(systemSymbolName: "chart.line.uptrend.xyaxis",
                        accessibilityDescription: nil)?
                    .withSymbolConfiguration(cfg)?
                    .draw(in: symRect)
            }

            // Connectivity dot: bottom-right corner, animated when heartbeating
            if let color = self.dotColor {
                let baseR: CGFloat = 3.0
                let (scale, alpha) = self.isHeartbeating ? self.heartbeatParams() : (1.0, 1.0)
                let r  = baseR * scale
                let cx = rect.maxX - baseR - 0.5
                let cy = rect.minY + baseR + 0.5
                color.withAlphaComponent(alpha).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r,
                                            width: r * 2, height: r * 2)).fill()
            }
            return true
        }
        image.isTemplate = false
        button.image = image
    }

    /// Combines connectivity + data-received signals into the three dot states.
    private func observeStatus() {
        statusCancellable = Publishers.CombineLatest(
            priceService.$isConnected,
            priceService.$lastUpdated
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isConnected, lastUpdated in
            guard let self else { return }
            if !isConnected {
                // Offline: orange dot, flatline — stop any in-progress animation
                self.dotColor = .systemOrange
                self.stopHeartbeat()
            } else if lastUpdated.isEmpty {
                // Connected but no data yet: no dot
                self.dotColor = nil
                self.stopHeartbeat()
            } else {
                // Connected + data: green dot, pulse-driven by fetchPulse
                self.dotColor = NSColor(red: 0.08, green: 0.72, blue: 0.25, alpha: 1)
            }
            self.redrawIcon()
        }
    }

    // MARK: - Heartbeat Animation (event-driven)

    /// Subscribes to PriceService.fetchPulse — each successful fetch cycle
    /// triggers one lub-dub animation, then the dot goes quiet until the next fetch.
    /// Rate naturally reflects network health: normal=2 s, backoff=up to 30 s, offline=stopped.
    private func observePulse() {
        pulseCancellable = priceService.fetchPulse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.triggerPulse() }
    }

    /// Plays one lub-dub animation (~0.1 s). If already animating, resets phase to 0
    /// so the current timer continues the animation from the beginning.
    private func triggerPulse() {
        beatPhase = 0
        guard !isHeartbeating else { return }
        isHeartbeating = true
        heartbeatTimer = Timer.publish(every: 1.0 / 24.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Full lub-dub plays over 0.45 s; stop once the dub is done (phase > 0.22)
                self.beatPhase += (1.0 / 24.0) / 0.45
                if self.beatPhase > 0.22 {
                    self.stopHeartbeat()
                }
                self.redrawIcon()
            }
    }

    private func stopHeartbeat() {
        isHeartbeating = false
        heartbeatTimer = nil
        beatPhase = 0
    }

    /// Returns (radiusScale, alpha) for the dot at the current beat phase.
    /// Models the classic lub-dub: a larger first peak followed by a smaller second peak.
    private func heartbeatParams() -> (scale: CGFloat, alpha: CGFloat) {
        let t = beatPhase
        // Lub  (0.00 – 0.08): sharp systolic peak
        let lub: Double = t < 0.08 ? sin(t / 0.08 * .pi) : 0
        // Dub  (0.11 – 0.20): smaller diastolic bump
        let dub: Double = (t >= 0.11 && t < 0.20) ? sin((t - 0.11) / 0.09 * .pi) * 0.50 : 0
        let pulse = lub + dub                       // 0 … ~1.5
        let scale = CGFloat(1.0 + pulse * 0.55)    // 1.0 … ~1.8×
        let alpha = CGFloat(0.70 + pulse * 0.30)   // 0.70 … 1.0
        return (scale, alpha)
    }

    private func observeSparkline() {
        // Klines refresh every 5 min. Redraw icon and sync tooltip from the same data —
        // tooltip shows the chart's own latest price, which is the most recent candle close.
        sparklineCancellable = btcSparkline.$prices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prices in
                guard let self else { return }
                self.sparklinePrices = prices
                self.redrawIcon()
                let raw = self.btcSparkline.lastPriceDisplay
                if !raw.isEmpty {
                    self.statusItem.button?.toolTip = "BTC  \(formatBinancePrice(raw))"
                }
            }
    }

    // MARK: - Popover

    private func makePopover() -> NSPopover {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 300, height: 440)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                store: store,
                panelController: panelController,
                leaderboard: leaderboardService,
                leaderboardPanel: leaderboardPanelController
            )
            .frame(width: 300, height: 440)
        )
        return pop
    }

    @objc private func togglePopover(_ sender: AnyObject) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
