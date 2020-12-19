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
julia> results = search("hydrophobicity")
julia> specific_entry = search_id("ABCD123456")
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
    key::String
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
