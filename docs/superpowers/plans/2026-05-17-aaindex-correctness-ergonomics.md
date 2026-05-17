# AAindex.jl Correctness & Ergonomics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AAindex.jl represent missing values as `missing`, drop the StaticArrays and DataFrames dependencies, harden the matrix parser, and add a `show`/indexing/discovery ergonomic surface — all without leaving the test suite red between commits.

**Architecture:** The data flow (raw flat-file record → `parse` → typed struct, with an on-disk CSV index for random access) is unchanged. The two container dependencies are replaced by plain `Vector`/`Matrix`/`Dict`. Tasks are ordered so each commit leaves `Pkg.test()` green: the element-type changes land first (Tasks 1–2), StaticArrays is removed once unreferenced (Task 3), and the `Dict` index migration removes DataFrames in one atomic task (Task 5).

**Tech Stack:** Julia 1.11, BioSequences, CSV, DataDeps. Removing: StaticArrays, DataFrames.

**Source spec:** `docs/superpowers/specs/2026-05-17-aaindex-correctness-ergonomics-design.md`

**Working directory:** this plan executes in the worktree `.claude/worktrees/aaindex-audit-spec` (branch `worktree-aaindex-audit-spec`).

---

## Conventions for every task

- **There is no single-test runner.** The verification command for every task is the
  full suite:

  ```sh
  julia --project=. -e 'using Pkg; Pkg.test()'
  ```

  The first run downloads the AAindex database via DataDeps (`DATADEPS_ALWAYS_ACCEPT`
  is set in `test/runtests.jl`, so it is non-interactive). Subsequent runs are fast.
- After every task the **entire suite must pass** — the tasks are ordered to make
  that possible.
- The canonical amino-acid order is `ARNDCQEGHILKMFPSTWYV` (`AMINO_ACIDS` in
  `src/index.jl`).

---

## Task 1: `Index` — represent `NA` as `missing`, store data as a `Vector`

AAindex index records mark unavailable values with `NA`. They currently parse to
`NaN`, which propagates silently through `sum`/`mean`. Switch to `missing`, change
`Index.data` from `SVector{20,Float64}` to `Vector{Union{Missing,Float64}}`, and add
an inner constructor enforcing the length-20 invariant the type no longer encodes.

> **Spec 1a, two derived changes that need NO source edit:** `getindex(::Index, ::AminoAcid)`
> is `index.data[...]`, and `transform` is `getindex.(Ref(index), sequence)`. Once
> `Index.data`'s element type becomes `Union{Missing,Float64}`, the `getindex` return
> type and the `transform` result type follow automatically. They are exercised by
> the `transform`-propagation test added in Task 9 — do not look for a missing step here.

**Files:**
- Modify: `src/index.jl` (the `Index` struct definition, ~lines 46-50)
- Modify: `src/parse.jl` (`_parse_index`, ~lines 60-75)
- Modify: `test/parse.jl` (~lines 9-31)
- Modify: `test/index.jl` (~lines 4-8)

- [ ] **Step 1: Update the tests to expect `missing` and a `Vector`**

In `test/parse.jl`, replace the `Parse Index` and `Parse index with missing value`
testsets so they read:

```julia
    @testset "Parse Index" begin
        @test AAindex._parse_index(test_index) == test_index_result
        @test AAindex._parse_index(test_index) isa Vector{Union{Missing,Float64}}
    end

    @testset "Parse Index rejects wrong length" begin
        @test_throws ArgumentError AAindex._parse_index("I 1.0 2.0 3.0")
    end

    @testset "Parse entry" begin
        parsed = AAindex.parse(test_a1)

        @test parsed isa AAindex.Index
        @test parsed.metadata.id == "ANDN920101"
        @test parsed.data == test_index_result
    end

    @testset "Parse index with missing value" begin
        parsed = AAindex.parse(test_index_with_na)

        @test parsed isa AAindex.Index
        # the R/K column, position 2, holds the NA
        @test ismissing(parsed.data[2])
        @test parsed.data isa Vector{Union{Missing,Float64}}
    end
```

(The `AAindex.parse_id(test_a1)` call is replaced with the literal `"ANDN920101"`;
`parse_id` is removed in Task 4, and the `Parse ID` testset is also removed there.)

In `test/index.jl`, replace the `field types are concrete` testset:

```julia
    @testset "field types are concrete" begin
        @test index.data isa Vector{Union{Missing,Float64}}
        @test index.correlation isa Dict{String,Float16}
        @test fieldtype(AAindex.Metadata, :reference) == Vector{String}
    end
```

- [ ] **Step 2: Run the suite to verify the new assertions fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL — `ismissing(parsed.data[2])` is false (value is `NaN`), and the
`isa Vector{Union{Missing,Float64}}` checks fail (data is an `SVector`).

- [ ] **Step 3: Change the `Index` struct and add the length-20 inner constructor**

In `src/index.jl`, replace the `Index` struct (currently `data::SVector{20, Float64}`):

```julia
"""
An amino acid index is a set of 20 numerical values representing various
physico-chemical and biochemical properties of amino acids.
"""
struct Index <: AbstractAAIndex
    data::Vector{Union{Missing,Float64}}
    correlation::Dict{String,Float16}
    metadata::Metadata

    function Index(data, correlation, metadata)
        length(data) == 20 || throw(ArgumentError(
            "an Index requires exactly 20 amino acid values, got $(length(data))"
        ))
        new(data, correlation, metadata)
    end
end
```

- [ ] **Step 4: Rewrite `_parse_index` to emit `missing` for `NA`**

In `src/parse.jl`, replace `_parse_index` (the version with `replace(data, "NA" => "NaN")`):

```julia
function _parse_index(data::AbstractString)
    tokens = split(data, r"\s+", keepempty=false)

    # An "NA" token is a missing value; a numeric token is its parsed Float64;
    # anything else (e.g. the "A/L" header labels) is skipped.
    values = Union{Missing,Float64}[]
    for token in tokens
        if token == "NA"
            push!(values, missing)
        else
            value = tryparse(Float64, token)
            isnothing(value) || push!(values, value)
        end
    end

    length(values) == 20 || throw(ArgumentError(
        "expected 20 amino acid index values, parsed $(length(values))"
    ))

    values
end
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS — all testsets green.

- [ ] **Step 6: Commit**

```bash
git add src/index.jl src/parse.jl test/parse.jl test/index.jl
git commit -m "Represent NA index values as missing, store Index.data as a Vector"
```

---

## Task 2: `AMatrix` — `missing` values, `Matrix` storage, hardened parser

`_parse_matrix` has two fragile steps: header detection that destructures an
arbitrary number of uppercase runs, and a `length(values) < m*n` heuristic that
assumes a triangular matrix is square. Replace both with an anchored header regex
and an explicit shape check, store the result as a plain
`Matrix{Union{Missing,Float64}}`, and fill **both** triangles for triangular input
so symmetric access is automatic.

**Files:**
- Modify: `src/index.jl` (the `AMatrix` struct definition, ~lines 89-98)
- Modify: `src/parse.jl` (`_parse_matrix`, ~lines 78-122)
- Modify: `test/parse.jl` (the matrix testsets, ~lines 44-81)

- [ ] **Step 1: Update the matrix tests for `Matrix` storage and the shape check**

In `test/parse.jl`, replace the four matrix testsets and the
`AMatrix.data is concretely typed` testset with:

```julia
    @testset "Parse lower-triangular matrix" begin
        parsed = AAindex.parse(test_a2)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa Matrix{Union{Missing,Float64}}
        @test parsed.data[1, 1] == 3.0
        @test parsed.data[2, 1] == -3.0
        # both triangles are filled, so access is symmetric
        @test parsed.data[1, 2] == -3.0
    end

    @testset "Parse full matrix" begin
        parsed = AAindex.parse(test_full_matrix_record)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa Matrix{Union{Missing,Float64}}
        @test parsed.data[1, 1] == -0.94
        @test parsed.data[1, 2] == 1.26
    end

    @testset "Parse matrix with a missing value" begin
        parsed = AAindex.parse(test_matrix_with_missing)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa Matrix{Union{Missing,Float64}}
        @test parsed.data[1, 1] == 1.0
        # a lone "-" marks a missing value
        @test ismissing(parsed.data[1, 2])
        @test parsed.data[2, 1] == 3.0
        @test parsed.data[2, 2] == 4.0
    end

    @testset "AMatrix.data is concretely typed" begin
        @test fieldtype(AAindex.AMatrix, :data) == Matrix{Union{Missing,Float64}}
    end

    @testset "matrix parser rejects a malformed header" begin
        # no "rows = ..." clause
        @test_throws ArgumentError AAindex._parse_matrix("cols = AR    1.0")
    end

    @testset "matrix parser rejects an inconsistent value count" begin
        # rows=AR, cols=AR: full needs 4 values, triangular needs 3; 5 matches neither
        @test_throws ArgumentError AAindex._parse_matrix(
            "rows = AR, cols = AR    1 2 3 4 5"
        )
    end

    @testset "matrix parser rejects a non-square triangular matrix" begin
        # rows=ARND (4), cols=AR (2): 10 values matches the triangular count for
        # m=4 (4*5/2) but the matrix is not square
        @test_throws ArgumentError AAindex._parse_matrix(
            "rows = ARND, cols = AR    1 2 3 4 5 6 7 8 9 10"
        )
    end
```

- [ ] **Step 2: Run the suite to verify the matrix testsets fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL — `parsed.data isa Matrix{...}` is false (data is an `SHermitianCompact`
/ `SMatrix`), and the three new rejection testsets do not yet throw.

- [ ] **Step 3: Change the `AMatrix` struct to a plain `Matrix`**

In `src/index.jl`, replace the `AMatrix` struct (keep the docstring above it):

```julia
struct AMatrix <: AbstractAAIndex
    rowids::String
    columnids::String
    data::Matrix{Union{Missing,Float64}}
    metadata::Metadata
end
```

- [ ] **Step 4: Rewrite `_parse_matrix` with an anchored header and explicit shape check**

In `src/parse.jl`, replace `_parse_matrix` entirely:

```julia
function _parse_matrix(data::AbstractString)
    # The M-tag value documents its axes as "rows = ... cols = ...". Anchor on
    # that format and capture both axis-label strings; continuation lines have
    # already been folded into one whitespace-joined string by `parse`.
    header = match(r"rows\s*=\s*([A-Z\-]+).*?cols\s*=\s*([A-Z\-]+)"s, data)
    isnothing(header) && throw(ArgumentError(
        "matrix record header does not match the expected " *
        "\"rows = ... cols = ...\" format"
    ))
    rowids, columnids = String.(header.captures)

    # Everything after the matched header is the value block. Matrix records are
    # ASCII, so a code-unit offset is also a valid character index.
    value_text = data[(header.offset + ncodeunits(header.match)):end]

    # A lone "-" (or "NA") marks a missing value.
    values = Union{Missing,Float64}[]
    for token in split(value_text, r"\s+", keepempty=false)
        if token == "-" || token == "NA"
            push!(values, missing)
        else
            value = tryparse(Float64, token)
            isnothing(value) || push!(values, value)
        end
    end

    m, n = length(rowids), length(columnids)
    triangular = m * (m + 1) ÷ 2

    if length(values) == triangular
        m == n || throw(ArgumentError(
            "a lower-triangular matrix must be square, but the header gives " *
            "$m rows and $n columns"
        ))
        matrix = Matrix{Union{Missing,Float64}}(undef, m, m)
        k = 1
        for i in 1:m, j in 1:i
            matrix[i, j] = values[k]
            matrix[j, i] = values[k]   # fill both triangles
            k += 1
        end
    elseif length(values) == m * n
        matrix = Matrix{Union{Missing,Float64}}(undef, m, n)
        k = 1
        for i in 1:m, j in 1:n
            matrix[i, j] = values[k]
            k += 1
        end
    else
        throw(ArgumentError(
            "matrix has $(length(values)) values, which matches neither a full " *
            "$m×$n matrix ($(m * n)) nor a lower-triangular one ($triangular)"
        ))
    end

    return rowids, columnids, matrix
end
```

Note: `parse` already calls `AMatrix(_parse_matrix(pairs['M'])..., metadata)` — the
3-tuple `(rowids, columnids, matrix)` plus `metadata` matches the 4 `AMatrix` fields,
so `parse` itself needs no change.

- [ ] **Step 5: Run the suite to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/index.jl src/parse.jl test/parse.jl
git commit -m "Store AMatrix.data as a Matrix, harden the matrix parser"
```

---

## Task 3: Remove the StaticArrays dependency

After Tasks 1–2 nothing in `src/` or `test/` references `SVector`, `SMatrix`, or
`SHermitianCompact`. StaticArrays was used purely as a fixed-size container; with
`Union{Missing,Float64}` element types (never `isbits`) it earns no benefit. Remove it.

**Files:**
- Modify: `src/AAindex.jl` (~line 14)
- Modify: `Project.toml` (`[deps]` and `[compat]`)

- [ ] **Step 1: Confirm StaticArrays is unreferenced**

Run: `grep -rn -e StaticArrays -e SVector -e SMatrix -e SHermitianCompact src test`
Expected: no output. If anything is found, fix it before continuing.

- [ ] **Step 2: Remove the `using StaticArrays` line**

In `src/AAindex.jl`, delete the line:

```julia
using StaticArrays
```

- [ ] **Step 3: Remove StaticArrays from `Project.toml`**

Delete this line from `[deps]`:

```toml
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
```

Delete this line from `[compat]`:

```toml
StaticArrays = "0.12, 1.0"
```

- [ ] **Step 4: Run the suite to verify it still passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS — StaticArrays is gone and nothing references it.

- [ ] **Step 5: Commit**

```bash
git add src/AAindex.jl Project.toml
git commit -m "Remove the StaticArrays dependency"
```

---

## Task 4: `parse` accepts `AbstractString`; remove `parse_id`

`parse(record::String)` is narrower than the rest of the API (e.g. `is_key` takes
`AbstractString`). Widen it. `parse_id` has no caller in `src/` — the accession
number is reachable as `parse(record).metadata.id` — and only `test/parse.jl`
exercises it; remove both.

**Files:**
- Modify: `src/parse.jl` (`parse` signature ~line 10; delete `parse_id` ~lines 55-57)
- Modify: `test/parse.jl` (delete the `Parse ID` testset, ~lines 4-7)

- [ ] **Step 1: Delete the `Parse ID` testset**

In `test/parse.jl`, delete this testset entirely:

```julia
    @testset "Parse ID" begin
        @test AAindex.parse_id(test_a1) == "ANDN920101"
        @test AAindex.parse_id(test_a2) == "ALTS910101"
    end
```

(The `Parse entry` testset was already updated in Task 1 to use the literal
`"ANDN920101"` instead of `parse_id`, so no other test references `parse_id`.)

- [ ] **Step 2: Run the suite to confirm it still passes (baseline)**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS — removing the testset cannot break anything; this confirms the
baseline before the source change.

- [ ] **Step 3: Widen the `parse` signature and delete `parse_id`**

In `src/parse.jl`, change the function signature:

```julia
function parse(record::AbstractString)
```

And delete the `parse_id` function entirely:

```julia
function parse_id(record::String)::String
    only(match(r"(\w{4}\d{6})", record).captures)
end
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/parse.jl test/parse.jl
git commit -m "Widen parse to AbstractString, remove unused parse_id"
```

---

## Task 5: Replace the `DataFrame` index with a `Dict{String,Entry}` (remove DataFrames)

The package-wide `INDEX` is a ~566-row `DataFrame` used only as a keyed lookup
table: id lookups run an allocating linear scan (`subset(... ByRow(==(id)))`), and
`aaindex_by_id` scans twice. Replace it with a `Dict` keyed by accession number.
This is one atomic task: the `Entry` type, `INDEX` `Ref`, `build_index`,
`load_index`, `load_entry`, `aaindex_by_id`, `search`, and the DataFrames removal
all change together, because no intermediate state compiles.

**Files:**
- Modify: `src/init.jl` (add `Entry`, change `INDEX` `Ref`)
- Modify: `src/data.jl` (`build_index`, `load_index`, `load_entry`)
- Modify: `src/search.jl` (`aaindex_by_id`, `search`)
- Modify: `src/AAindex.jl` (remove `using DataFrames`)
- Modify: `Project.toml` (remove DataFrames from `[deps]` and `[compat]`)
- Modify: `test/data.jl`

- [ ] **Step 1: Update `test/data.jl` for the `Dict{String,Entry}` index**

Replace the whole body of `test/data.jl` with:

```julia
@testset "Data" begin
    @testset "Build index" begin
        AAindex.build_index("testdata", "testdata/index.csv")

        @test isfile("testdata/index.csv")

        index = AAindex.load_index("testdata/index.csv")

        @test index isa Dict{String,AAindex.Entry}
        @test length(index) == 2

        # first entry in testdata/aaindex1
        first = index["ANDN920101"]
        @test first.aaindex == "aaindex1"
        @test first.position == 0
        @test first.description == "alpha-CH chemical shifts (Andersen et al., 1992)"

        # second entry in testdata/aaindex1
        second = index["ARGP820101"]
        @test second.aaindex == "aaindex1"
        @test second.position == 582
        @test second.description == "Hydrophobicity index (Argos et al., 1982)"

        @testset "Load entry" begin
            index = AAindex.load_index("testdata/index.csv")
            entry = AAindex.load_entry(index, "ANDN920101")

            @test entry.metadata.id == "ANDN920101"
            @test entry.metadata.description ==
                "alpha-CH chemical shifts (Andersen et al., 1992)"
        end
    end
end
```

- [ ] **Step 2: Run the suite to verify `test/data.jl` fails**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL — `AAindex.Entry` does not exist yet and `load_index` returns a
`DataFrame`.

- [ ] **Step 3: Add the `Entry` type and change the `INDEX` `Ref` in `src/init.jl`**

In `src/init.jl`, replace the `INDEX` definition (currently `const INDEX = Ref{DataFrame}()`)
with the `Entry` struct followed by the new `Ref`:

```julia
"""
A row of the package-wide index: where a record lives on disk plus the metadata
fields needed to search for it without re-reading the database file.
"""
struct Entry
    aaindex::String      # which database file the record lives in
    position::Int        # byte offset of the record within that file
    description::String
    title::String
    authors::String
end

# The package-wide index of entries, populated by `__init__`. A `const` `Ref`
# keeps lookups type-stable (a non-const global would not be).
const INDEX = Ref{Dict{String,Entry}}()
```

The `index()` accessor below it is unchanged — it already just returns `INDEX[]`.

- [ ] **Step 4: Rewrite `build_index`, `load_index`, and `load_entry` in `src/data.jl`**

Replace the entire contents of `src/data.jl` with:

```julia
# Concrete row type for the on-disk index, so `CSV.write` gets a stable schema.
const IndexRow = @NamedTuple{
    id::String, aaindex::String, position::Int,
    description::String, title::String, authors::String
}

"""
    build_index(directory_path, index_file)

Builds an index of AAindex entries from the given directory. The index is stored
as a CSV file with columns for accession number, index file name, entry seek
position, description, title, and authors.
"""
function build_index(
    directory_path = datadep"AAindex",
    index_file = joinpath(datadep"AAindex", "index.csv")
)
    database_files = filter(startswith("aaindex"), readdir(directory_path))
    entry_records = IndexRow[]

    for database_file in database_files
        open(joinpath(directory_path, database_file), "r") do io
            entry_position = position(io)

            while !eof(io)
                entry = readuntil(io, "//\n")
                record = try
                    parse(entry)
                catch err
                    error("failed to parse the entry at position " *
                          "$entry_position in $database_file: " *
                          sprint(showerror, err))
                end

                push!(entry_records, (;
                    id = record.metadata.id,
                    aaindex = database_file,
                    position = entry_position,
                    description = record.metadata.description,
                    title = record.metadata.title,
                    authors = record.metadata.authors
                ))

                # move to next entry
                entry_position = position(io)
            end
        end
    end

    CSV.write(index_file, entry_records)
end

"""
    load_index(index_file = joinpath(datadep"AAindex", "index.csv"))

Loads the index of AAindex entries from the given CSV file into a
`Dict{String,Entry}` keyed by accession number.
"""
function load_index(index_file = joinpath(datadep"AAindex", "index.csv"))
    # An empty free-text field round-trips through CSV as `missing`; coerce it
    # back to "" (what `parse` produces for a blank tag). `String` also strips
    # CSV's InlineStrings / SubString types so they never leak into the API.
    text(x) = ismissing(x) ? "" : String(x)

    index = Dict{String,Entry}()
    for row in CSV.File(index_file)
        index[String(row.id)] = Entry(
            String(row.aaindex),
            row.position,
            text(row.description),
            text(row.title),
            text(row.authors)
        )
    end
    index
end

"""
    load_entry(id::AbstractString)

Loads the entry with the given id from the index.
"""
load_entry(id::AbstractString) = load_entry(index(), id)

function load_entry(index::Dict{String,Entry}, id::AbstractString)
    entry = index[id]

    open(joinpath(datadep"AAindex", entry.aaindex), "r") do io
        seek(io, entry.position)
        parse(readuntil(io, "//\n"))
    end
end
```

- [ ] **Step 5: Rewrite `aaindex_by_id` and `search` in `src/search.jl`**

In `src/search.jl`, replace the `aaindex_by_id` and `search` definitions (keep the
`is_key` function and the docstrings above each, updating the `search` docstring as
shown). The result is:

```julia
"""
    aaindex_by_id(id::AbstractString)

Load an AAindex entry by its accession number.

Throws an `ArgumentError` if `id` is not present in the index. Errors raised
while reading or parsing a valid entry are *not* masked — they propagate
unchanged.
"""
aaindex_by_id(id::AbstractString) = aaindex_by_id(index(), id)

function aaindex_by_id(index::Dict{String,Entry}, id::AbstractString)
    haskey(index, id) || throw(ArgumentError(
        "$id is not a valid AAindex identifier"
    ))
    load_entry(index, id)
end

"""
    search(term::AbstractString)

Search for AAindex entries by term based on id and description. Returns a list
of `(id, description)` pairs that match the term, sorted by id with any exact
id match first.
"""
search(term::AbstractString) = search(index(), term)

function search(index::Dict{String,Entry}, term::AbstractString)
    needle = lowercase(term)
    results = @NamedTuple{id::String, description::String}[]

    for (id, entry) in index
        if id == term || occursin(needle, lowercase(entry.description))
            push!(results, (; id, description = entry.description))
        end
    end

    sort!(results, by = r -> (r.id != term, r.id))
end
```

This `search` is **behavior-preserving** — it matches the same fields (exact `id`,
case-insensitive `description`) as the current `DataFrame`-based `search`, just over
the `Dict`. `test/search.jl` therefore needs no change and the suite stays green.
Task 9 extends matching to `title`/`authors` (spec 3d) and updates the search tests
in that same task. The no-argument `search()` and `ids()` are also added in Task 9 —
do not add them here.

- [ ] **Step 6: Remove `using DataFrames` from `src/AAindex.jl`**

In `src/AAindex.jl`, delete the line:

```julia
using DataFrames
```

- [ ] **Step 7: Remove DataFrames from `Project.toml`**

Delete this line from `[deps]`:

```toml
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
```

Delete this line from `[compat]`:

```toml
DataFrames = "1.7.0"
```

- [ ] **Step 8: Confirm DataFrames is fully unreferenced**

Run: `grep -rn -e DataFrames -e DataFrame -e "ByRow" -e "subset(" -e "nrow(" src test`
Expected: no output. If anything is found, fix it before continuing.

- [ ] **Step 9: Run the suite to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS — `test/data.jl`, `test/search.jl`, and the rest are green.

- [ ] **Step 10: Commit**

```bash
git add src/init.jl src/data.jl src/search.jl src/AAindex.jl Project.toml test/data.jl
git commit -m "Replace the DataFrame index with a Dict{String,Entry}"
```

---

## Task 6: `Base.show` methods for `Index`, `AMatrix`, and `Metadata`

These three types currently print as a raw struct dump. Define both tiers of
Julia's display protocol: a terse two-argument `show` (used inside containers) and
a rich `show(io, ::MIME"text/plain", x)` that never dumps the internal representation.

**Files:**
- Modify: `src/index.jl` (append the `show` methods)
- Modify: `test/index.jl` (append a `show` testset)
- Modify: `test/parse.jl` (append an `AMatrix` `show` assertion)

- [ ] **Step 1: Write the failing `show` testset in `test/index.jl`**

Append to `test/index.jl`, inside the outer `@testset "Index"` block (before its
closing `end`):

```julia
    @testset "show does not dump the raw struct" begin
        @test sprint(show, index) == "Index KYTJ820101"

        rich = sprint(show, MIME("text/plain"), index)
        @test startswith(rich, "Index KYTJ820101")
        @test occursin(index.metadata.description, rich)
        # a raw struct dump would contain the constructor call / field types
        @test !occursin("Index(", rich)
        @test !occursin("Dict{", rich)

        @test sprint(show, index.metadata) == "Metadata KYTJ820101"

        rich_metadata = sprint(show, MIME("text/plain"), index.metadata)
        @test occursin("KYTJ820101", rich_metadata)
        @test !occursin("Metadata(", rich_metadata)
    end
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL — `sprint(show, index)` currently produces a raw `Index(...)` dump.

- [ ] **Step 3: Append the `show` methods to `src/index.jl`**

Add at the end of `src/index.jl`:

```julia
# --- Display ---------------------------------------------------------------

Base.show(io::IO, metadata::Metadata) = print(io, "Metadata ", metadata.id)

function Base.show(io::IO, ::MIME"text/plain", metadata::Metadata)
    println(io, "Metadata ", metadata.id)
    println(io, "  description: ", metadata.description)
    println(io, "  authors:     ", metadata.authors)
    print(io,   "  journal:     ", metadata.journal)
end

Base.show(io::IO, index::Index) = print(io, "Index ", index.metadata.id)

function Base.show(io::IO, ::MIME"text/plain", index::Index)
    println(io, "Index ", index.metadata.id)
    println(io, "  ", index.metadata.description)
    println(io, "  values:")
    for (aa, value) in zip(AMINO_ACIDS, index.data)
        println(io, "    ", aa, " => ", value)
    end
    print(io, "  ", length(index.correlation), " correlated entries")
end

Base.show(io::IO, matrix::AMatrix) = print(io, "AMatrix ", matrix.metadata.id)

function Base.show(io::IO, ::MIME"text/plain", matrix::AMatrix)
    println(io, "AMatrix ", matrix.metadata.id)
    println(io, "  ", matrix.metadata.description)
    print(io, "  ", size(matrix.data, 1), "×", size(matrix.data, 2),
          " matrix (rows: ", matrix.rowids, ", cols: ", matrix.columnids, ")")
end
```

- [ ] **Step 4: Add the `AMatrix` `show` assertion to `test/parse.jl`**

Append to `test/parse.jl`, inside the outer `@testset "Parse"` block (before its
closing `end`):

```julia
    @testset "AMatrix show does not dump the raw struct" begin
        parsed = AAindex.parse(test_a2)
        @test sprint(show, parsed) == "AMatrix ALTS910101"

        rich = sprint(show, MIME("text/plain"), parsed)
        @test occursin("ALTS910101", rich)
        @test occursin("20×20", rich)
        @test !occursin("AMatrix(", rich)
    end
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/index.jl test/index.jl test/parse.jl
git commit -m "Add show methods for Index, AMatrix, and Metadata"
```

---

## Task 7: `AMatrix` indexing and `size`

`AMatrix` has no `getindex`. Add integer-pair indexing, amino-acid-pair indexing
(resolving positions via `rowids`/`columnids`), and `Base.size`.

**Files:**
- Modify: `src/index.jl` (append the `getindex`/`size` methods)
- Modify: `test/parse.jl` (append an `AMatrix indexing` testset)

- [ ] **Step 1: Write the failing `AMatrix indexing` testset in `test/parse.jl`**

Append to `test/parse.jl`, inside the outer `@testset "Parse"` block:

```julia
    @testset "AMatrix indexing" begin
        parsed = AAindex.parse(test_a2)   # rows/cols = ARNDCQEGHILKMFPSTWYV

        @test size(parsed) == (20, 20)
        @test parsed[1, 1] == 3.0
        @test parsed[2, 1] == -3.0

        # indexing by amino acid resolves positions via rowids / columnids
        @test parsed[AAindex.AminoAcid('A'), AAindex.AminoAcid('A')] == 3.0
        @test parsed[AAindex.AminoAcid('R'), AAindex.AminoAcid('A')] == -3.0
        # both triangles filled, so the lookup is symmetric
        @test parsed[AAindex.AminoAcid('A'), AAindex.AminoAcid('R')] == -3.0

        # a label not present in the matrix is an error
        small = AAindex.parse(test_matrix_with_missing)   # rows/cols = AR
        @test_throws ArgumentError small[
            AAindex.AminoAcid('N'), AAindex.AminoAcid('A')
        ]
    end
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL — `AMatrix` has no `getindex` or `size` methods.

- [ ] **Step 3: Append the `AMatrix` indexing methods to `src/index.jl`**

Add at the end of `src/index.jl`:

```julia
# --- AMatrix indexing ------------------------------------------------------

Base.size(matrix::AMatrix) = size(matrix.data)

Base.getindex(matrix::AMatrix, i::Integer, j::Integer) = matrix.data[i, j]

function Base.getindex(matrix::AMatrix, row::AminoAcid, column::AminoAcid)
    # rowids / columnids are raw strings from the record header and are not
    # guaranteed to be standard amino-acid labels, so a missing label is an error.
    i = findfirst(==(Char(row)), matrix.rowids)
    j = findfirst(==(Char(column)), matrix.columnids)
    isnothing(i) && throw(ArgumentError(
        "row label $row is not present in this matrix (rows: $(matrix.rowids))"
    ))
    isnothing(j) && throw(ArgumentError(
        "column label $column is not present in this matrix " *
        "(cols: $(matrix.columnids))"
    ))
    matrix.data[i, j]
end
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/index.jl test/parse.jl
git commit -m "Add AMatrix indexing by integer and amino-acid pair, and size"
```

---

## Task 8: Flexible `Index` indexing by `Char` and `AbstractString`

`getindex(::Index, ::AminoAcid)` exists. Add `Char` (single-letter code) and
`AbstractString` (one- or three-letter code) overloads, reusing the conversion
logic in `sequence_to_amino_acids` so `Index` indexing accepts everything
`transform` accepts.

**Files:**
- Modify: `src/index.jl` (append the two `getindex` methods)
- Modify: `test/index.jl` (append an indexing testset)

- [ ] **Step 1: Write the failing indexing testset in `test/index.jl`**

Append to `test/index.jl`, inside the outer `@testset "Index"` block:

```julia
    @testset "getindex by Char and String" begin
        @test index['A'] == 1.8
        @test index['R'] == -4.5
        @test index["A"] == 1.8
        @test index["ALA"] == 1.8
        # case-insensitive, like transform
        @test index["ala"] == 1.8
        # an uninterpretable code is an error
        @test_throws ArgumentError index["XX"]
    end
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL — `index['A']` hits a `MethodError` (no `getindex(::Index, ::Char)`).

- [ ] **Step 3: Append the `Char`/`String` `getindex` methods to `src/index.jl`**

Add to `src/index.jl`, immediately after the existing
`Base.getindex(index::Index, aa::AminoAcid)` method:

```julia
# Index by one-letter Char or by a one- or three-letter code string, reusing the
# conversion logic that `transform` already accepts.
Base.getindex(index::Index, code::Char) =
    index[only(sequence_to_amino_acids([code]))]

Base.getindex(index::Index, code::AbstractString) =
    index[only(sequence_to_amino_acids([code]))]
```

(`[code]` is a `Vector{Char}` for a `Char` and a `Vector{String}` for a string,
each of which dispatches to an existing `sequence_to_amino_acids` method.)

- [ ] **Step 4: Run the suite to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/index.jl test/index.jl
git commit -m "Allow Index indexing by Char and one-/three-letter code string"
```

---

## Task 9: Discovery API — extend `search`, add `ids()` and no-arg `search()`; export `ids`

Extend `search` to also match an entry's `title` and `authors` (spec 3d), add
`ids()` (all accession numbers) and the no-argument `search()` (every entry, as
`(id, description)` pairs sorted by id), and export `ids`. Also add a test that a
`missing` value propagates through `transform`.

The `search` field-matching extension lives here, not in Task 5, so that the test
that proves it and any reconciliation of the existing `search` tests land in one
commit — keeping every task's suite green.

**Files:**
- Modify: `src/search.jl` (extend `search`, append `ids` and the no-arg `search`)
- Modify: `src/AAindex.jl` (add `ids` to the export list)
- Modify: `test/search.jl` (append discovery testsets; reconcile existing `search` tests)
- Modify: `test/index.jl` (append a `missing`-propagation testset)

- [ ] **Step 1: Write the failing discovery testsets in `test/search.jl`**

Append to `test/search.jl`, inside the outer `@testset "Search"` block:

```julia
    @testset "ids lists every accession number" begin
        all_ids = ids()
        @test all_ids isa Vector{String}
        @test issorted(all_ids)
        @test "KYTJ820101" in all_ids
        # the shipped v9.2 database has well over 500 entries
        @test length(all_ids) > 500
    end

    @testset "no-argument search returns every entry" begin
        @test length(search()) == length(ids())
        @test issorted([r.id for r in search()])
    end

    @testset "search matches title and authors" begin
        # an injected Dict makes the field-matching deterministic
        testindex = Dict(
            "AAAA000001" => AAindex.Entry(
                "aaindex1", 0,
                "a description", "a memorable title", "Ada Lovelace"
            )
        )
        @test only(AAindex.search(testindex, "memorable")).id == "AAAA000001"
        @test only(AAindex.search(testindex, "Lovelace")).id == "AAAA000001"
        @test isempty(AAindex.search(testindex, "no-such-term"))
    end
```

Append to `test/index.jl`, inside the outer `@testset "Index"` block:

```julia
    @testset "transform propagates missing values" begin
        with_na = AAindex.parse(test_index_with_na)   # NA in the R/K column
        result = transform(with_na, "AR")
        @test result isa Vector{Union{Missing,Float64}}
        @test result[1] == 4.35
        @test ismissing(result[2])
    end
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL — `ids` and the no-arg `search()` are undefined, and
`search(testindex, "memorable")` returns an empty result (`only` throws) because
Task 5's `search` matches only `id` and `description`.

- [ ] **Step 3: Extend `search` and add `ids` / no-arg `search` in `src/search.jl`**

In `src/search.jl`, replace the `search` docstring and the
`search(index::Dict{String,Entry}, term::AbstractString)` method (the
behavior-preserving version from Task 5) with the extended version below, then
append `ids` and the no-argument `search`:

```julia
"""
    search(term::AbstractString)

Search for AAindex entries whose id, description, title, or authors contain
`term` (case-insensitively). Returns a list of `(id, description)` pairs, sorted
by id with any exact id match first.
"""
search(term::AbstractString) = search(index(), term)

function search(index::Dict{String,Entry}, term::AbstractString)
    needle = lowercase(term)
    results = @NamedTuple{id::String, description::String}[]

    for (id, entry) in index
        if occursin(needle, lowercase(id)) ||
           occursin(needle, lowercase(entry.description)) ||
           occursin(needle, lowercase(entry.title)) ||
           occursin(needle, lowercase(entry.authors))
            push!(results, (; id, description = entry.description))
        end
    end

    # an exact id match sorts first; compare case-insensitively to stay
    # consistent with the case-insensitive matching above
    sort!(results, by = r -> (lowercase(r.id) != needle, r.id))
end

"""
    ids()

Returns a sorted `Vector{String}` of every accession number in the index.
"""
ids() = sort!(collect(keys(index())))

"""
    search()

Returns every entry as `(id, description)` pairs, sorted by id — the same result
shape as `search(term)`.
"""
search() = search(index(), "")
```

(`search(index, "")` works because `occursin("", x)` is always `true`; the sort key
`(r.id != "", r.id)` reduces to sorting purely by id.)

- [ ] **Step 4: Export `ids` from `src/AAindex.jl`**

In `src/AAindex.jl`, change the `# Functions` export line from:

```julia
aaindex_by_id, search, transform
```

to:

```julia
aaindex_by_id, ids, search, transform
```

- [ ] **Step 5: Run the suite; reconcile the existing `search` tests**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Extending `search` to match `title`/`authors` can make `search("PHAT")` or
`search("hydrophobicity")` in `test/search.jl` return entries they did not match
before — a *different* entry whose title or authors contains the term (for example,
`"phosphate"` contains the substring `"phat"`). If those existing testsets fail:

- Confirm the extra results genuinely contain the term in `title` or `authors` by
  inspecting them in the REPL — this is the feature working, not a bug.
- Update the affected assertions in `test/search.jl` to the new expected results.
  The `search` testset currently does `only(search("PHAT"))`; if there are now
  multiple matches, change it to locate the expected entry within the result, e.g.
  `result = only(filter(r -> r.id == "NGPC000101", search("PHAT")))`.
- Do **not** revert the `title`/`authors` matching to make the old test pass.

Re-run the suite until it is green.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/search.jl src/AAindex.jl test/search.jl test/index.jl
git commit -m "Add ids() and no-argument search(), export ids"
```

---

## Task 10: Update README and CHANGELOG

Documentation is out of scope except where this work makes the README contradict
the code. Update only the broken examples, and add CHANGELOG entries under the
existing `## [0.4.0] - Unreleased` section.

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Fix the struct listings in `README.md`**

Replace the `Index` / `AMatrix` listing (currently showing `data::SVector{20, Float64}`
and `data::Union{SHermitianCompact, SMatrix}`) with:

```julia
struct Index <: AbstractAAIndex
    data::Vector{Union{Missing, Float64}}
    correlation::Dict{String, Float16}
    metadata::Metadata
end

struct AMatrix <: AbstractAAIndex
    rowids::String
    columnids::String
    data::Matrix{Union{Missing, Float64}}
    metadata::Metadata
end
```

- [ ] **Step 2: Regenerate the `search("hydrophobicity")` example in `README.md`**

The result type changes (`InlineStrings.String15` → `String`) AND the result count
changes — extending `search` to match `title`/`authors` (Task 9) makes
`search("hydrophobicity")` return more entries than the old 34. Regenerate the whole
block from live output:

```sh
julia --project=. -e 'using AAindex; show(IOContext(stdout, :limit=>true, :displaysize=>(22,110)), MIME("text/plain"), search("hydrophobicity"))'
```

Replace the entire example output (the count line and every listed entry) with the
actual printed output. The element type must be `@NamedTuple{id::String, description::String}`.

- [ ] **Step 3: Verify the `transform` output type in `README.md`**

`transform` returns `Vector{Union{Missing,Float64}}` only when the sequence touches a
`missing` slot; for an all-present sequence Julia's broadcast narrows the element type
to `Float64`. The `transform(index, "ARN")` example uses JURD980101 (no `NA` at A/R/N),
so its real output is `3-element Vector{Float64}:`. Confirm with:

```sh
julia --project=. -e 'using AAindex; show(stdout, MIME("text/plain"), transform(aaindex_by_id("JURD980101"), "ARN"))'
```

and make the README block match the actual output (it should remain `Vector{Float64}`).

- [ ] **Step 4: Regenerate the `aaindex_by_id` REPL output in `README.md`**

The `julia> index = aaindex_by_id("JURD980101")` example currently shows a raw
struct dump, which is no longer how `Index` prints. Start a fresh REPL:

```sh
julia --project=. -e 'using AAindex; show(stdout, MIME("text/plain"), aaindex_by_id("JURD980101"))'
```

Replace the example's output block with the actual printed output. It must begin
with `Index JURD980101`, contain the description line, and contain **no**
`Index(` constructor dump and no `Dict{` field dump.

- [ ] **Step 5: Update `CHANGELOG.md`**

Under `## [0.4.0] - Unreleased`:

1. Rewrite the existing field-types bullet (currently "`Index.data` is now typed
   `SVector{20, Float64}` …") to describe the final 0.4.0 state:

   ```markdown
   - **Breaking:** index values now use `missing` (not `NaN`) for AAindex `NA`
     markers. `Index.data` is a `Vector{Union{Missing, Float64}}`, `AMatrix.data`
     is a `Matrix{Union{Missing, Float64}}`, `Index.correlation` is a
     `Dict{String, Float16}`, and `Metadata.reference` is a `Vector{String}`.
   ```

2. Add an `### Added` section (place it before `### Changed`):

   ```markdown
   ### Added
   - `show` methods for `Index`, `AMatrix`, and `Metadata`, so they no longer
     print as a raw struct dump.
   - `AMatrix` indexing by integer pair and by amino-acid pair, plus `size`.
   - `Index` indexing by one-letter `Char` and by one-/three-letter code string.
   - `ids()` returns every accession number; no-argument `search()` returns every
     entry. `ids` is exported.
   - `search` now also matches an entry's title and authors.
   ```

3. Add to the `### Changed` section:

   ```markdown
   - `parse` now accepts any `AbstractString`.
   - The package-wide index is a `Dict{String, Entry}` keyed by accession number;
     `aaindex_by_id` and `load_entry` are now O(1) lookups.
   ```

4. Add a `### Removed` section (place it before `### Fixed`):

   ```markdown
   ### Removed
   - The StaticArrays and DataFrames dependencies, which were used only as
     containers.
   - The unused internal `parse_id` function — use `parse(record).metadata.id`.
   ```

5. Add to the `### Fixed` section:

   ```markdown
   - The matrix parser now uses an anchored `rows = ... cols = ...` header match
     and an explicit value-count check, raising a clear `ArgumentError` on a
     malformed header or an inconsistent matrix shape instead of guessing.
   ```

- [ ] **Step 6: Fix the stale statements in `CLAUDE.md`**

`CLAUDE.md` is project-instruction context future contributors and agents rely on;
this work makes several of its statements wrong. Apply these exact replacements:

In the `src/init.jl` bullet, change `assigns the module-global `INDEX` (a `DataFrame`)`
to `assigns the module-global `INDEX` (a `Dict{String,Entry}`)`.

In the `src/parse.jl` bullet, change `` `parse(record::String)` turns one raw record ``
to `` `parse(record::AbstractString)` turns one raw record ``.

In the `src/search.jl` bullet, change `query the in-memory `INDEX` DataFrame.` to
`query the in-memory `INDEX` `Dict`.`

In the `### Key conventions` section, change:

```
  `Index.data` is a 20-element `SVector` in that order.
- `AMatrix` data is stored as `SHermitianCompact` when the record gives a lower-triangle
  matrix, otherwise `SMatrix`. Row/column identities are raw strings from the record
  header and are not guaranteed to be standard amino-acid labels.
```

to:

```
  `Index.data` is a 20-element `Vector{Union{Missing,Float64}}` in that order.
- `AMatrix.data` is a `Matrix{Union{Missing,Float64}}`; a lower-triangular record is
  expanded into a full matrix with both triangles filled. Row/column identities are
  raw strings from the record header and are not guaranteed to be standard
  amino-acid labels.
```

- [ ] **Step 7: Run the suite to confirm nothing broke**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: PASS — documentation-only changes, suite still green.

- [ ] **Step 8: Commit**

```bash
git add README.md CHANGELOG.md CLAUDE.md
git commit -m "Update README, CHANGELOG, and CLAUDE.md for the 0.4.0 correctness work"
```

---

## Final verification

- [ ] Run the full suite once more: `julia --project=. -e 'using Pkg; Pkg.test()'` — PASS.
- [ ] `grep -rn -e StaticArrays -e DataFrames -e SVector -e SMatrix src test` — no output.
- [ ] Confirm `Project.toml` `[deps]` lists only `BioSequences`, `CSV`, `DataDeps`.
```
