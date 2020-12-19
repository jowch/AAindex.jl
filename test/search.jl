
@testset "Search" begin

    @testset "is_key" begin
        @test AAindex.is_key("CORJ870107")
        @test !AAindex.is_key("701078JROC")
        @test !AAindex.is_key("COJ80107")
    end

    @testset "search_id" begin
        result = search("NGPC000101")
        
        @test result isa AAindex.AMatrix
        @test result.metadata.title == "PHAT: a transmembrane-specific substitution matrix"
    end

    @testset "search" begin
        results = search("PHAT")

        @test length(results) == 1
        @test only(results) isa AAindex.AMatrix
        @test only(results).metadata.key == "NGPC000101"
    end

end
