abstract type AbstractNode{T<:Commodity} end

Base.@kwdef mutable struct Node{T} <: AbstractNode{T}
    ### Fields without defaults
    id::Symbol
    demand::Vector{Float64}
    time_interval::StepRange{Int64,Int64}
    ######### fuel_price::Vector{Float64}
    #### Fields with defaults
    max_nse::Vector{Float64} = [1.0]
    price_nse::Vector{Float64} = [5000]
    operation_vars::Dict = Dict()
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} =
        [EnergyBalanceConstraint{T}(), MaxNonServedEnergyConstraint{T}()]
end

time_interval(n::AbstractNode) = n.time_interval;

commodity_type(n::AbstractNode{T}) where {T} = T;

get_id(n::AbstractNode) = n.id;

demand(n::AbstractNode) = n.demand;

non_served_energy(n::AbstractNode) = n.operation_vars[:non_served_energy];

net_energy_production(n::AbstractNode) = n.operation_expr[:net_energy_production];

max_non_served_energy(n::AbstractNode) = n.max_nse;

price_non_served_energy(n::AbstractNode) = n.price_nse;

segments_non_served_energy(n::AbstractNode) = 1:length(n.max_nse);

all_constraints(g::AbstractNode) = g.constraints;


function add_operation_variables!(n::AbstractNode, model::Model)

    n.operation_vars[:non_served_energy] = @variable(
        model,
        [s in segments_non_served_energy(n) ,t in time_interval(n)],
        lower_bound = 0.0,
        base_name = "vNSE_$(commodity_type(n))_$(get_id(n))_$(s)_$(t)"
    )

    n.operation_expr[:net_energy_production] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])

    for t in time_interval(n)
        for s in segments_non_served_energy(n)
            add_to_expression!(model[:eVariableCost], price_non_served_energy(n)[s]*non_served_energy(n)[s,t])
            add_to_expression!(net_energy_production(n)[t], non_served_energy(n)[s,t])
        end
    end

    return nothing
end
