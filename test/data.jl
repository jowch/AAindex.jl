@testset "Data" begin
    @testset "Build index" begin
        AAindex.build_index("testdata", "testdata/index.csv")

        @test isfile("testdata/index.csv")

        index = AAindex.load_index("testdata/index.csv")

        @test index isa Dict{String,AAindex.Entry}
        @test length(index) == 2

        # first entry in testdata/aaindex1
        first = index["ANDN920101"]
        @test first.aaindex == "aaindex1"
        @test first.position == 0
        @test first.description == "alpha-CH chemical shifts (Andersen et al., 1992)"
        # authors contains commas — verifies CSV quoted-field round-tripping
        @test first.authors == "Andersen, N.H., Cao, B. and Chen, C."

        # second entry in testdata/aaindex1
        second = index["ARGP820101"]
        @test second.aaindex == "aaindex1"
        @test second.position == 582
        @test second.description == "Hydrophobicity index (Argos et al., 1982)"

        @testset "Load entry" begin
            index = AAindex.load_index("testdata/index.csv")
            entry = AAindex.load_entry(index, "ANDN920101")

            @test entry.metadata.id == "ANDN920101"
            @test entry.metadata.description ==
                "alpha-CH chemical shifts (Andersen et al., 1992)"
        end
    end
end
