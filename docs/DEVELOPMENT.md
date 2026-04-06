# Development Guide

## Requirements

| Tool | Minimum version |
|------|----------------|
| macOS | 12 Monterey |
| Xcode | 14 |
| XcodeGen | 2.38.0 |

XcodeGen is only needed if you change `project.yml`. The committed
`PriceTicker.xcodeproj` can be opened directly in Xcode without it.

---

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/PriceTicker.git
cd PriceTicker
./scripts/bootstrap.sh
```

`bootstrap.sh` will:

1. Download XcodeGen 2.38.0 to `/tmp/xcodegen/` if not already present.
2. Run `xcodegen generate` to produce `PriceTicker.xcodeproj`.
3. Run `xcodebuild` in Debug mode and report the result.

The finished app is at `build/Debug/PriceTicker.app`.

To open in Xcode instead:

```bash
open PriceTicker.xcodeproj
```

---

## Build and Run from the Command Line

```bash
# Debug build (output → build/Debug/PriceTicker.app)
xcodebuild -scheme PriceTicker -configuration Debug build

# Show only errors and final result
xcodebuild -scheme PriceTicker -configuration Debug build 2>&1 | grep -E "error:|BUILD"

# Kill any running instance and launch the new build
pkill -x PriceTicker; sleep 1; open build/Debug/PriceTicker.app
```

---

## Regenerating the Xcode Project

Whenever you edit `project.yml`, regenerate the `.xcodeproj`:

```bash
/tmp/xcodegen/bin/xcodegen generate
```

If XcodeGen is not yet downloaded:

```bash
./scripts/bootstrap.sh
```

Commit both `project.yml` and the updated `PriceTicker.xcodeproj` together so
other contributors do not need to run XcodeGen to open the project.

---

## Proxy Configuration

Proxy support is **disabled by default** and can be configured at runtime
without recompiling:

1. Launch the app and click the menu bar icon.
2. Click the **⚙️** (gear) button in the popover footer.
3. Toggle **Use HTTP Proxy** on and enter your host and port.
4. Click **Save** — the new session takes effect immediately.

Settings are stored in `UserDefaults` and persist across restarts.

If you prefer to hard-code a proxy for development, edit
`PriceTicker/Models/ProxySettings.swift` — but do not commit that change.

---

## Adding a New Service

1. Create `PriceTicker/Services/MyService.swift`.
2. Make it an `ObservableObject` if views need to subscribe to it.
3. Assemble and inject it through `AppDelegate` rather than using additional
   global singletons.
4. Use `NetworkSession.shared.dataTaskPublisher(for:)` for all network calls
   so proxy settings and timeouts are inherited automatically.
5. Implement exponential backoff on failure — see `PriceService` or
   `BtcSparklineService` for the pattern.

Example skeleton:

```swift
import Foundation
import Combine

class MyService: ObservableObject {
    @Published var result: SomeModel?
    private var task: AnyCancellable?
    private var failureStreak = 0
    // ... timer + backoff logic

    func fetch() {
        guard let url = URL(string: "https://api.example.com/endpoint") else { return }
        task = NetworkSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: SomeModel.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in /* increment failureStreak, backoff */ },
                receiveValue: { [weak self] in
                    self?.result = $0
                    self?.failureStreak = 0
                }
            )
    }
}
```

---

## Adding a New Floating Panel

1. Create a controller class (see `LeaderboardPanelController` as a template).
2. Create a `FloatingPanel` at the desired position.
3. Wrap the SwiftUI view in `NSHostingController` and assign it as
   `panel.contentViewController` — do not use `NSHostingView` directly.
4. Wire `panel.onMoved` to persist position and `panel.onTap` for any
   click-toggle behaviour.
5. Expose `@Published var isVisible` so the popover UI can reflect state.

---

## Adding a New View

1. Create `PriceTicker/Views/MyView.swift` as a SwiftUI `View`.
2. Receive dependencies via `init` parameters.
3. To host the view in a floating panel:

```swift
let hc = NSHostingController(rootView: MyView(service: myService))
panel.contentViewController = hc
```

---

## Project Structure Reference

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full file map, data flow
diagram, and explanations of key design decisions.
