###### ###### ###### ###### ###### ######
# CSV file handling
###### ###### ###### ###### ###### ######

function read_csv(file_path::AbstractString; select::Vector{Symbol} = Symbol[])::DataFrame
    data = DataFrame(duckdb_read(file_path))
    if length(select) > 0
        @debug("Loading columns $select from CSV data from $file_path")
        select!(data, select)
        isempty(data) && error("Columns $select not found in $file_path")
    else
        @debug("Loading CSV data from $file_path")
    end
    @debug("Loading CSV data from $file_path")
    return data
end

function csv_header(path::AbstractString)
    f = open(path, "r")
    header = readline(f)
    close(f)
    header
end

macro CSV_EXT()
    return (".csv", ".csv.gz")
end

iscsv(path::AbstractString) = any(endswith.(path, @CSV_EXT))