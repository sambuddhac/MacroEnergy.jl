abstract type AbstractTEdge{T1<:Commodity,T2<:Commodity} end

abstract type AbstractEdge{T<:Commodity} <: AbstractTEdge{T,T} end

Base.@kwdef mutable struct Edge{T} <: AbstractEdge{T}
    time_interval::StepRange{Int64,Int64}
    start_node::Node{T}
    end_node::Node{T}
    existing_capacity::Float64
    unidirectional::Bool = false
    max_line_flow_capacity::Float64 = Inf
    max_line_reinforcement::Float64 = Inf
    line_reinforcement_cost::Float64 = 0.0
    num_lines_existing::Int64 = 1
    can_expand::Bool = true
    max_num_lines_expanded::Int64 = Inf
    investment_cost::Float64 = 0.0
    op_cost::Float64 = 0.0
    distance::Float64 = 0.0
    line_loss_percentage::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = [CapacityConstraint{T}()]
end

start_node(e::AbstractEdge) = e.start_node;
end_node(e::AbstractEdge) = e.end_node;

start_node_id(e::AbstractEdge) = node_id(e.start_node);
end_node_id(e::AbstractEdge) = node_id(e.end_node);

time_interval(e::AbstractEdge) = e.time_interval;
commodity_type(e::AbstractEdge{T}) where {T} = T;
existing_capacity(e::AbstractEdge) = e.existing_capacity;
can_expand(e::AbstractEdge) = e.can_expand;
new_capacity(e::AbstractEdge) = e.planning_vars[:new_capacity];
capacity(e::AbstractEdge) = e.planning_vars[:capacity];
flow(e::AbstractEdge) = e.operation_vars[:flow];

all_constraints(e::AbstractEdge) = e.constraints;



const Network = Union{Vector{Edge},Vector{Node}}

function add_planning_variables!(e::AbstractEdge, model::Model)

    e.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAPEDGE_$(commodity_type(e))_$(start_node_id(e))_$(end_node_id(e))"
    )

    e.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPEDGE_$(commodity_type(e))_$(start_node_id(e))_$(end_node_id(e))"
    )

    @constraint(model, capacity(e) == new_capacity(e) + existing_capacity(e))

    if !can_expand(e)
        fix(new_capacity(e), 0.0; force = true)
    end

    return nothing

end

function add_operation_variables!(
    e::AbstractEdge,
    model::Model,
)

    e.operation_vars[:flow] = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(commodity_type(e))_$(start_node_id(e))_$(end_node_id(e))"
    )

    for t in time_interval(e)
        add_to_expression!(net_energy_production(start_node(e))[t], -flow(e)[t])
        add_to_expression!(net_energy_production(end_node(e))[t], flow(e)[t])
    end

end


struct TEdge{T1,T2} <: AbstractTEdge{T1,T2}
    id::Symbol
    start_node::Node{T1}
    end_node::Node{T2}
    transformation::Symbol
    flow_direction::Int64
end
TEdge(
    id::Symbol,
    start_node::Node{T1},
    end_node::Node{T2},
    transformation::Symbol,
    flow_direction::Int64,
) where {T1<:Commodity,T2<:Commodity} =
    TEdge{T1,T2}(id, start_node, end_node, transformation, flow_direction)

end_node(e::TEdge) = e.end_node;
flow_direction(e::TEdge) = e.flow_direction;
end_node_commodity_type(e::TEdge) = commodity_type(end_node(e));
