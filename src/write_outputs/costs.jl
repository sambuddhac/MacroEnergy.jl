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
3×9 DataFrame
 Row │ commodity  commodity_subtype  zone    resource_id  component_id  type    variable      value    unit   
     │ Symbol     Symbol             Symbol  Symbol       Symbol        Symbol  Symbol        Float64  Symbol 
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ all        cost               all     all          all           Cost    FixedCost     22471.1  USD
   2 │ all        cost               all     all          all           Cost    VariableCost  14316.2  USD
   3 │ all        cost               all     all          all           Cost    TotalCost     36787.3  USD
```
"""
function get_optimal_costs(model::Model)
    costs = prepare_costs(model)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end
