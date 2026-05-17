# Concrete row type for the on-disk index, so `CSV.write` gets a stable schema.
const IndexRow = @NamedTuple{
    id::String, aaindex::String, position::Int,
    description::String, title::String, authors::String
}

"""
    build_index(directory_path, index_file)

Builds an index of AAindex entries from the given directory. The index is stored
as a CSV file with columns for accession number, index file name, entry seek
position, description, title, and authors.
"""
function build_index(
    directory_path = datadep"AAindex",
    index_file = joinpath(datadep"AAindex", "index.csv")
)
    database_files = filter(startswith("aaindex"), readdir(directory_path))
    entry_records = IndexRow[]

    for database_file in database_files
        open(joinpath(directory_path, database_file), "r") do io
            entry_position = position(io)

            while !eof(io)
                entry = readuntil(io, "//\n")
                record = try
                    parse(entry)
                catch err
                    error("failed to parse the entry at position " *
                          "$entry_position in $database_file: " *
                          sprint(showerror, err))
                end

                push!(entry_records, (;
                    id = record.metadata.id,
                    aaindex = database_file,
                    position = entry_position,
                    description = record.metadata.description,
                    title = record.metadata.title,
                    authors = record.metadata.authors
                ))

                # move to next entry
                entry_position = position(io)
            end
        end
    end

    CSV.write(index_file, entry_records)
end

"""
    load_index(index_file = joinpath(datadep"AAindex", "index.csv"))

Loads the index of AAindex entries from the given CSV file into a
`Dict{String,Entry}` keyed by accession number.
"""
function load_index(index_file = joinpath(datadep"AAindex", "index.csv"))
    # An empty free-text field round-trips through CSV as `missing`; coerce it
    # back to "" (what `parse` produces for a blank tag). `String` also strips
    # CSV's InlineStrings / SubString types so they never leak into the API.
    text(x) = ismissing(x) ? "" : String(x)

    index = Dict{String,Entry}()
    for row in CSV.File(index_file)
        index[String(row.id)] = Entry(
            String(row.aaindex),
            row.position,
            text(row.description),
            text(row.title),
            text(row.authors)
        )
    end
    index
end

"""
    load_entry(id::AbstractString)

Loads the entry with the given id from the index.
"""
load_entry(id::AbstractString) = load_entry(index(), id)

function load_entry(index::Dict{String,Entry}, id::AbstractString)
    entry = index[id]

    open(joinpath(datadep"AAindex", entry.aaindex), "r") do io
        seek(io, entry.position)
        parse(readuntil(io, "//\n"))
    end
end
