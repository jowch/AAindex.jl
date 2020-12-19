# AAindex.jl

A package to read [AAindex](https://www.genome.jp/aaindex/) database files. These contain a variety of reported
physico-chemical and biochemical properties of amino acids (Kawashima and Kanehisa, 2000).

## Usage
The main interface provided by this package is the `parse` function, which
accepts a path to an AAindex database file and returns a list of all (or
requested) database entries in specified file.

```julia-repl
julia> entries = parse("./aaindex1")
julia> specific_entries = parse("./aaindex1", ["ABCD123456"])
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
Kawashima, S., & Kanehisa, M. (2000). AAindex: amino acid index database. Nucleic acids research, 28(1), 374. https://doi.org/10.1093/nar/28.1.374
