# Utility function to get the optimal capacity by macro object field
function get_optimal_capacity_by_field(system::System, capacity_func::Function)
    edges, edge_asset_idmap = edges_with_capacity_variables(system, return_ids_map=true)
    asset_capacity = get_optimal_vars(edges, capacity_func, edge_asset_idmap)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function get_optimal_capacity_by_field(asset::AbstractAsset, capacity_func::Function)
    edges, edge_asset_idmap = edges_with_capacity_variables(asset, return_ids_map=true)
    asset_capacity = get_optimal_vars(edges, capacity_func, edge_asset_idmap)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

# Wrapper functions
"""
    get_optimal_capacity(system::System)

Get the optimal capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze

# Returns
- `DataFrame`: A dataframe containing the optimal capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_capacity(system)
153×9 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable  value    unit   
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol    Float64  Symbol 
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Electricity  capacity           elec_SE        existing_solar_SE                  existing_solar_SE_edge             VRE               capacity   8.5022  MW
   2 │ Electricity  capacity           elec_NE        existing_solar_NE                  existing_solar_NE_edge             VRE               capacity   0.0     MW
   3 │ Electricity  capacity           elec_NE        existing_wind_NE                   existing_wind_NE_edge              VRE               capacity   3.6545  MW
```
"""
get_optimal_capacity(system::System) = get_optimal_capacity_by_field(system, capacity)

"""
    get_optimal_new_capacity(system::System)

Get the optimal new capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze

# Returns
- `DataFrame`: A dataframe containing the optimal new capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_new_capacity(system)
153×9 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable      value    unit   
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol        Float64  Symbol 
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Biomass      capacity           bioherb_SE     SE_BECCS_Electricity_Herb          SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  new_capacity      0.0  t
   2 │ Biomass      capacity           bioherb_MIDAT  MIDAT_BECCS_Electricity_Herb       MIDAT_BECCS_Electricity_Herb_bio…  BECCSElectricity  new_capacity      0.0  t
   3 │ Biomass      capacity           bioherb_NE     NE_BECCS_Electricity_Herb          NE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  new_capacity      0.0  t
```
"""
get_optimal_new_capacity(system::System) = get_optimal_capacity_by_field(system, new_capacity)

"""
    get_optimal_ret_capacity(system::System)

Get the optimal retired capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze

# Returns
- `DataFrame`: A dataframe containing the optimal retired capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_ret_capacity(system)
```
"""
get_optimal_ret_capacity(system::System) = get_optimal_capacity_by_field(system, ret_capacity)

get_optimal_capacity(asset::AbstractAsset) = get_optimal_capacity_by_field(asset, capacity)
get_optimal_new_capacity(asset::AbstractAsset) = get_optimal_capacity_by_field(asset, new_capacity)
get_optimal_ret_capacity(asset::AbstractAsset) = get_optimal_capacity_by_field(asset, ret_capacity)




