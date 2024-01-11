# abstract type AbstractTEdge{T1<:Commodity,T2<:Commodity} end

# abstract type AbstractEdge{T<:Commodity} <: AbstractTEdge{T,T} end

abstract type AbstractEdge{T<:Commodity} end
Base.@kwdef mutable struct Edge{T} <: AbstractEdge{T}
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    start_node::Node{T}
    end_node::Node{T}
    existing_capacity::Float64
    unidirectional::Bool = false
    max_line_reinforcement::Float64 = Inf
    line_reinforcement_cost::Float64 = 0.0
    #### num_lines_existing::Int64 = 1
    can_expand::Bool = true
    ####max_num_lines_expanded::Int64 = Inf
    ####investment_cost_per_line::Float64 = 0.0
    op_cost::Float64 = 0.0
    distance::Float64 = 0.0
    line_loss_percentage::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = [CapacityConstraint()]
end

start_node(e::AbstractEdge) = e.start_node;
end_node(e::AbstractEdge) = e.end_node;

start_node_id(e::AbstractEdge) = get_id(e.start_node);
end_node_id(e::AbstractEdge) = get_id(e.end_node);

time_interval(e::AbstractEdge) = e.time_interval;
subperiods(e::AbstractEdge) = e.subperiods;
commodity_type(e::AbstractEdge{T}) where {T} = T;
existing_capacity(e::AbstractEdge) = e.existing_capacity;
max_line_reinforcement(e::AbstractEdge) = e.max_line_reinforcement;
line_reinforcement_cost(e::AbstractEdge) = e.line_reinforcement_cost;
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
        upper_bound = max_line_reinforcement(e),
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
    else
        add_to_expression!(model[:eFixedCost], line_reinforcement_cost(e) * new_capacity(e))
    end

    return nothing

end

function add_operation_variables!(e::AbstractEdge, model::Model)
    if e.unidirectional
        e.operation_vars[:flow] = @variable(
            model,
            [t in time_interval(e)],
            lower_bound = 0.0,
            base_name = "vFLOW_$(commodity_type(e))_$(start_node_id(e))_$(end_node_id(e))"
        )
    else
        e.operation_vars[:flow] = @variable(
            model,
            [t in time_interval(e)],
            base_name = "vFLOW_$(commodity_type(e))_$(start_node_id(e))_$(end_node_id(e))"
        )
    end

    add_to_expression!.(net_production(start_node(e)), -flow(e))
    
    add_to_expression!.(net_production(end_node(e)), flow(e))
    # for t in time_interval(e)
    #     add_to_expression!(net_production(start_node(e))[t], -flow(e)[t])
    #     add_to_expression!(net_production(end_node(e))[t], flow(e)[t])
    # end

end
