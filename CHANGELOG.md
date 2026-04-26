# Changelog

All notable changes to **HeyListen** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-04-26

### Fixed
- Ready check mirroring did nothing because the full-screen flash frame failed
  to build at init: `GameFontHuge` is a retail-only font object and not present
  on TBC Classic. Switched the warning text to `GameFontNormalHuge`.
- Added a lazy rebuild path for the flash frame so an init failure no longer
  silently disables ready check alerts.

### Changed
- `/hey test` now triggers both the toast and the full-screen flash, so future
  flash regressions show up without waiting for a real ready check.

## [0.1.0] - 2026-04-26

### Added
- Initial release.
- Mirror ready checks and whispers from one WoW account to another over the
  addon-message channel.
- Whisper toast (top-right, draggable) showing sender and recipient without
  realm suffix.
- Full-screen flash plus sound when a ready check fires on the partner account.
- Slash commands `/hey`, `/heylisten`, `/hl` with `pair`, `unpair`, `status`,
  `mute`, `test`, and `move`.
- Whisper text chunking for messages longer than the addon-message size limit.
- Sender filter to prevent loops when the partner whispers you directly.

[0.1.1]: https://github.com/stroexd/HeyListen/releases/tag/v0.1.1
[0.1.0]: https://github.com/stroexd/HeyListen/releases/tag/v0.1.0
