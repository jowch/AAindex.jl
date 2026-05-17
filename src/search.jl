"""
    is_key(candidate)

Checks whether `candidate` is exactly an AAindex accession number (four word
characters followed by six digits).
"""
function is_key(candidate::AbstractString)::Bool
    match(r"^\w{4}\d{6}$", candidate) !== nothing
end

"""
    aaindex_by_id(id::String)

Load an AAindex entry by its accession number.

Throws an `ArgumentError` if `id` is not present in the index. Errors raised
while reading or parsing a valid entry are *not* masked — they propagate
unchanged.
"""
aaindex_by_id(id::AbstractString) = aaindex_by_id(index(), id)

function aaindex_by_id(index::DataFrame, id::AbstractString)
    matches = subset(index, :id => ByRow(==(id)))

    if nrow(matches) != 1
        throw(ArgumentError("$id is not a valid AAindex identifier"))
    end

    load_entry(index, id)
end


"""
    search(term::AbstractString)

Search for AAindex entries by term based on id and description. Returns a list
of `(id, description)` pairs that match the term, sorted by id with any exact
id match first.
"""
search(term::AbstractString) = search(index(), term)

function search(index::DataFrame, term::AbstractString)
    match_indices = Set{Int}()

    for (i, id) in enumerate(index.id)
        if id == term
            push!(match_indices, i)
        end
    end

    needle = lowercase(term)
    for (i, description) in enumerate(index.description)
        if occursin(needle, lowercase(description))
            push!(match_indices, i)
        end
    end

    results = [
        (; id = index[i, :id], description = index[i, :description])
        for i in match_indices
    ]

    sort!(results, by = r -> (r.id != term, r.id))
end
