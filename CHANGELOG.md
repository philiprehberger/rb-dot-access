# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2026-03-24

### Fixed
- Standardize README code examples to use double-quote require statements

## [0.1.2] - 2026-03-24

### Fixed
- Fix Installation section quote style to double quotes
- Remove inline comments from Development section to match template

## [0.1.1] - 2026-03-22

### Changed
- Improve source code, tests, and rubocop compliance

## [0.1.0] - 2026-03-21

### Added
- Initial release
- Dot-notation access for nested hashes via `DotAccess.wrap(hash)`
- Nil-safe traversal with `NullAccess` object for missing keys
- Path-based `get` with dot-separated strings and optional default values
- Immutable `set` that returns a new wrapper instance
- YAML loading via `DotAccess.from_yaml(str_or_path)`
- JSON loading via `DotAccess.from_json(str)`
- Automatic symbol key normalization
