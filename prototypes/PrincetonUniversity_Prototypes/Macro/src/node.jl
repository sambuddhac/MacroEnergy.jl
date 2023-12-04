abstract type AbstractNode{T<:Commodity} end

Base.@kwdef mutable struct Node{T} <: AbstractNode{T}
    ### Fields without defaults
    id::Symbol
    demand::Vector{Float64}
    time_interval::StepRange{Int64,Int64}
    fuel_price::Vector{Float64}
    #### Fields with defaults
    max_nse::Float64 = 1.0
    price_nse::Float64 = 5000
    operation_vars::Dict = Dict()
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} =
        [EnergyBalanceConstraint{T}(), MaxNonServedEnergyConstraint{T}()]
end

time_interval(n::AbstractNode) = n.time_interval;

commodity_type(n::AbstractNode{T}) where {T} = T;

node_id(n::AbstractNode) = n.id;

demand(n::AbstractNode) = n.demand;

non_served_energy(n::AbstractNode) = n.operation_vars[:non_served_energy];

net_energy_production(n::AbstractNode) = n.operation_expr[:net_energy_production];

max_non_served_energy(n::AbstractNode) = n.max_nse;

all_constraints(g::AbstractNode) = g.constraints;


function add_operation_variables!(n::AbstractNode, model::Model)

    n.operation_vars[:non_served_energy] = @variable(
        model,
        [t in time_interval(n)],
        lower_bound = 0.0,
        base_name = "vNSE_$(commodity_type(n))_$(node_id(n))"
    )

    n.operation_expr[:net_energy_production] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])

    return nothing
end
