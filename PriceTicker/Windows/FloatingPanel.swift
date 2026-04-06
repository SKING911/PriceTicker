import AppKit

/// A transparent, borderless, always-on-top NSPanel for price tags.
final class FloatingPanel: NSPanel {

    var tickerId: UUID?
    /// Called with the new origin whenever the user finishes dragging.
    var onMoved: ((CGPoint) -> Void)?
    /// Called when the user clicks without dragging (tap).
    var onTap: (() -> Void)?

    init(at position: CGPoint) {
        super.init(
            contentRect: NSRect(origin: position, size: NSSize(width: 200, height: 38)),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel             = true
        level                       = .floating
        collectionBehavior          = [.moveToActiveSpace, .stationary]
        isMovableByWindowBackground = false  // we handle dragging in sendEvent
        hasShadow                   = true   // system shadow contours to transparent pill
        backgroundColor             = .clear
        isOpaque                    = false
        titleVisibility             = .hidden
        titlebarAppearsTransparent  = true
        hidesOnDeactivate           = false
        isReleasedWhenClosed        = false
        delegate                    = self
    }

    /// Force arrow cursor everywhere.
    /// Intentionally skips super to prevent SwiftUI subviews from overriding with resize/text cursors.
    override func resetCursorRects() {
        guard let cv = contentView else { return }
        discardCursorRects()
        cv.addCursorRect(cv.bounds, cursor: .arrow)
    }

    /// Left-click: drag if moved beyond threshold, otherwise treat as a tap.
    override func sendEvent(_ event: NSEvent) {
        guard event.type == .leftMouseDown,
              !event.modifierFlags.contains(.control) else {
            super.sendEvent(event)
            return
        }

        let startMouse  = NSEvent.mouseLocation
        let startOrigin = frame.origin
        let dragThreshold: CGFloat = 4
        var dragging = false

        while let next = NSApp.nextEvent(
            matching: [.leftMouseDragged, .leftMouseUp],
            until: .distantFuture,
            inMode: .eventTracking,
            dequeue: true
        ) {
            if next.type == .leftMouseUp {
                if dragging {
                    onMoved?(frame.origin)
                } else {
                    onTap?()
                }
                break
            }

            let loc = NSEvent.mouseLocation
            let dx  = loc.x - startMouse.x
            let dy  = loc.y - startMouse.y

            if !dragging, abs(dx) > dragThreshold || abs(dy) > dragThreshold {
                dragging = true
            }
            if dragging {
                setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension FloatingPanel: NSWindowDelegate {}
