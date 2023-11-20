abstract type AbstractEdge{T<:Commodity} end

Base.@kwdef mutable struct Edge{T} <: AbstractEdge{T}
    start_node::Int64
    end_node::Int64
    unidirectional::Bool = false
    time_interval::StepRange{Int64, Int64}
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64
    can_expand::Bool = true
    investment_cost::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints ::Vector{AbstractTypeConstraint}=[CapacityConstraint{T}()]
end

start_node_id(e::AbstractEdge) = e.start_node;
end_node_id(e::AbstractEdge) = e.end_node;

time_interval(e::AbstractEdge) = e.time_interval;
commodity_type(e::AbstractEdge{T}) where {T} = T;
existing_capacity(e::AbstractEdge) = e.existing_capacity;
can_expand(e::AbstractEdge) = e.can_expand;
new_capacity(e::AbstractEdge) = e.planning_vars[:new_capacity];
capacity(e::AbstractEdge) = e.planning_vars[:capacity];
flow(e::AbstractEdge) = e.operation_vars[:flow];

all_constraints(e::AbstractEdge) = e.constraints;

map_edge_to_nodes(e::AbstractEdge,nodes::Vector{AbstractNode}) = (nodes[start_node_id(e)],nodes[end_node_id(e)])


function add_planning_variables!(e::AbstractEdge, model::Model)

    e.planning_vars[:new_capacity] = @variable(model, lower_bound = 0.0, base_name = "vNEWCAPEDGE_$(commodity_type(e))_$(e.start_node)_$(e.end_node)")

    e.planning_vars[:capacity] = @variable(model, lower_bound = 0.0, base_name = "vCAPEDGE_$(commodity_type(e))_$(e.start_node)_$(e.end_node)")

    @constraint(model, capacity(e) == new_capacity(e) + existing_capacity(e))

    if !can_expand(e)
        fix(new_capacity, 0.0; force=true)
    end

    return nothing

end

function add_operation_variables!(e::AbstractEdge, nodes::Vector{AbstractNode}, model::Model)
    
    e.operation_vars[:flow] = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOW_$(commodity_type(e))_$(e.start_node)_$(e.end_node)")

    start_node,end_node = map_edge_to_nodes(e,nodes);

    for t in time_interval(e)
        add_to_expression!(start_node.operation_expr[:net_energy_production][t], -flow(e)[t])
        add_to_expression!(end_node.operation_expr[:net_energy_production][t], flow(e)[t])
    end

end


