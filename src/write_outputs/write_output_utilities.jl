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
# from a list of MacroObjects (e.g., edges, and storage) and a list of fields (e.g., capacity, new_capacity, retired_capacity)
#   e.g.: get_optimal_vars(edges, (capacity, new_capacity, retired_capacity))
get_optimal_vars(objs::Vector{T}, field::Function, scaling::Float64=1.0, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()) where {T<:Union{AbstractEdge,Storage}} =
    get_optimal_vars(objs, (field,), scaling, obj_asset_map)
function get_optimal_vars(objs::Vector{T}, field_list::Tuple, scaling::Float64=1.0, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()) where {T<:Union{AbstractEdge,Storage}}
    # the obj_asset_map is used to map the asset component (e.g., natgas_1_natgas_edge, natgas_2_natgas_edge, natgas_1_elec_edge) to the actual asset id (e.g., natgas_1)
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
) where {T<:Union{AbstractEdge,Storage,Node,Location}}
    reduce(vcat, [get_optimal_vars_timeseries(o, field_list, scaling, obj_asset_map) for o in objs if !isa(o, Location)]) # filter out locations
end

function get_optimal_vars_timeseries(
    objs::Vector{T},
    f::Function,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage,Node,Location}}
    reduce(vcat, [get_optimal_vars_timeseries(o, f, scaling, obj_asset_map) for o in objs if !isa(o, Location)])
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
get_commodity_name(obj::AbstractEdge) = typesymbol(commodity_type(obj))
get_commodity_name(obj::Node) = typesymbol(commodity_type(obj))
get_commodity_name(obj::Storage) = typesymbol(commodity_type(obj))

# The commodity subtype is an identifier for the field names
# e.g., "capacity" for capacity variables, "flow" for flow variables, etc.
function get_commodity_subtype(f::Function)
    field_name = Symbol(f)
    if any(field_name .== (:capacity, :new_capacity, :retired_capacity, :existing_capacity))
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

# Function to collect all the outputs from a system and return them as a DataFrame
"""
    collect_results(system::System, model::Model, settings::NamedTuple, period_index::Int64=1, scaling::Float64=1.0)

Returns a `DataFrame` with all the results after the optimization is performed. 

# Arguments
- `system::System`: The system object containing the case inputs.
- `model::Model`: The model being optimized.
- `settings::NamedTuple`: The settings for the system, including output configurations.
- `period_index::Int64`: The index of the period to collect results for (default is 1).
- `scaling::Float64`: The scaling factor for the results.
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
function collect_results(system::System, model::Model, settings::NamedTuple, period_index::Int64=1, scaling::Float64=1.0)
    edges, edge_asset_map = get_edges(system, return_ids_map=true)

    # capacity variables 
    field_list = (capacity, new_capacity, retired_capacity)
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
    create_discounted_cost_expressions!(model, system, settings)

    compute_undiscounted_costs!(model, system, settings)

    discounted_costs = prepare_discounted_costs(model, period_index, scaling)

    undiscounted_costs = prepare_undiscounted_costs(model, period_index, scaling)

    convert_to_dataframe(reduce(vcat, [ecap, eflow, nsd, storlevel, discounted_costs,undiscounted_costs]))
end

# Function to convert a vector of OutputRow objects to a DataFrame for 
# visualization purposes
convert_to_dataframe(data::Vector{OutputRow}) = DataFrame(data, copycols=false)
function convert_to_dataframe(data::Vector{<:Tuple}, header::Vector)
    @assert length(data[1]) == length(header)
    DataFrame(data, header)
end

"""
    reshape_wide(df::DataFrame; variable_col::Symbol=:variable, value_col::Symbol=:value)

Reshape a DataFrame from long to wide format.

# Arguments
- `df::DataFrame`: Input DataFrame
- `variable_col::Symbol`: Column name containing variable names
- `value_col::Symbol`: Column name containing values

# Examples
```julia
df_long = DataFrame(id=[1,1,2,2], variable=[:a,:b,:a,:b], value=[10,30,20,40])
df_wide = reshape_wide(df_long)
```
"""
function reshape_wide(df::DataFrame, variable_col::Symbol=:variable, value_col::Symbol=:value)
    if !all(col -> col ∈ propertynames(df), [variable_col, value_col])
        throw(ArgumentError("DataFrame must contain '$variable_col' and '$value_col' columns for wide format"))
    end
    return unstack(df, variable_col, value_col)
end

"""
    reshape_wide(df::DataFrame, id_cols::Union{Vector{Symbol},Symbol}, variable_col::Symbol, value_col::Symbol)

Reshape a DataFrame from long to wide format.

# Arguments
- `df::DataFrame`: DataFrame in long format to be reshaped
- `id_cols::Union{Vector{Symbol},Symbol}`: Column(s) to use as identifiers
- `variable_col::Symbol`: Column containing variable names that will become new columns
- `value_col::Symbol`: Column containing values that will fill the new columns

# Returns
- `DataFrame`: Reshaped DataFrame in wide format

# Throws
- `ArgumentError`: If required columns are not present in the DataFrame

# Examples
```julia
df_wide = reshape_wide(df, :year, :variable, :value)
```
"""
function reshape_wide(df::DataFrame, id_cols::Union{Vector{Symbol},Symbol}, variable_col::Symbol, value_col::Symbol)
    if !all(col -> col ∈ propertynames(df), [variable_col, value_col])
        throw(ArgumentError("DataFrame must contain '$variable_col' and '$value_col' columns for wide format"))
    end
    return unstack(df, id_cols, variable_col, value_col)
end

"""
    reshape_long(df::DataFrame; id_cols::Vector{Symbol}=Symbol[], view::Bool=true)

Reshape a DataFrame from wide to long format.

# Arguments
- `df::DataFrame`: Input DataFrame
- `id_cols::Vector{Symbol}`: Columns to use as identifiers when stacking
- `view::Bool`: Whether to return a view of the DataFrame instead of a copy

# Examples
```julia
df_wide = DataFrame(id=[1,2], a=[10,20], b=[30,40])
df_long = reshape_long(df_wide, :time, :component_id, :value)
```
"""
function reshape_long(df::DataFrame; id_cols::Vector{Symbol}=Symbol[], view::Bool=true)
    if isempty(id_cols)
        return stack(df, view=view)
    else
        return stack(df, Not(id_cols), view=view)
    end
end

# Function to collect the results from a system and write them to a CSV file
"""
    write_results(file_path::AbstractString, system::System, model::Model, settings::NamedTuple, period_index::Int64=1)

Collects all the results as a `DataFrame` and then writes them to disk after the optimization is performed. 

# Arguments
- `file_path::AbstractString`: full path of the file to export. 
- `system::System`: The system object containing the case inputs.
- `model::Model`: The model being optimized.
- `period_index::Int64`: The index of the period to collect results for (default is 1).
- `settings::NamedTuple`: The settings for the system, including output configurations.

# Returns

# Example
```julia
write_results(case_path * "results.csv", system, model) # CSV
write_results(case_path * "results.csv.gz", system, model)  # GZIP
write_results(case_path * "results.parquet", system, model) # PARQUET
```
"""
function write_results(file_path::AbstractString, system::System, model::Model, settings::NamedTuple, period_index::Int64=1)
    @info "Writing results to $file_path"

    # Prepare output data
    output = collect_results(system, model,settings, period_index)
    output.case_name .= coalesce.(output.case_name, basename(system.data_dirpath))
    output.year .= coalesce.(output.year, year(now()))

    # Write the DataFrame
    write_dataframe(file_path, output)
end

"""
    write_dataframe(
        file_path::AbstractString, 
        df::AbstractDataFrame, 
        drop_cols::Vector{<:AbstractString}=String[]
    )

Write a DataFrame to a file in the appropriate format based on file extension.
Supported formats: .csv, .csv.gz, .parquet

# Arguments
- `file_path::AbstractString`: Path where to save the file
- `df::AbstractDataFrame`: DataFrame to write
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame
"""
function write_dataframe(
    file_path::AbstractString,
    df::AbstractDataFrame,
    drop_cols::Vector{<:AbstractString}=String[]
)
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

    # Drop the columns specified by the user
    select!(df, Not(Symbol.(drop_cols)))

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

"""
    create_output_path(system::System, path::String=system.data_dirpath)

Create and return the path to the output directory for storing results based on system settings.

# Arguments
- `system::System`: The system object containing settings and configuration
- `path::String`: Base path for the output directory (defaults to system.data_dirpath)

# Returns
- `String`: Path to the created output directory

The function creates an output directory based on system settings. If `OverwriteResults` 
is false, it will avoid overwriting existing directories by appending incremental numbers 
(e.g., "_001", "_002") to the directory name. The directory is created if it doesn't exist.

# Example
```julia
julia> system.settings
(..., OverwriteResults = true, OutputDir = "result_dir")
julia> output_path = create_output_path(system)
# Returns "path/to/system.data_dirpath/result_dir" or "path/to/system.data_dirpath/result_dir_001" if original exists
julia> output_path = create_output_path(system, "path/to/output")
# Returns "path/to/output/result_dir" or "path/to/output/result_dir_001" if original exists
```
"""
function create_output_path(system::System, path::String=system.data_dirpath)
    if system.settings.OverwriteResults
        path = joinpath(path, system.settings.OutputDir)
    else
        # Find closest unused ouput directory name and create it
        path = find_available_path(path, system.settings.OutputDir)
    end
    @debug "Writing results to $path"
    mkpath(path)
    return path
end

"""
    find_available_path(path::String, basename::String="results"; max_attempts::Int=999)

Choose an available output directory with the name "basename_<number>" by appending incremental numbers to the base path.

# Arguments
- `path::String`: Base path for the output directory.
- `basename::String`: Base name of the output directory.
- `max_attempts::Int`: Maximum number of attempts to find an available directory (default is 999).

# Returns
- `String`: Full path to the chosen output directory.

The function first expands the given path to its full path and then attempts to find an available directory
by appending incremental numbers (e.g., "basename_001", "basename_002") up to `max_attempts` times.
If an available directory is found, it returns the full path to that directory. If no available
directory is found after `max_attempts` attempts, it raises an error.

# Example
```julia
julia> path = "path/to/output"
julia> output_path = find_available_path(path)
# Returns "path/to/output/results_001" or "path/to/output/results_002" etc.
```
"""
function find_available_path(path::String, basename::String="results"; max_attempts::Int=999)
    path = abspath(path) # expand path to the full path

    for i in 1:max_attempts
        dir_name = "$(basename)_$(lpad(i, 3, '0'))"
        full_path = joinpath(path, dir_name)

        if !isdir(full_path)
            return full_path
        end
    end

    error("Could not find available directory after $max_attempts attempts")
end

"""
    get_output_layout(system::System, variable::Union{Nothing,Symbol}=nothing)::String

Get the output layout ("wide" or "long") for a specific variable from system settings.

# Arguments
- `system::System`: System containing output layout settings
- `variable::Union{Nothing,Symbol}=nothing`: Variable to get layout for (e.g., :Cost, :Flow)

# Returns
String indicating layout format: "wide" or "long"

# Settings Format
The `OutputLayout` setting can be specified in three ways:

1. Global string setting:
   ```julia
   settings = (OutputLayout="wide",)  # Same layout for all variables
   ```

2. Per-variable settings using NamedTuple:
   ```julia
   settings = (OutputLayout=(Cost="wide", Flow="long"),)
   ```

3. Default behavior:
   - Returns "long" if setting is missing or invalid
   - Logs warning for unsupported types or missing variables

# Examples
```julia
# Global layout
system = System(settings=(OutputLayout="wide",))
get_output_layout(system, :Cost)  # Returns "wide"

# Per-variable layout
system = System(settings=(OutputLayout=(Cost="wide", Flow="long"),))
get_output_layout(system, :Cost)  # Returns "wide"
get_output_layout(system, :Flow)  # Returns "long"
get_output_layout(system, :Other) # Returns "long" with warning
```
"""
function get_output_layout(system::System, variable::Union{Nothing,Symbol}=nothing)::String
    output_layout = system.settings.OutputLayout

    # String layouts supported are "wide" and "long"
    if isa(output_layout, String)
        @debug "Using output layout $output_layout"
        return output_layout
    end

    if isnothing(variable)
        @warn "OutputLayout in settings does not have a variable key. Using 'long' as default."
        return "long"
    end

    # Handle NamedTuple case (per-file settings)
    if isa(output_layout, NamedTuple)
        if !haskey(output_layout, variable)
            @warn "OutputLayout in settings does not have a $variable key. Using 'long' as default."
        end
        layout = get(output_layout, variable, "long")
        @debug "Using output layout $layout for variable $variable"
        return layout
    end

    # Handle unknown types
    @warn "OutputLayout type $(typeof(output_layout)) not supported. Using 'long' as default."
    return "long"
end

"""
    filter_edges_by_commodity!(edges::Vector{AbstractEdge}, commodity::Union{Symbol,Vector{Symbol}}, edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}())

Filter the edges by commodity and update the edge_asset_map to match the filtered edges (optional).

# Arguments
- `edges::Vector{AbstractEdge}`: The edges to filter
- `commodity::Union{Symbol,Vector{Symbol}}`: The commodity to filter by
- `edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}`: The edge_asset_map to update (optional)

# Effects
- Modifies `edges` in-place to keep only edges matching the commodity type
- If `edge_asset_map` is provided, filters it to match remaining edges

# Example
```julia
filter_edges_by_commodity!(edges, :Electricity)
filter_edges_by_commodity!(edges, [:Electricity, :NaturalGas], edge_asset_map)
```

"""
function filter_edges_by_commodity!(
    edges::Vector{AbstractEdge},
    commodity::Union{Symbol,Vector{Symbol}},
    edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    @debug "Filtering edges by commodity $commodity"

    # convert commodity to vector if it is a symbol
    commodity = isa(commodity, Symbol) ? [commodity] : commodity

    # convert commodity from a Vector{Symbol} to a Vector{DataType}
    macro_commodities = commodity_types()
    if !all(c -> c ∈ keys(macro_commodities), commodity)
        throw(ArgumentError("Commodity $commodity not found in the system.\n" *
                            "Available commodities are $macro_commodities"))
    end
    commodities = Set(macro_commodities[c] for c in commodity)

    # filter edges by commodity
    filter!(e -> commodity_type(e) in commodities, edges)

    # filter edge_asset_map to match the filtered edges
    if !isempty(edge_asset_map)
        edge_ids = Set(id.(edges)) # caching for performance
        filter!(pair -> pair[1] in edge_ids, edge_asset_map)
    end

    return nothing
end

"""
    filter_edges_by_asset_type!(edges::Vector{AbstractEdge}, asset_type::Union{Symbol,Vector{Symbol}}, edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}})

Filter edges and their associated assets by asset type.

# Arguments
- `edges::Vector{AbstractEdge}`: Edges to filter
- `asset_type::Union{Symbol,Vector{Symbol}}`: Target asset type(s)
- `edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}`: Mapping of edges to assets

# Effects
- Modifies `edges` in-place to keep only edges matching the asset type
- Modifies `edge_asset_map` to keep only matching assets

# Throws
- `ArgumentError`: If none of the requested asset types are found in the system

# Example
```julia
filter_edges_by_asset_type!(edges, :Battery, edge_asset_map)
```
"""
function filter_edges_by_asset_type!(
    edges::Vector{AbstractEdge},
    asset_type::Union{Symbol,Vector{Symbol}},
    edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}
)
    @debug "Filtering edges by asset type $asset_type"

    # convert asset_type to vector if it is a symbol
    asset_type = isa(asset_type, Symbol) ? [asset_type] : asset_type

    # check if the asset_type is available in the system
    available_types = unique(get_type(asset) for asset in values(edge_asset_map))
    if !any(t -> t ∈ available_types, asset_type)
        throw(ArgumentError(
            "Asset type(s) $asset_type not found in the system.\n" *
            "Available types are $available_types"
        ))
    end

    # filter asset map by type (done first as it's used for edge filtering)
    filter!(pair -> get_type(pair[2]) in asset_type, edge_asset_map)

    # filter edges according to new edge_asset_map
    filter!(e -> id(e) in keys(edge_asset_map), edges)

    return nothing
end

function has_wildcard(s::AbstractString)
    return endswith(s, "*")
end

function has_wildcard(s::Symbol)
    return endswith(string(s), "*")
end

"""
    search_commodities(commodities, available_commodities)

Search for commodity types in a list of available commodities, supporting wildcards and subtypes.

# Arguments
- `commodities::Union{AbstractString,Vector{<:AbstractString}}`: Commodity type(s) to search for
- `available_commodities::Vector{<:AbstractString}`: Available commodity types to search from

# Returns
Tuple of two vectors:
1. `Vector{Symbol}`: Found commodity types
2. `Vector{Symbol}`: Missing commodity types (only if no matches found)

# Pattern Matching
Supports two types of matches:
1. Exact match: `"Electricity"` matches only `"Electricity"`
2. Wildcard match: `"CO2*"` matches both `CO2` and its subtypes (e.g., `CO2Captured`)

# Examples
```julia
# Available commodities
commodities = ["Electricity", "CO2", "CO2Captured"]

# Exact match
found, missing = search_commodities("Electricity", commodities)
# found = [:Electricity], missing = []

# Wildcard match
found, missing = search_commodities("CO2*", commodities)
# found = [:CO2, :CO2Captured], missing = []

# Multiple types
found, missing = search_commodities(["Electricity", "Heat"], commodities)
# found = [:Electricity], missing = [:Heat]
```

!!! note 
    Wildcard searches check against registered commodity types in MacroEnergy.jl.
"""
function search_commodities(
    commodities::Union{AbstractString,Vector{<:AbstractString}},
    available_commodities::Vector{<:AbstractString}
)
    commodities = isa(commodities, AbstractString) ? [commodities] : commodities
    macro_commodity_types = commodity_types()
    final_commodities = Set{Symbol}()
    missed_commodites = Set{Symbol}()
    for c in commodities
        wildcard_search = has_wildcard(c)
        if wildcard_search
            c = c[1:end-1]
            c_sym = Symbol(c)
            if !haskey(macro_commodity_types, c_sym)
                continue
            end
            c_datatype = macro_commodity_types[c_sym]
            # Find all commodities which start with the part before the wildcard
            union!(final_commodities, typesymbol.(Set{DataType}([c_datatype, subtypes(c_datatype)...])))
        end
        # Add the commodity itself, if it's in the dataframe
        if c in available_commodities
            push!(final_commodities, Symbol(c))
        elseif !wildcard_search
            push!(missed_commodites, Symbol(c))
        end
    end
    # Final check to make sure the commodities are in the system
    final_commodities = intersect(final_commodities, Set(Symbol.(available_commodities)))
    return collect(final_commodities), collect(missed_commodites)
end

"""
    search_assets(asset_type, available_types)

Search for asset types in a list of available assets, supporting wildcards and parametric types.

# Arguments
- `asset_type::Union{AbstractString,Vector{<:AbstractString}}`: Type(s) to search for
- `available_types::Vector{<:AbstractString}`: Available asset types to search from

# Returns
Tuple of two vectors:
1. `Vector{Symbol}`: Found asset types
2. `Vector{Symbol}`: Missing asset types (only if no matches found)

# Pattern Matching
Supports three types of matches:
1. Exact match: `"Battery"` matches `"Battery"`
2. Parametric match: `"ThermalPower"` matches `"ThermalPower{Fuel}"`
3. Wildcard match: `"ThermalPower*"` matches both `"ThermalPower{Fuel}"` and `"ThermalPowerCCS{Fuel}"`

# Examples
```julia
# Available assets
assets = ["Battery", "ThermalPower{Coal}", "ThermalPower{Gas}"]

# Exact match
found, missing = search_assets("Battery", assets)
# found = [:Battery], missing = []

# Parametric match
found, missing = search_assets("ThermalPower", assets)
# found = [:ThermalPower{Coal}, :ThermalPower{Gas}], missing = []

# Wildcard match
found, missing = search_assets("ThermalPower*", assets)
# found = [:ThermalPower{Coal}, :ThermalPower{Gas}], missing = []

# Multiple types
found, missing = search_assets(["Battery", "Solar"], assets)
# found = [:Battery], missing = [:Solar]
```
"""
function search_assets(
    asset_type::Union{AbstractString,Vector{<:AbstractString}},
    available_types::Vector{<:AbstractString}
)
    asset_type = isa(asset_type, AbstractString) ? [asset_type] : asset_type
    final_asset_types = Set{Symbol}()
    missed_asset_types = Set{Symbol}()
    
    for a in asset_type
        found_any = false
        wildcard_search = has_wildcard(a)
        
        if wildcard_search
            a = a[1:end-1]
            # Find all asset types which start with the part before the wildcard
            matches = Symbol.(available_types[startswith.(available_types, Ref(a))])
            # Add the asset types, accounting for parametric commodities
            union!(final_asset_types, matches)
            found_any = !isempty(matches)
        end
        
        # Add the parametric types
        parametric_matches = Symbol.(available_types[startswith.(available_types, Ref(a * "{"))])
        union!(final_asset_types, parametric_matches)
        found_any = found_any || !isempty(parametric_matches)
        
        # Add the asset types itself, if they're in the dataframe
        if a in available_types
            push!(final_asset_types, Symbol(a))
            found_any = true
        end
        
        # Only add to missed if we found no matches at all
        if !found_any && !wildcard_search
            push!(missed_asset_types, Symbol(a))
        end
    end
    
    return collect(final_asset_types), collect(missed_asset_types)
end

function find_available_filepath(path::AbstractString, filename::AbstractString; max_attempts::Int=999)
    path = abspath(path) # expand path to the full path

    # Split filename on the last "."
    basename, ext = splitext(filename) 
    
    for i in 1:max_attempts
        full_path = joinpath(path, filename)
        if !isfile(full_path)
            return full_path
        end
        filename = "$(basename)_$(lpad(i, 3, '0'))$(ext)"
    end
    return filename
    error("Could not find available file after $max_attempts attempts")
end

function find_available_filepath(filepath::AbstractString; max_attempts::Int=999)
    path = dirname(filepath)
    filename = basename(filepath)
    return find_available_filepath(path, filename; max_attempts=max_attempts)
end

function write_outputs(results_dir::AbstractString, system::System, model::Model)
    
    # Capacity results
    write_capacity(joinpath(results_dir, "capacity.csv"), system)
    
    # Cost results
    write_costs(joinpath(results_dir, "costs.csv"), system, model)
    write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), system, model)

    # Flow results
    write_flow(joinpath(results_dir, "flows.csv"), system)

    return nothing
end

"""
Write results when using Monolithic as solution algorithm.
"""
function write_outputs(case_path::AbstractString, case::Case, model::Model)
    num_periods = number_of_periods(case)
    periods = get_periods(case)
    for (period_idx,period) in enumerate(periods)
        @info("Writing results for period $period_idx")
        
        create_discounted_cost_expressions!(model, period, get_settings(case))

        compute_undiscounted_costs!(model, period, get_settings(case))

        ## Create results directory to store the results
        if num_periods > 1
            # Create a directory for each period
            results_dir = joinpath(case_path, "results_period_$period_idx")
        else
            # Create a directory for the single period
            results_dir = joinpath(case_path, "results")
        end
        mkpath(results_dir)
        write_outputs(results_dir, period, model)
    end

    return nothing
end

"""
Write results when using Myopic as solution algorithm. 
"""
function write_outputs(case_path::AbstractString, case::Case, myopic_results::MyopicResults)
    num_periods = number_of_periods(case);
    periods = get_periods(case)
    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")

        create_discounted_cost_expressions!(myopic_results.models[period_idx], period, get_settings(case))

        compute_undiscounted_costs!(myopic_results.models[period_idx], period, get_settings(case))
        ## Create results directory to store the results
        if num_periods > 1
            # Create a directory for each period
            results_dir = joinpath(case_path, "results_period_$period_idx")
        else
            # Create a directory for the single period
            results_dir = joinpath(case_path, "results")
        end
        mkpath(results_dir)
        write_outputs(results_dir, period, myopic_results.models[period_idx])
    end

    return nothing
end

"""
Write results when using Benders as solution algorithm.
"""
function write_outputs(case_path::AbstractString, case::Case, bd_results::BendersResults)

    settings = get_settings(case);
    num_periods = number_of_periods(case);
    periods = get_periods(case);

    period_to_subproblem_map, _ = get_period_to_subproblem_mapping(periods)

    # get the flow results from the operational subproblems
    flow_df = collect_flow_results(case, bd_results)

    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")
        ## Create results directory to store the results
        if num_periods > 1
            # Create a directory for each period
            results_dir = joinpath(case_path, "results_period_$period_idx")
        else
            # Create a directory for the single period
            results_dir = joinpath(case_path, "results")
        end
        mkpath(results_dir)

        # subproblem indices for the current period
        subop_indices_period = period_to_subproblem_map[period_idx]

        # Note: period has been updated with the capacity values in planning_solution at the end of function solve_case
        # Capacity results
        write_capacity(joinpath(results_dir, "capacity.csv"), period)

        # Flow results
        write_flows(results_dir, period, flow_df[subop_indices_period])
        
        # Cost results
        costs = prepare_costs_benders(period, bd_results, subop_indices_period, settings)
        write_costs(joinpath(results_dir, "costs.csv"), period, costs)
        write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), period, costs)
    end

    return nothing
end

function prepare_costs_benders(system::System, 
    bd_results::BendersResults, 
    subop_indices::Vector{Int64}, 
    settings::NamedTuple
    )
    planning_problem = bd_results.planning_problem
    subop_sol = bd_results.subop_sol
    planning_variable_values = bd_results.planning_sol.values

    create_discounted_cost_expressions!(planning_problem, system, settings)
    compute_undiscounted_costs!(planning_problem, system, settings)

    # Evaluate the fixed cost expressions in the planning problem. Note that this expression has been re-built
    # in compute_undiscounted_costs! to utilize undiscounted costs and the Benders planning solutions that are 
    # stored in system. So, no need to re-evaluate the expression on planning_variable_values.
    fixed_cost = value(planning_problem[:eFixedCost])
    # Evaluate the discounted fixed cost expression on the Benders planning solutions
    discounted_fixed_cost = value(x -> planning_variable_values[name(x)], planning_problem[:eDiscountedFixedCost])

    # evaluate the variable cost expressions using the subproblem solutions
    variable_cost = evaluate_vtheta_in_expression(planning_problem, :eVariableCost, subop_sol, subop_indices)
    discounted_variable_cost = evaluate_vtheta_in_expression(planning_problem, :eDiscountedVariableCost, subop_sol, subop_indices)

    return (
        eFixedCost = fixed_cost,
        eVariableCost = variable_cost,
        eDiscountedFixedCost = discounted_fixed_cost,
        eDiscountedVariableCost = discounted_variable_cost
    )
end
    
"""
Collect flow results from all subproblems, handling distributed case.
"""
function collect_flow_results(case::Case, bd_results::BendersResults)
    if case.settings.BendersSettings[:Distributed]
        return collect_distributed_flows(bd_results)
    else
        return collect_local_flows(bd_results)
    end
end

"""
Collect flow results from subproblems on distributed workers.
"""
function collect_distributed_flows(bd_results::BendersResults)
    p_id = workers()
    np_id = length(p_id)
    flow_df = Vector{Vector{DataFrame}}(undef, np_id)
    @sync for i in 1:np_id
        @async flow_df[i] = @fetchfrom p_id[i] get_local_expressions(get_optimal_flow, DistributedArrays.localpart(bd_results.op_subproblem))
    end
    return reduce(vcat, flow_df)
end

"""
Collect flow results from local subproblems.
"""
function collect_local_flows(bd_results::BendersResults)
    flow_df = Vector{DataFrame}(undef, length(bd_results.op_subproblem))
    for i in eachindex(bd_results.op_subproblem)
        system = bd_results.op_subproblem[i][:system_local]
        flow_df[i] = get_optimal_flow(system)
    end
    return flow_df
end


function write_flows(results_dir::AbstractString, system::System, flow_dfs::Vector{DataFrame})
    file_path = joinpath(results_dir, "flows.csv")
    @info("Writing flow results to $file_path")
    flow_results = reduce(vcat, flow_dfs)
    
    # Reshape if wide layout requested
    layout = get_output_layout(system, :Flow)
    if layout == "wide"
        flow_results = reshape_wide(flow_results, :time, :component_id, :value)
    end
    write_dataframe(file_path, flow_results)
end

function get_local_expressions(optimal_getter::Function, subproblems_local::Vector{Dict{Any,Any}})
    @assert isdefined(MacroEnergy, Symbol(optimal_getter))
    n_local_subprob = length(subproblems_local)
    expr_df = Vector{DataFrame}(undef, n_local_subprob)
    for s in eachindex(subproblems_local)
        expr_df[s] = optimal_getter(subproblems_local[s][:system_local])
    end
    return expr_df
end

function create_discounted_cost_expressions!(model::Model, system::System, settings::NamedTuple)
    
    period_index = system.time_data[:Electricity].period_index;
    discount_rate = settings.DiscountRate
    period_lengths = collect(settings.PeriodLengths)
    cum_years = sum(period_lengths[i] for i in 1:period_index-1; init=0)
    discount_factor = 1/( (1 + discount_rate)^cum_years)
    
    unregister(model,:eDiscountedFixedCost)

    if isa(solution_algorithm(settings[:SolutionAlgorithm]), Myopic)

        unregister(model,:eDiscountedInvestmentFixedCost)
        add_costs_not_seen_by_myopic!(system, settings)
        unregister(model,:eInvestmentFixedCost)
        model[:eInvestmentFixedCost] = AffExpr(0.0)
        compute_investment_costs!(system, model)
        
        model[:eDiscountedInvestmentFixedCost] = discount_factor * model[:eInvestmentFixedCost]
        
        model[:eDiscountedFixedCost] = model[:eDiscountedInvestmentFixedCost] + model[:eOMFixedCostByPeriod][period_index]

    elseif isa(solution_algorithm(settings[:SolutionAlgorithm]), Monolithic) || isa(solution_algorithm(settings[:SolutionAlgorithm]), Benders)
        # Perfect foresight  cases (applies to both Monolithic and Benders)
        model[:eDiscountedFixedCost] = model[:eFixedCostByPeriod][period_index]
    else
        nothing
    end

    unregister(model,:eDiscountedVariableCost)
    model[:eDiscountedVariableCost] = model[:eVariableCostByPeriod][period_index]
end

function compute_undiscounted_costs!(model::Model, system::System, settings::NamedTuple)
    
    period_lengths = collect(settings.PeriodLengths)
    discount_rate = settings.DiscountRate
    period_index = system.time_data[:Electricity].period_index;

    undo_discount_fixed_costs!(system, settings)
    unregister(model,:eFixedCost)
    model[:eFixedCost] = AffExpr(0.0)
    model[:eOMFixedCost] = AffExpr(0.0)
    model[:eInvestmentFixedCost] = AffExpr(0.0)
    compute_fixed_costs!(system, model)
    model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost] 

    cum_years = sum(period_lengths[i] for i in 1:period_index-1; init=0);
    discount_factor = 1/( (1 + discount_rate)^cum_years)
    opexmult = sum([1 / (1 + discount_rate)^(i) for i in 1:period_lengths[period_index]])

    model[:eVariableCost] = period_lengths[period_index]*model[:eVariableCostByPeriod][period_index]/(discount_factor * opexmult)

end

"""
    Helper function to extract discounted costs from the optimization results and return them as a DataFrame.
"""
function get_optimal_discounted_costs(model::Union{Model,NamedTuple}, period_index::Int64; scaling::Float64=1.0)
    @debug " -- Getting optimal discounted costs for the system."
    costs = prepare_discounted_costs(model, period_index, scaling)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function get_optimal_undiscounted_costs(model::Union{Model,NamedTuple}, period_index::Int64; scaling::Float64=1.0)
    @debug " -- Getting optimal discounted costs for the system."
    costs = prepare_undiscounted_costs(model, period_index, scaling)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

# This fuction will returns:
# - Variable cost
# - Fixed cost
# - Total cost
# Preparing undiscounted costs
function prepare_undiscounted_costs(model::Union{Model,NamedTuple}, period_index::Int64, scaling::Float64=1.0)
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

function prepare_discounted_costs(model::Union{Model,NamedTuple}, period_index::Int64, scaling::Float64=1.0)
    fixed_cost = value(model[:eDiscountedFixedCost])
    variable_cost = value(model[:eDiscountedVariableCost])
    total_cost = fixed_cost + variable_cost
    OutputRow[
        OutputRow(
            :all,
            :cost,
            :all,
            :all,
            :all,
            :Cost,
            :DiscountedFixedCost,
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
            :DiscountedVariableCost,
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
            :DiscountedTotalCost,
            missing,
            missing,
            missing,
            total_cost * scaling^2,
            # :USD,
        )
    ]
end


"""
Evaluate the expression `expr` for a specific period using operational subproblem solutions.

# Arguments
- `m::Model`: JuMP model containing vTHETA variables and the expression `expr` to evaluate
- `expr::Symbol`: The expression to evaluate
- `subop_sol::Dict`: Dictionary mapping subproblem indices to their operational costs
- `subop_indices::Vector{Int64}`: The subproblem indices to evaluate

# Returns
The evaluated expression for the specified period 
"""
function evaluate_vtheta_in_expression(m::Model, expr::Symbol, subop_sol::Dict, subop_indices::Vector{Int64})
    @assert haskey(m, expr)
    
    # Create mapping from theta variables to their operational costs for this period
    theta_to_cost = Dict(
        m[:vTHETA][w] => subop_sol[w].op_cost 
        for w in subop_indices
    )
    
    # Evaluate the expression `expr` using the mapping
    return value(x -> theta_to_cost[x], m[expr])
    
end
