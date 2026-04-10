# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-04-10

### Added
- `each` / `each_pair` for iterating over top-level key-value pairs
- `Enumerable` mixin (adds `map`, `select`, `reject`, `any?`, `none?`, etc.)
- `empty?` for checking if the wrapped hash has no keys
- `size` / `count` for returning the number of top-level keys
- `to_json` for serializing back to JSON
- `to_yaml` for serializing back to YAML

## [0.3.0] - 2026-04-09

### Added
- `fetch!` for strict path access that raises `KeyError` on missing paths
- `slice` for extracting a subset of dot-paths into a new wrapper
- `values_at` for retrieving multiple values in a single call

## [0.2.0] - 2026-04-03

### Added
- `exists?` for checking path existence
- `keys` for listing all dot-paths with optional depth limit
- `delete` for immutable path removal
- `flatten` for converting nested structure to flat dot-path hash
- `merge` for deep merging two wrapped structures

## [0.1.6] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.1.5] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.1.4] - 2026-03-26

### Fixed
- Add Sponsor badge to README
- Fix license section link format

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
