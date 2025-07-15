@testset "Index" begin
    # Test transform
    index = aaindex_by_id("KYTJ820101")
    @test AAindex.transform(index, "AAA") == [1.8, 1.8, 1.8]
end