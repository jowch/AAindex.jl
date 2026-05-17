# AAindex.jl — Correctness & Ergonomics Improvements

**Date:** 2026-05-17
**Status:** Approved design — ready for implementation planning
**Target version:** 0.4.0 (unreleased)

## Motivation

A broad audit of AAindex.jl found the package well-structured but carrying two
dependencies used only as containers, an unsafe missing-value representation,
and several ergonomic gaps. This design covers two of the four audited areas —
**correctness & robustness** and **API ergonomics** — and the dependency
simplifications that fall out of them. Documentation and a wider testing/QA
effort are explicitly out of scope, except where a change here would otherwise
leave the README contradicting the code.

Breaking changes are acceptable: 0.4.0 is unreleased.

## Goals

- Represent AAindex `NA` markers as `missing` rather than `NaN`.
- Remove dependencies (StaticArrays, DataFrames) that are used only as
  containers and earn no algorithmic benefit.
- Harden the matrix parser against fragile header detection and shape guessing.
- Add the ergonomic surface a user expects: readable `show` output, matrix
  indexing, flexible `Index` indexing, and a small discovery API.

## Non-goals

- A Documenter.jl docs site, doctests, or a wider documentation rewrite.
- New test fixtures for `aaindex2`/`aaindex3`, a whole-database smoke test, or
  `Aqua.jl`/`JET.jl` integration.
- Widening the `search` *result* shape beyond `(id, description)`.
- Search-by-`Regex` or other new query forms.

---

## Section 1 — Correctness & data model

### 1a. `NA` → `missing`

AAindex records mark unavailable values with `NA` (index records) or a lone `-`
/ `NA` (matrix records). These currently become `NaN`. `NaN` propagates
silently through `mean`/`sum`, so a single missing value quietly poisons an
aggregate. `missing` is the idiomatic Julia representation and forces callers
to opt in to handling gaps (`skipmissing`).

**Field and return-type changes:**

| Item | Before | After |
|---|---|---|
| `Index.data` | `SVector{20, Float64}` | `Vector{Union{Missing,Float64}}` |
| `AMatrix.data` | `Union{SHermitianCompact{N,Float64}, SMatrix{M,N,Float64}}` | `Matrix{Union{Missing,Float64}}` |
| `transform(...)` return | `Vector{Float64}` | `Vector{Union{Missing,Float64}}` |
| `getindex(::Index, aa)` | `Float64` (`NaN` for `NA`) | `Union{Missing,Float64}` (`missing` for `NA`) |

**Parser changes:**

- `_parse_index`: remove the `replace(data, "NA" => "NaN")` text substitution.
  Handle tokens explicitly — a `"NA"` token contributes `missing`, a numeric
  token contributes its parsed `Float64`, anything else (e.g. the `A/L` header
  labels) is skipped. The existing "exactly 20 values" length check is retained.
- `_parse_matrix`: emit `missing` instead of `NaN` for `-` / `NA` tokens.

`Index.data` is constructed as a `Vector` of length 20; an inner constructor
(or a construction-site assertion) enforces the length-20 invariant that the
type no longer encodes.

### 1b. Harden `_parse_matrix`

The current matrix parser has two fragile steps:

1. **Header detection** uses `findfirst(r"^[A-Za-z\s\-=,]+\s", data)` and then
   `findall(r"[A-Z\-]+", header)`, destructuring the result expecting exactly
   two uppercase runs. Any stray uppercase token breaks the destructuring.
2. **Triangular detection** uses the heuristic `length(values) < m*n`, and the
   triangular branch assumes the matrix is square (`SHermitianCompact{m}`).

**Changes:**

- Replace header detection with an anchored capture against the documented `M`
  tag format: `r"rows\s*=\s*([A-Z\-]+).*?cols\s*=\s*([A-Z\-]+)"s`. If it does
  not match, throw an `ArgumentError` naming the problem.
- Replace the count heuristic with an explicit shape check:
  - `length(values) == m*(m+1)÷2` ⇒ lower-triangular (requires `m == n`);
  - `length(values) == m*n` ⇒ full matrix;
  - anything else ⇒ `ArgumentError`.
- For a triangular input, materialize a full `Matrix` and fill **both**
  triangles, so symmetric access (`data[i,j] == data[j,i]`) is automatic
  without a specialized matrix type.

### 1c. Signatures & error messages

- `parse(record::AbstractString)` instead of `parse(record::String)`, for
  consistency with the rest of the API (e.g. `is_key`).
- Remove `parse_id`. Nothing in `src/` calls it; only `test/parse.jl`
  references it, and that test exists solely to test `parse_id`. The
  accession number is already reachable as `parse(record).metadata.id`.

### 1d. Remove StaticArrays

StaticArrays is used purely as a fixed-size container — there is no
static-array arithmetic anywhere in the package. Its performance rationale
(stack allocation, SIMD on small-array math) never applied to this IO- and
parse-bound package, and the switch to `Union{Missing,Float64}` (never an
`isbits` type) removes it entirely. With `Index.data` a `Vector` and
`AMatrix.data` a `Matrix`, StaticArrays is removed from `[deps]` and `[compat]`
in `Project.toml`.

---

## Section 2 — Index representation

### 2a. Remove DataFrames

The package-wide `INDEX` is a `DataFrame` of ~566 rows used only as a keyed
lookup table: id-based lookup is done with `subset(index, :id => ByRow(==(id)))`
— an allocating linear scan — and `search` iterates two columns. No joins,
grouping, or tabular algebra. `aaindex_by_id` performs the scan twice (once for
its `nrow != 1` check, then again inside `load_entry`).

DataFrames is replaced with a `Dict` keyed by accession number.

```julia
struct Entry
    aaindex::String      # which database file the record lives in
    position::Int        # byte offset of the record within that file
    description::String
    title::String
    authors::String
end

const INDEX = Ref{Dict{String,Entry}}()
```

- `index()` returns the `Dict{String,Entry}` (same accessor, new return type).
- `aaindex_by_id` / `load_entry` become O(1) `haskey` + `getindex` lookups
  instead of two O(n) scans.
- The two-argument dependency-injection methods (`search(index, term)`,
  `aaindex_by_id(index, id)`, `load_entry(index, id)`) keep their shape; the
  injected parameter type changes from `::DataFrame` to `::Dict{String,Entry}`.

A bonus of removing DataFrames: `CSV.File` currently yields
`InlineStrings.String15` ids that leak into the public `search` return type.
Building `Entry` with plain `String` fields removes that leak — `search`
results become `@NamedTuple{id::String, description::String}`.

### 2b. CSV is retained

Record descriptions and titles contain commas, so robust quoted-field IO is
required; `DelimitedFiles` is not safe here. `CSV.File` is iterable on its own
and does not need DataFrames as a sink, so CSV stays as the on-disk format.

- `build_index` writes a CSV with columns
  `(id, aaindex, position, description, title, authors)`.
- `load_index` reads that CSV and builds the `Dict{String,Entry}`.

### 2c. `authors` and `title` get a consumer

`authors` and `title` are kept in `Entry` (and the on-disk index) rather than
dropped, and `search` is extended to match against them (see 3d). This keeps
the in-memory index self-sufficient for search: every searchable field lives
in the `Dict`, so `search` never reads from disk. Loading a full record is
reserved for `aaindex_by_id`, when the caller actually wants the data.

---

## Section 3 — API ergonomics

### 3a. `Base.show` methods

`Index`, `AMatrix`, and `Metadata` currently print as a raw struct dump. Define
both tiers of Julia's display protocol for each:

- Two-argument `show(io, x)` — terse, used inside containers (e.g.
  `Index KYTJ820101`).
- `show(io, ::MIME"text/plain", x)` — rich multi-line display: accession id,
  description, the 20 amino-acid values (aligned) or the matrix dimensions, and
  the correlation count for an `Index`.

Exact formatting is left to implementation; the requirement is that neither
type dumps its full internal representation.

### 3b. `AMatrix` indexing

`AMatrix` currently has no `getindex`. Add:

- `getindex(::AMatrix, ::Integer, ::Integer)` — delegates to `data`.
- `getindex(::AMatrix, ::AminoAcid, ::AminoAcid)` — resolves positions via
  `rowids` / `columnids`. Throws an `ArgumentError` if a label is not present
  (matrix row/column identities are not guaranteed to be standard amino-acid
  labels).
- `Base.size(::AMatrix)` — delegates to `data`.

### 3c. Flexible `Index` indexing

`getindex(::Index, ::AminoAcid)` already exists. Add:

- `getindex(::Index, ::Char)` — single-letter code.
- `getindex(::Index, ::AbstractString)` — one- or three-letter code.

Both reuse the conversion logic already used by `sequence_to_amino_acids`, so
`Index` indexing accepts everything `transform` already accepts.

### 3d. Discovery API

- `ids()` → `Vector{String}` of every accession number in the index.
- `search()` (no arguments) → all `(id, description)` pairs, sorted by id —
  the same result shape as `search(term)`.
- `search(term)` now matches `term` (case-insensitively) against `id`,
  `description`, `title`, **and** `authors`. An exact `id` match still sorts
  first; results remain `(id, description)` pairs.
- `ids` is added to the package exports. `search` and `transform` exports are
  unchanged.

Entry count is `length(ids())`; no dedicated count function is added (a module
cannot define `Base.length`).

---

## Consequences

### README

Documentation is out of scope, but these changes make the current README
examples wrong (struct definitions, REPL output, return types). The README is
updated **minimally** — only the examples directly broken by this work:

- The `Index` / `AMatrix` / `Metadata` struct listings.
- The `aaindex_by_id` REPL output (no longer a raw struct dump; new field
  types).
- `transform` output types where a `missing` could appear.

No new documentation sections, no docs site.

### CHANGELOG

New entries are added under the existing `## [0.4.0] - Unreleased` section,
following the Keep a Changelog format already in use, covering: the
`NA` → `missing` change, removal of StaticArrays and DataFrames, the new
`show` / indexing / discovery API, and the matrix-parser hardening.

---

## Testing

This work updates the existing test suite rather than expanding test scope.

- `test/parse.jl`: update for `missing` (replace `isnan` assertions with
  `ismissing`); update the `AMatrix.data` / `Index.data` type assertions for
  `Matrix` / `Vector`; add a case for the hardened triangular-vs-full shape
  check; drop the `parse_id` testset.
- `test/index.jl`: update `transform` expectations for the
  `Union{Missing,Float64}` element type; add cases for `getindex(::Index, ::Char)`
  and `getindex(::Index, ::AbstractString)`.
- `test/data.jl`: update for the `Dict{String,Entry}` index type instead of a
  `DataFrame`.
- `test/search.jl`: add cases for no-arg `search()`, `ids()`, and `search`
  matching `title` / `authors`.
- New cases: `missing` propagation through `transform`, `AMatrix` indexing by
  integer pair and amino-acid pair (plus the absent-label error), and `show`
  output not containing a raw struct dump.

## Implementation risks

- `Entry` / `Dict` construction from `CSV.File`: ensure id and string fields
  are materialized as `String` (not `InlineStrings`/`SubString`) when building
  the `Dict`.
- The length-20 invariant on `Index.data` is no longer enforced by the type;
  it must be asserted at construction.
- `_parse_matrix`'s anchored header regex must be checked against the shipped
  `aaindex2` / `aaindex3` files to confirm the `rows = … cols = …` format holds
  for every matrix record.
