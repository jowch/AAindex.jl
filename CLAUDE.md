# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

AAindex.jl reads [AAindex](https://www.genome.jp/aaindex/) database files — flat-file
records of physico-chemical and biochemical properties of amino acids. The package
ships the v9.2 database files and downloads them on first use via DataDeps.

## Commands

```sh
# Run the full test suite (uses test/Project.toml for test-only deps)
julia --project=. -e 'using Pkg; Pkg.test()'

# Instantiate dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

There is no single-test runner. `test/runtests.jl` iterates over a hard-coded `tests`
array and `include`s each file; to run a subset, temporarily edit that array. The test
data files (`test_a1`, `test_index`, etc.) live in `test/testdata/testvars.jl` and are
loaded once by `runtests.jl` before any test file runs — individual test files cannot
be run standalone without that context.

`DATADEPS_ALWAYS_ACCEPT` is set in `runtests.jl` so the database download is
non-interactive during tests.

## Architecture

The data flow is: **raw flat-file record → `parse` → typed struct**, with an on-disk
CSV index providing random access by accession number.

- `src/init.jl` — `__init__` registers the `AAindex` DataDep (download URLs + SHA256s).
  On first load it builds `index.csv` if absent, then assigns the module-global `INDEX`
  (a `DataFrame`). The registry-CI branch skips all of this.
- `src/data.jl` — `build_index` walks each `aaindexN` file, recording each entry's
  byte `position`; `load_entry` seeks to that position and parses just that record.
  This avoids holding the whole database in memory.
- `src/parse.jl` — `parse(record::String)` turns one raw record into an `Index` or
  `AMatrix`. AAindex records are tag-prefixed lines (`H`, `D`, `R`, `A`, `T`, `J`, `C`,
  `I`, `M`, `*`); continuation lines start with whitespace and are folded into the
  preceding tag's value. `I` → `Index`, `M` → `AMatrix`.
- `src/index.jl` — type definitions (`Metadata`, `Index`, `AMatrix`), `getindex` for
  looking up a value by `AminoAcid`, and `transform` (maps an amino-acid sequence to a
  vector of index values). `sequence_to_amino_acids` accepts single-letter strings,
  three-letter codes, `Char` vectors, or `AminoAcid` vectors.
- `src/search.jl` — `search` and `aaindex_by_id` query the in-memory `INDEX` DataFrame.

### Key conventions

- The canonical amino-acid order is `ARNDCQEGHILKMFPSTWYV` (`AMINO_ACIDS` in `index.jl`);
  `Index.data` is a 20-element `SVector` in that order.
- `AMatrix` data is stored as `SHermitianCompact` when the record gives a lower-triangle
  matrix, otherwise `SMatrix`. Row/column identities are raw strings from the record
  header and are not guaranteed to be standard amino-acid labels.
- `AAindex.parse` is intentionally *not* exported — it is a distinct function from
  `Base.parse`, not a method of it, so exporting it would shadow `Base.parse`.

## Notes

- The database files are large and version-pinned by SHA256 in `src/init.jl`; updating
  the AAindex release requires updating those hashes.
- Tests run on GitHub Actions via `.github/workflows/CI.yml` (Julia 1.11 and latest).
