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
function write_csv(file_path::AbstractString, data::AbstractDataFrame)
    CSV.write(file_path, data)
end
