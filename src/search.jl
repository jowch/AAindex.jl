
const ENTRY_INDICES = [
    "list_of_indices",
    "list_of_matrices",
    "list_of_potentials"
]

const PROVIDED_AAINDEX_DIRECTORY = joinpath(@__DIR__, "aaindex")


function is_key(candidate::String)::Bool
    match(r"\w{4}\d{6}", candidate) !== nothing
end

function search_id(key::String, aaindex_directory=PROVIDED_AAINDEX_DIRECTORY)::AbstractAAIndex
    if is_key(key)
        try
            return only(search(key, aaindex_directory))
        catch
            throw(KeyError("Accession number $key was not found in database"))
        end
    end
end

function search(term::String, aaindex_directory=PROVIDED_AAINDEX_DIRECTORY)::Array{AbstractAAIndex}
    results = []

    for (i, index) in enumerate(ENTRY_INDICES)
        open(joinpath(aaindex_directory, index), "r") do io
            entries = readlines(io)[6:end]
            for entry in entries
                if occursin(term, entry)
                    key = parse_id(entry)
                    push!(results, only(parse(joinpath(aaindex_directory, "aaindex$i"), [key])))
                end
            end
        end
    end

    results
end

