# Utility function to get the optimal capacity by macro object field
function get_optimal_capacity_by_field(system::System, capacity_func::Function, scaling::Float64=1.0)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the system."
    edges, edge_asset_idmap = edges_with_capacity_variables(system, return_ids_map=true)
    asset_capacity = get_optimal_vars(edges, capacity_func, scaling, edge_asset_idmap)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function get_optimal_capacity_by_field(asset::AbstractAsset, capacity_func::Function, scaling::Float64=1.0)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the asset $(id(asset))."
    edges, edge_asset_idmap = edges_with_capacity_variables(asset, return_ids_map=true)
    asset_capacity = get_optimal_vars(edges, capacity_func, scaling, edge_asset_idmap)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

# Wrapper functions
"""
    get_optimal_capacity(system::System; scaling::Float64=1.0)

Get the optimal capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.

# Returns
- `DataFrame`: A dataframe containing the optimal capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_capacity(system)
153×8 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable  value    
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol    Float64 
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Electricity  capacity           elec_SE        existing_solar_SE                  existing_solar_SE_edge             VRE               capacity   8.5022
   2 │ Electricity  capacity           elec_NE        existing_solar_NE                  existing_solar_NE_edge             VRE               capacity   0.0   
   3 │ Electricity  capacity           elec_NE        existing_wind_NE                   existing_wind_NE_edge              VRE               capacity   3.6545
```
"""
get_optimal_capacity(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, capacity, scaling)

"""
    get_optimal_new_capacity(system::System; scaling::Float64=1.0)

Get the optimal new capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.
# Returns
- `DataFrame`: A dataframe containing the optimal new capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_new_capacity(system)
153×8 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable      value  
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol        Float64
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Biomass      capacity           bioherb_SE     SE_BECCS_Electricity_Herb          SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  new_capacity      0.0
   2 │ Biomass      capacity           bioherb_MIDAT  MIDAT_BECCS_Electricity_Herb       MIDAT_BECCS_Electricity_Herb_bio…  BECCSElectricity  new_capacity      0.0
   3 │ Biomass      capacity           bioherb_NE     NE_BECCS_Electricity_Herb          NE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  new_capacity      0.0
```
"""
get_optimal_new_capacity(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, new_capacity, scaling)

"""
    get_optimal_retired_capacity(system::System; scaling::Float64=1.0)

Get the optimal retired capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.
# Returns
- `DataFrame`: A dataframe containing the optimal retired capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_retired_capacity(system)
153×8 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable      value    
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol        Float64  
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Biomass      capacity           bioherb_SE     SE_BECCS_Electricity_Herb          SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  retired_capacity  0.0
   2 │ Biomass      capacity           bioherb_MIDAT  MIDAT_BECCS_Electricity_Herb       MIDAT_BECCS_Electricity_Herb_bio…  BECCSElectricity  retired_capacity  0.0
   3 │ Biomass      capacity           bioherb_NE     NE_BECCS_Electricity_Herb          NE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  retired_capacity  0.0
```
"""
get_optimal_retired_capacity(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, retired_capacity, scaling)

get_optimal_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, capacity, scaling)
get_optimal_new_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, new_capacity, scaling)
get_optimal_retired_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, retired_capacity, scaling)

"""
    write_capacity(file_path::AbstractString, system::System; scaling::Float64=1.0, drop_cols::Vector{Symbol}=Symbol[], commodity::Union{Symbol,Vector{Symbol},Nothing}=nothing, asset_type::Union{Symbol,Vector{Symbol},Nothing}=nothing)

Write the optimal capacity results for all assets/edges in a system to a file. 
The extension of the file determines the format of the file.
`Capacity`, `NewCapacity`, and `RetiredCapacity` are first concatenated and then written to the file.

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the assets/edges to analyze as well as the settings for the output
- `scaling::Float64`: The scaling factor for the results
- `drop_cols::Vector{Symbol}`: Columns to drop from the DataFrame
- `commodity::Union{Symbol,Vector{Symbol},Nothing}`: The commodity to filter by
- `asset_type::Union{Symbol,Vector{Symbol},Nothing}`: The asset type to filter by

# Returns
- `nothing`: The function returns nothing, but writes the results to the file

# Example
```julia
write_capacity(joinpath(results_dir, "all_capacity.csv"), system)
write_capacity(joinpath(results_dir, "all_capacity.csv"), system, commodity=:Electricity)
write_capacity(joinpath(results_dir, "all_capacity.csv"), system, asset_type=:VRE)
write_capacity(joinpath(results_dir, "all_capacity.csv"), system, commodity=:Electricity, asset_type=[:VRE, :Battery])
```
"""
function write_capacity(
    file_path::AbstractString, 
    system::System; 
    scaling::Float64=1.0, 
    drop_cols::Vector{Symbol}=Symbol[],
    commodity::Union{Symbol,Vector{Symbol},Nothing}=nothing,
    asset_type::Union{Symbol,Vector{Symbol},Nothing}=nothing
)
    @info "Writing capacity results to $file_path"
    capacity_results = get_optimal_capacity(system; scaling)
    new_capacity_results = get_optimal_new_capacity(system; scaling)
    retired_capacity_results = get_optimal_retired_capacity(system; scaling)
    all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results)
    
    # Reshape the dataframe based on the requested format
    layout = get_output_layout(system, :Capacity)
    all_capacity_results = layout == "wide" ? reshape_wide(all_capacity_results) : all_capacity_results
    
    ## filter the dataframe based on the requested commodity and asset type
    # filter by commodity if specified
    if !isnothing(commodity)
        @debug "Filtering by commodity $commodity"
        commodity = isa(commodity, Symbol) ? [commodity] : commodity
        # check if the commodity is in the dataframe
        if !all(c -> c in all_capacity_results.commodity, commodity)
            commodities_in_df = collect(Set(all_capacity_results.commodity))
            throw(ArgumentError("Some commodities in $commodity not found in the dataframe.\nCommodities present in the dataframe are $commodities_in_df"))
        end
        filter!(:commodity => in(commodity), all_capacity_results)
    end
    
    # filter by asset type if specified
    if !isnothing(asset_type)
        @debug "Filtering by asset type $asset_type"
        asset_type = isa(asset_type, Symbol) ? [asset_type] : asset_type
        # check if the asset type is in the dataframe
        if !all(t -> t in all_capacity_results.type, asset_type)
            asset_types_in_df = collect(Set(all_capacity_results.type))
            throw(ArgumentError("Some asset types in $asset_type not found in the dataframe.\nAsset types present in the dataframe are $asset_types_in_df"))
        end
        filter!(:type => in(asset_type), all_capacity_results)
    end

    write_dataframe(file_path, all_capacity_results, drop_cols)
    return nothing
end


