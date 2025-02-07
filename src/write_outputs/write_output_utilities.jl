# Results are stored as a table with the following columns:
# | case_name | commodity | commodity_subtype | zone | year | time | resource_id | type | variable | value | unit | 
# Internally, each row is represented as an OutputRow object:
struct OutputRow
    case_name::Union{Symbol,Missing}
    commodity::Symbol
    commodity_subtype::Union{Symbol,Missing}
    zone::Symbol
    resource_id::Symbol
    component_id::Symbol
    type::Symbol
    variable::Symbol
    year::Union{Int,Missing}
    segment::Union{Int,Missing}
    time::Union{Int,Missing}
    value::Float64
    # unit::Symbol # Commented out for now
end

# Ctor if the case_name is missing
OutputRow(commodity::Symbol, commodity_subtype::Union{Symbol,Missing}, zone::Symbol, resource_id::Symbol, component_id::Symbol, type::Symbol, variable::Symbol, year::Union{Int,Missing}, segment::Union{Int,Missing}, time::Union{Int,Missing}, value::Float64) =
    OutputRow(missing, commodity, commodity_subtype, zone, resource_id, component_id, type, variable, year, segment, time, value)

## Helper functions to extract optimal values of fields from MacroObjects ##
# The following functions are used to extract the values after the model has been solved
# from a list of MacroObjects (e.g., edges, and storage) and a list of fields (e.g., capacity, new_capacity, ret_capacity)
#   e.g.: get_optimal_vars(edges, (capacity, new_capacity, ret_capacity))
get_optimal_vars(objs::Vector{T}, field::Function, scaling::Float64=1.0, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()) where {T<:Union{AbstractEdge,Storage}} =
    get_optimal_vars(objs, (field,), scaling, obj_asset_map)
function get_optimal_vars(objs::Vector{T}, field_list::Tuple, scaling::Float64=1.0, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()) where {T<:Union{AbstractEdge,Storage}}
    # the obj_asset_map is used to map the asset component (e.g., natgas_1_ng_edge, natgas_2_ng_edge, natgas_1_elec_edge) to the actual asset id (e.g., natgas_1)
    if isempty(obj_asset_map)
        return OutputRow[
            OutputRow(
                get_commodity_name(obj),
                get_commodity_subtype(f),
                get_zone_name(obj),
                get_component_id(obj),  # if obj_asset_map is empty, the component id is the same as the resource id
                get_component_id(obj),
                get_type(obj),
                Symbol(f),
                missing,
                missing,
                missing,
                Float64(value(f(obj))) * scaling,
                # get_unit(obj, f),
            ) for obj in objs for f in field_list
        ]
    else
        return OutputRow[
            OutputRow(
                get_commodity_name(obj),
                get_commodity_subtype(f),
                get_zone_name(obj),
                get_resource_id(obj, obj_asset_map),
                get_component_id(obj),
                get_type(obj_asset_map[id(obj)]),
                Symbol(f),
                missing,
                missing,
                missing,
                Float64(value(f(obj))) * scaling,
                # get_unit(obj, f),
            ) for obj in objs for f in field_list
        ]
    end
end

## Helper functions to extract the optimal values of given fields from a list of MacroObjects at different time intervals ##
# e.g., get_optimal_vars_timeseries(edges, flow)
function get_optimal_vars_timeseries(
    objs::Vector{T},
    field_list::Tuple,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    reduce(vcat, [get_optimal_vars_timeseries(o, field_list, scaling, obj_asset_map) for o in objs])
end

function get_optimal_vars_timeseries(
    objs::Vector{T},
    f::Function,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    reduce(vcat, [get_optimal_vars_timeseries(o, f, scaling, obj_asset_map) for o in objs])
end

function get_optimal_vars_timeseries(
    obj::T,
    field_list::Tuple,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    reduce(vcat, [get_optimal_vars_timeseries(obj, f, scaling, obj_asset_map) for f in field_list])
end

function get_optimal_vars_timeseries(
    obj::T,
    f::Function,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    time_axis = time_interval(obj)
    # check if the time series is piecewise linear approximation with segments
    has_segments = ndims(f(obj)) > 1 # a matrix (segments, time)
    num_segments = has_segments ? size(f(obj), 1) : 1
    out = Vector{OutputRow}(undef, num_segments * length(time_axis))
    if isempty(obj_asset_map)
        for s in 1:num_segments
            for (j, t) in enumerate(time_axis)
                out[s+(j-1)*num_segments] = OutputRow(
                    get_commodity_name(obj),
                    get_commodity_subtype(f),
                    get_zone_name(obj),
                    get_component_id(obj),
                    get_component_id(obj),
                    get_type(obj),
                    Symbol(f),
                    missing,
                    s,
                    t,
                    has_segments ? value(f(obj, s, t)) * scaling : value(f(obj, t)) * scaling,
                    # get_unit(obj, f),
                )
            end
        end
    else
        for s in 1:num_segments
            for (j, t) in enumerate(time_axis)
                out[s+(j-1)*num_segments] = OutputRow(
                    get_commodity_name(obj),
                    get_commodity_subtype(f),
                    get_zone_name(obj),
                    isa(obj, Node) ? get_resource_id(obj) : get_resource_id(obj, obj_asset_map),
                    get_component_id(obj),
                    isa(obj, Node) ? get_type(obj) : get_type(obj_asset_map[id(obj)]),
                    Symbol(f),
                    missing,
                    s,
                    t,
                    has_segments ? value(f(obj, s, t)) * scaling : value(f(obj, t)) * scaling,
                    # get_unit(obj, f),
                )
            end
        end
    end
    out
end

# Get the commodity type of a MacroObject
get_commodity_name(obj::AbstractEdge) = Symbol(commodity_type(obj))
get_commodity_name(obj::Node) = Symbol(commodity_type(obj))
get_commodity_name(obj::Storage) = Symbol(commodity_type(obj))

# The commodity subtype is an identifier for the field names
# e.g., "capacity" for capacity variables, "flow" for flow variables, etc.
function get_commodity_subtype(f::Function)
    field_name = Symbol(f)
    if any(field_name .== (:capacity, :new_capacity, :ret_capacity))
        return :capacity
    # elseif f == various cost # TODO: implement this
    #     return :cost
    else
        return field_name
    end
end

# The resource id is the id of the asset that the object belongs to
function get_resource_id(obj::T, asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}) where {T<:Union{AbstractEdge,Storage}}
    asset = asset_map[id(obj)]
    asset[].id
end
get_resource_id(obj::Node) = id(obj)

# The component id is the id of the object itself
get_component_id(obj::T) where {T<:Union{AbstractEdge,Node,Storage}} = Symbol("$(id(obj))")

# Get the zone name/location of a vertex
get_zone_name(v::AbstractVertex) = id(v)
# The default zone name for an edge is the concatenation of the ids of its nodes:
# e.g., "elec_1_elec_2" for an edge connecting nodes "elec_1" and "elec_2" or 
# "elec_1" if connecting a node to storage/transformation
function get_zone_name(e::AbstractEdge)
    region_name = join((id(n) for n in (e.start_vertex, e.end_vertex) if isa(n, Node)), "_")
    if isempty(region_name)
        region_name = :internal # edge not connecting nodes
    end
    Symbol(region_name)
end

# Get the type of an asset
get_type(asset::Base.RefValue{<:AbstractAsset}) = Symbol(typeof(asset).parameters[1])
# Get the type of a MacroObject
get_type(obj::T) where {T<:Union{AbstractEdge,Node,Storage}} = Symbol(typeof(obj))

# Get the unit of a MacroObject
get_unit(obj::AbstractEdge, f::Function) = unit(commodity_type(obj.timedata), f)    #TODO: check if this is correct
get_unit(obj::T, f::Function) where {T<:Union{Node,Storage}} = unit(commodity_type(obj), f)

## Helper functions to extract final costs from the optimized model ##
# This fuction will returns:
# - Variable cost
# - Fixed cost
# - Total cost
function prepare_costs(model::Model, scaling::Float64=1.0)
    fixed_cost = value(model[:eFixedCost])
    variable_cost = value(model[:eVariableCost])
    total_cost = fixed_cost + variable_cost
    OutputRow[
        OutputRow(
            :all,
            :cost,
            :all,
            :all,
            :all,
            :Cost,
            :FixedCost,
            missing,
            missing,
            missing,
            fixed_cost * scaling^2,
            # :USD,
        ),
        OutputRow(
            :all,
            :cost,
            :all,
            :all,
            :all,
            :Cost,
            :VariableCost,
            missing,
            missing,
            missing,
            variable_cost * scaling^2,
            # :USD,
        ),
        OutputRow(
            :all,
            :cost,
            :all,
            :all,
            :all,
            :Cost,
            :TotalCost,
            missing,
            missing,
            missing,
            total_cost * scaling^2,
            # :USD,
        )
    ]
end

# Function to collect all the outputs from a system and return them as a DataFrame
"""
    collect_results(system::System, model::Model)

Returns a `DataFrame` with all the results after the optimization is performed. 

# Arguments
- `system::System`: The system object containing the case inputs.
- `model::Model`: The model being optimized.

# Returns
- `DataFrame`: A `DataFrame containing all the outputs from a system.

# Example
```julia
collect_results(system, model)
198534×12 DataFrame
    Row │ case_name  commodity    commodity_subtype  zone        resource_id                component_id                       type              variable  segment  time   value
        │ Missing    Symbol       Symbol             Symbol      Symbol                     Symbol                             Symbol            Symbol    Int64    Int64  Float64
────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      1 │   missing  Biomass      flow               bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  flow            1      1  0.0
      2 │   missing  Biomass      flow               bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  flow            1      2  0.0
      3 │   missing  Biomass      flow               bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  flow            1      3  0.0
      ...
```
"""
function collect_results(system::System, model::Model)
    scaling = system.settings.Scaling ? ScalingFactor : 1.0

    edges, edge_asset_map = get_edges(system, return_ids_map=true)

    # capacity variables 
    field_list = (capacity, new_capacity, ret_capacity)
    edges_with_capacity = edges_with_capacity_variables(edges)
    edges_with_capacity_asset_map = filter(edge -> edge[1] in id.(edges_with_capacity), edge_asset_map)
    ecap = get_optimal_vars(edges_with_capacity, field_list, scaling, edges_with_capacity_asset_map)

    ## time series
    # edge flow
    eflow = get_optimal_vars_timeseries(edges, flow, scaling, edge_asset_map)

    # non_served_demand
    nsd = get_optimal_vars_timeseries(system.locations, non_served_demand, scaling, edge_asset_map)

    # storage storage_level
    storages, storage_asset_map = get_storage(system, return_ids_map=true)
    storlevel = get_optimal_vars_timeseries(storages, storage_level, scaling, storage_asset_map)

    # costs
    costs = prepare_costs(model, scaling)

    convert_to_dataframe(reduce(vcat, [ecap, eflow, nsd, storlevel, costs]))
end

# Function to convert a vector of OutputRow objects to a DataFrame for 
# visualization purposes
convert_to_dataframe(data::Vector{OutputRow}) = DataFrame(data, copycols=false)
function convert_to_dataframe(data::Vector{<:Tuple}, header::Vector)
    @assert length(data[1]) == length(header)
    DataFrame(data, header)
end

# Function to collect the results from a system and write them to a CSV file
"""
    write_results(file_path::AbstractString, system::System, model::Model)

Collects all the results as a `DataFrame` and then writes them to disk after the optimization is performed. 

# Arguments
- `file_path::AbstractString`: full path of the file to export. 
- `system::System`: The system object containing the case inputs.
- `model::Model`: The model being optimized.

# Returns

# Example
```julia
write_results(case_path * "results.csv", system, model) # CSV
write_results(case_path * "results.csv.gz", system, model)  # GZIP
write_results(case_path * "results.parquet", system, model) # PARQUET
```
"""
function write_results(file_path::AbstractString, system::System, model::Model)
    @info "Writing results to $file_path"

    # Prepare output data
    output = collect_results(system, model)
    output.case_name .= coalesce.(output.case_name, basename(system.data_dirpath))
    output.year .= coalesce.(output.year, year(now()))

    # Write the DataFrame
    write_dataframe(file_path, output)
end

"""
    write_dataframe(file_path::AbstractString, df::AbstractDataFrame)

Write a DataFrame to a file in the appropriate format based on file extension.
Supported formats: .csv, .csv.gz, .parquet

# Arguments
- `file_path::AbstractString`: Path where to save the file
- `df::AbstractDataFrame`: DataFrame to write
"""
function write_dataframe(file_path::AbstractString, df::AbstractDataFrame)
    # Extract file extension and check if supported in Macro
    extension = lowercase(splitext(file_path)[2])
    # Create a map (supported_formats => write functions)
    supported_formats = Dict(
        ".csv" => (path, data) -> write_csv(path, data, false),
        ".csv.gz" => (path, data) -> write_csv(path, data, true),
        ".parquet" => write_parquet
    )
    
    # Validate file extension
    if !any(ext -> endswith(file_path, ext), keys(supported_formats))
        throw(ArgumentError("Unsupported file extension: $extension. Supported formats: $(join(keys(supported_formats), ", "))"))
    end

    # Get the appropriate writer function
    writer = first(writer for (ext, writer) in supported_formats if endswith(file_path, ext))
    # Write the DataFrame using the appropriate writer function
    writer(file_path, df)
    
    return nothing
end

# Function to write a DataFrame to a CSV file
function write_csv(file_path::AbstractString, data::AbstractDataFrame, compress::Bool=false)
    CSV.write(file_path, data, compress=compress)
end

# Function to write a DataFrame to a Parquet file
function write_parquet(file_path::AbstractString, data::DataFrame)
    # Parquet2 does not support Symbol columns
    # Convert Symbol columns to String in place
    for col in names(data)
        if eltype(data[!, col]) <: Symbol
            transform!(data, col => ByRow(string) => col)
        end
    end
    Parquet2.writefile(file_path, data)
end
