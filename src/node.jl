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

Base.@kwdef mutable struct SourceNode{T} <: AbstractNode{T}
    id::Symbol
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    price::Vector{Float64} = Float64[]
    operation_vars::Dict = Dict()
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end

Base.@kwdef mutable struct SinkNode{T} <: AbstractNode{T}
    id::Symbol
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    price::Vector{Float64} = Float64[]
    operation_vars::Dict = Dict()
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} =Vector{AbstractTypeConstraint}()
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

inflow(n::SourceNode) = n.operation_vars[:inflow];

outflow(n::SinkNode) = n.operation_vars[:outflow];

price(n::Union{SinkNode,SourceNode}) = n.price;

demand(n::Union{SinkNode,SourceNode}) = zeros(length(n.time_interval));

function add_operation_variables!(n::AbstractNode, model::Model)

    n.operation_vars[:non_served_demand] = @variable(
        model,
        [s in segments_non_served_demand(n) ,t in time_interval(n)],
        lower_bound = 0.0,
        base_name = "vNSD_$(commodity_type(n))_$(get_id(n))"
    )

    n.operation_expr[:net_production] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])

    for t in time_interval(n)
        for s in segments_non_served_demand(n)
            add_to_expression!(model[:eVariableCost], price_non_served_demand(n)[s], non_served_demand(n)[s,t])
            add_to_expression!(net_production(n)[t], non_served_demand(n)[s,t])
        end
    end

    return nothing
end

function add_operation_variables!(n::SourceNode, model::Model)

    n.operation_expr[:net_production] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])


    n.operation_vars[:inflow] = @variable(
        model,
        [t in time_interval(n)],
        lower_bound = 0.0,
        base_name = "vINFLOW_$(commodity_type(n))_$(get_id(n))"
    )

    add_to_expression!.(net_production(n), inflow(n))

    for t in time_interval(n)

        if !isempty(price(n))
            add_to_expression!(model[:eVariableCost], price(n)[t], inflow(n)[t])
        end

    end


    return nothing
end


function add_operation_variables!(n::SinkNode, model::Model)

    n.operation_expr[:net_production] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])


    n.operation_vars[:outflow] = @variable(
        model,
        [t in time_interval(n)],
        lower_bound = 0.0,
        base_name = "vOUTFLOW_$(commodity_type(n))_$(get_id(n))"
    )

    add_to_expression!.(net_production(n), -outflow(n))

    for t in time_interval(n)

        if !isempty(price(n))
            add_to_expression!(model[:eVariableCost], price(n)[t], outflow(n)[t])
        end

    end


    return nothing
end
