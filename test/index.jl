@testset "Index" begin
    index = aaindex_by_id("KYTJ820101")

    @testset "field types are concrete" begin
        @test index.data isa AAindex.SVector{20,Float64}
        @test index.correlation isa Dict{String,Float16}
    end

    @testset "getindex by amino acid" begin
        @test index[AAindex.AminoAcid('A')] == 1.8
        @test index[AAindex.AminoAcid('R')] == -4.5
    end

    @testset "transform" begin
        @test transform(index, "AAA") == [1.8, 1.8, 1.8]
        @test transform(index, "ARN") == [1.8, -4.5, -3.5]
    end

    @testset "transform is case-insensitive for single-letter codes" begin
        @test transform(index, "arn") == [1.8, -4.5, -3.5]
    end

    @testset "transform accepts three-letter codes of any case" begin
        @test transform(index, ["Ala", "ARG", "asn"]) == [1.8, -4.5, -3.5]
    end

    @testset "transform rejects unsupported sequence types" begin
        @test_throws ArgumentError transform(index, 123)
    end
end
