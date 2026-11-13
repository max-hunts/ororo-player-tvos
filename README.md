[![CI][ci-badge]][ci-url]
[![Swift][swift-badge]][swift-url]
[![Platform][platform-badge]][platform-url]
[![License][mit-badge]][mit-url]

# Ororo.tv Player

An unofficial Apple TV app for watching [Ororo.tv](https://ororo.tv/en).
Written in pure Swift. The only third-party dependency is the author's own
[Transitions](https://github.com/maxovtsin/Transitions) navigation library, which ships
prebuilt as a committed `xcframework`, so a fresh clone builds without running Carthage.

> This project is not affiliated with, endorsed by, or sponsored by Ororo.tv.
> You need your own Ororo.tv account to use it.

## Requirements

- Xcode with the tvOS SDK (tested with Xcode 27)
- tvOS 15 or later
- An Ororo.tv account

## Getting started

1. Clone the repo.
2. Open `Ororo-Player.xcworkspace` (always the workspace, never an individual project).
3. Select the `Ororo-Player-tvOS` scheme and an Apple TV simulator.
4. Build and run.
5. Sign in with your Ororo.tv account. Credentials are stored in the Keychain on the device and sent only to ororo.tv, as HTTP Basic auth.

### Running on a real Apple TV

The simulator needs no signing setup. To install on a device, give Xcode your own team and
bundle ID prefix:

```
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Then edit `Config/Local.xcconfig`. It is git-ignored, so your team ID stays out of commits.

## Features

- [x] Movies and shows, with genre filters and sorting.
- [x] Search across movies and shows.
- [x] Subtitles.
- [x] Favorites.
- [x] Resume playing from where you stopped.
- [x] Playback quality picker.
- [x] Sign in with your Ororo.tv account.

- [ ] Subtitle language picker.
- [ ] A queue for episodes.
- [ ] Let `GenericCollectionViewDataSource` show different kinds of cells on the same screen.

## Development

```
swiftlint lint --strict
xcodebuild test -workspace Ororo-Player.xcworkspace -scheme Ororo-KitTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for details and [CLAUDE.md](CLAUDE.md) for an
architecture overview.

## License

**Ororo.tv Player** is released under the [MIT license](LICENSE).

[ci-badge]: ../../actions/workflows/ci.yml/badge.svg
[ci-url]: ../../actions/workflows/ci.yml
[swift-badge]: https://img.shields.io/badge/swift-5-orange.svg?style=flat
[swift-url]: https://swift.org
[platform-badge]: https://img.shields.io/badge/platform-tvos-lightgrey.svg
[platform-url]: https://developer.apple.com/tvos/
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: LICENSE
