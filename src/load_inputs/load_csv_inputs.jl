###### ###### ###### ###### ###### ######
# CSV data handling
###### ###### ###### ###### ###### ######

@doc raw"""
    load_time_series_data(file_path::AbstractString, header::AbstractVector{Symbol})::Dict{Symbol,Any}

    Load time series data from one or more headers in a CSV file and return as a DataFrame.

"""
function load_csv(
    file_path::AbstractString;
    select::S = Symbol[],
    lazy_load::Bool = true,
) where {S<:Union{Symbol,Vector{Symbol}}}
    if isa(select, Symbol)
        select = [select]
    end
    csv_data = read_csv(file_path, select)
    return csv_data
    #TODO check how to use lazy_load with CSV files
end

###### ###### ###### ###### ###### ######
# CSV --> Dict
###### ###### ###### ###### ###### ######

# The general idea is that each row of the CSV
# file is an entry, and each column is a property.
# Each CSV file will be specific to one kind of 
# asset, node, etc.

# Nested properties in a dict, will be denoted by
# the <top_property>--<sub_property> notation.>

function load_csv_inputs(file_path::AbstractString; rel_path::AbstractString=dirname(file_path), lazy_load::Bool = true)::Dict{Symbol,Any}
    @debug("Loading CSV data from $file_path")
    json_data = csv_to_json(file_path)
    if !lazy_load
        json_data = eager_load_json_inputs(json_data, rel_path)
        json_data = clean_up_keys(json_data)
    end
    return json_data
end

function validate_csv_data(loaded_csv)::Nothing
    headers = loaded_csv.names
    # headers must be at least 2 columns
    if length(headers) < 2
        error("CSV file must have at least 2 columns: type and id")
    end
    # The first column must be "type"
    if headers[1] != :Type
        error("The first column of the CSV file must be 'Type'")
    end
    # The second column must be "id"
    if headers[2] != :id
        error("The second column of the CSV file must be 'id'")
    end
    return nothing
end

function insert_data(dict::Dict{Symbol, Any}, keys::Vector{Symbol}, data::Any)
    # Create nested dictionaries for each key in the vector
    next_key = keys[1]
    
    if length(keys) == 1
        dict[next_key] = data
        return dict
    end
    
    if !haskey(dict, next_key)
        dict[next_key] = Dict{Symbol, Any}()
    end
    return insert_data(dict[next_key], keys[2:end], data)
end

function csv_to_json(file_path::AbstractString, nesting_str::AbstractString="--")::Vector{Dict{Symbol,Any}}
    data = duckdb_read(file_path)
    validate_csv_data(data)

    column_map = Dict{Symbol, Any}()
    for header in data.names
        props = Symbol.(split(string(header), nesting_str))
        column_map[header] = [:instance_data, props...]
    end
    # Take "Type" out of instance_data
    # FIXME: maybe we should move the type into the instance data
    column_map[:Type] = [:type]
    
    all_json_data = Vector{Dict{Symbol, Any}}()
    for row in data
        json_data = Dict{Symbol, Any}()
        for (col_name, dict_address) in column_map
            insert_data(json_data, dict_address, row[col_name])
        end
        push!(all_json_data, json_data)
    end

    return all_json_data
end

function extract_data(json_data::AbstractDict{Symbol, Any}, row_data::AbstractDict{Symbol, Any}, prefix::AbstractString="", nesting_str::AbstractString="--")
    for (key, value) in json_data
        if value isa Dict
            new_prefix = string(key) * nesting_str
            extract_data(value, row_data, new_prefix, nesting_str)
        elseif value isa Vector
            if length(value) == 1
                row_data[Symbol(prefix * string(key))] = value[1]
            end
            # move data to another CSV and make a link
            continue
        else
            row_data[Symbol(prefix * string(key))] = value
        end
    end
end

function json_to_csv(json_data::AbstractDict{Symbol, Any}, nesting_str::AbstractString="--")
    # We want to convert the input Dict into a row of data
    # in a manner which is not affected by the order of the
    # keys in the Dict.
    
    if !haskey(json_data, :type)
        @debug("Missing :type key in $(json_data)")
        error("Missing :type key in JSON data")
    end
        
    if haskey(json_data, :global_data)
        global_row_data = OrderedDict{Symbol, Any}()
        extract_data(json_data[:global_data], global_row_data, "", nesting_str)
    end

    if !haskey(json_data, :instance_data)
        #TODO: We need to decide if we want to keep this
        # behaviour or return an error
        return [global_row_data]
    end

    # Assuming haskey(json_data, :instance_data) = true
    # As currently formatted, :Type and :id key must be
    # the first and second columns in row_data
    all_row_data = Vector{OrderedDict{Symbol, Any}}()
    for instance_data in json_data[:instance_data]
        row_data = OrderedDict{Symbol, Any}(
            :Type => json_data[:type],
            :id => instance_data[:id]
        )
        delete!(instance_data, :id)
        merge!(row_data, deepcopy(global_row_data))
        extract_data(instance_data, row_data, "", nesting_str)
        push!(all_row_data, row_data)
    end

    return DataFrame(all_row_data)
end