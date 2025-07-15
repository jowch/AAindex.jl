
@testset "Search" begin

    @testset "is_key" begin
        @test AAindex.is_key("CORJ870107")
        @test !AAindex.is_key("701078JROC")
        @test !AAindex.is_key("COJ80107")
    end

    @testset "search" begin
        (; id, description) = only(search("PHAT"))

        expected_id = "NGPC000101"
        expected_description = "Substitution matrix (PHAT) built from hydrophobic and transmembrane regions   of the Blocks database (Ng et al., 2000)"

        @test id == expected_id
        @test description == expected_description

        result = aaindex_by_id(id)
        
        @test result isa AAindex.AMatrix
        @test result.metadata.description == expected_description
    end

end
