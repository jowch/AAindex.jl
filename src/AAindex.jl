"""
    AAindex

An AAindex parser.

Provides simple functionality to read AAindex database files. See [Kawashima
S and Kanehisa M. (2000)](https://dx.doi.org/10.1093%2Fnar%2F28.1.374)
"""
module AAindex

using StaticArrays

export AbstractAAIndex, Metadata, Index, AMatrix, parse

abstract type AbstractAAIndex end

include("./index.jl")
include("./parse.jl")

end # module
