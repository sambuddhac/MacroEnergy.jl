abstract type AbstractTransformationNode end

abstract type AbstractTransformationEdge{T<:Commodity} end

Base.@kwdef mutable struct TNode <: AbstractTransformationNode
    id::Symbol
    time_interval::StepRange{Int64,Int64}
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeStochiometryConstraint} =
        [StochiometryBalanceConstraint()]
end

get_id(n::AbstractTransformationNode) = n.id;
time_interval(n::AbstractTransformationNode) = n.time_interval;
all_constraints(n::AbstractTransformationNode) = n.constraints;
stochiometry_balance(n::AbstractTransformationNode) =
    n.operation_expr[:stochiometry_balance];

function initialize_stochiometry_balance!(n::AbstractTransformationNode, model::Model)
    n.operation_expr[:stochiometry_balance] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])
end

Base.@kwdef mutable struct TEdge{T} <: AbstractTransformationEdge{T}
    id::Symbol
    start_node::Union{AbstractNode{T},AbstractTransformationNode}
    end_node::Union{AbstractNode{T},AbstractTransformationNode}
    time_interval::StepRange{Int64,Int64} = 1:1
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    st_coeff::Float64 = 1.0
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    investment_cost::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    variable_om_cost::Float64 = 0.0
    start_cost_per_mw::Float64 = 0.0
    ramp_up_percentage::Float64 = 0.0
    ramp_down_percentage::Float64 = 0.0
    up_time::Int64 = 0
    down_time::Int64 = 0
    min_flow::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = [CapacityConstraint{T}]
end

commodity_type(e::AbstractTransformationEdge{T}) where {T} = T;
time_interval(e::AbstractTransformationEdge) = e.time_interval;
subperiods(e::AbstractTransformationEdge) = e.subperiods;
existing_capacity(e::AbstractTransformationEdge) = e.existing_capacity;
min_capacity(e::AbstractTransformationEdge) = e.min_capacity;
max_capacity(e::AbstractTransformationEdge) = e.max_capacity;
can_expand(e::AbstractTransformationEdge) = e.can_expand;
can_retire(e::AbstractTransformationEdge) = e.can_retire;
new_capacity(e::AbstractTransformationEdge) = e.planning_vars[:new_capacity];
ret_capacity(e::AbstractTransformationEdge) = e.planning_vars[:ret_capacity];
capacity(e::AbstractTransformationEdge) = e.planning_vars[:capacity];
flow(e::AbstractTransformationEdge) = e.operation_vars[:flow];
all_constraints(e::AbstractTransformationEdge) = e.constraints;
start_node(e::AbstractTransformationEdge) = e.start_node;
end_node(e::AbstractTransformationEdge) = e.end_node;
get_id(e::AbstractTransformationEdge) = e.id;
st_coeff(e::AbstractTransformationEdge) = e.st_coeff;


# add_variable  functions
function add_planning_variables!(e::AbstractTransformationEdge, model::Model)

    e.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(commodity_type(e))_$(get_id(e))"
    )

    e.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(commodity_type(e))_$(get_id(e))"
    )

    e.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAP_$(commodity_type(e))_$(get_id(e))"
    )

    ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
    @constraint(
        model,
        capacity(e) == new_capacity(e) - ret_capacity(e) + existing_capacity(e)
    )

    if !can_expand(e)
        fix(new_capacity(e), 0.0; force = true)
    end

    if !can_retire(e)
        fix(ret_capacity(e), 0.0; force = true)
    end

    return nothing

end

function add_operation_variables!(e::AbstractTransformationEdge, model::Model)

    e.operation_vars[:flow] = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(commodity_type(e))_$(get_id(e))"
    )


    for t in time_interval(e)
        if isa(start_node(e), AbstractNode)
            add_to_expression!(net_production(start_node(e))[t], -flow(e)[t])
            add_to_expression!(
                stochiometry_balance(end_node(e))[t],
                st_coeff(e) * flow(e)[t],
            )
        elseif isa(end_node(e), AbstractNode)
            add_to_expression!(net_production(start_node(e))[t], flow(e)[t])
            add_to_expression!(
                stochiometry_balance(end_node(e))[t],
                -st_coeff(e) * flow(e)[t],
            )
        else
            error(
                "Either the start or end node of a trasnformation edge has to be a transformation node",
            )
        end
    end

    return nothing
end
