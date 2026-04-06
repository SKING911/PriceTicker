import AppKit
import SwiftUI
import Combine

/// Manages the single floating leaderboard panel.
class LeaderboardPanelController: ObservableObject {
    @Published private(set) var isVisible = false
    @Published var showGainers = true

    private var panel: FloatingPanel?
    private var hostingController: NSHostingController<LeaderboardPanelView>?
    private var showGainersCancellable: AnyCancellable?
    private let leaderboard: LeaderboardService

    private let visibleKey   = "leaderboardPanel.visible"
    private let positionXKey = "leaderboardPanel.x"
    private let positionYKey = "leaderboardPanel.y"

    init(leaderboard: LeaderboardService) {
        self.leaderboard = leaderboard
        if UserDefaults.standard.bool(forKey: visibleKey) {
            show()
        }
    }

    // MARK: - Public

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Private

    private func makeView() -> LeaderboardPanelView {
        LeaderboardPanelView(leaderboard: leaderboard, showGainers: showGainers)
    }

    private func show() {
        guard panel == nil else { return }

        let pos = savedPosition() ?? defaultPosition()
        let p   = FloatingPanel(at: pos)

        let hc = NSHostingController(rootView: makeView())
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        hc.view.layer?.isOpaque = false
        p.contentViewController = hc
        hostingController = hc

        let fit = hc.view.fittingSize
        p.setContentSize(NSSize(width: max(fit.width, 130), height: max(fit.height, 120)))

        p.onMoved = { [weak self] origin in self?.savePosition(origin) }
        p.onTap   = { [weak self] in self?.showGainers.toggle() }
        p.orderFrontRegardless()

        // When showGainers flips, replace rootView so SwiftUI re-renders.
        showGainersCancellable = $showGainers
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.hostingController?.rootView = self.makeView()
            }

        panel = p
        isVisible = true
        UserDefaults.standard.set(true, forKey: visibleKey)
    }

    private func hide() {
        showGainersCancellable = nil
        hostingController = nil
        panel?.close()
        panel = nil
        isVisible = false
        UserDefaults.standard.set(false, forKey: visibleKey)
    }

    // MARK: - Position persistence

    private func savedPosition() -> CGPoint? {
        let d = UserDefaults.standard
        guard d.object(forKey: positionXKey) != nil else { return nil }
        return CGPoint(x: d.double(forKey: positionXKey),
                       y: d.double(forKey: positionYKey))
    }

    private func savePosition(_ p: CGPoint) {
        UserDefaults.standard.set(p.x, forKey: positionXKey)
        UserDefaults.standard.set(p.y, forKey: positionYKey)
    }

    private func defaultPosition() -> CGPoint {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        return CGPoint(x: screen.maxX - 160, y: screen.maxY - 180)
    }
}
