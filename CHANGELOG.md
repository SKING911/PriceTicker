# Changelog

All notable changes to PriceTicker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-04-06

### Added

- Menu bar icon with live BTC 24-hour sparkline rendered as a custom NSImage.
- Network status dot on menu bar icon (green = online, red = offline/error).
- Popover UI for managing the watchlist (add/remove tickers).
- Draggable, always-on-top floating tag panels for each watched symbol, showing price and 24h percentage change.
- Real-time price updates via Binance REST API polled every 2 seconds per ticker.
- Top-5 gainers / top-5 losers leaderboard sourced from the Binance 24h ticker feed, displayed in a floating panel.
- Persistent watchlist and window positions across app restarts (UserDefaults).
- `NetworkSession` with optional HTTP/HTTPS proxy support (disabled by default).
- XcodeGen `project.yml` so the Xcode project can be fully regenerated from source.
- `scripts/bootstrap.sh` for one-command setup from a fresh clone.
- `docs/ARCHITECTURE.md` and `docs/DEVELOPMENT.md` developer documentation.

[1.0.0]: https://github.com/YOUR_USERNAME/PriceTicker/releases/tag/v1.0.0
