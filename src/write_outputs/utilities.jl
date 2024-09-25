struct OutputRow
    model::Union{Symbol,Missing}
    scenario::Union{Symbol,Missing}
    region::Symbol
    variable::Symbol
    unit::Symbol
    time::Union{Int,Missing}
    value::Float64
    OutputRow(region::Symbol, variable::Symbol, unit::Symbol, value::Float64) =
        new(missing, missing, region, variable, unit, missing, value)
    OutputRow(region::Symbol, variable::Symbol, unit::Symbol, time::Int, value::Float64) =
        new(missing, missing, region, variable, unit, time, value)
end
get_optimal_vars(syst::System, field::Function, unit::Symbol) =
    get_optimal_vars(syst, (field,), unit)
get_optimal_vars(objs::Vector, field::Function, unit::Symbol) =
    get_optimal_vars(objs, (field,), unit)
function get_optimal_vars(objs::Vector, field_list::Tuple, unit::Symbol)
    OutputRow[
        OutputRow(
            get_region_name(obj),
            get_header_variable_name(obj, f),
            unit,
            Float64(value(f(obj))),
        ) for obj in objs for f in field_list
    ]
end

get_region_name(v::AbstractVertex) = id(v)
get_region_name(e::AbstractEdge) =
    Symbol(join((id(n) for n in (e.start_vertex, e.end_vertex) if isa(n, Node)), "_"))
get_header_variable_name(obj::T, f::Function) where {T<:Union{AbstractEdge,Node,Storage}} =
    Symbol("$(f)|$(commodity_type(obj))|$(id(obj))")
function get_optimal_vars_timeseries(
    objs::Vector{T},
    field_list::Tuple,
    unit::Symbol,
) where {T<:MacroObject}
    reduce(vcat, [get_optimal_vars_timeseries(e, field_list, unit) for e in objs])
end

function get_optimal_vars_timeseries(
    objs::Vector{T},
    f::Function,
    unit::Symbol,
) where {T<:MacroObject}
    reduce(vcat, [get_optimal_vars_timeseries(e, f, unit) for e in objs])
end

function get_optimal_vars_timeseries(
    obj::T,
    field_list::Tuple,
    unit::Symbol,
) where {T<:MacroObject}
    reduce(vcat, [get_optimal_vars_timeseries(obj, f, unit) for f in field_list])
end

function get_optimal_vars_timeseries(
    obj::T,
    f::Function,
    unit::Symbol,
) where {T<:MacroObject}
    time_axis = time_interval(obj)
    out = Vector{OutputRow}(undef, length(time_axis))
    for (i, t) in enumerate(time_axis)
        out[i] = OutputRow(
            get_region_name(obj),
            get_header_variable_name(obj, f),
            unit,
            t,
            value(f(obj, t)),
        )
    end
    out
end
get_edges(asset::AbstractAsset) = get_macro_objs(asset, AbstractEdge)
get_edges(assets::Vector{<:AbstractAsset}) =
    reduce(vcat, [get_edges(asset) for asset in assets])
get_edges(system::System) = get_edges(system.assets)

get_nodes(system::System) = system.locations

get_transformations(asset::AbstractAsset) = get_macro_objs(asset, Transformation)
get_transformations(assets::Vector{<:AbstractAsset}) =
    reduce(vcat, [get_transformations(asset) for asset in assets])
get_transformations(system::System) = get_transformations(system.assets)

get_storage(system::System) = get_storage(system.assets)
get_storage(assets::Vector{<:AbstractAsset}) =
    reduce(vcat, [get_storage(asset) for asset in assets])
get_storage(asset::AbstractAsset) = get_macro_objs(asset, Storage)

function get_macro_objs(asset::AbstractAsset, T::Type{<:MacroObject})
    objs = Vector{T}()
    for y in getfield.(Ref(asset), propertynames(asset))
        if isa(y, T)
            push!(objs, y)
        end
    end
    return objs
end

edges_with_planning_variables(system::System) = edges_with_planning_variables(system.assets)
edges_with_planning_variables(assets::Vector{<:AbstractAsset}) =
    reduce(vcat, [edges_with_planning_variables(asset) for asset in assets])
edges_with_planning_variables(asset::AbstractAsset) =
    AbstractEdge[edge for edge in get_edges(asset) if has_planning_variables(edge)]
edges_with_planning_variables(edges::Vector{<:AbstractEdge}) =
    AbstractEdge[edge for edge in edges if has_planning_variables(edge)]
convert_to_dataframe(data::Vector{OutputRow}) = DataFrame(data, copycols = false)
function convert_to_dataframe(data::Vector{Tuple}, header::Vector)
    @assert length(data[1]) == length(header)
    DataFrame(data, header)
end
function collect_results(system::System)
    edges = get_edges(system)

    # capacity variables 
    field_list = (capacity, new_capacity, ret_capacity)
    e_with_vars = edges_with_planning_variables(edges)
    ecap = get_optimal_vars(e_with_vars, field_list, :MW)

    ## time series
    # edge flow
    eflow = get_optimal_vars_timeseries(edges, flow, :unknown)

    # # non_served_demand
    # nsd = get_optimal_vars_timeseries(system.locations, (non_served_demand, policy_slack_vars), :MW) # TODO: add segments

    # # storage storage_level
    storages = get_storage(system)
    storlevel = get_optimal_vars_timeseries(storages, storage_level, :MWh)

    convert_to_dataframe(reduce(vcat, [ecap, eflow, storlevel]))
end
function write_csv(file_path::AbstractString, data::AbstractDataFrame)
    CSV.write(file_path, data)
end
