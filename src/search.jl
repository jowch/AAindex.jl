"""
    is_key(candidate)

Checks if provided candidate key matches the format for AAindex accession
numbers.
"""
function is_key(candidate::String)::Bool
    match(r"\w{4}\d{6}", candidate) !== nothing
end

"""
    aaindex_by_id(id)

Load an AAindex by its id.
"""
function aaindex_by_id(id::String)
    if !is_key(id)
        throw(ArgumentError("$id is not a valid AAindex identifier"))
    end

    try
        jldopen(joinpath(datadep"AAindex", "aaindex.jld2"), "r") do file
            return file["entries"][id]
        end
    catch
        throw(ArgumentError("$id is not a valid AAindex identifier"))
    end
end

function search(term::String)
    database_path = joinpath(datadep"AAindex", "aaindex.jld2")

    ids, descriptions, types = jldopen(database_path, "r") do file
        file["ids"], file["descriptions"], file["types"]
    end

    match_indices = Set()

    for (i, id) in enumerate(ids)
        if id == term
            push!(match_indices, i)
        end
    end

    for (i, description) in enumerate(descriptions)
        if occursin(term |> lowercase, description |> lowercase)
            push!(match_indices, i)
        end
    end

    [(ids[i], descriptions[i], types[i]) for i in match_indices]
end
