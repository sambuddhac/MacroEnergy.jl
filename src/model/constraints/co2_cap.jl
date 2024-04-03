Base.@kwdef mutable struct CO2CapConstraint <:OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::CO2CapConstraint,
    n::Node{CO2},
    model::Model
)
    ct_type = typeof(ct);

    total_net_balance = @expression(model,0*model[:vREF]);
    for t in time_interval(n)
        w = current_subperiod(n,t);
        add_to_expression!(total_net_balance,subperiod_weight(n,w),net_balance(n,t));
    end

    if haskey(price_unmet_policy(n),ct_type)
        n.operation_vars[Symbol(string(ct_type)*"_Slack")] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "v"*string(ct_type)*"_Slack_$(get_id(n))"
        )
        add_to_expression!(model[:eVariableCost], price_unmet_policy(n,ct_type),n.operation_vars[Symbol(string(ct_type)*"_Slack")])
        add_to_expression!.(total_net_balance, -n.operation_vars[Symbol(string(ct_type)*"_Slack")])
    end

    ct.constraint_ref = @constraint(model, [i in [1]], total_net_balance <= rhs_policy(n,ct_type))


end