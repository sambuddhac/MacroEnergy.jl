abstract type AbstractTransformation{T<:TransformationType} end

abstract type AbstractTransformationEdge{T<:Commodity} end
Base.@kwdef mutable struct TEdge{T} <: AbstractTransformationEdge{T}
    id::Symbol
    node::AbstractNode{T}
    transformation::AbstractTransformation
    direction::Symbol = :input
    has_planning_variables::Bool = false
    can_retire::Bool = false
    can_expand::Bool = false 
    capacity_size :: Float64 = 1.0
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
    start_cost::Float64 = 0.0
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

Base.@kwdef mutable struct Transformation{T} <: AbstractTransformation{T}
    id::Symbol
    time_interval::StepRange{Int64,Int64}
    number_of_stoichiometry_balances::Int64
    TEdges::Vector{TEdge} = TEdge[]
    operation_expr::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = [StochiometryBalanceConstraint()]
end

transformation_type(g::AbstractTransformation{T}) where {T} = T;
number_of_stoichiometry_balances(g::AbstractTransformation) = g.number_of_stoichiometry_balances;
get_id(g::AbstractTransformation) = g.id;
time_interval(g::AbstractTransformation) = g.time_interval;
all_constraints(g::AbstractTransformation) = g.constraints;
stoichiometry_balance(g::AbstractTransformation) = g.operation_expr[:stoichiometry_balance];
edges(g::AbstractTransformation) = g.TEdges;

commodity_type(e::AbstractTransformationEdge{T}) where {T} = T;
time_interval(e::AbstractTransformationEdge) = e.time_interval;
subperiods(e::AbstractTransformationEdge) = e.subperiods;
has_planning_variables(e::AbstractTransformationEdge) = e.has_planning_variables;
direction(e::AbstractTransformationEdge) = e.direction;
existing_capacity(e::AbstractTransformationEdge) = e.existing_capacity;
capacity_size(e::AbstractTransformationEdge) = e.capacity_size;
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
node(e::AbstractTransformationEdge) = e.node;
stoichiometry_balance(e::AbstractTransformationEdge) = stoichiometry_balance(e.transformation);
get_id(e::AbstractTransformationEdge) = e.id;
st_coeff(e::AbstractTransformationEdge) = e.st_coeff;
unit_commitment(e::AbstractTransformationEdge) = e.ucommit;

# add_variable  functions

function add_planning_variables!(g::AbstractTransformation,model::Model)

    add_planning_variables!.(edges(g),model)

end

function add_operation_variables!(g::AbstractTransformation,model::Model)

    g.operation_expr[:stoichiometry_balance] = @expression(model, [i in 1:number_of_stoichiometry_balances(g), t in time_interval(g)], 0 * model[:vREF])

    add_operation_variables!.(edges(g),model)

end

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

    dir_coeff =  (direction(e) == :input) ? -1 : (direction(e) == :output) ? 1 : error("Invalid TEdge direction")

    e_st_coeff = st_coeff(e);
    e_node = node(e);

    for t in time_interval(e)

        add_to_expression!(net_production(e_node)[t], dir_coeff * flow(e)[t])

        for i in 1:length(e_st_coeff)
            add_to_expression!(stoichiometry_balance(e)[i,t], dir_coeff * e_st_coeff[i] * flow(e)[t])
        end

        if variable_om_cost(e)>0
            add_to_expression!(model[:eVariableCost], variable_om_cost(e) * flow(e)[t])
        end

    end

    return nothing
end
