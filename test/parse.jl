
@testset "Parse" begin

    @testset "Parse Index" begin
        @test AAindex._parse_index(test_index) == test_index_result
        @test AAindex._parse_index(test_index) isa Vector{Union{Missing,Float64}}
    end

    @testset "Parse Index rejects wrong length" begin
        @test_throws ArgumentError AAindex._parse_index("I 1.0 2.0 3.0")
    end

    @testset "Parse entry" begin
        parsed = AAindex.parse(test_a1)

        @test parsed isa AAindex.Index
        @test parsed.metadata.id == "ANDN920101"
        @test parsed.data == test_index_result
    end

    @testset "Parse index with missing value" begin
        parsed = AAindex.parse(test_index_with_na)

        @test parsed isa AAindex.Index
        # the R/K column, position 2, holds the NA
        @test ismissing(parsed.data[2])
        @test parsed.data isa Vector{Union{Missing,Float64}}
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
        @test parsed.data isa Matrix{Union{Missing,Float64}}
        @test parsed.data[1, 1] == 3.0
        @test parsed.data[2, 1] == -3.0
        # both triangles are filled, so access is symmetric
        @test parsed.data[1, 2] == -3.0
    end

    @testset "Parse full matrix" begin
        parsed = AAindex.parse(test_full_matrix_record)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa Matrix{Union{Missing,Float64}}
        @test parsed.data[1, 1] == -0.94
        @test parsed.data[1, 2] == 1.26
    end

    @testset "Parse matrix with a missing value" begin
        parsed = AAindex.parse(test_matrix_with_missing)

        @test parsed isa AAindex.AMatrix
        @test parsed.data isa Matrix{Union{Missing,Float64}}
        @test parsed.data[1, 1] == 1.0
        # a lone "-" marks a missing value
        @test ismissing(parsed.data[1, 2])
        @test parsed.data[2, 1] == 3.0
        @test parsed.data[2, 2] == 4.0
    end

    @testset "Parse triangular matrix with a missing value" begin
        # rows/cols = AR: 3 values is the triangular count for a 2×2 matrix
        rowids, columnids, data = AAindex._parse_matrix(
            "rows = AR, cols = AR    1.0 2.0 -"
        )
        @test data isa Matrix{Union{Missing,Float64}}
        @test data[1, 1] == 1.0
        @test data[2, 1] == 2.0
        @test data[1, 2] == 2.0          # mirrored into the upper triangle
        @test ismissing(data[2, 2])      # the lone "-" in the lower triangle
    end

    @testset "AMatrix.data is concretely typed" begin
        @test fieldtype(AAindex.AMatrix, :data) == Matrix{Union{Missing,Float64}}
    end

    @testset "matrix parser rejects a malformed header" begin
        # no "rows = ..." clause
        @test_throws ArgumentError AAindex._parse_matrix("cols = AR    1.0")
    end

    @testset "matrix parser rejects an inconsistent value count" begin
        # rows=AR, cols=AR: full needs 4 values, triangular needs 3; 5 matches neither
        @test_throws ArgumentError AAindex._parse_matrix(
            "rows = AR, cols = AR    1 2 3 4 5"
        )
    end

    @testset "matrix parser rejects a non-square triangular matrix" begin
        # rows=ARND (4), cols=AR (2): 10 values matches the triangular count for
        # m=4 (4*5/2) but the matrix is not square
        @test_throws ArgumentError AAindex._parse_matrix(
            "rows = ARND, cols = AR    1 2 3 4 5 6 7 8 9 10"
        )
    end

    @testset "parse is not exported (does not shadow Base.parse)" begin
        @test !(:parse in names(AAindex))
        # still reachable as a qualified name
        @test AAindex.parse(test_a1) isa AAindex.Index
    end

    @testset "AMatrix show does not dump the raw struct" begin
        parsed = AAindex.parse(test_a2)
        @test sprint(show, parsed) == "AMatrix ALTS910101"

        rich = sprint(show, MIME("text/plain"), parsed)
        @test occursin("ALTS910101", rich)
        @test occursin("20×20", rich)
        @test !occursin("AMatrix(", rich)
    end
end
