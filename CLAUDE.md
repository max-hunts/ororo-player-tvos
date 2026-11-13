# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Unofficial tvOS video player for [ororo.tv](https://ororo.tv), written in pure Swift. The app is tvOS only; there is no iOS target. The only third-party dependency is the author's own `Transitions` navigation library. A single Xcode workspace contains two projects:

- **`Ororo-Kit`** builds the `OroroKit` framework: models, networking, Core Data storage, data providers, the subtitle parser, and reusable generic collection-view components. This layer is UIKit-aware but screen-agnostic and has the only unit tests.
- **`Ororo-Player`** is the tvOS app: view controllers, navigation flows, and managers (video, subtitle, credentials).

`Ororo-Player` depends on `OroroKit`; both build from `Ororo-Player.xcworkspace`. Deployment target is tvOS 15, Swift 5.

## Build / Test / Lint

Always open the workspace, never an individual `.xcodeproj`:

```
open Ororo-Player.xcworkspace
```

Schemes: `Ororo-Player-tvOS`, `Ororo-Kit`, `Ororo-KitTests`.

Build the app (use any Apple TV simulator from `xcrun simctl list devices available`):

```
xcodebuild build -workspace Ororo-Player.xcworkspace -scheme Ororo-Player-tvOS \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  CODE_SIGNING_ALLOWED=NO
```

Run the unit tests:

```
xcodebuild test -workspace Ororo-Player.xcworkspace -scheme Ororo-KitTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

Run a single test class or method with `-only-testing:Ororo-KitTests/SubtitleParserTests/testSomeCase`.

Lint (CI runs SwiftLint 0.65.1 with `--strict`, so warnings fail the build; the version is pinned in `.github/workflows/ci.yml`). Config is in `.swiftlint.yml`:

```
swiftlint lint --strict
```

CI is GitHub Actions (`.github/workflows/ci.yml`): lint, app build, and `Ororo-KitTests` on a tvOS simulator. There are only two test files (`DiffTests`, `SubtitleParserTests`) and they live in `Ororo-Kit`; the app target has no tests.

## Signing

No team ID or personal bundle ID is committed. Both projects use `Config/Signing.xcconfig` as their project-level base configuration; it sets `DEVELOPMENT_TEAM` (empty) and `BUNDLE_ID_PREFIX` (`com.example`), then optionally includes the git-ignored `Config/Local.xcconfig` (template: `Config/Local.xcconfig.example`). Bundle IDs are `$(BUNDLE_ID_PREFIX).Ororo-Player`, `.Ororo-Kit`, `.Ororo-KitTests`. Do not add `DEVELOPMENT_TEAM` or literal bundle IDs to the `.pbxproj` files, since target-level values would override the xcconfig.

## Dependencies

`Transitions` (the Flow/Coordinator library) is a Carthage dependency pinned in `Cartfile.resolved`. A prebuilt `Transitions.xcframework` (tvOS device + simulator slices) is committed under `Ororo-Player/` and linked directly, so a fresh clone builds without running Carthage. If you do need to rebuild it:

```
carthage bootstrap --platform tvOS --use-xcframeworks
```

then copy `Carthage/Build/Transitions.xcframework` over the committed one.

## Architecture

### Navigation: Coordinator + Flow (no storyboard segues)

All navigation is flow-based via the external `Transitions` library (which provides `Flow`, `Coordinator`, `MainCoordinator`, `Injection`, `TransitionHandler`, `BaseTransition`). The pattern:

- Each screen or transition is a `Flow` type with a nested `Injection` struct (its typed inputs) and a `start(injection:transitionHandler:)` method.
- A flow is launched by `coordinator.show(SomeFlow.self, injection: SomeFlow.Injection(...))`.
- Inside `start`, the flow builds its view controller(s) and calls `transitionHandler.present(flow:transition:params:)` with a `BaseTransition` case (`.root`, `.inTabBar`, etc.). The `params` payload type is dictated by the transition (e.g. a `UINavigationController`, or a `(UINavigationController, UIImage?)` tuple for tab items).
- Flows handle user actions by conforming to their view controller's `...Output` delegate protocol (e.g. `OpenMoviesFlow: SearchViewOutput`), and respond by `coordinator.show(...)`-ing the next flow.

Entry point: `AppDelegate` creates a `MainCoordinator`, checks `CredentialsStore`, and launches either `LoginFlow` (no stored credentials) or `RootFlow`. `RootFlow` loads movies + shows, builds the `UITabBarController`, and shows one flow per tab: Search, Movies, Shows, Favorites, Settings. Long-pressing a movie, show, or episode opens an options flow (favorites, reset progress). Flows live under `Ororo-Player/Flows/`.

### Dependency injection: ServiceProvider

`ServiceProvider` (`Ororo-Player/Managers/ServiceProvider.swift`) is the composition root. Constructed from `Credentials`, it wires up `StorageService`, an authenticated `NetworkService` (as `NetworkRequestsService`), and the two data providers. It is then threaded through flow `Injection`s. Re-login constructs a brand-new `ServiceProvider`.

### Data providers: cache-then-network

`MoviesDataProvider` / `SeriesDataProvider` return Core Data-cached results first, then fetch from the API and persist. They only re-fire `onSuccess` from the network response when the cache was empty (the `shouldUpdateOnSuccess` flag), so the UI updates immediately from cache and silently refreshes storage otherwise.

Every model has a **dual representation**: a `Codable` value struct (e.g. `Movie`, `Episode`) used for API decoding and UI, and a `CD…` `NSManagedObject` (e.g. `CDMovie`) used for persistence. Conversion is via `init(movie: CDMovie)` and `CDMovie.configure(with: Movie)`. When adding a model field, update both representations plus the `.xcdatamodeld`.

`Episode` / `CDEpisode` still carry `downloadedId`, `isDownloading`, and `downloadSubtitlePath` from the removed iOS downloads feature. They are unused; leave them in place unless you also add a new Core Data model version.

### Networking

`NetworkService` wraps `URLSession`; its generic `request<T: Decodable>` decodes JSON and dispatches all callbacks on the main queue. `Endpoint` is a protocol exposing `path`; `ApiServiceEnpoint` is the enum of ororo.tv API v2 URLs. `RequestBuilder` attaches HTTP Basic auth from `Credentials`.

### Storage

Core Data through `StorageService(modelName: "Ororo")`. The `Ororo.xcdatamodeld` lives in the **OroroKit bundle**, not the app bundle. Writes go through `performAsync` (background context, auto-saves if `hasChanges`); reads go through the `Fetchable` protocol (`fetchAll` / `fetchOne` with NSPredicate-style clause strings). Entities: `CDMovie`, `CDShow`, `CDSeason`, `CDEpisode`, `CDSubtitle`.

### Generic collection views

All list screens are driven by `GenericCollectionViewDataSource<PresenterType: CollectionViewCellPresenter>`. A `CollectionViewCellPresenter` is a protocol of **static** methods that maps a `ModelType: Uniqueable` to a `CellType: UICollectionViewCell` and supplies sizing. Updates are diffed via `Diff.diff(old:new:)` and applied through `performBatchUpdates`. `Searchable` wraps any `DecoratedSearchable` (Movie or Show) so both share the search/list UI; its `id` uses bitwise-NOT for shows (`~id`) to keep movie and show IDs in disjoint spaces and avoid diff collisions.

### App-layer managers

- `VideoPlayerManager`: `AVPlayer` wrapper; resumes from a stored progress fraction, applies the playback quality cap, and exposes a periodic time observer (used to persist playback progress and sync subtitles).
- `SubtitleManager` / `SubtitleParser`: `SubtitleParser` (in OroroKit) regex-parses SRT-style payloads into `Interval`s; `searchSubtitles(payload:time:)` returns the line for a timestamp.
- `CredentialsStore`: persists `Credentials` as one generic-password Keychain item. `load()` migrates logins saved by older builds in `UserDefaults` and deletes the plain-text copy.

## Conventions

- **Logging**: use `logDebug(_:)` and `logFatal(_:)` from `OroroKit` (not `print` / `fatalError` directly). `logDebug` is currently a no-op (its body is commented out); `logFatal` traps.
- **Localization**: user-facing strings go through `String.localized()`; localizations exist for `en` and `ru`.
- **SwiftLint**: `identifier_name`, `force_cast`, and `type_name` rules are disabled; line-length warning is 150. Keep new code lint-clean since CI is `--strict`.

## Website (`docs/`)

`docs/` is the GitHub Pages site (`https://max-hunts.github.io/ororo-player-tvos/`), served from the `main` branch's `/docs` folder. It is plain HTML/CSS with no build step and no JavaScript; `.nojekyll` turns off Jekyll. `docs/index.html` is English and `docs/ru/index.html` is Russian, linked with `hreflang`; both share `docs/assets/style.css` and `docs/sitemap.xml` lists both. `docs/social-preview.jpg` (1280×640) is the Open Graph image, the README hero, and the image to upload as the repo's social preview.

The features, install steps, and FAQ appear in three places: `README.md` and both pages. When a feature changes, update all three, and bump `<lastmod>` in the sitemap.

## Authentication

Authentication goes through `LoginFlow` + `CredentialsStore`; credentials are sent to ororo.tv as HTTP Basic auth by `RequestBuilder`. You need a valid ororo.tv account to exercise the app against the live API.
