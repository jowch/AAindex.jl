using AAindex
using Test

const testdir = dirname(@__FILE__)

tests = [
    "index",
    "parse",
    "search"
]

include("testdata/testvars.jl")

@testset "AAindex" begin
    for t in tests
        @info "Testing $t"
        tp = joinpath(testdir, "$(t).jl")
        include(tp)
    end
end