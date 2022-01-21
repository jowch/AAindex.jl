"""
    AAindex

An AAindex parser.

Provides simple functionality to read AAindex database files. See [Kawashima
S and Kanehisa M. (2000)](https://dx.doi.org/10.1093%2Fnar%2F28.1.374)
"""
module AAindex

using DataDeps
using JLD2
using StaticArrays

export 
# Types
AbstractAAIndex, Metadata, Index, AMatrix, 

# Functions
parse, aaindex_by_id, search

abstract type AbstractAAIndex end

include("./init.jl")
include("./data.jl")
include("./index.jl")
include("./parse.jl")
include("./search.jl")

end # module
