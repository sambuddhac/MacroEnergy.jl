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

function load_system(system_data::AbstractDict{Symbol, Any}, dir_path::AbstractString=pwd())::System
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

function generate_system!(system::System, system_data::AbstractDict{Symbol, Any})::Nothing
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

    # Load capacity factor data
    #FIXME Need to un-hardcode this and integrate it into the system_data struct
    load_capacity_factor!(system.assets, joinpath(system.data_dirpath, "assets"))

    load_fuel_data!(system.assets, joinpath(system.data_dirpath, "system"))

    return nothing
end

###### ###### ###### ###### ###### ######
# Internal functions to handle loading the system_data.json file
###### ###### ###### ###### ###### ######

function load_system_data(file_path::AbstractString; default_file_path::String=joinpath(@__DIR__, "default_system_data.json"), lazy_load::Bool=true)::Dict{Symbol, Any}
    load_system_data(file_path, dirname(file_path), default_file_path=default_file_path, lazy_load=lazy_load)
     return load_json(file_path; lazy_load=lazy_load)
end

function load_system_data(file_path::AbstractString, rel_path::AbstractString; default_file_path::String=joinpath(@__DIR__, "default_system_data.json"), lazy_load::Bool=true)::Dict{Symbol, Any}
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

function load_system_data!(system::System, data::AbstractDict{Symbol, Any})::Nothing

end

# function load_system_data!(system::System, data::AbstractDict{Symbol, Any})::Nothing
#     # For now, we can simply iterate over the dict of inputs
#     # We can add special cases as we go
#     if !haskey(data, :settings)
#         error("No settings found in system data")
#     else
#         @info("Loading settings")
#         if isa(value, AbstractDict{Symbol, Any})
#             system.macro_settings = configure_settings(value)
#         else
#             @warn("No settings found. Using default settings")
#             system.macro_settings = configure_settings(Dict{Symbol, Any}())
#         end
#     end
#     delete!(data, :settings)

#     if !haskey(data, :commodities)
#         error("No commodities found in system data")
#     else
#         @info("Loading commodities")
        
#     end
#     delete!(data, :assets)

#     if !haskey(data, :locations)
#         error("No locations found in system data")
#     else
#         @info("Loading locations")
#         # load!(system, data[:locations])
#         println("Skipping locations")
#     end
#     delete!(data, :locations)

#     if !haskey(data, :assets)
#         error("No assets found in system data")
#     else
#         @info("Loading assets")
#         load!(system, data[:assets])
#     end
#     delete!(data, :assets)

    

#     for (key, value) in data
#         println("Loading $key from $path")
#         load!(system, value)
#     end
#     return nothing
# end

function load_default_system_data(default_file_path::String=joinpath(@__DIR__, "default_system_data.json"))::Dict{Symbol, Any}
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
function load!(system::System, data::AbstractDict{Symbol, Any})::Nothing
    if data_is_system_data(data)
        # println("Loading system data")
        load_system_data!(system, data)

    # Check that data has only :type and :instance_data fields
    elseif data_is_single_instance(data)
        data_type = check_and_convert_type(data)
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
function load!(system::System, data::AbstractVector{<:AbstractDict{Symbol, Any}})::Nothing
    for instance in data
        load!(system, instance)
    end
    return nothing
end

recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
recursive_merge(x::AbstractVector...) = cat(x...; dims=1)
recursive_merge(x...) = x[end]

function expand_instances(data::AbstractDict{Symbol, Any})
    instances = Vector{Dict{Symbol, Any}}()
    type = data[:type]
    global_data = data[:global_data]
    for (instance_idx, instance_data) in enumerate(data[:instance_data])
        instance_data = recursive_merge(global_data, instance_data)
        # haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_asset_name(instance_idx, a_name)
        # instance_data[:id], _ = make_asset_id(instance_id, asset_data)
        # asset_data[instance_data[:id]] = make_asset(a_type, instance_data, time_data, nodes)
        push!(instances, Dict{Symbol, Any}(:type => type, :instance_data => instance_data))
    end
    return instances
end

###### ###### ###### ###### ###### ######
# Checks on the kind of data
###### ###### ###### ###### ###### ######

function check_and_convert_type(data::AbstractDict{Symbol, Any}, m::Module=Macro)::DataType
    if !haskey(data, :type)
        throw(ArgumentError("Instance data does not have a :type field"))
    end
    return getfield(m, Symbol(data[:type]))
end

function data_is_single_instance(data::AbstractDict{Symbol, Any})::Bool
    # Check that data has only :type and :instance_data fields
    # We could also check the types of the fields
    entries = collect(keys(data))
    if length(entries) == 2 && issetequal(entries, [:type, :instance_data])
        return true
    else
        return false
    end
end

function data_has_global_data(data::AbstractDict{Symbol, Any})::Bool
    # Check that data has only :type, :instance_data, :global_data fields
    entries = collect(keys(data))
    if length(entries) == 3 && issetequal(entries, [:type, :instance_data, :global_data])
        return true
    else
        return false
    end
end

function data_is_filepath(data::AbstractDict{Symbol, Any})::Bool
    entries = collect(keys(data))
    if length(entries) == 1 && issetequal(entries, [:path])
        return true
    else
        return false
    end
end

function data_is_system_data(data::AbstractDict{Symbol, Any})::Bool
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

function rel_or_abs_path(path::T, rel_dir::T=pwd())::T where T<:AbstractString
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

function load_json(file_path::AbstractString; lazy_load::Bool=true)::Dict{Symbol, Any}
    @info("Loading JSON data from $file_path")
    json_data = read_json(file_path)
    if !lazy_load
        # Recursively check if any of the fields are paths to other JSON files
        json_data = load_paths(json_data, :path, dirname(file_path), lazy_load)
        json_data = clean_up_keys(json_data)
    end
    return json_data
end

function load_paths(dict::AbstractDict{Symbol, Any}, path_key::Symbol, root_path::AbstractString, lazy_load::Bool=true)
    if isa(dict, JSON3.Object)
        dict = copy(dict)
    end
    for (key, value) in dict
        if key == path_key
            dict = fetch_data(value, root_path, lazy_load)
        elseif isa(value, AbstractDict{Symbol, Any})
            dict[key] = load_paths(value, path_key, root_path, lazy_load)
        elseif isa(value, AbstractVector{<:AbstractDict{Symbol, Any}})
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

function clean_up_keys(dict::AbstractDict{Symbol, Any})
    # If a key and value match, then copy the value to the key
    for (key, value) in dict
        if isa(value, AbstractDict{Symbol, Any}) && length(value) == 1 && first(collect(keys(value))) == key
            dict[key] = value[key]
        elseif isa(value, AbstractVector{<:AbstractDict{Symbol, Any}})
            for idx in eachindex(value)
                if isa(value[idx], AbstractDict{Symbol, Any})
                    value[idx] = clean_up_keys(value[idx])
                end
            end
            dict[key] = value
        end
    end
    return dict
end

###### ###### ###### ###### ###### ######
# Function to print the system data
###### ###### ###### ###### ###### ######

function print_to_json(system_data::AbstractDict{Symbol, Any}, file_path::AbstractString="")::Nothing
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

function write_json(file_path::AbstractString, data::Dict{Symbol, Any})::Nothing
    io = open(file_path, "w")
    JSON3.pretty(io, data)
    close(io)
    return nothing
end

# function add_constraint!(a::AbstractAsset, c::Type{<:AbstractTypeConstraint})
#     for t in fieldnames(a)
#         add_constraint!(getfield(a,t), c())
#     end
#     return nothing
# end

# function add_constraint!(t::T, c::Type{<:AbstractTypeConstraint}) where T<:Union{AbstractVertex, Edge, AbstractAsset}
#     push!(t.constraints, c())
#     return nothing
# end

# function add_constraints!(target::T, data::Dict{Symbol,Any}) where T<:Union{AbstractVertex, Edge, AbstractAsset}
#     constraints = get(data, :constraints, nothing)
#     if constraints !== nothing
#         macro_constraints = constraint_types()
#         for (k,v) in constraints
#             v == true && add_constraint!(target, macro_constraints[k])
#         end
#     end
#     return nothing
# end

function find_node(nodes_list::Vector{Node}, id::Symbol)
    for node in nodes_list
        if node.id == id
            return node
        end
    end
    error("Vertex $id not found")
    return nothing
end

# Function to make a node. 
# This is called when the "Type" of the object is a commodity
# We can do:
#   Commodity -> Node{Commodity}
#   
function make(commodity::Type{<:Commodity}, data::AbstractDict{Symbol, Any}, system::System)
    data = validate_data(data)
    node = Node{commodity}(;
        id = Symbol(data[:id]),
        demand = get(data, :demand, Vector{Float64}()),
        demand_header = get(data, :demand_header, nothing),
        timedata = system.time_data[Symbol(commodity)],
        max_nsd = get(data, :max_nsd, [0.0]),
        price_nsd = get(data, :price_nsd, [0.0]),
        price_unmet_policy = get(data, :price_unmet_policy, Dict{DataType,Float64}()),
        rhs_policy = get(data, :rhs_policy, Dict{DataType,Float64}()),
        balance_data = Dict(:demand=>Dict()),
        constraints = [BalanceConstraint(); MaxNonServedDemandConstraint()]
    )
    return node
end

"""
    make(::Type{Battery}, data::AbstractDict{Symbol, Any}, system::System) -> Battery

    Necessary data fields:
     - storage: Dict{Symbol, Any}
        - id: String
        - commodity: String
        - can_retire: Bool
        - can_expand: Bool
        - existing_capacity_storage: Float64
        - investment_cost_storage: Float64
        - fixed_om_cost_storage: Float64
        - storage_loss_fraction: Float64
        - min_duration: Float64
        - max_duration: Float64
        - min_storage_level: Float64
        - min_capacity_storage: Float64
        - max_capacity_storage: Float64
        - balance_data: Dict{Symbol, Dict{Symbol, Float64}}
        - constraints: Vector{AbstractTypeConstraint}
     - edges: Dict{Symbol, Any}
        - charge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_vars: Bool
        - discharge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_vars: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{Battery}, data::AbstractDict{Symbol, Any}, system::System)
    storage_data = validate_data(data[:storage])
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    battery_storage = Storage{commodity}(;
        id = Symbol(storage_data[:id] * "_storage"),
        timedata = system.time_data[commodity_symbol],
        can_retire = get(storage_data, :can_retire, false),
        can_expand = get(storage_data, :can_expand, false),
        existing_capacity_storage = get(storage_data, :existing_capacity_storage, 0.0),
        investment_cost_storage = get(storage_data, :investment_cost_storage, 0.0),
        fixed_om_cost_storage = get(storage_data, :fixed_om_cost_storage, 0.0),
        storage_loss_fraction = get(storage_data, :storage_loss_fraction, 0.0),
        min_duration = get(storage_data, :min_duration, 0.0),
        max_duration = get(storage_data, :max_duration, 0.0),
        min_storage_level = get(storage_data, :min_storage_level, 0.0),
        min_capacity_storage = get(storage_data, :min_capacity_storage, 0.0),
        max_capacity_storage = get(storage_data, :max_capacity_storage, Inf),
        balance_data = get(storage_data, :balance_data, Dict(:storage=>Dict(:discharge=>1/0.9,:charge=>0.9))),
        constraints = get(storage_data, :constraints, [BalanceConstraint(), StorageCapacityConstraint(), StorageMaxDurationConstraint(), StorageMinDurationConstraint(), StorageSymmetricCapacityConstraint()])
    )

    charging_edge_data = validate_data(data[:edges][:charge])
    charging_start_node = find_node(system.locations, Symbol(charging_edge_data[:start_vertex]))
    charging_end_node = battery_storage
    battery_charging = Edge{commodity}(;
        id = Symbol(data[:id] * "_charge"),
        start_vertex = charging_start_node,
        end_vertex = charging_end_node,
        timedata = system.time_data[commodity_symbol],
        unidirectional = get(charging_edge_data, :unidirectional, true),
        has_planning_variables = get(charging_edge_data, :has_planning_vars, false),
    )

    discharge_edge_data = validate_data(data[:edges][:discharge])
    discharge_start_node = battery_storage
    discharge_end_node = find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    battery_discharge = Edge{commodity}(;
        id = Symbol(data[:id] * "_discharge"),
        start_vertex = discharge_start_node,
        end_vertex = discharge_end_node,
        timedata = system.time_data[commodity_symbol],
        unidirectional = get(discharge_edge_data, :unidirectional, true),
        has_planning_variables = get(discharge_edge_data, :has_planning_vars, true),
        can_retire = get(discharge_edge_data, :can_retire, false),
        can_expand = get(discharge_edge_data, :can_expand, true),
        constraints = [CapacityConstraint(), RampingLimitConstraint()]
    )

    battery_storage.discharge_edge = battery_discharge
    battery_storage.charge_edge = battery_charging

    return Battery(battery_storage, battery_discharge, battery_charging)
end

"""
    make(::Type{NaturalGasPower}, data::AbstractDict{Symbol, Any}, system::System) -> NaturalGasPower

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - time_commodity: String
        - balance_data: Dict{Symbol, Dict{Symbol, Float64}}
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - elec: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_vars: Bool
            - can_retire: Bool
            - can_expand: Bool
            - min_up_time: Int
            - min_down_time: Int
            - startup_cost: Float64
            - startup_fuel: Float64
            - startup_fuel_balance_id: Symbol
            - constraints: Vector{AbstractTypeConstraint}
        - natgas: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_vars: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - co2: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_vars: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{NaturalGasPower}, data::AbstractDict{Symbol, Any}, system::System)

    transform_data = validate_data(data[:transforms])
    natgas_transform = Transformation(;
        id = Symbol(transform_data[:id]),
        timedata = system.time_data[Symbol(transform_data[:time_commodity])],
        balance_data = get(transform_data, :balance_data, Dict{Symbol, Dict{Symbol, Float64}}()),
        constraints = get(transform_data, :constraints, [BalanceConstraint()])
    )

    elec_edge_data = validate_data(data[:edges][:elec])
    elec_start_node = natgas_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    elec_edge = EdgeWithUC{Electricity}(;
        id = Symbol(elec_edge_data[:id]),
        start_vertex = elec_start_node,
        end_vertex = elec_end_node,
        timedata = system.time_data[:Electricity],
        unidirectional = get(elec_edge_data, :unidirectional, true),
        has_planning_variables = get(elec_edge_data, :has_planning_vars, false),
        can_retire = get(elec_edge_data, :can_retire, false),
        can_expand = get(elec_edge_data, :can_expand, false),
        min_up_time = get(elec_edge_data, :min_up_time, 0),
        min_down_time = get(elec_edge_data, :min_down_time, 0),
        startup_cost = get(elec_edge_data, :startup_cost, 0.0),
        startup_fuel = get(elec_edge_data, :startup_fuel, 0.0),
        startup_fuel_balance_id = get(elec_edge_data, :startup_fuel_balance_id, :energy),
        constraints = get(elec_edge_data, :constraints, [CapacityConstraint(), RampingLimitConstraint(), MinUpTimeConstraint(), MinDownTimeConstraint()])
    )

    ng_edge_data = validate_data(data[:edges][:natgas])
    ng_start_node = find_node(system.locations, Symbol(ng_edge_data[:start_vertex]))
    ng_end_node = natgas_transform
    ng_edge = Edge{NaturalGas}(;
        id = Symbol(ng_edge_data[:id]),
        start_vertex = ng_start_node,
        end_vertex = ng_end_node,
        timedata = system.time_data[:NaturalGas],
        unidirectional = get(ng_edge_data, :unidirectional, true),
        has_planning_variables = get(ng_edge_data, :has_planning_vars, false),
        can_retire = get(ng_edge_data, :can_retire, false),
        can_expand = get(ng_edge_data, :can_expand, false),
        constraints = get(ng_edge_data, :constraints, [])
    )

    co2_edge_data = validate_data(data[:edges][:co2])
    co2_start_node = natgas_transform
    co2_end_node = find_node(system.locations, Symbol(co2_edge_data[:end_vertex]))
    co2_edge = Edge{CO2}(;
        id = Symbol(co2_edge_data[:id]),
        start_vertex = co2_start_node,
        end_vertex = co2_end_node,
        timedata = system.time_data[:CO2],
        unidirectional = get(co2_edge_data, :unidirectional, true),
        has_planning_variables = get(co2_edge_data, :has_planning_vars, false),
        can_retire = get(co2_edge_data, :can_retire, false),
        can_expand = get(co2_edge_data, :can_expand, false),
        constraints = get(co2_edge_data, :constraints, [])
    )

    return NaturalGasPower(natgas_transform, elec_edge, ng_edge, co2_edge)
end

"""
    make(::Type{<:VRE}, data::AbstractDict{Symbol, Any}, system::System) -> VRE
    
    VRE is an alias for Union{SolarPV, WindTurbine}

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - time_commodity: String
    - edges: Dict{Symbol, Any}
        - id: String
        - end_vertex: String
        - unidirectional: Bool
        - has_planning_vars: Bool
        - can_retire: Bool
        - can_expand: Bool
        - constraints: Vector{AbstractTypeConstraint}
"""
function make(asset_type::Type{<:VRE}, data::AbstractDict{Symbol, Any}, system::System)
    transform_data = validate_data(data[:transforms])
    vre_transform = Transformation(;
        id = Symbol(transform_data[:id]),
        timedata = system.time_data[Symbol(transform_data[:time_commodity])],
    )

    elec_edge_data = validate_data(data[:edges])
    elec_start_node = vre_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    elec_edge = Edge{Electricity}(;
        id = Symbol(elec_edge_data[:id]),
        start_vertex = elec_start_node,
        end_vertex = elec_end_node,
        timedata = system.time_data[:Electricity],
        unidirectional = get(elec_edge_data, :unidirectional, true),
        has_planning_variables = get(elec_edge_data, :has_planning_vars, false),
        can_retire = get(elec_edge_data, :can_retire, false),
        can_expand = get(elec_edge_data, :can_expand, false),
        constraints = get(elec_edge_data, :constraints, [CapacityConstraint()])
    )

    return asset_type(vre_transform, elec_edge)
end