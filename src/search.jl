"""
    is_key(candidate)

Checks whether `candidate` is exactly an AAindex accession number (four word
characters followed by six digits).
"""
function is_key(candidate::AbstractString)::Bool
    match(r"^\w{4}\d{6}$", candidate) !== nothing
end

"""
    aaindex_by_id(id::AbstractString)

Load an AAindex entry by its accession number.

Throws an `ArgumentError` if `id` is not present in the index. Errors raised
while reading or parsing a valid entry are *not* masked — they propagate
unchanged.
"""
aaindex_by_id(id::AbstractString) = aaindex_by_id(index(), id)

function aaindex_by_id(index::Dict{String,Entry}, id::AbstractString)
    haskey(index, id) || throw(ArgumentError(
        "$id is not a valid AAindex identifier"
    ))
    load_entry(index, id)
end

"""
    search(term::AbstractString)

Search for AAindex entries whose id, description, title, or authors contain
`term` (case-insensitively). Returns a list of `(id, description)` pairs, sorted
by id with any exact id match first.
"""
search(term::AbstractString) = search(index(), term)

function search(index::Dict{String,Entry}, term::AbstractString)
    needle = lowercase(term)
    results = @NamedTuple{id::String, description::String}[]

    for (id, entry) in index
        if occursin(needle, lowercase(id)) ||
           occursin(needle, lowercase(entry.description)) ||
           occursin(needle, lowercase(entry.title)) ||
           occursin(needle, lowercase(entry.authors))
            push!(results, (; id, description = entry.description))
        end
    end

    # an exact id match sorts first; compare case-insensitively to stay
    # consistent with the case-insensitive matching above
    sort!(results, by = r -> (lowercase(r.id) != needle, r.id))
end

"""
    ids()

Returns a sorted `Vector{String}` of every accession number in the index.
"""
ids() = sort!(collect(keys(index())))

"""
    search()

Returns every entry as `(id, description)` pairs, sorted by id — the same result
shape as `search(term)`.
"""
search() = search(index(), "")
