
@testset "Parse" begin

    @testset "Parse ID" begin
        @test AAindex.parse_id(test_a1) == "ANDN920101"
        @test AAindex.parse_id(test_a2) == "ALTS910101"
    end

    @testset "Parse Index" begin
        @test AAindex._parse_index(test_index) == test_index_result
    end

    @testset "Parse Index rejects wrong length" begin
        @test_throws ArgumentError AAindex._parse_index("I 1.0 2.0 3.0")
    end

    @testset "Parse entry" begin
        parsed = AAindex.parse(test_a1)

        @test parsed isa AAindex.Index
        @test parsed.metadata.id == AAindex.parse_id(test_a1)
        @test parsed.data == test_index_result
    end

    @testset "Parse index with missing value" begin
        parsed = AAindex.parse(test_index_with_na)

        @test parsed isa AAindex.Index
        # the R/K column, position 2, holds the NA
        @test isnan(parsed.data[2])
    end

    @testset "Parse index without correlations" begin
        parsed = AAindex.parse(test_index_no_c)

        @test parsed isa AAindex.Index
        @test isempty(parsed.correlation)
    end

    @testset "Parse record with no data section throws" begin
        @test_throws ArgumentError AAindex.parse(test_no_data_record)
    end

    @testset "Parse lower-triangular matrix" begin
        parsed = AAindex.parse(test_a2)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa AAindex.SHermitianCompact
        @test parsed.data[1, 1] == 3.0
        @test parsed.data[2, 1] == -3.0
        # stored as Hermitian, so the matrix is symmetric
        @test parsed.data[1, 2] == -3.0
    end

    @testset "Parse full matrix" begin
        parsed = AAindex.parse(test_full_matrix_record)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa AAindex.SMatrix
        @test parsed.data[1, 1] == -0.94
        @test parsed.data[1, 2] == 1.26
    end

    @testset "Parse matrix with a missing value" begin
        parsed = AAindex.parse(test_matrix_with_missing)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa AAindex.SMatrix
        @test parsed.data[1, 1] == 1.0
        # a lone "-" marks a missing value
        @test isnan(parsed.data[1, 2])
        @test parsed.data[2, 1] == 3.0
        @test parsed.data[2, 2] == 4.0
    end

    @testset "AMatrix.data is concretely typed" begin
        # the element type is pinned even though the container shape varies
        @test fieldtype(AAindex.AMatrix, :data) ==
            Union{AAindex.SHermitianCompact{N,Float64} where N,
                  AAindex.SMatrix{M,N,Float64} where {M,N}}
    end

    @testset "parse is not exported (does not shadow Base.parse)" begin
        @test !(:parse in names(AAindex))
        # still reachable as a qualified name
        @test AAindex.parse(test_a1) isa AAindex.Index
    end
end
