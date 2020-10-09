
const ENTRY_SYMBOLS = "HDRATJCIM*"

"""
    parse(path, [targets])

Reads and parses the AAindex file located at `path`. Optionally, specific
entry IDs (denoted by H) can be provided in `targets`.
"""
function parse(path::AbstractString, targets::Array{String} = String[])::Array{AbstractAAIndex}
    if !ispath(path)
        error("PATH does not exist (given: $path)")
    end

    indices::Array{AbstractAAIndex} = []

    open(path, "r") do io
        while !eof(io)
            # read and parse indicies until end of file
            span = readuntil(io, "//\n")

            if isempty(targets) || _parse_id(span) in targets
                if !isempty(strip(span))
                    push!(indices, _parse(span))
                end
            end
        end
    end

    return indices
end


function _parse(record::String)::AbstractAAIndex
    pairs = Dict()
    lines = map(String, split(record, '\n', keepempty=false))

    while !isempty(lines) && first(lines) != "//"
        line = popfirst!(lines)
        tag, value = line[1], line[3:end]

        while !isempty(lines) && isspace(first(first(lines)))
            value *= " " * popfirst!(lines)
        end

        push!(pairs, tag => value)
    end
    
    if 'R' in keys(pairs)
        pairs['R'] = map(String, split(pairs['R'], " "))
    end

    metadata = Metadata(
        pairs['H'],
        pairs['D'],
        'R' in keys(pairs) ? pairs['R'] : String[],
        pairs['J'],
        pairs['T'],
        pairs['A'],
        '*' in keys(pairs) ? pairs['*'] : ""
    )

    if 'M' in keys(pairs)
        return AMatrix(_parse_matrix(pairs['M'])..., metadata)
    elseif 'I' in keys(pairs)
        return Index(
            _parse_index(pairs['I']),
            _parse_correlations(pairs['C']),
            metadata
        )
    end
end


function _parse_id(record::String)::String
    only(match(r"^H ([\w\d]+)\n", record).captures)
end


function _parse_index(data::AbstractString)
    data = replace(data, "NA" => "NaN")
    data = split(data, r"\s+", keepempty=false)

    values = filter(x -> !isnothing(x), map(x -> tryparse(Float64, x), data))
        
    SVector{length(values)}(values)
end


function _parse_matrix(data::AbstractString)
    header_idx = findfirst(r"^[A-Za-z\s\-=,]+\s", data)
    header, data = data[header_idx], data[header_idx.stop+1:end]
    rowids, columnids = [header[idx] for idx in findall(r"[A-Z\-]+", header)]

    data = replace(data, "NA" => "NaN")
    data = replace(data, r"\s-\s" => "NaN")
    data = split(data, r"\s+", keepempty=false)

    values = filter(x -> !isnothing(x), map(x -> tryparse(Float64, x), data))

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
    tokens = split(data, r"\s", keepempty=false)
    values = []

    for i = 1:2:length(tokens)
        push!(values, String(tokens[i]) => tryparse(Float16, tokens[i+1]))
    end

    Dict(values)
end
