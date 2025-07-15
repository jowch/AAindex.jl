import Base: getindex
using BioSequences: AminoAcid, AA_A, AA_R, AA_N, AA_D, AA_C, AA_Q, AA_E, AA_G,
AA_H, AA_I, AA_L, AA_K, AA_M, AA_F, AA_P, AA_S, AA_T, AA_W, AA_Y, AA_V

const AMINO_ACIDS = AminoAcid.(collect("ARNDCQEGHILKMFPSTWYV"))
const AMINO_ACID_TO_INDEX = Dict(aa => i for (i, aa) in enumerate(AMINO_ACIDS))
const AMINO_ACID_FROM_THREE_LETTER = Dict(
    "ALA" => AA_A, "ARG" => AA_R, "ASN" => AA_N, "ASP" => AA_D, "CYS" => AA_C,
    "GLN" => AA_Q, "GLU" => AA_E, "GLY" => AA_G, "HIS" => AA_H, "ILE" => AA_I,
    "LEU" => AA_L, "LYS" => AA_K, "MET" => AA_M, "PHE" => AA_F, "PRO" => AA_P,
    "SER" => AA_S, "THR" => AA_T, "TRP" => AA_W, "TYR" => AA_Y, "VAL" => AA_V
)

"""
Each entry has the following format:
  - H Accession number
  - D Data description
  - R PMID
  - A Author(s)
  - T Title of the article
  - J Journal reference
  - * Comment or missing
  - C Accession numbers of similar entries with the correlation coefficients
      of 0.8 (-0.8) or more (less).
      Notice: The correlation coefficient is calculated with zeros
      filled for missing values.
  - I Amino acid index data in the following order
      Ala    Arg    Asn    Asp    Cys    Gln    Glu    Gly    His    Ile
      Leu    Lys    Met    Phe    Pro    Ser    Thr    Trp    Tyr    Val
"""
struct Metadata
    id::String
    description::String
    reference::Array{String}
    journal::String
    title::String
    authors::String
    comment::String
end

"""
An amino acid index is a set of 20 numerical values representing various
physico-chemical and biochemical properties of amino acids.

"""
struct Index <: AbstractAAIndex
    data::SVector{20}
    correlation::Dict{String, AbstractFloat}
    metadata::Metadata
end

struct IndexSerialization
    data::Vector{Float64}
    correlation::Dict{String, Real}
    metadata::Metadata
end

"""
An amino acid mutation and contact potential matrix is __generally__ 20 x 20
numerical values representing similarity of amino acids.

Note that the row/column identities may not represent standard amino acid
labels depending on the source paper. They should be interpreted by the user.

Each entry has the following format:
  - H Accession number
  - D Data description
  - R PMID
  - A Author
  - T Title of the article
  - J Journal reference
  - * Comment or missing
  - M rows = ARNDCQEGHILKMFPSTWYV, cols = ARNDCQEGHILKMFPSTWYV
      AA
      AR RR
      AN RN NN
      AD RD ND DD
      AC RC NC DC CC
      AQ RQ NQ DQ CQ QQ
      AE RE NE DE CE QE EE
      AG RG NG DG CG QG EG GG
      AH RH NH DH CH QH EH GH HH
      AI RI NI DI CI QI EI GI HI II
      AL RL NL DL CL QL EL GL HL IL LL
      AK RK NK DK CK QK EK GK HK IK LK KK
      AM RM NM DM CM QM EM GM HM IM LM KM MM
      AF RF NF DF CF QF EF GF HF IF LF KF MF FF
      AP RP NP DP CP QP EP GP HP IP LP KP MP FP PP
      AS RS NS DS CS QS ES GS HS IS LS KS MS FS PS SS
      AT RT NT DT CT QT ET GT HT IT LT KT MT FT PT ST TT
      AW RW NW DW CW QW EW GW HW IW LW KW MW FW PW SW TW WW
      AY RY NY DY CY QY EY GY HY IY LY KY MY FY PY SY TY WY YY
      AV RV NV DV CV QV EV GV HV IV LV KV MV FV PV SV TV WV YV VV
"""
struct AMatrix <: AbstractAAIndex
    rowids::String
    columnids::String
    data::Union{SHermitianCompact, SMatrix}
    metadata::Metadata
end

function Base.getindex(index::Index, aa::AminoAcid)
    index.data[AMINO_ACID_TO_INDEX[aa]]
end

"""
    sequence_to_amino_acids(sequence)

Converts a sequence of amino acids into a vector of amino acids. Sequence can
be provided as a vector of characters (single-letter codes), a string of
single-letter codes, or a vector of strings (three-letter codes).
"""
sequence_to_amino_acids(sequence::AbstractVector{Char}) =
    AminoAcid.(sequence)

sequence_to_amino_acids(sequence::AbstractString) =
    sequence_to_amino_acids(collect(sequence))

sequence_to_amino_acids(sequence::AbstractVector{<:AbstractString}) =
    [AMINO_ACID_FROM_THREE_LETTER[uppercase(aa)] for aa in sequence]

"""
    transform(index::Index, sequence)

Transforms a sequence of amino acids into a vector of values from the given index. Sequences
should be provided as a vector of amino acids (either as single letter or three letter codes),
a string of single-letter codes, or a vector of strings (three-letter codes).

# Examples

```julia
julia> index = aaindex_by_id("KYTJ820101")

julia> transform(index, [AA_A, AA_R, AA_N])
[1.8, -4.5, -3.5]

julia> transform(index, "ARN")
[1.8, 1.8, 1.8]

julia> transform(index, ["ALA", "ARG", "ASN"])
[1.8, -4.5, -3.5]

julia> transform(index, ["Ala", "Arg", "Asn"])
[1.8, -4.5, -3.5]
```
"""
transform(index::Index, sequence::AbstractVector{AminoAcid}) =
    getindex.(Ref(index), sequence)

transform(index::Index, sequence::Any) =
    transform(index, sequence_to_amino_acids(sequence))
