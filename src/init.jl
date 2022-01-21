function __init__()
    register(DataDep(
        "AAindex",
        """
        Dataset: AAindex
        Website: https://www.genome.jp/aaindex/

        Please cite the following references when making use of the database:

        Nakai, K., Kidera, A., and Kanehisa, M.;  Cluster analysis of
           amino acid indices for prediction of protein structure and
           function.  Protein Eng. 2, 93-100 (1988)
    
        Tomii, K. and Kanehisa, M.;  Analysis of amino acid indices and
           mutation matrices for sequence comparison and structure
           prediction of proteins.  Protein Eng. 9, 27-36 (1996).
    
        Kawashima, S., Ogata, H., and Kanehisa, M.;  AAindex: amino acid
           index database.  Nucleic Acids Res. 27, 368-369 (1999).
    
        Kawashima, S. and Kanehisa, M.;  AAindex: amino acid index
           database.  Nucleic Acids Res. 28, 374 (2000).
    
        Last update: 2017/02/01
        """,
        [
            "https://www.genome.jp/ftp/db/community/aaindex/aaindex1",
            "https://www.genome.jp/ftp/db/community/aaindex/aaindex2",
            "https://www.genome.jp/ftp/db/community/aaindex/aaindex3",
        ],
        [
            "560f102dbee8ca9837186c4b2b93e253ea6efc58c88617234cef4e54bd61f676"
            "d3eb30c075452aa737b111a3d127358d0b669d0e847fca967b253a05c7796aa9"
            "8c9b9b0e7b7937b4674585b25f3f9370499f219b2583b1204fc9a0a5f06b1671"
        ]
    ))

    if !isfile(joinpath(datadep"AAindex", "aaindex.jld2"))
        preprocess_aaindex()
    end
end
