"""
    is_key(candidate)

Checks if provided candidate key matches the format for AAindex accession
numbers.
"""
function is_key(candidate::String)::Bool
    match(r"\w{4}\d{6}", candidate) !== nothing
end

"""
    aaindex_by_id(id::String)

Load an AAindex by its id.
"""
aaindex_by_id(id::AbstractString) = aaindex_by_id(INDEX, id)

function aaindex_by_id(index::DataFrame, id::AbstractString)
    try
        return load_entry(index, id)
    catch
        throw(ArgumentError("$id is not a valid AAindex identifier"))
    end
end


"""
    search(term::AbstractString)

Search for AAindex entries by term based on id and description. Returns a list of
ids and descriptions that match the term.
"""
search(term::AbstractString) = search(INDEX, term)

function search(index::DataFrame, term::AbstractString)
    match_indices = Set()

    for (i, id) in enumerate(index.id)
        if id == term
            push!(match_indices, i)
        end
    end

    for (i, description) in enumerate(index.description)
        if occursin(term |> lowercase, description |> lowercase)
            push!(match_indices, i)
        end
    end

    [(; id = index[i, :id], description = index[i, :description]) for i in match_indices]
end
