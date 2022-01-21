
function preprocess_aaindex()
    data_dir = datadep"AAindex"
    aaindex_files = readdir(data_dir; join = true)

    # this might be some no-no stuff
    jldopen(joinpath(data_dir, "aaindex.jld2"), "w") do file
        ids, descriptions, types = [], [], []

        entries = JLD2.Group(file, "entries")

        foreach(aaindex_files) do aaindex
            foreachentry(aaindex) do entry
                record = parse(entry)
                (; id, description) = record.metadata

                push!(ids, id)  
                push!(descriptions, description)
                push!(types, typeof(record))

                entries[id] = record
            end
        end

        file["ids"] = ids
        file["descriptions"] = descriptions
        file["types"] = types
    end
end

