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
`aaindex_by_id` function provides a more direct interface for loading a specific
entry.

```julia-repl
julia> search("hydrophobicity")
82-element Vector{@NamedTuple{id::String, description::String}}:
 (id = "ARGP820101", description = "Hydrophobicity index (Argos et al., 1982)")
 (id = "BASU050101", description = "Interactivity scale obtained from the contact matrix (Bastolla et al., 2005)")
 (id = "BASU050102", description = "Interactivity scale obtained by maximizing the mean of correlation   coefficient over single-domain globular proteins (Bastolla et al., 2005)")
 (id = "BASU050103", description = "Interactivity scale obtained by maximizing the mean of correlation   coefficient over pairs of sequences sharing the TIM barrel fold (Bastolla et    al., 2005)")
 (id = "BIGC670101", description = "Residue volume (Bigelow, 1967)")
 (id = "BLAS910101", description = "Scaled side chain hydrophobicity values (Black-Mould, 1991)")
 (id = "BULH740101", description = "Transfer free energy to surface (Bull-Breese, 1974)")
 (id = "BULH740102", description = "Apparent partial specific volume (Bull-Breese, 1974)")
 (id = "CASG920101", description = "Hydrophobicity scale from native protein structures (Casari-Sippl, 1992)")
 ⋮
 (id = "WIMW960101", description = "Free energies of transfer of AcWl-X-LL peptides from bilayer interface to   water (Wimley-White, 1996)")
 (id = "WOLR790101", description = "Hydrophobicity index (Wolfenden et al., 1979)")
 (id = "YUTK870101", description = "Unfolding Gibbs energy in water, pH7.0 (Yutani et al., 1987)")
 (id = "YUTK870102", description = "Unfolding Gibbs energy in water, pH9.0 (Yutani et al., 1987)")
 (id = "YUTK870103", description = "Activation Gibbs energy of unfolding, pH7.0 (Yutani et al., 1987)")
 (id = "YUTK870104", description = "Activation Gibbs energy of unfolding, pH9.0 (Yutani et al., 1987)")
 (id = "ZASB820101", description = "Dependence of partition coefficient on ionic strength (Zaslavsky et al.,   1982)")
 (id = "ZIMJ680101", description = "Hydrophobicity (Zimmerman et al., 1968)")

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
```

This returns an array of `Index` and `AMatrix` objects with the following
respective interfaces:

```julia-repl
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

Entry metadata is stored in a separate struct with the following interface:

```julia-repl
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

Amino acid sequences can be transformed into vectors of values from an index
using the `transform` function.

```julia-repl
julia> transform(index, "ARN")
3-element Vector{Float64}:
  1.1
 -5.1
 -3.5
```

You can use the `transform` function to calculate the average value of an index
over a sequence.

```julia-repl
julia> using Statistics

julia> transform(index, ["Ala", "Arg", "Asn"]) |> mean
-2.5
```

You can also define your own functions to calculate properties of a sequence. For example, here is a function that calculates the GRAVY (Grand Average of Hydropathy) metric of a sequence.

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

## References

Kawashima, S., & Kanehisa, M. (2000). AAindex: amino acid index database.
Nucleic acids research, 28(1), 374. [https://doi.org/10.1093/nar/28.1.374](https://doi.org/10.1093/nar/28.1.374)
