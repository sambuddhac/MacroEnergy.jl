abstract type AbstractTransformationNode end

abstract type AbstractTransformationEdge{T<:Commodity} end

Base.@kwdef mutable struct TNode <: AbstractTransformationNode
    id::Symbol
    time_interval::StepRange{Int64,Int64}
    number_stoichiometry_balances::Int64
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} =
        [StochiometryBalanceConstraint()]
end
number_stoichiometry_balances(n::AbstractTransformationNode) = n.number_stoichiometry_balances;
get_id(n::AbstractTransformationNode) = n.id;
time_interval(n::AbstractTransformationNode) = n.time_interval;
all_constraints(n::AbstractTransformationNode) = n.constraints;
stochiometry_balance(n::AbstractTransformationNode) =
    n.operation_expr[:stochiometry_balance];

function initialize_stochiometry_balance!(n::AbstractTransformationNode, model::Model)
    n.operation_expr[:stochiometry_balance] =
        @expression(model, [i in 1:number_stoichiometry_balances(n), t in time_interval(n)], 0 * model[:vREF])
end

Base.@kwdef mutable struct TEdge{T} <: AbstractTransformationEdge{T}
    id::Symbol
    start_node::Union{AbstractNode{T},AbstractTransformationNode}
    end_node::Union{AbstractNode{T},AbstractTransformationNode}
    has_planning_variables::Bool = false
    time_interval::StepRange{Int64,Int64} = 1:1
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    st_coeff::Vector{Float64} = Float64[]
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    investment_cost::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    variable_om_cost::Float64 = 0.0
    ###### Fuel price is set by defining a resource with the same commodity type as the transformation edge
    #####price::Vector{Float64} = Float64[]
    start_cost_per_mw::Float64 = 0.0
    ucommit::Bool = false
    ramp_up_percentage::Float64 = 0.0
    ramp_down_percentage::Float64 = 0.0
    up_time::Int64 = 0
    down_time::Int64 = 0
    min_flow::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = []
end

commodity_type(e::AbstractTransformationEdge{T}) where {T} = T;
time_interval(e::AbstractTransformationEdge) = e.time_interval;
subperiods(e::AbstractTransformationEdge) = e.subperiods;
has_planning_variables(e::AbstractTransformationEdge) = e.has_planning_variables;
existing_capacity(e::AbstractTransformationEdge) = e.existing_capacity;
investment_cost(e::AbstractTransformationEdge) = e.investment_cost;
fixed_om_cost(e::AbstractTransformationEdge) = e.fixed_om_cost;
variable_om_cost(e::AbstractTransformationEdge) = e.variable_om_cost;
start_cost(e::AbstractTransformationEdge) = e.start_cost_per_mw;
###### Fuel price is set by defining a resource with the same commodity type as the transformation edge
######price(e::AbstractTransformationEdge) = e.price;
min_capacity(e::AbstractTransformationEdge) = e.min_capacity;
max_capacity(e::AbstractTransformationEdge) = e.max_capacity;
can_expand(e::AbstractTransformationEdge) = e.can_expand;
can_retire(e::AbstractTransformationEdge) = e.can_retire;
new_capacity(e::AbstractTransformationEdge) = e.planning_vars[:new_capacity];
ret_capacity(e::AbstractTransformationEdge) = e.planning_vars[:ret_capacity];
ramp_up_percentage(e::AbstractTransformationEdge) = e.ramp_up_percentage;
ramp_down_percentage(e::AbstractTransformationEdge) = e.ramp_down_percentage;
up_time(e::AbstractTransformationEdge) = e.up_time;
down_time(e::AbstractTransformationEdge) = e.down_time;
min_flow(e::AbstractTransformationEdge) = e.min_flow;
capacity(e::AbstractTransformationEdge) = e.planning_vars[:capacity];
flow(e::AbstractTransformationEdge) = e.operation_vars[:flow];
all_constraints(e::AbstractTransformationEdge) = e.constraints;
start_node(e::AbstractTransformationEdge) = e.start_node;
end_node(e::AbstractTransformationEdge) = e.end_node;
get_id(e::AbstractTransformationEdge) = e.id;
st_coeff(e::AbstractTransformationEdge) = e.st_coeff;
unit_commitment(e::AbstractTransformationEdge) = e.ucommit;

# add_variable  functions
function add_planning_variables!(e::AbstractTransformationEdge, model::Model)

    if has_planning_variables(e)

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
        else
            add_to_expression!(model[:eFixedCost], investment_cost(e) * new_capacity(e))
        end

        if !can_retire(e)
            fix(ret_capacity(e), 0.0; force = true)
        end

        if fixed_om_cost(e)>0
            add_to_expression!(model[:eFixedCost], fixed_om_cost(e) * capacity(e))
        end
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

    _st_coeff = st_coeff(e);
    _start_node = start_node(e);
    _end_node = end_node(e);

    for t in time_interval(e)
        if isa(_start_node, AbstractNode)
            #### The start node is a demand node and the end node is a transformation node
            add_to_expression!(net_production(_start_node)[t], -flow(e)[t])
            for i in 1:length(_st_coeff)
                add_to_expression!(
                stochiometry_balance(_end_node)[i,t],
                _st_coeff[i] * flow(e)[t],
                )
            end
        elseif isa(_end_node, AbstractNode)
            #### The end node is a demand node and the start node is a transformation node
            add_to_expression!(net_production(_end_node)[t], flow(e)[t])
            for i in 1:length(_st_coeff)
                add_to_expression!(
                    stochiometry_balance(_start_node)[i,t],
                    -_st_coeff[i] * flow(e)[t],
                )
            end
        else
            error(
                "Either the start or end node of a transformation edge has to be a transformation node",
            )
        end

        if variable_om_cost(e)>0
            add_to_expression!(model[:eVariableCost], variable_om_cost(e) * flow(e)[t])
        end

    end

    return nothing
end
