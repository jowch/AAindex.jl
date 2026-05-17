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
    # The M-tag value documents its axes as "rows = ... cols = ...". Anchor on
    # that format and capture both axis-label strings; continuation lines have
    # already been folded into one whitespace-joined string by `parse`.
    header = match(r"rows\s*=\s*([A-Z\-]+).*?cols\s*=\s*([A-Z\-]+)"s, data)
    isnothing(header) && throw(ArgumentError(
        "matrix record header does not match the expected " *
        "\"rows = ... cols = ...\" format"
    ))
    rowids, columnids = String.(header.captures)

    # Everything after the matched header is the value block. Matrix records are
    # ASCII, so a code-unit offset is also a valid character index.
    value_text = data[(header.offset + ncodeunits(header.match)):end]

    # A lone "-" (or "NA") marks a missing value.
    values = Union{Missing,Float64}[]
    for token in split(value_text, r"\s+", keepempty=false)
        if token == "-" || token == "NA"
            push!(values, missing)
        else
            value = tryparse(Float64, token)
            isnothing(value) || push!(values, value)
        end
    end

    m, n = length(rowids), length(columnids)
    triangular = m * (m + 1) ÷ 2

    if m == n && length(values) == triangular
        matrix = Matrix{Union{Missing,Float64}}(undef, m, m)
        k = 1
        for i in 1:m, j in 1:i
            matrix[i, j] = values[k]
            matrix[j, i] = values[k]   # fill both triangles
            k += 1
        end
    elseif length(values) == m * n
        matrix = Matrix{Union{Missing,Float64}}(undef, m, n)
        k = 1
        for i in 1:m, j in 1:n
            matrix[i, j] = values[k]
            k += 1
        end
    else
        throw(ArgumentError(
            "matrix has $(length(values)) values, which matches neither a full " *
            "$m×$n matrix ($(m * n)) nor a lower-triangular one ($triangular)"
        ))
    end

    return rowids, columnids, matrix
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
