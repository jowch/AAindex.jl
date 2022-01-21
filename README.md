# AAindex.jl

A package to read [AAindex](https://www.genome.jp/aaindex/) database files.
These contain a variety of reported physico-chemical and biochemical
properties of amino acids (Kawashima and Kanehisa, 2000). The package now
also provides a copy of the database files (v9.2) for convenience. However,
you may still use your own copy if you want to.

## Usage
The main interface provided by this package is the `search` function, which
accepts a search term (_e.g._, `ANDN920101` or `hydrophobicity`) and,
optionally, a path to an AAindex database file. It will search through the
database and return a list of matching database entries. Additionally, the
`search_id` function provides a more direct interface for loading a specific
entry.

```julia-repl
julia> search("hydrophobicity")
16-element Vector{Tuple{String, String, DataType}}:
 ("CIDH920103", "Normalized hydrophobicity scales for alpha+beta-proteins (Cid et al., 1992)", Index)
 ("CIDH920102", "Normalized hydrophobicity scales for beta-proteins (Cid et al., 1992)", Index)
 ("CIDH920105", "Normalized average hydrophobicity scales (Cid et al., 1992)", Index)
 ("EISD840101", "Consensus normalized hydrophobicity scale (Eisenberg, 1984)", Index)
 ("JURD980101", "Modified Kyte-Doolittle hydrophobicity scale (Juretic et al., 1998)", Index)
 ("BLAS910101", "Scaled side chain hydrophobicity values (Black-Mould, 1991)", Index)
 ("PONP800106", "Surrounding hydrophobicity in turn (Ponnuswamy et al., 1980)", Index)
 ("CIDH920104", "Normalized hydrophobicity scales for alpha/beta-proteins (Cid et al., 1992)", Index)
 ("SWER830101", "Optimal matching hydrophobicity (Sweet-Eisenberg, 1983)", Index)
 ("PONP800101", "Surrounding hydrophobicity in folded form (Ponnuswamy et al., 1980)", Index)
 ("CIDH920101", "Normalized hydrophobicity scales for alpha-proteins (Cid et al., 1992)", Index)
 ("MANP780101", "Average surrounding hydrophobicity (Manavalan-Ponnuswamy, 1978)", Index)
 ("PONP800103", "Average gain ratio in surrounding hydrophobicity (Ponnuswamy et al., 1980)", Index)
 ("PONP800105", "Surrounding hydrophobicity in beta-sheet (Ponnuswamy et al., 1980)", Index)
 ("PONP800102", "Average gain in surrounding hydrophobicity (Ponnuswamy et al., 1980)", Index)
 ("PONP800104", "Surrounding hydrophobicity in alpha-helix (Ponnuswamy et al., 1980)", Index)

julia> aaindex_by_id("JURD980101")
```

This returns an array of `Index` and `AMatrix` objects with the following
respective interfaces:
```julia
struct Index <: AbstractAAIndex
    data::SVector{20}
    correlation::Dict{String, AbstractFloat}
    metadata::Metadata
end

struct AMatrix <: AbstractAAIndex
    rowids::String
    columnids::String
    data::Union{SHermitianCompact, SMatrix}
    metadata::Metadata
end
```

Entry metadata is stored in a separate struct with the following interface:
```julia
struct Metadata
    id::String
    description::String
    reference::Array{String}
    journal::String
    title::String
    authors::String
    comment::String
end
```

## References
Kawashima, S., & Kanehisa, M. (2000). AAindex: amino acid index database.
Nucleic acids research, 28(1), 374. https://doi.org/10.1093/nar/28.1.374
