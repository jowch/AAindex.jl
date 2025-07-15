@testset "Data" begin
    @testset "Build index" begin
        AAindex.build_index("testdata", "testdata/index.csv")

        @test isfile("testdata/index.csv")

        # load index
        index = AAindex.load_index("testdata/index.csv")

        @test index isa AAindex.DataFrames.DataFrame
        @test AAindex.DataFrames.nrow(index) == 2

        # check if entry matches the first entry in testdata/aaindex1
        @test index.aaindex[1] == "aaindex1"
        @test index.position[1] == 0
        @test index.id[1] == "ANDN920101"
        @test index.description[1] == "alpha-CH chemical shifts (Andersen et al., 1992)"

        # check if second entry matches the second entry in testdata/aaindex1
        @test index.aaindex[2] == "aaindex1"
        @test index.position[2] == 582
        @test index.id[2] == "ARGP820101"
        @test index.description[2] == "Hydrophobicity index (Argos et al., 1982)"

        @testset "Load entry" begin
            index = AAindex.load_index("testdata/index.csv")
            entry = AAindex.load_entry(index, "ANDN920101")

            @test entry.metadata.id == "ANDN920101"
            @test entry.metadata.description == "alpha-CH chemical shifts (Andersen et al., 1992)"
        end
    end
end