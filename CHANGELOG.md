# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog,
and this project follows Semantic Versioning.

## [1.4.2] - 2026-04-30

### Fixed
- Fixed a Retail tooltip taint error caused by using secret/tainted player GUID strings as inspect cache keys.
- Fixed 'attempted to index a table that cannot be indexed with secret keys' during GameTooltip mouseover player info updates.
- Reworked inspect cache/throttle keys to use an internal safe mouseover key instead of 'UnitGUID()', 'UnitName()', or 'UnitFullName()'.
- Added safe table access helpers for inspect cache and inspect request throttling.
- Cleared mouseover inspect state when tooltip unit or mouseover target changes to prevent stale inspect data.

## [1.4.1] - 2026-04-30

### Fixed
- Fixed a critical taint error caused by comparing tooltip text (GetText()) against addon-generated strings in TooltipHasLine.
- Fixed a taint-related error triggered by comparing secret/tainted unit name strings returned by UnitFullName.
- Fixed repeated errors: attempt to compare local 'existing' (a secret string value) in player tooltip handling.
- Fixed repeated errors: attempt to compare local 'name' (a secret string value) in inspect key generation.

### Changed
- Reworked player tooltip deduplication logic to rely exclusively on internal tooltip state instead of scanning and comparing tooltip text.
- Replaced inspect cache key generation from UnitFullName to UnitGUID for safer and taint-free identification.
- Simplified inspect queue validation by removing unnecessary unit string comparisons.

### Improved
- Increased overall stability of the playerinfo module when interacting with secure/tainted tooltip data.
- Reduced risk of UI taint propagation when hovering player tooltips repeatedly.
- Improved compatibility with Blizzard's protected tooltip system in Retail.

## [1.4.0] - 2026-04-24

### Fixed
- Fixed a critical Lua error:
- attempted to index a table that cannot be indexed with secret keys.
- Replaced unsafe GUID-based table indexing with a safe Name-Realm key.
- Fixed player item level (ilvl) disappearing from tooltips after inspect updates.
- Fixed flickering of player ilvl/spec caused by tooltip re-rendering and stale state tracking.

### Changed
- Reworked inspect cache system to use a safe and stable key instead of GUID values.
- Improved tooltip rendering logic to verify actual line presence instead of relying only on internal state flags.
- Adjusted inspect request flow to allow re-fetching data when cache is missing without causing spam.

### Performance
- Prevented inspect requests while in combat.
- Added per-unit inspect throttling to avoid repeated inspect calls.
- Reduced reliance on OnUpdate for inspect triggering.
- Increased inspect ticker interval to lower CPU usage.
- Optimized inspect queue processing to minimize unnecessary API calls.

### Stability
- Improved compatibility with Retail security restrictions related to “secret” values.
- Hardened tooltip update behavior during rapid mouseover changes.
- Improved consistency of player info display across delayed inspect callbacks and tooltip refreshes.

## [1.3.2] - 2026-03-10

### Fixed
- Fixed a taint-related error caused by comparing secret GUID string values during the inspect/player tooltip flow.
- Fixed repeated secure execution errors caused by passing tooltip-derived secret unit values into `UnitExists()` and related unit APIs.
- Reworked player inspect resolution to use a safe `mouseover` unit token path for GameTooltip instead of unsafe tooltip unit values.

### Changed
- Simplified inspect queue and inspect-ready handling to avoid unsafe GUID comparisons.
- Hardened player tooltip update logic to rely on cached inspect data without reusing secret tooltip unit references.
- Improved player info tooltip stability in `OnUpdate`, delayed inspect callbacks, and `INSPECT_READY` handling.

## [1.3.1] - 2026-03-10

### Fixed
- Fixed a taint-related error caused by comparing secret/tainted tooltip string values directly.
- Fixed stack tooltip errors triggered from action bar item tooltips (`SetAction` path).
- Improved duplicate-line detection to avoid unsafe string comparisons in tooltip state tracking.

### Changed
- Added defensive error handling around tooltip text writes and selected API calls.
- Improved stack count normalization for action bar items by safely falling back to owned item count when needed.
- Hardened inspect cleanup flow and tooltip rendering paths to reduce edge-case UI errors.

## [1.3.0] - 2026-03-10

### Added
- Player item level.

## [1.2.0] - 2026-03-07

### Added
- Support for showing stack count in the item tooltip while viewing items in the Auction House.
- Added Auctionator support.

### Fixed
- Prevented a taint error when reading tooltip data in certain secure contexts.

## [1.1.1] - 2026-03-06

### Added
- Initial support for IconID.
- Individual checkboxes in the addon options.

### Changed
- Improved ID presentation inside the tooltip.

## [Unreleased]

### Added
- Option to show/hide IconID in the tooltip.

### Changed
- Adjusted the visual alignment of IconID below ItemID/SpellID.

### Fixed
- Fixed stack display for usable items on action bars.