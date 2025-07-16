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
search("hydrophobicity")
34-element Vector{@NamedTuple{id::InlineStrings.String15, description::String}}:
 (id = "CIDH920103", description = "Normalized hydrophobicity scales for alpha+beta-proteins (Cid et al., 1992)")
 (id = "CIDH920102", description = "Normalized hydrophobicity scales for beta-proteins (Cid et al., 1992)")
 (id = "KIDA850101", description = "Hydrophobicity-related index (Kidera et al., 1985)")
 (id = "CIDH920105", description = "Normalized average hydrophobicity scales (Cid et al., 1992)")
 (id = "WILM950101", description = "Hydrophobicity coefficient in RP-HPLC, C18 with 0.1%TFA/MeCN/H2O (Wilce et   al. 1995)")
 (id = "PRAM900101", description = "Hydrophobicity (Prabhakaran, 1990)")
 (id = "ZIMJ680101", description = "Hydrophobicity (Zimmerman et al., 1968)")
 (id = "EISD840101", description = "Consensus normalized hydrophobicity scale (Eisenberg, 1984)")
 (id = "CASG920101", description = "Hydrophobicity scale from native protein structures (Casari-Sippl, 1992)")
 (id = "PONP930101", description = "Hydrophobicity scales (Ponnuswamy, 1993)")
 (id = "WILM950102", description = "Hydrophobicity coefficient in RP-HPLC, C8 with 0.1%TFA/MeCN/H2O (Wilce et al.   1995)")
 (id = "RIER950101", description = "Hydrophobicity scoring matrix (Riek et al., 1995)")
 (id = "WILM950104", description = "Hydrophobicity coefficient in RP-HPLC, C18 with 0.1%TFA/2-PrOH/MeCN/H2O   (Wilce et al. 1995)")
 (id = "JURD980101", description = "Modified Kyte-Doolittle hydrophobicity scale (Juretic et al., 1998)")
 (id = "WOLR790101", description = "Hydrophobicity index (Wolfenden et al., 1979)")
 (id = "BLAS910101", description = "Scaled side chain hydrophobicity values (Black-Mould, 1991)")
 (id = "GOLD730101", description = "Hydrophobicity factor (Goldsack-Chalifoux, 1973)")
 (id = "PONP800106", description = "Surrounding hydrophobicity in turn (Ponnuswamy et al., 1980)")
 (id = "WILM950103", description = "Hydrophobicity coefficient in RP-HPLC, C4 with 0.1%TFA/MeCN/H2O (Wilce et al.   1995)")
 (id = "ENGD860101", description = "Hydrophobicity index (Engelman et al., 1986)")
 (id = "GEOD900101", description = "Hydrophobicity scoring matrix (George et al., 1990)")
 (id = "CIDH920104", description = "Normalized hydrophobicity scales for alpha/beta-proteins (Cid et al., 1992)")
 (id = "SWER830101", description = "Optimal matching hydrophobicity (Sweet-Eisenberg, 1983)")
 (id = "PONP800101", description = "Surrounding hydrophobicity in folded form (Ponnuswamy et al., 1980)")
 (id = "CIDH920101", description = "Normalized hydrophobicity scales for alpha-proteins (Cid et al., 1992)")
 (id = "ARGP820101", description = "Hydrophobicity index (Argos et al., 1982)")
 (id = "MANP780101", description = "Average surrounding hydrophobicity (Manavalan-Ponnuswamy, 1978)")
 (id = "PONP800103", description = "Average gain ratio in surrounding hydrophobicity (Ponnuswamy et al., 1980)")
 (id = "PONP800105", description = "Surrounding hydrophobicity in beta-sheet (Ponnuswamy et al., 1980)")
 (id = "FASG890101", description = "Hydrophobicity index (Fasman, 1989)")
 (id = "PONP800102", description = "Average gain in surrounding hydrophobicity (Ponnuswamy et al., 1980)")
 (id = "PONP800104", description = "Surrounding hydrophobicity in alpha-helix (Ponnuswamy et al., 1980)")
 (id = "JOND750101", description = "Hydrophobicity (Jones, 1975)")
 (id = "COWR900101", description = "Hydrophobicity index, 3.0 pH (Cowan-Whittaker, 1990)")

julia> index = aaindex_by_id("JURD980101")
Index(Union{Nothing, Float64}[1.1, -5.1, -3.5, -3.6, 2.5, -3.68, -3.2, -0.64, -3.2, 4.5, 3.8, -4.11, 1.9, 2.8, -1.9, -0.5, -0.7, -0.46, -1.3, 4.2], Dict{String, AbstractFloat}("BASU050103" => Float16(0.871), "JANJ790101" => Float16(0.868), "PONP800101" => Float16(0.858), "CORJ870107" => Float16(0.804), "MIYS990104" => Float16(-0.813), "KANM800104" => Float16(0.826), "FASG890101" => Float16(-0.857), "CORJ870101" => Float16(0.849), "NADH010101" => Float16(0.925), "JANJ780102" => Float16(0.928)…), Metadata("JURD980101", "Modified Kyte-Doolittle hydrophobicity scale (Juretic et al., 1998)", [""], "Theoretical and Computational Chemistry, 5, 405-445 (1998)", "Protein transmembrane structure: recognition and prediction by using   hydrophobicity scales through preference functions", "Juretic, D., Lucic, B., Zucic, D. and Trinajstic, N.", ""))
```

This returns an array of `Index` and `AMatrix` objects with the following
respective interfaces:

```julia-repl
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
