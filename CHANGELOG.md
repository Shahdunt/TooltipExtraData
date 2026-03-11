# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog,
and this project follows Semantic Versioning.

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