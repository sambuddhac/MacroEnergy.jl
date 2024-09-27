# Results are stored as a table with the following columns:
# | model | scenario | region | variable | unit | time | value | 
# Internally, each row is represented as an OutputRow object:
struct OutputRow
    model::Union{Symbol,Missing}
    scenario::Union{Symbol,Missing}
    region::Symbol
    variable::Symbol
    type::Symbol
    unit::Symbol
    time::Union{Int,Missing}
    value::Float64
    OutputRow(region::Symbol, variable::Symbol, type::Symbol, unit::Symbol, value::Float64) =
        new(missing, missing, region, variable, type, unit, missing, value)
    OutputRow(region::Symbol, variable::Symbol, type::Symbol, unit::Symbol, time::Int, value::Float64) =
        new(missing, missing, region, variable, type, unit, time, value)
end

#### Helper functions to extract optimal values of fields from MacroObjects ####
# The following functions are used to extract the optimal values of given fields
# or a list of fields from:
# - System: e.g.: get_optimal_vars(system, capacity, :MW)
# - Vector of MacroObjects (e.g., edges, nodes, transformations, storage)
#   e.g.: get_optimal_vars(edges, (capacity, new_capacity, ret_capacity), :MW)
get_optimal_vars(objs::Vector{T}, field::Function, unit::Symbol, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=()) where {T<:Union{AbstractEdge,Storage}} =
    get_optimal_vars(objs, (field,), unit, obj_asset_map)
function get_optimal_vars(objs::Vector{T}, field_list::Tuple, unit::Symbol, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=()) where {T<:Union{AbstractEdge,Storage}}
    if isempty(obj_asset_map)
        return OutputRow[
            OutputRow(
                get_region_name(obj),
                get_header_variable_name(obj, f),
                get_type(obj),
                unit,
                Float64(value(f(obj))),
            ) for obj in objs for f in field_list
        ]
    else
        return OutputRow[
            OutputRow(
                get_region_name(obj),
                get_header_variable_name(obj, f),
                get_type(obj_asset_map[id(obj)]),
                unit,
                Float64(value(f(obj))),
            ) for obj in objs for f in field_list
        ]
    end
end

get_region_name(v::AbstractVertex) = id(v)

# The default region name for an edge is the concatenation of the ids of its nodes:
# e.g., "elec_1_elec_2" for an edge connecting nodes "elec_1" and "elec_2" or 
# "elec_1" if connecting a node to storage/transformation
function get_region_name(e::AbstractEdge)
    region_name = join((id(n) for n in (e.start_vertex, e.end_vertex) if isa(n, Node)), "_")
    if isempty(region_name)
        region_name = :internal # TODO: fix this
    end
    Symbol(region_name)
end
# The default "variable" name for an edge is: field_name|commodity_type|edge_id
# e.g., "capacity|Electricity|ng_1_e_edge"
get_header_variable_name(obj::T, f::Function) where {T<:Union{AbstractEdge,Node,Storage}} =
    Symbol("$(f)|$(commodity_type(obj))|$(id(obj))")

get_type(asset::Base.RefValue{<:AbstractAsset}) = Symbol(typeof(asset).parameters[1])
get_type(obj::Node) = Symbol(commodity_type(obj))

get_unit(obj::AbstractEdge) = unit(commodity_type(obj.timedata))    #TODO: check if this is correct
get_unit(obj::T) where {T<:Union{Node,Storage}} = unit(commodity_type(obj))

# This function is used to extract the optimal values of given fields from a 
# list of MacroObjects at different time intervals.
# e.g., get_optimal_vars_timeseries(edges, flow, :my_unit)
function get_optimal_vars_timeseries(
    objs::Vector{T},
    field_list::Tuple,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    reduce(vcat, [get_optimal_vars_timeseries(o, field_list, obj_asset_map) for o in objs])
end

function get_optimal_vars_timeseries(
    objs::Vector{T},
    f::Function,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    reduce(vcat, [get_optimal_vars_timeseries(o, f, obj_asset_map) for o in objs])
end

function get_optimal_vars_timeseries(
    obj::T,
    field_list::Tuple,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    reduce(vcat, [get_optimal_vars_timeseries(obj, f, obj_asset_map) for f in field_list])
end

function get_optimal_vars_timeseries(
    obj::T,
    f::Function,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node}}
    time_axis = time_interval(obj)
    out = Vector{OutputRow}(undef, length(time_axis))
    if isempty(obj_asset_map)
        for (i, t) in enumerate(time_axis)
            out[i] = OutputRow(
                get_region_name(obj),
                get_header_variable_name(obj, f),
                get_type(obj),
                get_unit(obj),
                t,
                value(f(obj, t)),
            )
        end
    else
        for (i, t) in enumerate(time_axis)
            out[i] = OutputRow(
                get_region_name(obj),
                get_header_variable_name(obj, f),
                get_type(obj_asset_map[id(obj)]),
                get_unit(obj),
                t,
                value(f(obj, t)),
            )
        end
    end
    out
end

################################################################################

#### Helper functions to extract MacroObjects from System ####
function get_macro_objs(asset::AbstractAsset, T::Type{<:MacroObject}, return_map::Bool=false)
    objs = Vector{T}()
    for y in getfield.(Ref(asset), propertynames(asset))
        if isa(y, T)
            push!(objs, y)
        end
    end
    if return_map
        return objs, Dict{Symbol,Base.RefValue{<:AbstractAsset}}((obj.id, Ref(asset)) for obj in objs)
    end
    return objs
end

function get_macro_objs(assets::Vector{<:AbstractAsset}, T::Type{<:MacroObject}, return_map::Bool=false)
    if return_map
        objs = Vector{Vector{T}}(undef, length(assets))
        asset_obj_map = Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
        for i in eachindex(assets)
            asset = assets[i]
            asset_objs, asset_obj_asset_map = get_macro_objs(asset, T, return_map)
            objs[i] = asset_objs
            merge!(asset_obj_map, asset_obj_asset_map)
        end
        return reduce(vcat, objs), asset_obj_map
    else
        return reduce(vcat, [get_macro_objs(asset, T) for asset in assets])
    end
end

get_macro_objs(system::System, T::Type{<:MacroObject}, return_map::Bool=false) =
    get_macro_objs(system.assets, T, return_map)

get_edges(system::System; return_ids_map::Bool=false) = get_macro_objs(system, AbstractEdge, return_ids_map)
get_transformations(system::System; return_ids_map::Bool=false) = get_macro_objs(system, Transformation, return_ids_map)
get_storage(system::System; return_ids_map::Bool=false) = get_macro_objs(system, Storage, return_ids_map)
get_nodes(system::System) = system.locations

edges_with_planning_variables(system::System) = edges_with_planning_variables(system.assets)
edges_with_planning_variables(assets::Vector{<:AbstractAsset}) =
    reduce(vcat, [edges_with_planning_variables(asset) for asset in assets])
edges_with_planning_variables(asset::AbstractAsset) =
    AbstractEdge[edge for edge in get_edges(asset) if has_planning_variables(edge)]
edges_with_planning_variables(edges::Vector{<:AbstractEdge}) =
    AbstractEdge[edge for edge in edges if has_planning_variables(edge)]
################################################################################

# Function to convert a vector of OutputRow objects to a DataFrame for 
# visualization purposes and writing to CSV
convert_to_dataframe(data::Vector{OutputRow}) = DataFrame(data, copycols=false)
function convert_to_dataframe(data::Vector{Tuple}, header::Vector)
    @assert length(data[1]) == length(header)
    DataFrame(data, header)
end

# Function to collect all the outputs from a system and return them as a DataFrame
function collect_results(system::System)
    edges, edge_asset_map = get_edges(system, return_ids_map=true)

    # capacity variables 
    field_list = (capacity, new_capacity, ret_capacity)
    e_with_vars = edges_with_planning_variables(edges)
    evars_asset_map = filter(edge -> edge[1] in id.(e_with_vars), edge_asset_map)
    ecap = get_optimal_vars(e_with_vars, field_list, :MW, evars_asset_map)

    ## time series
    # edge flow
    eflow = get_optimal_vars_timeseries(edges, flow, edge_asset_map)

    # # non_served_demand
    # nsd = get_optimal_vars_timeseries(system.locations, (non_served_demand, policy_slack_vars), :MW) # TODO: add segments

    # # storage storage_level
    storages, storage_asset_map = get_storage(system, return_ids_map=true)
    storlevel = get_optimal_vars_timeseries(storages, storage_level, storage_asset_map)

    convert_to_dataframe(reduce(vcat, [ecap, eflow, storlevel]))
end

function write_results(file_path::AbstractString, system::System)
    @info "Writing results to $file_path"
    output = collect_results(system)
    if all(ismissing.(output.model))
        output.model .= basename(system.data_dirpath)
    end
    if all(ismissing.(output.scenario))
        output.scenario .= :default
    end
    CSV.write(file_path, output, compress=true)
end

function write_csv(file_path::AbstractString, data::AbstractDataFrame)
    CSV.write(file_path, data)
end
