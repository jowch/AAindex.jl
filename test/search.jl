
@testset "Search" begin

    @testset "is_key" begin
        @test AAindex.is_key("CORJ870107")
        @test !AAindex.is_key("701078JROC")
        @test !AAindex.is_key("COJ80107")

        # the match must be anchored: surrounding characters are not a key
        @test !AAindex.is_key("CORJ870107XX")
        @test !AAindex.is_key("XXCORJ870107")

        # any AbstractString is accepted, not just String
        @test AAindex.is_key(SubString("xCORJ870107", 2))
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

    @testset "search returns results in a deterministic, sorted order" begin
        results = search("hydrophobicity")
        ids = [r.id for r in results]

        @test issorted(ids)
        @test ids == [r.id for r in search("hydrophobicity")]
    end

    @testset "aaindex_by_id rejects unknown ids" begin
        @test_throws ArgumentError aaindex_by_id("NOTANID000")
        # the error message should name the offending id
        @test_throws "NOTANID000" aaindex_by_id("NOTANID000")
    end

    @testset "ids lists every accession number" begin
        all_ids = ids()
        @test all_ids isa Vector{String}
        @test issorted(all_ids)
        @test "KYTJ820101" in all_ids
        # the shipped v9.2 database has well over 500 entries
        @test length(all_ids) > 500
    end

    @testset "no-argument search returns every entry" begin
        @test length(search()) == length(ids())
        @test issorted([r.id for r in search()])
    end

    @testset "search matches title and authors" begin
        # an injected Dict makes the field-matching deterministic
        testindex = Dict(
            "AAAA000001" => AAindex.Entry(
                "aaindex1", 0,
                "a description", "a memorable title", "Ada Lovelace"
            )
        )
        @test only(AAindex.search(testindex, "memorable")).id == "AAAA000001"
        @test only(AAindex.search(testindex, "Lovelace")).id == "AAAA000001"
        @test isempty(AAindex.search(testindex, "no-such-term"))
    end

end
