"""
    get_optimal_costs(model::Model)

Get the total, fixed, and variable costs for the system.

# Arguments
- `model::Model`: The optimal model after the optimization

# Returns
- `DataFrame`: A dataframe containing the total, fixed, and variable costs for the system, with missing columns removed

# Example
```julia
get_optimal_costs(model)
3×8 DataFrame
 Row │ commodity  commodity_subtype  zone    resource_id  component_id  type    variable      value   
     │ Symbol     Symbol             Symbol  Symbol       Symbol        Symbol  Symbol        Float64 
─────┼───────────────────────────────────────────────────────────────────────────────────────────────
   1 │ all        cost               all     all          all           Cost    FixedCost     22471.1
   2 │ all        cost               all     all          all           Cost    VariableCost  14316.2
   3 │ all        cost               all     all          all           Cost    TotalCost     36787.3
```
"""
function get_optimal_costs(model::Model, scaling::Float64=1.0)
    @info "Getting optimal costs for the system."
    costs = prepare_costs(model, scaling)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function get_optimal_costs(model::Model, system::System)
    @info "Getting optimal costs for the system."
    scaling = system.settings.Scaling ? ScalingFactor : 1.0
    costs = prepare_costs(model, scaling)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end
