

function compute_nominal_costs!(model::Model, system::System, settings::NamedTuple)
    
    undo_discount_fixed_costs!(system, settings)

    unregister(model,:eFixedCost)
    model[:eFixedCost] = AffExpr(0.0)
    compute_fixed_costs!(system, model)

    stage_lengths = collect(settings.StageLengths)
    wacc = settings.WACC
    stage_index = system.time_data[:Electricity].stage_index;

    cum_years = sum(stage_lengths[i] for i in 1:stage_index-1; init=0);
    discount_factor = 1/( (1 + wacc)^cum_years)
    opexmult = sum([1 / (1 + wacc)^(i - 1) for i in 1:stage_lengths[stage_index]])

    unregister(model,:eVariableCost)
    model[:eVariableCost] = model[:eDiscountedVariableCost][stage_index]/(discount_factor * opexmult);

end

function write_discounted_costs(
    file_path::AbstractString, 
    system::System, 
    model::Union{Model,NamedTuple};
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing discounted costs to $file_path"

    # Get costs and determine layout (wide or long)
    costs = get_optimal_discounted_costs(model; scaling)
    layout = get_output_layout(system, :Costs)

    if layout == "wide"
        default_drop_cols = ["commodity", "commodity_subtype", "zone", "resource_id", "component_id", "type"]
        # Only use default_drop_cols if user didn't specify any
        drop_cols = isempty(drop_cols) ? default_drop_cols : drop_cols
        costs = reshape_wide(costs)
    end

    write_dataframe(file_path, costs, drop_cols)
    return nothing
end

function get_optimal_discounted_costs(model::Union{Model,NamedTuple}; scaling::Float64=1.0)
    @debug " -- Getting optimal discounted costs for the system."
    costs = prepare_discounted_costs(model, scaling)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function prepare_discounted_costs(model::Union{Model,NamedTuple}, scaling::Float64=1.0)
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
Evaluate the expression `expr` for a specific stage using operational subproblem solutions.

# Arguments
- `m::Model`: JuMP model containing vTHETA variables and the expression `expr` to evaluate
- `expr::Symbol`: The expression to evaluate
- `subop_sol::Dict`: Dictionary mapping subproblem indices to their operational costs
- `subop_indices::Vector{Int64}`: The subproblem indices to evaluate
- `stage_index::Int64`: The stage to evaluate

# Returns
The evaluated expression for the specified stage 
"""
function evaluate_vtheta_in_expression(m::Model, expr::Symbol, subop_sol::Dict, subop_indices::Vector{Int64}, stage_index::Union{Int64,Nothing}=nothing)
    @assert haskey(m, expr)
    
    # Create mapping from theta variables to their operational costs for this stage
    theta_to_cost = Dict(
        m[:vTHETA][w] => subop_sol[w].op_cost 
        for w in subop_indices
    )
    
    # Evaluate the expression `expr` using the mapping
    if isnothing(stage_index)
        return value(x -> theta_to_cost[x], m[expr])
    else
        return value(x -> theta_to_cost[x], m[expr][stage_index])
    end
end

function validate_existing_capacity(asset::AbstractAsset)
    for t in fieldnames(typeof(asset))
        if isa(getfield(asset, t), AbstractEdge) || isa(getfield(asset, t), AbstractStorage)
            if existing_capacity(getfield(asset, t)) > 0
                msg = " -- Asset with id: \"$(id(asset))\" has existing capacity equal to $(existing_capacity(getfield(asset,t)))"
                msg *= "\nbut it was not present in the previous stage. Please double check that the input data is correct."
                @warn(msg)
            end
        end
    end
end