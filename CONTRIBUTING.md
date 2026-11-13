# Contributing

Thanks for your interest in improving Ororo.tv Player. Bug reports, fixes, and small
features are all welcome.

## Setup

1. Open `Ororo-Player.xcworkspace` (not the individual `.xcodeproj` files).
2. Build the `Ororo-Player-tvOS` scheme for an Apple TV simulator. No signing setup is needed.
3. To run on a device, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set
   your own team ID and bundle ID prefix. Never commit a team ID or personal bundle ID to the
   `.pbxproj` files.

You need an Ororo.tv account to sign in and exercise the app.

## Before opening a pull request

- `swiftlint lint --strict` passes (CI fails on warnings).
- `Ororo-KitTests` pass on a tvOS simulator.
- New user-facing strings go through `String.localized()` and are added to both `en` and `ru`
  `Localizable.strings`. If you can't write the Russian string, add the English text and say so
  in the PR.
- Use `logDebug(_:)` / `logFatal(_:)` from OroroKit instead of `print` / `fatalError`.
- Keep pull requests focused: one fix or feature per PR, with a short description of what
  changed and how you tested it.

## Reporting bugs

Open an issue with the tvOS version, what you did, what you expected, and what happened.
Never include your Ororo.tv password or other credentials in an issue or log.

For security problems, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## License

By contributing, you agree that your contributions are licensed under the [MIT license](LICENSE).
