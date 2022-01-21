
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
