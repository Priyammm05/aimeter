# AIMeter

![AIMeter logo](docs/brand/aimeter-logo.svg)

AIMeter is a minimal macOS menu bar app for tracking personal Cursor and Claude usage from authenticated local web sessions. It gives you a quiet, glanceable dashboard for the usage numbers that usually live several clicks deep in provider settings.

> AIMeter is an experimental, unofficial Cursor and Claude integration. It does not use provider APIs, and it may need updates when provider account pages change.

![AIMeter menu bar dashboard screenshot](docs/screenshots/menu-popover.png)

## Highlights

- Native macOS menu bar utility with no Dock icon.
- **Color-coded progress bar** — green (≤60%), orange (61–85%), red (≥86%) at a glance.
- **Usage percentage** shown directly in the menu bar next to the bar.
- **Burn rate & estimated time remaining** — calculated automatically from your reading history.
- **Trend badge** — ↗/↘ arrow on the plan label shows if usage is climbing or dropping.
- Tracks Cursor total, Auto, and API usage.
- Tracks Claude plan usage, reset time, All models and Claude Design limits when available.
- Uses local web sessions — no API key required.
- Keeps the latest successful usage snapshot visible if a background refresh fails.
- **Demo mode** for testing the UI without a real Cursor or Claude connection.

## Screenshots

| Dashboard | Settings |
| --- | --- |
| ![AIMeter dashboard](docs/screenshots/menu-popover.png) | ![AIMeter settings](docs/screenshots/settings.png) |

## Install

### Download The App

1. Open the latest [GitHub Release](https://github.com/Priyammm05/aimeter/releases).
2. Download `AIMeter.dmg`.
3. Open the DMG.
4. Drag `AIMeter` into `Applications`.
5. Launch `AIMeter` from `Applications`.

AIMeter is a menu bar app — it does not appear in the Dock. After launch, look for the color-coded progress bar in the macOS menu bar.

### First Setup

1. Click the AIMeter menu bar item.
2. Click `Connect Cursor` or `Connect Claude`.
3. Sign in to the provider in the connection window.
4. AIMeter closes the connection window after it detects your usage data.

If the menu bar is crowded, macOS may hide some menu bar apps. You may need to reduce other menu bar items or use Control Center.

### Update

Download the newer `AIMeter.dmg` from GitHub Releases, drag the new `AIMeter` app into `Applications`, and replace the old copy.

## Menu Bar Icon

The icon is a color-coded progress bar with your current usage percentage:

| Color | Meaning |
| --- | --- |
| 🟢 Green | Usage ≤ 60% — healthy |
| 🟠 Orange | Usage 61–85% — getting busy |
| 🔴 Red | Usage ≥ 86% — critical |

When disconnected, a small dot replaces the percentage indicator.

## What AIMeter Tracks

| Provider | Metrics |
| --- | --- |
| Cursor | Plan label, total usage %, Auto usage %, API usage % |
| Claude | Plan label, session usage %, reset time, All models usage, Claude Design usage |

Both providers also show:
- **Burn rate** — average % consumed per hour (calculated from history)
- **Estimated time remaining** — how long until your quota runs out at current burn rate

## Demo Mode

Test the UI with realistic fake data — no Cursor or Claude account needed.

**Build first:**
```bash
make build
```

**Run the interactive launcher:**
```bash
bash demo.sh
```

The script asks which provider(s) to simulate, what usage percentage to show, and what plan label to use. It then launches AIMeter with that fake data pre-loaded including history, burn rate, and estimated remaining time.

You can also launch directly:
```bash
# Both providers with defaults (Cursor 67%, Claude 82%)
build/AIMeter.app/Contents/MacOS/AIMeter --demo

# Cursor only at 45%
build/AIMeter.app/Contents/MacOS/AIMeter --demo --cursor-only --cursor-percent 45

# Claude only at 94% (red zone)
build/AIMeter.app/Contents/MacOS/AIMeter --demo --claude-only --claude-percent 94
```

Demo mode is gated behind a `DemoMode.isEnabled` flag that is **always `false`** in normal builds — it only activates when the `--demo` argument is present.

## How It Works

AIMeter reads the same usage information you can see after signing in on Cursor and Claude account/settings pages.

- It opens each provider in a local browser view owned by AIMeter.
- Your sign-in sessions stay local to AIMeter.
- AIMeter only loads HTTPS pages from allowed Cursor and Claude hosts.
- It reads the usage values shown by each provider and displays them in the menu bar.
- Usage readings are saved locally and used to calculate burn rate and show history.
- It never sends your usage data to an AIMeter server.

Disconnecting a provider clears that provider's local sign-in data. Sessions can still expire normally, in which case AIMeter will ask you to reconnect.

## Privacy

AIMeter stores provider login state and usage history locally on your Mac. It does not ask for API keys and does not send any data to an AIMeter server.

- AIMeter only loads HTTPS provider pages from allowed Cursor and Claude hosts.
- Provider sessions can expire and require reconnecting.
- Disconnecting a provider clears AIMeter's local sign-in data for that provider.
- Do not include personal account data, cookies, or unredacted screenshots in issues or pull requests.

## Requirements

- macOS 14 or newer

## Limitations

- AIMeter relies on authenticated local web sessions.
- Cursor and Claude can change routes, DOM structure, response shapes, or copy at any time.
- Background refresh may fail until you reconnect after session expiry.
- Usage values are only as accurate as the provider pages AIMeter can read.
- Burn rate and estimated remaining time require at least 3 historical readings to calculate.

## Building from Source

```bash
git clone https://github.com/Priyammm05/aimeter.git
cd aimeter
make build          # produces build/AIMeter.app
make demo           # build + launch demo mode
```

Requires Xcode 15 or newer.

## Support

Open a GitHub issue if AIMeter cannot connect, the usage values look wrong, or provider settings pages change.

Security-sensitive issues should be reported privately. See [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
