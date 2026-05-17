@testset "Index" begin
    index = aaindex_by_id("KYTJ820101")

    @testset "field types are concrete" begin
        @test index.data isa Vector{Union{Missing,Float64}}
        @test fieldtype(AAindex.Index, :data) == Vector{Union{Missing,Float64}}
        @test index.correlation isa Dict{String,Float16}
        @test fieldtype(AAindex.Metadata, :reference) == Vector{String}
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

    @testset "show does not dump the raw struct" begin
        @test sprint(show, index) == "Index KYTJ820101"

        rich = sprint(show, MIME("text/plain"), index)
        @test startswith(rich, "Index KYTJ820101")
        @test occursin(index.metadata.description, rich)
        # a raw struct dump would contain the constructor call / field types
        @test !occursin("Index(", rich)
        @test !occursin("Dict{", rich)

        @test sprint(show, index.metadata) == "Metadata KYTJ820101"

        rich_metadata = sprint(show, MIME("text/plain"), index.metadata)
        @test occursin("KYTJ820101", rich_metadata)
        @test !occursin("Metadata(", rich_metadata)
        @test occursin(index.metadata.authors, rich_metadata)
        @test occursin(index.metadata.journal, rich_metadata)
    end

    @testset "getindex by Char and String" begin
        @test index['A'] == 1.8
        @test index['R'] == -4.5
        @test index["A"] == 1.8
        @test index["ALA"] == 1.8
        # case-insensitive, like transform
        @test index["ala"] == 1.8
        # an uninterpretable code is an error
        @test_throws ArgumentError index["XX"]
    end

    @testset "transform propagates missing values" begin
        with_na = AAindex.parse(test_index_with_na)   # NA in the R/K column
        result = transform(with_na, "AR")
        @test result isa Vector{Union{Missing,Float64}}
        @test result[1] == 4.35
        @test ismissing(result[2])
    end
end
