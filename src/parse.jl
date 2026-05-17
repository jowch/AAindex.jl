"""
    parse(record)

Parses the given AAindex `record` (the raw text of one database entry) into an
[`Index`](@ref) or [`AMatrix`](@ref).

Throws an `ArgumentError` if the record contains neither an `I` (index) nor an
`M` (matrix) section.
"""
function parse(record::String)
    pairs = Dict{Char,Any}()
    lines = map(String, split(record, '\n', keepempty=false))

    while !isempty(lines) && first(lines) != "//"
        line = popfirst!(lines)
        tag = line[1]
        value = length(line) > 2 ? strip(line[3:end]) : ""

        while !isempty(lines) && isspace(first(first(lines)))
            value *= " " * popfirst!(lines)
        end

        push!(pairs, tag => value)
    end

    if 'R' in keys(pairs)
        pairs['R'] = map(String, split(pairs['R'], " "))
    end

    metadata = Metadata(
        get(pairs, 'H', ""),
        get(pairs, 'D', ""),
        get(pairs, 'R', String[]),
        get(pairs, 'J', ""),
        get(pairs, 'T', ""),
        get(pairs, 'A', ""),
        get(pairs, '*', "")
    )

    if 'M' in keys(pairs)
        return AMatrix(_parse_matrix(pairs['M'])..., metadata)
    elseif 'I' in keys(pairs)
        correlations = 'C' in keys(pairs) ?
            _parse_correlations(pairs['C']) : Dict{String,Float16}()
        return Index(_parse_index(pairs['I']), correlations, metadata)
    else
        throw(ArgumentError(
            "AAindex record \"$(metadata.id)\" has neither an I (index) " *
            "nor an M (matrix) section"
        ))
    end
end


function parse_id(record::String)::String
    only(match(r"(\w{4}\d{6})", record).captures)
end


function _parse_index(data::AbstractString)
    tokens = split(data, r"\s+", keepempty=false)

    # An "NA" token is a missing value; a numeric token is its parsed Float64;
    # anything else (e.g. the "A/L" header labels) is skipped.
    values = Union{Missing,Float64}[]
    for token in tokens
        if token == "NA"
            push!(values, missing)
        else
            value = tryparse(Float64, token)
            isnothing(value) || push!(values, value)
        end
    end

    length(values) == 20 || throw(ArgumentError(
        "expected 20 amino acid index values, parsed $(length(values))"
    ))

    values
end


function _parse_matrix(data::AbstractString)
    header_idx = findfirst(r"^[A-Za-z\s\-=,]+\s", data)
    header, data = data[header_idx], data[header_idx.stop+1:end]
    rowids, columnids = [header[idx] for idx in findall(r"[A-Z\-]+", header)]

    # A token is parsed value-by-value rather than with a regex substitution:
    # a lone "-" (or "NA") marks a missing value, and splitting first avoids
    # the boundary/adjacency hazards of rewriting whitespace-delimited markers.
    tokens = split(data, r"\s+", keepempty=false)

    values = Float64[]
    for token in tokens
        if token == "-" || token == "NA"
            push!(values, NaN)
        else
            value = tryparse(Float64, token)
            isnothing(value) || push!(values, value)
        end
    end

    m, n = length(rowids), length(columnids)
    data = zeros(m, n)

    # check if matrix is lower triangular
    if length(values) < m * n
        indices = [(x, y) for x in 1:m for y in 1:x]

        for (k, (i, j)) in enumerate(indices)
            data[i, j] = values[k]
        end

        data = SHermitianCompact{m}(data)
    else
        indices = [(x, y) for x in 1:m for y in 1:n]

        for (k, (i, j)) in enumerate(indices)
            data[i, j] = values[k]
        end

        data = SMatrix{m,n}(data)
    end


    return rowids, columnids, data
end


function _parse_correlations(data::AbstractString)
    tokens = split(data, r"\s+", keepempty=false)
    pairs = Pair{String,Float16}[]

    for i in 1:2:length(tokens)-1
        value = tryparse(Float16, tokens[i+1])
        isnothing(value) || push!(pairs, String(tokens[i]) => value)
    end

    Dict(pairs)
end
