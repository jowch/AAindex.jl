
@testset "Parse" begin

    @testset "Parse ID" begin
        @test AAindex._parse_id(test_a1) == "ANDN920101"
        @test AAindex._parse_id(test_a2) == "ALTS910101"
    end

    @testset "Parse Index" begin
        @test AAindex._parse_index(test_index) == test_index_result
    end

end
