# PriceTicker

![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.7-orange)
![License](https://img.shields.io/badge/license-MIT-green)

A lightweight macOS menu bar app that shows real-time cryptocurrency prices as draggable floating tags, powered by the Binance public API.

<!-- Screenshot placeholder -->
<!-- ![PriceTicker screenshot](docs/screenshot.png) -->

---

## Features

- **BTC sparkline** — 24-hour BTC/USDT price chart renders directly inside the menu bar icon, updated every 5 minutes. Hover to see the latest price.
- **Floating price tags** — Add any Binance Spot or Futures symbol (e.g. BTCUSDT, ETHUSDT). Each tag is a draggable, always-on-top panel showing live price + 24h change.
- **Top 5 leaderboard** — Built-in gainers/losers panel (default view) showing the biggest movers from the Binance futures market, refreshed every 30 seconds.
- **Real-time prices** — Binance REST API polled every 2 seconds per ticker, with adaptive backoff on network failures.
- **Network status dot** — Colour-coded dot on the menu bar icon: green = live, orange = offline, none = waiting.
- **Proxy support** — Configure an HTTP proxy at runtime via the ⚙️ settings sheet — no recompile needed.
- **Persisted state** — Window positions and the full watchlist survive app restarts.
- **No dependencies** — Pure Swift + SwiftUI + Combine. No CocoaPods, no SPM packages.

---

## Requirements

- macOS 12 Monterey or later
- Xcode 14 or later (to build from source)

---

## Installation

### Option 1 — Download a release

1. Go to the [Releases](../../releases) page and download the latest `PriceTicker.app.zip`.
2. Unzip and drag `PriceTicker.app` to `/Applications`.
3. Launch it — a sparkline icon appears in the menu bar.

> Because the app is not notarised, you may need to right-click → **Open** the first time.

### Option 2 — Build from source

```bash
git clone https://github.com/YOUR_USERNAME/PriceTicker.git
cd PriceTicker
./scripts/bootstrap.sh
```

`bootstrap.sh` downloads XcodeGen if needed, regenerates the `.xcodeproj`, and
runs a Debug build. The finished app is at `build/Debug/PriceTicker.app`.

To open in Xcode instead:

```bash
open PriceTicker.xcodeproj
```

---

## Usage

1. Click the sparkline icon in the menu bar to open the popover.
2. The **Top 5** tab (default) shows the biggest futures gainers and losers.
3. Switch to **Watchlist**, type a Binance symbol (e.g. `SOLUSDT`), and press **Add** to create a floating price tag.
4. Drag any price tag to reposition it — position is saved automatically.
5. Click a floating leaderboard panel to toggle between gainers and losers.
6. Use the **⚙️** button in the footer to open Settings.

---

## Proxy Configuration

Proxy is **disabled by default**. To enable it:

1. Click the menu bar icon to open the popover.
2. Click the **⚙️** (gear) button in the footer.
3. Toggle **Use HTTP Proxy** on and enter your host and port.
4. Click **Save** — all network requests immediately use the new proxy.

Settings are stored in `UserDefaults` and persist across restarts.

---

## Architecture

```
App             AppDelegate, PriceTickerApp
Windows         FloatingPanel, FloatingPanelController,
                LeaderboardPanelController
Services        PriceService (2 s poll + backoff)
                LeaderboardService (30 s poll + backoff)
                BtcSparklineService (5 min klines)
                NetworkSession (rebuilds on proxy change)
Models          Ticker, TickerStore, ProxySettings
Views           PopoverContentView, SettingsView,
                AddTickerView, FloatingTagView,
                LeaderboardView, LeaderboardPanelView
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a deeper breakdown,
data flow diagram, and key design decisions.

---

## Contributing

Pull requests are welcome. For larger changes, please open an issue first to
discuss what you would like to change. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
for the development workflow.

---

## License

MIT — see [LICENSE](LICENSE).
