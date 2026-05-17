# AAindex.jl

A package to read [AAindex](https://www.genome.jp/aaindex/) database files.
These contain a variety of reported physico-chemical and biochemical
properties of amino acids (Kawashima and Kanehisa, 2000). The package ships a
copy of the database files (v9.2) and downloads them on first use, so no manual
setup is required. You may still point the package at your own copy if you
prefer.

## Usage

### Searching for entries

`search` accepts a search term (_e.g._, `ANDN920101` or `hydrophobicity`) and
returns a sorted list of matching `(id, description)` pairs. Matching is
case-insensitive and covers each entry's id, description, title, and authors;
an exact id match sorts first.

```julia-repl
julia> search("hydrophobicity")
82-element Vector{@NamedTuple{id::String, description::String}}:
 (id = "ARGP820101", description = "Hydrophobicity index (Argos et al., 1982)")
 (id = "BASU050101", description = "Interactivity scale obtained from the contact matrix (Bastolla et al., 2005)")
 (id = "BASU050102", description = "Interactivity scale obtained by maximizing the mean of correlation   coefficient over single-domain globular proteins (Bastolla et al., 2005)")
 ⋮
 (id = "YUTK870104", description = "Activation Gibbs energy of unfolding, pH9.0 (Yutani et al., 1987)")
 (id = "ZASB820101", description = "Dependence of partition coefficient on ionic strength (Zaslavsky et al.,   1982)")
 (id = "ZIMJ680101", description = "Hydrophobicity (Zimmerman et al., 1968)")
```

Calling `search()` with no arguments returns every entry in the database, in
the same `(id, description)` shape. `ids()` returns just the accession numbers
as a sorted `Vector{String}`.

```julia-repl
julia> search()
707-element Vector{@NamedTuple{id::String, description::String}}:
 ⋮

julia> ids()
707-element Vector{String}:
 "ALTS910101"
 "ANDN920101"
 "ARGP820101"
 ⋮
```

### Loading an entry

`aaindex_by_id` loads a specific entry by its accession number. It returns
either an `Index` (a set of 20 per-amino-acid values) or an `AMatrix` (a
mutation or contact-potential matrix), depending on the record.

```julia-repl
julia> index = aaindex_by_id("JURD980101")
Index JURD980101
  Modified Kyte-Doolittle hydrophobicity scale (Juretic et al., 1998)
  values:
    A => 1.1
    R => -5.1
    N => -3.5
    D => -3.6
    C => 2.5
    Q => -3.68
    E => -3.2
    G => -0.64
    H => -3.2
    I => 4.5
    L => 3.8
    K => -4.11
    M => 1.9
    F => 2.8
    P => -1.9
    S => -0.5
    T => -0.7
    W => -0.46
    Y => -1.3
    V => 4.2
  79 correlated entries

julia> aaindex_by_id("ALTS910101")
AMatrix ALTS910101
  The PAM-120 matrix (Altschul, 1991)
  20×20 matrix (rows: ARNDCQEGHILKMFPSTWYV, cols: ARNDCQEGHILKMFPSTWYV)
```

`Index` and `AMatrix` have the following respective interfaces:

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

`Index.data` holds 20 values in the canonical `ARNDCQEGHILKMFPSTWYV` order.
AAindex marks unavailable values with `NA`; these are represented as `missing`
(not `NaN`), so a gap never silently poisons an aggregate — use `skipmissing`
to opt in to handling them.

Entry metadata is stored in a separate struct:

```julia
struct Metadata
    id::String
    description::String
    reference::Vector{String}
    journal::String
    title::String
    authors::String
    comment::String
end
```

### Looking up values

An `Index` can be indexed by a `BioSequences.AminoAcid`, a single-letter
`Char`, or a one- or three-letter code string:

```julia-repl
julia> index['A']
1.1

julia> index["A"]
1.1

julia> index["ALA"]
1.1
```

An `AMatrix` can be indexed by an integer pair or by an amino-acid pair, and
reports its dimensions via `size`. Note that a matrix's row/column identities
come straight from the source record and are not guaranteed to be standard
amino-acid labels.

```julia-repl
julia> matrix = aaindex_by_id("ALTS910101");

julia> size(matrix)
(20, 20)

julia> matrix[5, 18]
-8.0

julia> using BioSequences: AA_C, AA_W

julia> matrix[AA_C, AA_W]
-8.0
```

### Transforming sequences

Amino acid sequences can be transformed into vectors of values from an index
using the `transform` function. The sequence may be a string of single-letter
codes, a vector of `Char`s, a vector of one- or three-letter code strings, or a
vector of `AminoAcid`s.

```julia-repl
julia> transform(index, "ARN")
3-element Vector{Float64}:
  1.1
 -5.1
 -3.5
```

You can use `transform` to calculate the average value of an index over a
sequence.

```julia-repl
julia> using Statistics

julia> transform(index, ["Ala", "Arg", "Asn"]) |> mean
-2.5
```

You can also define your own functions to calculate properties of a sequence.
For example, here is a function that calculates the GRAVY (Grand Average of
Hydropathy) metric of a sequence.

```julia-repl
julia> function gravy(sequence)
           # use the Kyte-Doolittle hydropathy index
           index = aaindex_by_id("KYTJ820101")
           hydropathies = transform(index, sequence)

           sum(hydropathies) / length(sequence)
       end

julia> gravy("LLGDFFRKSKEKIGKEFKRIVQRIKDFLRNLVPRTES")
-0.7243243243243245
```

### Parsing raw records

To parse the raw text of a single AAindex record directly, use
`AAindex.parse`. It is intentionally *not* exported: it is a distinct function
from `Base.parse`, and exporting it would shadow `Base.parse` for code doing
`using AAindex`.

## References

Kawashima, S., & Kanehisa, M. (2000). AAindex: amino acid index database.
Nucleic acids research, 28(1), 374. [https://doi.org/10.1093/nar/28.1.374](https://doi.org/10.1093/nar/28.1.374)
