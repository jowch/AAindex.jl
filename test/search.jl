
@testset "Search" begin

    @testset "is_key" begin
        @test AAindex.is_key("CORJ870107")
        @test !AAindex.is_key("701078JROC")
        @test !AAindex.is_key("COJ80107")
    end

    @testset "search" begin
        id, description, index_type = only(search("PHAT"))

        @test id == "NGPC000101"
        @test index_type === AAindex.AMatrix

        result = aaindex_by_id(id)
        
        @test result isa AAindex.AMatrix
        @test result.metadata.title == "PHAT: a transmembrane-specific substitution matrix"
    end

end
