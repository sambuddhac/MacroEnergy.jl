abstract type AbstractNode{T<:Commodity} end

Base.@kwdef mutable struct Node{T} <: AbstractNode{T}
    ### Fields without defaults
    id::Symbol
    demand::Vector{Float64}
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    #### Fields with defaults
    max_nsd::Vector{Float64} = [0.0]
    price_nsd::Vector{Float64} = [0.0]
    operation_vars::Dict = Dict()
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end

time_interval(n::AbstractNode) = n.time_interval;
subperiods(n::AbstractNode) = n.subperiods;

commodity_type(n::AbstractNode{T}) where {T} = T;

get_id(n::AbstractNode) = n.id;

demand(n::AbstractNode) = n.demand;

non_served_demand(n::AbstractNode) = n.operation_vars[:non_served_demand];

net_production(n::AbstractNode) = n.operation_expr[:net_production];

max_non_served_demand(n::AbstractNode) = n.max_nsd;

price_non_served_demand(n::AbstractNode) = n.price_nsd;

segments_non_served_demand(n::AbstractNode) = 1:length(n.max_nsd);

all_constraints(n::AbstractNode) = n.constraints;

function add_operation_variables!(n::AbstractNode, model::Model)

    n.operation_expr[:net_production] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])

    if !all(max_non_served_demand(n).==0)
        n.operation_vars[:non_served_demand] = @variable(
            model,
            [s in segments_non_served_demand(n) ,t in time_interval(n)],
            lower_bound = 0.0,
            base_name = "vNSD_$(get_id(n))"
        )

        for t in time_interval(n)
            for s in segments_non_served_demand(n)
                add_to_expression!(model[:eVariableCost], price_non_served_demand(n)[s], non_served_demand(n)[s,t])
                add_to_expression!(net_production(n)[t], non_served_demand(n)[s,t])
            end
        end
    end

    return nothing
end

function add_model_constraint!(ct::DemandBalanceConstraint, n::AbstractNode, model::Model)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(n)],
        net_production(n)[t]  == demand(n)[t]
    )

end

function add_model_constraint!(
    ct::MaxNonServedDemandConstraint,
    n::AbstractNode,
    model::Model,
)
    if haskey(n.operation_vars,:non_served_demand)
        ct.constraint_ref = @constraint(
            model,
            [s in segments_non_served_demand(n), t in time_interval(n)],
            non_served_demand(n)[s,t] <= max_non_served_demand(n)[s] * demand(n)[t]
        )
    else
        @warn "MaxNonServedDemandConstraint required for a node that does not have a non-served demand variable so MACRO will not create this constraint"
    end

end


function add_model_constraint!(ct::CO2Cap,
    n::AbstractNode,
    model::Model
)
    
    

end