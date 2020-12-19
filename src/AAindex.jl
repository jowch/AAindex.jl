"""
    AAindex

An AAindex parser.

Provides simple functionality to read AAindex database files. See [Kawashima
S and Kanehisa M. (2000)](https://dx.doi.org/10.1093%2Fnar%2F28.1.374)
"""
module AAindex

using StaticArrays

export 
# Types
AbstractAAIndex, Metadata, Index, AMatrix, 

# Functions
parse, search, search_id, is_key

abstract type AbstractAAIndex end

include("./index.jl")
include("./parse.jl")
include("./search.jl")

end # module
