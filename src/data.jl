

"""
    build_index(index_directory_path)

Builds an index of AAindex entries from the given directory. The index is stored
as a CSV file with columns for index file name and entry seek position, as well
as entry metadata such as accession number (H), description (D), reference (R),
authors (A), and title (T).
"""
function build_index(
    directory_path = datadep"AAindex",
    index_file = joinpath(datadep"AAindex", "index.csv")
)
    database_files = filter(startswith("aaindex"), readdir(directory_path))
    entry_records = []


    for database_file in database_files
        open(joinpath(directory_path, database_file), "r") do io
            entry_position = position(io)

            while !eof(io)
                entry = readuntil(io, "//\n")
                record = parse(entry)

                push!(entry_records, (;
                    aaindex = database_file,
                    position = entry_position,
                    id = record.metadata.id,
                    description = record.metadata.description,
                    authors = record.metadata.authors,
                    title = record.metadata.title
                ))

                # move to next entry
                entry_position = position(io)
            end
        end
    end

    CSV.write(index_file, DataFrame(entry_records))
end

"""
    load_index(index_file = joinpath(datadep"AAindex", "index.csv"))

Loads the index of AAindex entries from the given file.
"""
function load_index(index_file = joinpath(datadep"AAindex", "index.csv"))
    CSV.read(index_file, DataFrame)
end

"""
    load_entry(id::AbstractString)

Loads the entry with the given id from the index.
"""
load_entry(id::AbstractString) = load_entry(INDEX, id)

function load_entry(index::DataFrame, id::AbstractString)
    record = only(subset(index, :id => ByRow(==(id))))

    open(joinpath(datadep"AAindex", record.aaindex), "r") do io
        seek(io, record.position)
        parse(readuntil(io, "//\n"))
    end
end