# Retro Season Manager

[![Tests](https://github.com/johnwderrick/RSM/actions/workflows/tests.yml/badge.svg)](https://github.com/johnwderrick/RSM/actions/workflows/tests.yml)

An offline, single-player, text/pixel-art football (soccer) management game for iOS, built in SwiftUI. Retro/CRT green-monochrome aesthetic throughout — no real club or player names or trademarks (everything is fictionalized: "National Cup" not "FA Cup," "Continental Cup" not "Champions League"). Pick a club, manage one continuous save across transfers, tactics, training, finances, press, and youth development, through a fixed-length career.

## Requirements

- Xcode 17+ (an iOS 17+ SDK)
- iOS 17.0+ deployment target
- No external dependencies — no networking, no backend, no third-party frameworks or packages. Everything ships in the app bundle.

## Building & running

Open `Retro Season Manager.xcodeproj` in Xcode and run the `Retro Season Manager` scheme on any iOS Simulator or device (landscape-only — the app locks orientation, so rotate the Simulator to see it correctly).

From the command line:

```bash
xcodebuild -project "Retro Season Manager.xcodeproj" -scheme "Retro Season Manager" \
  -destination "generic/platform=iOS Simulator" build
```

## Testing

```bash
xcodebuild test -project "Retro Season Manager.xcodeproj" -scheme "Retro Season Manager" \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

Tests run automatically on every push and pull request to `main` (see `.github/workflows/tests.yml`).

> **Note**: constructing `GameStore()` directly inside a synchronous `@MainActor` test method crashes on some toolchains (a Swift Concurrency runtime issue, not an app bug — see `Retro Season ManagerTests/GameStoreTestSupport.swift`). Use `await makeTestStore()` in any test that needs a live instance.

## Project layout

- `RetroSeasonManagerApp.swift` — app entry point
- `ContentView.swift` — thin root view, routes between Main Menu / Main Game / Match / Season Review by store state
- `GameStore.swift` + `GameStore+<Domain>.swift` — the single `@Observable` state container, with logic split into per-domain extensions on the same class (not separate manager objects — see architecture notes below)
- `LiveMatch.swift` — the live match simulation engine, its own `@Observable` class
- `Models.swift` — shared data types (`Player`, `Club`, `Fixture`, `Formation`, etc.)
- One SwiftUI view file per screen (`HomeView.swift`, `SquadView.swift`, `TransfersView.swift`, ...)
- `HistoricalSquads*.swift` / `EuropeanSquads*.swift` — hand-authored era-specific rosters (2000, 2010, 2020 career starts)
- `Retro Season ManagerTests/` — the XCTest target

For a deeper architecture walkthrough, see `Docs/Architecture.md` and `.claude/architecture.md` (both carry a note pointing at the most recent session handover where relevant — check that note before trusting anything that looks out of date).
