import AppKit
import SwiftUI
import Combine

/// Owns all FloatingPanel instances and keeps them in sync with TickerStore.
class FloatingPanelController {

    private var panels: [UUID: FloatingPanel] = [:]
    let store: TickerStore
    let priceService: PriceService
    private var cancellables = Set<AnyCancellable>()

    init(store: TickerStore, priceService: PriceService) {
        self.store = store
        self.priceService = priceService

        // React to add / remove (skip the initial value — restoreWindows handles it)
        store.$tickers
            .dropFirst()
            .sink { [weak self] tickers in
                self?.syncPanels(with: tickers)
            }
            .store(in: &cancellables)

        // Resize all panels once price data arrives (debounced)
        priceService.$prices
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.resizePanels() }
            .store(in: &cancellables)

        // Build initial panels for already-loaded tickers
        restoreWindows()
    }

    // MARK: - Public

    func focusPanel(id: UUID) {
        panels[id]?.orderFrontRegardless()
    }

    // MARK: - Private

    private func restoreWindows() {
        for ticker in store.tickers {
            createPanel(for: ticker)
        }
    }

    private func createPanel(for ticker: Ticker) {
        guard panels[ticker.id] == nil else { return }

        let position = ticker.windowPosition ?? nextDefaultPosition()
        let panel = FloatingPanel(at: position)
        panel.tickerId = ticker.id

        // Use NSHostingController so SwiftUI's observation (@ObservedObject)
        // integrates correctly with the view controller lifecycle.
        let tagView = FloatingTagView(
            ticker: ticker,
            priceService: priceService
        )
        let hc = NSHostingController(rootView: tagView)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        hc.view.layer?.isOpaque = false

        panel.contentViewController = hc

        // Initial size; refined by resizePanels() once price data arrives
        let fit = hc.view.fittingSize
        panel.setContentSize(NSSize(
            width: max(fit.width, 160),
            height: max(fit.height, 46)
        ))

        // Persist position when dragged
        panel.onMoved = { [weak self, weak panel] origin in
            guard let id = panel?.tickerId else { return }
            self?.store.updatePosition(id: id, to: origin)
        }

        panel.orderFrontRegardless()
        panels[ticker.id] = panel
    }

    private func removePanel(id: UUID) {
        panels[id]?.close()
        panels.removeValue(forKey: id)
    }

    private func syncPanels(with tickers: [Ticker]) {
        let liveIDs = Set(tickers.map(\.id))

        // Close panels whose ticker was removed
        for id in panels.keys where !liveIDs.contains(id) {
            removePanel(id: id)
        }
        // Open panels for newly added tickers
        for ticker in tickers where panels[ticker.id] == nil {
            createPanel(for: ticker)
        }
    }

    private func resizePanels() {
        for (_, panel) in panels {
            guard let view = panel.contentViewController?.view else { continue }
            let newSize = view.fittingSize
            guard newSize.width > 40, newSize.height > 10 else { continue }
            // Skip if size hasn't changed — avoids unnecessary layout passes.
            guard newSize != panel.frame.size else { continue }
            var frame = panel.frame
            frame.origin.y += frame.height - newSize.height  // keep top-left fixed
            frame.size = newSize
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    private func nextDefaultPosition() -> CGPoint {
        let offset = CGFloat(panels.count) * 44
        let screenH = NSScreen.main?.visibleFrame.height ?? 800
        // Stack tags from top-right
        let x = (NSScreen.main?.visibleFrame.maxX ?? 1200) - 250
        let y = screenH - 60 - offset
        return CGPoint(x: x, y: y)
    }
}

