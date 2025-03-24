# Utility function to get the optimal capacity by macro object field
"""
    get_optimal_flow(
        system::System; 
        scaling::Float64=1.0, 
        commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing, 
        asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
    )

Get the optimal flow values for all edges in a system.

## Filtering
Results can be filtered by:
- `commodity`: Specific commodity type(s)
- `asset_type`: Specific asset type(s)

## Pattern Matching
Two types of pattern matching are supported:

1. Parameter-free matching:
   - `"ThermalPower"` matches any `ThermalPower{...}` type (i.e. no need to specify parameters inside `{}`)

2. Wildcards using "*":
   - `"ThermalPower*"` matches `ThermalPower{Fuel}`, `ThermalPowerCCS{Fuel}`, etc.
   - `"CO2*"` matches `CO2`, `CO2Captured`, etc.

# Arguments
- `system::System`: The system containing the all edges to output   
- `scaling::Float64`: The scaling factor for the results.
- `commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The commodity to filter by
- `asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The asset type to filter by

# Returns
- `DataFrame`: A dataframe containing the optimal flow values for all edges, with missing columns removed

# Example
```julia
get_optimal_flow(system)
186984×11 DataFrame
    Row │ commodity    commodity_subtype  zone        resource_id                component_id                       type              variable  segment  time   value     
        │ Symbol       Symbol             Symbol      Symbol                     Symbol                             Symbol            Symbol    Int64    Int64  Float64
────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      1 │ Biomass      flow               bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  flow            1      1  0.0    
      2 │ Biomass      flow               bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  flow            1      2  0.0    
      3 │ Biomass      flow               bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  flow            1      3  0.0    
      ...
# Filter by commodity
get_optimal_flow(system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
get_optimal_flow(system, commodity="Electricity", asset_type="ThermalPower") # only ThermalPower{Fuel} will be returned
# Filter by commodity and asset type using wildcard matching
get_optimal_flow(system, commodity="Electricity", asset_type="ThermalPower*") # all types starting with ThermalPower (e.g., ThermalPower{Fuel}, ThermalPowerCCS{Fuel}) will be returned)
```
"""
function get_optimal_flow(
    system::System; 
    scaling::Float64=1.0, 
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @debug " -- Getting optimal flow values for the system"
    edges, edge_asset_map = get_edges(system, return_ids_map=true)

    # filter edges by commodity
    if !isnothing(commodity)
        (commodity, missed_commodites) = search_commodities(commodity, string.(collect(Set(MacroEnergy.commodity_type.(edges)))))
        if !isempty(missed_commodites)
            @warn "Commodities not found: $(missed_commodites) when printing flow results"
        end
        filter_edges_by_commodity!(edges, commodity, edge_asset_map)
    end
    # filter edges by asset type
    if !isnothing(asset_type)
        (asset_type, missed_asset_type) = search_assets(asset_type, string.(unique(get_type(asset) for asset in values(edge_asset_map))))
        if !isempty(missed_asset_type)
            @warn "Asset type(s) not found: $(missed_asset_type) when printing flow results"
        end
        @debug("Writing flow results for asset type $asset_type")
        filter_edges_by_asset_type!(edges, asset_type, edge_asset_map)
    end
    if isempty(edges)
        @warn "No edges found after filtering"
        return DataFrame()
    end
    eflow = get_optimal_vars_timeseries(edges, flow, scaling, edge_asset_map)
    df = convert_to_dataframe(eflow)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

"""
    get_optimal_flow(asset::AbstractAsset, scaling::Float64=1.0)

Get the optimal flow values for all edges in an asset.

# Arguments
- `asset::AbstractAsset`: The asset containing the edges to analyze
- `scaling::Float64`: The scaling factor for the results.

# Returns
- `DataFrame`: A dataframe containing the optimal flow values for all edges, with missing columns removed

# Example
```julia
asset = get_asset_by_id(system, :elec_SE)
get_optimal_flow(asset)
```
"""
function get_optimal_flow(asset::AbstractAsset; scaling::Float64=1.0)
    @debug " -- Getting optimal flow values for the asset $(id(asset))"
    edges, edge_asset_map = get_edges(asset, return_ids_map=true)
    eflow = get_optimal_vars_timeseries(edges, flow, scaling, edge_asset_map)
    df = convert_to_dataframe(eflow)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

"""
    get_optimal_flow(edge::AbstractEdge, scaling::Float64=1.0)

Get the optimal flow values for an edge.

# Arguments
- `edge::AbstractEdge`: The edge to analyze
- `scaling::Float64`: The scaling factor for the results.

# Returns
- `DataFrame`: A dataframe containing the optimal flow values for the edge, with missing columns removed

# Example
```julia
asset = get_asset_by_id(system, :elec_SE)
elec_edge = asset.elec_edge
get_optimal_flow(elec_edge)
```
"""
function get_optimal_flow(edge::AbstractEdge; scaling::Float64=1.0)
    @debug " -- Getting optimal flow values for the edge $(id(edge))"
    eflow = get_optimal_vars_timeseries(edge, flow, scaling)
    df = convert_to_dataframe(eflow)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

"""
    write_flow(
        file_path::AbstractString, 
        system::System; 
        scaling::Float64=1.0, 
        drop_cols::Vector{<:AbstractString}=String[],
        commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
        asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
    )

Write the optimal flow results for the system to a file.
The extension of the file determines the format of the file.

## Filtering
Results can be filtered by:
- `commodity`: Specific commodity type(s)
- `asset_type`: Specific asset type(s)

## Pattern Matching
Two types of pattern matching are supported:

1. Parameter-free matching:
   - `"ThermalPower"` matches any `ThermalPower{...}` type (i.e. no need to specify parameters inside `{}`)

2. Wildcards using "*":
   - `"ThermalPower*"` matches `ThermalPower{Fuel}`, `ThermalPowerCCS{Fuel}`, etc.
   - `"CO2*"` matches `CO2`, `CO2Captured`, etc.

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the edges to analyze as well as the settings for the output
- `scaling::Float64`: The scaling factor for the results
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame
- `commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The commodity to filter by
- `asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The asset type to filter by

# Returns
- `nothing`: The function returns nothing, but writes the results to the file

# Example
```julia
write_flow("flow.csv", system)
# Filter by commodity
write_flow("flow.csv", system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower")
# Filter by commodity and asset type using wildcard matching
write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower*")
```
"""
function write_flow(
    file_path::AbstractString, 
    system::System; 
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[],
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @info "Writing flow results to $file_path"

    # Get flow results and determine layout (wide or long)
    flow_results = get_optimal_flow(system; scaling, commodity, asset_type)
    layout = get_output_layout(system, :Flow)

    if layout == "wide"
        # df will be of size (time_steps, component_ids)
        flow_results = reshape_wide(flow_results, :time, :component_id, :value)
    end
    write_dataframe(file_path, flow_results, drop_cols)
    return nothing
end
