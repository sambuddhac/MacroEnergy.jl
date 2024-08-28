###### ###### ###### ###### ###### ######
# Functions for the user to load a system based on JSON files
###### ###### ###### ###### ###### ######

function load_system(path::AbstractString=pwd())::System

    # The path should either be a a file path to a JSON file, preferably "system_data.json"
    # or a directory containing "system_data.json"
    # We'll check the absolute path first, then the path relative to the working directory

    # If path ends with ".json", we assume it's a file
    if endswith(path, ".json")
        path = rel_or_abs_path(path)
    else
        # Assume it's a dir, ignoring other possible suffixes
        path = rel_or_abs_path(joinpath(path, "system_data.json"))
    end

    if isfile(path)
        system = empty_system(dirname(path))
        system_data = load_system_data(path)
        generate_system!(system, system_data)
        return system
    else
        throw(ArgumentError("
            No system data found in $path
            Either provide a path to a .JSON file or a directory containing a system_data.json file
        "))
    end
end

function load_system(system_data::AbstractDict{Symbol,Any}, dir_path::AbstractString=pwd())::System
    # The path should point to the location of the system data files
    # If path is not provided, we assume the data is in the current working directory
    if isfile(dir_path)
        dir_path = dirname(dir_path)
    end
    system = empty_system(dir_path)
    generate_system!(system, system_data)
    return system
end

###### ###### ###### ###### ###### ######
# Internal functions to handle loading the system
###### ###### ###### ###### ###### ######

function generate_system!(system::System, file_path::AbstractString; lazy_load::Bool=true)::nothing
    # Load the system data file
    system_data = load_system_data(file_path, system.data_dirpath; lazy_load=lazy_load)
    generate_system!(system, system_data)
    return nothing
end

function generate_system!(system::System, system_data::AbstractDict{Symbol,Any})::Nothing
    # Configure the settings
    system.settings = configure_settings(system_data[:settings], system.data_dirpath)

    # Load the commodities
    system.commodities = load_commodities(system_data[:commodities], system.data_dirpath)

    # Load the time data
    system.time_data = load_time_data(system_data[:time_data], system.commodities, system.data_dirpath)

    # Load the nodes
    load!(system, system_data[:nodes])

    # Load the assets
    load!(system, system_data[:assets])

    return nothing
end

###### ###### ###### ###### ###### ######
# Internal functions to handle loading the system_data.json file
###### ###### ###### ###### ###### ######

function load_system_data(file_path::AbstractString; default_file_path::String=joinpath(@__DIR__, "default_system_data.json"), lazy_load::Bool=true)::Dict{Symbol,Any}
    load_system_data(file_path, dirname(file_path), default_file_path=default_file_path, lazy_load=lazy_load)
    return load_json(file_path; lazy_load=lazy_load)
end

function load_system_data(file_path::AbstractString, rel_path::AbstractString; default_file_path::String=joinpath(@__DIR__, "default_system_data.json"), lazy_load::Bool=true)::Dict{Symbol,Any}
    file_path = abspath(rel_or_abs_path(file_path, rel_path))

    prep_system_data(file_path, default_file_path)

    # Load the system data from the JSON file(s)
    return load_json(file_path; lazy_load=lazy_load)
end

function load_system_data!(system::System, file_path::AbstractString, default_file_path::String=joinpath(@__DIR__, "default_system_data.json"))::Nothing
    # Load the provided system data
    # We're assuming the file_path is a JSON file, not a directory
    file_path = abspath(rel_or_abs_path(file_path, system.data_dirpath))

    # Make sure the default arguments are included
    prep_system_data(file_path, default_file_path)

    # Load the system data from the JSON file(s)
    system_data = load_json(file_path)

    # Configure the model
    load_system_data!(system, system_data)
    return nothing
end


function load_default_system_data(default_file_path::String=joinpath(@__DIR__, "default_system_data.json"))::Dict{Symbol,Any}
    if isfile(default_file_path)
        default_system_data = read_json(default_file_path)
    else
        @warn("No default system data file found at $default_file_path")
    end
    return default_system_data
end

function add_default_system_data!(system_data::AbstractDict{Symbol,Any}, default_file_path::String=joinpath(@__DIR__, "default_system_data.json"))::Nothing
    # Load a hard-coded set of default locations for the system data
    # This could be moved to the settings defaults later
    default_system_data = load_default_system_data(default_file_path)
    merge!(default_system_data, system_data)
    return nothing
end

function prep_system_data(file_path::AbstractString, default_file_path::String=joinpath(@__DIR__, "default_system_data.json"))::Nothing
    if isfile(file_path)
        system_data = read_json(file_path)
    else
        error("No system data file found at $file_path")
    end

    # Load a hard-coded set of default locations for the system data
    # This could be moved to the settings defaults later
    add_default_system_data!(system_data, default_file_path)

    # FIXME currenltly overwriting and then re-reading the system_data
    # This is a little janky, but lets us quickly use the JSON parsing functions
    open(file_path, "w") do io
        JSON3.pretty(io, system_data)
    end
    return nothing
end

###### ###### ###### ###### ###### ######
# Functions to handle loading MacroEnergy object data
###### ###### ###### ###### ###### ######

# Load data from a JSON file into a System
function load!(system::System, file_path::AbstractString)::Nothing
    file_path = rel_or_abs_path(file_path, system.data_dirpath)
    if isfile(file_path)
        load!(system, load_json(file_path))
    elseif isdir(file_path)
        for file in filter(x -> endswith(x, ".json"), readdir(file_path))
            load!(system, joinpath(file_path, file))
        end
    end
    return nothing
end

# Load a single instance of an asset, location, etc. into a System
function load!(system::System, data::AbstractDict{Symbol,Any})::Nothing
    if data_is_system_data(data)
        # println("Loading system data")
        load_system_data!(system, data)

    # Check that data has only :type and :instance_data fields
    elseif data_is_single_instance(data)
        data_type = check_and_convert_type(data)
        load_time_series_data!(system, data) # substritute ts file paths with actual vectors of data
        add!(system, make(data_type, data[:instance_data], system))

    elseif data_has_global_data(data)
        # println("Expanding global data")
        load!(system, expand_instances(data))

    elseif data_is_filepath(data)
        # println("Loading data from file")
        load!(system, data[:path])

    else
        for (key, value) in data
            # println("Loading $key")
            load!(system, value)
        end

    end

    return nothing
end

# Load a vector of instances of assets, locations, etc. into a System
function load!(system::System, data::AbstractVector{<:AbstractDict{Symbol,Any}})::Nothing
    for instance in data
        load!(system, instance)
    end
    return nothing
end

recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
recursive_merge(x::AbstractVector...) = cat(x...; dims=1)
recursive_merge(x...) = x[end]

function expand_instances(data::AbstractDict{Symbol,Any})
    instances = Vector{Dict{Symbol,Any}}()
    type = data[:type]
    global_data = data[:global_data]
    for (instance_idx, instance_data) in enumerate(data[:instance_data])
        instance_data = recursive_merge(global_data, instance_data)
        # haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_asset_name(instance_idx, a_name)
        # instance_data[:id], _ = make_asset_id(instance_id, asset_data)
        # asset_data[instance_data[:id]] = make_asset(a_type, instance_data, time_data, nodes)
        push!(instances, Dict{Symbol,Any}(:type => type, :instance_data => instance_data))
    end
    return instances
end

###### ###### ###### ###### ###### ######
# Checks on the kind of data
###### ###### ###### ###### ###### ######

function check_and_convert_type(data::AbstractDict{Symbol,Any}, m::Module=Macro)::DataType
    if !haskey(data, :type)
        throw(ArgumentError("Instance data does not have a :type field"))
    end
    !isdefined(m, Symbol(data[:type])) && throw(ArgumentError("Type $(data[:type]) not found in module $m"))
    return getfield(m, Symbol(data[:type]))
end

function data_is_single_instance(data::AbstractDict{Symbol,Any})::Bool
    # Check that data has only :type and :instance_data fields
    # We could also check the types of the fields
    entries = collect(keys(data))
    if length(entries) == 2 && issetequal(entries, [:type, :instance_data])
        return true
    else
        return false
    end
end

function data_has_global_data(data::AbstractDict{Symbol,Any})::Bool
    # Check that data has only :type, :instance_data, :global_data fields
    entries = collect(keys(data))
    if length(entries) == 3 && issetequal(entries, [:type, :instance_data, :global_data])
        return true
    else
        return false
    end
end

function data_is_filepath(data::AbstractDict{Symbol,Any})::Bool
    entries = collect(keys(data))
    if length(entries) == 1 && issetequal(entries, [:path])
        return true
    else
        return false
    end
end

function data_is_system_data(data::AbstractDict{Symbol,Any})::Bool
    # Check if it contains any special fields
    entries = collect(keys(data))
    special_keys = [
        :settings
    ]
    for key in special_keys
        if key in entries
            return true
        end
    end
    return false
end

###### ###### ###### ###### ###### ######
# Functions to check whether a path is relative or absolute, relative to a given directory
# Some of this might be unnecessary, as Julia does some of it automatically 
# to the current working directory

# However, I haven't tested it on all OS, and this lets us 
# set out own "root" directory

# We might need to swap the default behaviour to use the
# path relative to rel_dir
###### ###### ###### ###### ###### ######

function rel_or_abs_path(path::T, rel_dir::T=pwd())::T where {T<:AbstractString}
    if ispath(path)
        return path
    elseif ispath(joinpath(rel_dir, path))
        return joinpath(rel_dir, path)
    else
        return path
        # throw(ArgumentError("File $path not found"))
    end
end

###### ###### ###### ###### ###### ######
# JSON data handling
###### ###### ###### ###### ###### ######

function load_json(file_path::AbstractString; lazy_load::Bool=true)::Dict{Symbol,Any}
    @info("Loading JSON data from $file_path")
    json_data = read_json(file_path)
    if !lazy_load
        # Recursively check if any of the fields are paths to other JSON files
        json_data = load_paths(json_data, :path, dirname(file_path), lazy_load)
        json_data = clean_up_keys(json_data)
    end
    return json_data
end

function load_paths(dict::AbstractDict{Symbol,Any}, path_key::Symbol, root_path::AbstractString, lazy_load::Bool=true)
    if isa(dict, JSON3.Object)
        dict = copy(dict)
    end
    for (key, value) in dict
        if key == path_key
            dict = fetch_data(value, root_path, lazy_load)
        elseif isa(value, AbstractDict{Symbol,Any})
            dict[key] = load_paths(value, path_key, root_path, lazy_load)
        elseif isa(value, AbstractVector{<:AbstractDict{Symbol,Any}})
            for idx in eachindex(value)
                if isa(value[idx], JSON3.Object)
                    value[idx] = copy(value[idx])
                end
                value[idx] = load_paths(value[idx], path_key, root_path, lazy_load)
            end
            dict[key] = value
        end
    end
    return dict
end

function fetch_data(path::AbstractString, root_path::AbstractString, lazy_load::Bool=true)
    # Load data from a JSON file and merge it into the existing data dict
    # overwriting any existing keys
    path = rel_or_abs_path(path, root_path)
    if isfile(path)
        if endswith(path, ".json")
            return load_json(path; lazy_load=lazy_load)
        else
            return path
        end
    elseif isdir(path)
        json_files = filter(x -> endswith(x, ".json"), readdir(path))
        if length(json_files) > 1
            for file in json_files
                return load_json(joinpath(path, file); lazy_load=lazy_load)
            end
        else
            return path
        end
    else
        @warn "Could not find: \"$(path)\", full path: $(abspath(path))"
        return path
    end
end

function clean_up_keys(dict::AbstractDict{Symbol,Any})
    # If a key and value match, then copy the value to the key
    for (key, value) in dict
        if isa(value, AbstractDict{Symbol,Any}) && length(value) == 1 && first(collect(keys(value))) == key
            dict[key] = value[key]
        elseif isa(value, AbstractVector{<:AbstractDict{Symbol,Any}})
            for idx in eachindex(value)
                if isa(value[idx], AbstractDict{Symbol,Any})
                    value[idx] = clean_up_keys(value[idx])
                end
            end
            dict[key] = value
        end
    end
    return dict
end

"""
    get_value_and_keys(dict::AbstractDict, target_key::Symbol, keys=Symbol[])

Recursively searches for a target key in a dictionary and returns a list of 
tuples containing the value associated with the target key and the keys leading 
to it.
This function is used to replace the path to a timeseries file with the actual
vector of data.

# Arguments
- `dict::AbstractDict`: The (nested) dictionary to search in.
- `target_key::Symbol`: The key to search for.
- `keys=Symbol[]`: (optional) The keys leading to the current dictionary.

# Returns
- `value_keys`: A list of tuples, where each tuple contains 
                - the value associated with the target key
                - the keys leading to it in the nested dictionary.

# Examples
```julia
dict = Dict(:a => Dict(:b => 1, :c => Dict(:b => 2)))
get_value_and_keys(dict, :b) # returns [(1, [:a, :b]), (2, [:a, :c, :b])]
```
Where the first element of the tuple is the value of the key :b and the second 
element is the list of keys to reach that value.
"""
function get_value_and_keys(dict::AbstractDict, target_key::Symbol, keys=Symbol[])
    value_keys = []

    if haskey(dict, target_key)
        push!(value_keys, (dict[target_key], [keys; target_key]))
    end

    for (key, value) in dict
        if isa(value, AbstractDict)
            result = get_value_and_keys(value, target_key, [keys; key])
            append!(value_keys, result)
        end
    end

    return value_keys
end

# This function is used to get the value of a key in a nested dictionary.
"""
    get_value(dict::AbstractDict, keys::Vector{Symbol})

Get the value from a dictionary based on a sequence of keys.

# Arguments
- `dict::AbstractDict`: The dictionary from which to retrieve the value.
- `keys::Vector{Symbol}`: The sequence of keys to traverse the dictionary.

# Returns
- The value retrieved from the dictionary based on the given keys.

# Examples
```julia
dict = Dict(:a => Dict(:b => 1, :c => Dict(:b => 2)))
get_value(dict, [:a, :b]) # returns 1
get_value(dict, [:a, :c, :b]) # returns 2
```
"""
function get_value(dict::AbstractDict, keys::Vector{Symbol})
    value = dict
    for key in keys
        value = value[key]
    end
    return value
end

"""
    set_value(dict::AbstractDict, keys::Vector{Symbol}, new_value)

Set the value of a nested dictionary given a list of keys.

# Arguments
- `dict::AbstractDict`: The dictionary to modify.
- `keys::Vector{Symbol}`: A list of keys representing the path to the value to 
be modified.
- `new_value`: The new value to set.

# Examples
```julia
dict = Dict(:a => Dict(:b => 1, :c => Dict(:b => 2)))
set_value(dict, [:a, :b], 3)
get_value(dict, [:a, :b]) # returns 3
```
"""
function set_value(dict::AbstractDict, keys::Vector{Symbol}, new_value)
    value = dict
    for key in keys[1:end-1]
        value = value[key]
    end
    value[keys[end]] = new_value
end

function update_data!(data::AbstractDict{Symbol,Any}, keys::Vector{Symbol}, new_value)
    set_value(data, keys[1:end-1], new_value)
end

###### ###### ###### ###### ###### ######
# CSV data handling
###### ###### ###### ###### ###### ######

function load_csv(file_path::AbstractString, sink::T=DataFrame; select::S=Symbol[], lazy_load::Bool=true) where {T,S<:Union{Symbol, Vector{Symbol}}}
    if isa(select, Symbol)
        select = [select]
    end
    csv_data = read_csv(file_path, sink, select=select)
    return csv_data
    #TODO check how to use lazy_load with CSV files
end

function read_csv(file_path::AbstractString, sink::T=DataFrame; select::Vector{Symbol}=Symbol[]) where T
    if length(select) > 0
        @info("Loading columns $select from CSV data from $file_path")
        csv_data = CSV.read(file_path, sink, select=select)
        isempty(csv_data) && error("Columns $select not found in $file_path")
        return csv_data
    end
    @info("Loading CSV data from $file_path")
    return CSV.read(file_path, sink)
end

###### ###### ###### ###### ###### ######
# Function to load time series data
###### ###### ###### ###### ###### ######

function load_time_series_data!(system::System, data::AbstractDict{Symbol,Any})
    # get list of paths to time series data
    time_series_paths = get_value_and_keys(data, :timeseries)
    
    # load each time series data and update the data dictionary
    for (value, keys) in time_series_paths
        file_path = rel_or_abs_path(value[:path], system.data_dirpath)
        time_series = load_time_series_data(file_path, value[:header])
        update_data!(data, keys, time_series)
    end

    return nothing
end

function load_time_series_data(file_path::AbstractString, header::T)::Vector{Float64} where T <: Union{Symbol, String}
    time_series = load_csv(file_path, select=Symbol(header))
    return time_series[!, header]
end

###### ###### ###### ###### ###### ######
# Function to print the system data
###### ###### ###### ###### ###### ######

function print_to_json(system_data::AbstractDict{Symbol,Any}, file_path::AbstractString="")::Nothing
    if file_path == ""
        file_path = joinpath(pwd(), "printed_system_data.json")
    end
    write_json(file_path, system_data)
    return nothing
end

function read_json(file_path::AbstractString)
    io = open(file_path, "r")
    json_data = JSON3.read(io)
    close(io)
    return json_data
end

function write_json(file_path::AbstractString, data::Dict{Symbol,Any})::Nothing
    io = open(file_path, "w")
    JSON3.pretty(io, data)
    close(io)
    return nothing
end

function find_node(nodes_list::Vector{Node}, id::Symbol)
    for node in nodes_list
        if node.id == id
            return node
        end
    end
    error("Vertex $id not found")
    return nothing
end

function constraint_types(m::Module=Macro)
    return all_subtypes(m, :AbstractTypeConstraint)
end

# Function to make a node. 
# This is called when the "Type" of the object is a commodity
# We can do:
#   Commodity -> Node{Commodity}
#   
function make(commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any}, system::System)

    data = validate_data(data)

    node = Node(data, system.time_data[Symbol(commodity)], commodity)

    #### Note that not all nodes have a balance constraint, e.g., a NG source node does not have one. So the default should be empty.
    node.constraints = get(data, :constraints, Vector{AbstractTypeConstraint}())

    if any(isa.(node.constraints, BalanceConstraint))
        node.balance_data = get(data, :balance_data, Dict(:demand => Dict{Symbol,Float64}()))
    elseif any(isa.(node.constraints, CO2CapConstraint))
        node.balance_data = get(data, :balance_data, Dict(:emissions => Dict{Symbol,Float64}()))
    else
        node.balance_data = get(data, :balance_data, Dict(:exogenous => Dict{Symbol,Float64}()))
    end

    return node
end

function validate_id!(data::AbstractDict{Symbol,Any})
    if !haskey(data, :id)
        throw(ArgumentError("Edge data must have an id"))
    end
    return nothing
end

function validate_vector_symbol!(data::AbstractDict{Symbol,Any}, key::Symbol)
    if haskey(data, key) && !isa(data[key], Vector{Symbol})
        data[key] = Symbol.(data[key])
    end
    return nothing
end

function validate_single_symbol!(data::AbstractDict{Symbol,Any}, key::Symbol)
    if haskey(data, key) && !isa(data[key], Symbol)
        data[key] = Symbol(data[key])
    end
    return nothing
end

# FIXME: This function hides some important details about how constraints are declared
function validate_constraints_data!(data::AbstractDict{Symbol,Any})
    macro_constraints = constraint_types()
    if haskey(data, :constraints)
        constraints = Vector{AbstractTypeConstraint}(undef, length(data[:constraints]))
        for (counter, (k, v)) in enumerate(data[:constraints])
            # We'll assume that they're all included if they're mentioned here
            constraint_symbol = Symbol(join(push!(uppercasefirst.(split(string(k), "_")), "Constraint")))
            constraints[counter] = macro_constraints[constraint_symbol]()
        end
        data[:constraints] = constraints
    end
    return nothing
end

function validate_demand_header!(data::AbstractDict{Symbol,Any})
    validate_single_symbol!(data, :demand_header)
    return nothing
end

function validate_fuel_header!(data::AbstractDict{Symbol,Any})
    validate_single_symbol!(data, :price_header)
    return nothing
end

function validate_max_line_reinforcement!(data::AbstractDict{Symbol,Any})
    if haskey(data, :max_line_reinforcement)
        # Convert "Inf" to Inf
        max_line_reinforcement = get(data, :max_line_reinforcement, Inf)
        data[:max_line_reinforcement] = max_line_reinforcement == "Inf" ? Inf : max_line_reinforcement
    end
    return nothing
end

function validate_rhs_policy!(data::AbstractDict{Symbol,Any})
    if haskey(data, :rhs_policy)
        rhs_policy = Dict{DataType,Float64}()
        constraints = constraint_types()
        for (k, v) in data[:rhs_policy]
            new_k = constraints[Symbol(k)]
            rhs_policy[new_k] = v
        end
        data[:rhs_policy] = rhs_policy
    end
    return nothing
end

function validate_data(data::AbstractDict{Symbol,Any})
    if isa(data, JSON3.Object)
        data = copy(data)
    end
    validate_id!(data)
    validate_constraints_data!(data)
    validate_max_line_reinforcement!(data)
    validate_demand_header!(data)
    validate_fuel_header!(data)
    validate_rhs_policy!(data)

    validate_single_symbol!(data, :startup_fuel_balance_id)
    return data
end
