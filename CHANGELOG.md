# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - Unreleased

### Changed
- **Breaking:** `parse` is no longer exported. It is a distinct function from
  `Base.parse`, and exporting it shadowed `Base.parse` for callers using
  `using AAindex`. Call it as `AAindex.parse`.
- `Index.data` is now typed `SVector{20, Float64}` and `Index.correlation` is
  now `Dict{String, Float16}`, replacing the previous abstract element types.
- `search` now returns results in a deterministic order (sorted by id, with any
  exact id match first).
- The package-wide index is held in a `const Ref`, making `search` and
  `aaindex_by_id` lookups type-stable.

### Fixed
- `aaindex_by_id` no longer masks unrelated errors as "invalid identifier"; only
  genuinely unknown ids raise an `ArgumentError`.
- `parse` raises an `ArgumentError` for records with no `I`/`M` section instead
  of failing with a `convert` error, and tolerates entries with missing tags.
- `_parse_index` validates that exactly 20 values were parsed.
- `_parse_correlations` no longer reads past the end of an odd token list.

## [0.3.0]

### Added
- `transform` function for mapping amino acid sequences onto index values.
- Amino acid handling based on BioSequences.

### Removed
- JLD2 dependency.

## [0.2.0] - 2020-12-19

### Added
- Package provided copy of AAindex database files (v9.2)
- `search` and `is_key` utility functions for finding appropriate indices.
