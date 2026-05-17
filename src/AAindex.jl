"""
    AAindex

An AAindex parser.

Provides simple functionality to read AAindex database files. See [Kawashima
S and Kanehisa M. (2000)](https://dx.doi.org/10.1093%2Fnar%2F28.1.374)
"""
module AAindex

using CSV
using DataDeps

import Base: getindex

export
# Types
AbstractAAIndex, Metadata, Index, AMatrix,

# Functions
aaindex_by_id, search, transform

# Note: `parse` is intentionally not exported. It is a distinct function from
# `Base.parse` (not a method of it); exporting it would shadow `Base.parse` for
# anyone doing `using AAindex`. Call it as `AAindex.parse` instead.

abstract type AbstractAAIndex end

include("./init.jl")
include("./data.jl")
include("./index.jl")
include("./parse.jl")
include("./search.jl")

end # module
