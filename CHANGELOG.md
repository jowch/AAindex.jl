# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - Unreleased

### Added
- `show` methods for `Index`, `AMatrix`, and `Metadata`, so they no longer
  print as a raw struct dump.
- `AMatrix` indexing by integer pair and by amino-acid pair, plus `size`.
- `Index` indexing by one-letter `Char` and by one-/three-letter code string.
- `ids()` returns every accession number; no-argument `search()` returns every
  entry. `ids` is exported.
- `search` now also matches an entry's title and authors.

### Changed
- **Breaking:** `parse` is no longer exported. It is a distinct function from
  `Base.parse`, and exporting it shadowed `Base.parse` for callers using
  `using AAindex`. Call it as `AAindex.parse`.
- **Breaking:** index values now use `missing` (not `NaN`) for AAindex `NA`
  markers. `Index.data` is a `Vector{Union{Missing, Float64}}`, `AMatrix.data`
  is a `Matrix{Union{Missing, Float64}}`, `Index.correlation` is a
  `Dict{String, Float16}`, and `Metadata.reference` is a `Vector{String}`.
- `search` now returns results in a deterministic order (sorted by id, with any
  exact id match first).
- The package-wide index is held in a `const Ref`, making `search` and
  `aaindex_by_id` lookups type-stable.
- `is_key` now requires an exact (anchored) match and accepts any
  `AbstractString` rather than only `String`.
- `parse` now accepts any `AbstractString`.
- The package-wide index is a `Dict{String, Entry}` keyed by accession number;
  `aaindex_by_id` and `load_entry` are now O(1) lookups.

### Removed
- The StaticArrays and DataFrames dependencies, which were used only as
  containers.
- The unused internal `parse_id` function — use `parse(record).metadata.id`.

### Fixed
- `aaindex_by_id` no longer masks unrelated errors as "invalid identifier"; only
  genuinely unknown ids raise an `ArgumentError`.
- `parse` raises an `ArgumentError` for records with no `I`/`M` section instead
  of failing with a `convert` error, and tolerates entries with missing tags.
- `parse` no longer carries an abstract `::AbstractAAIndex` return annotation,
  so callers can infer the concrete `Union{Index, AMatrix}`.
- `_parse_index` validates that exactly 20 values were parsed.
- `_parse_correlations` no longer reads past the end of an odd token list.
- Matrix parsing correctly handles a lone `-` missing-value marker; it
  previously consumed surrounding whitespace and corrupted neighbouring values.
- `build_index` reports the source file and offset of an entry that fails to
  parse, and accessing the index before it is loaded raises a clear error
  rather than an `UndefRefError`.
- The matrix parser now uses an anchored `rows = ... cols = ...` header match
  and an explicit value-count check, raising a clear `ArgumentError` on a
  malformed header or an inconsistent matrix shape instead of guessing.

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
