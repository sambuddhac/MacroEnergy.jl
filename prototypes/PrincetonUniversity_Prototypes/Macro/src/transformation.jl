abstract type AbstractTransformation end


Base.@kwdef mutable struct Transformation <: AbstractTransformation
    id::Symbol
    tedges::Vector{TEdge}

    num_edges::Int64 = length(tedges)

    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    variable_om_cost::Float64 = 0.0

    start_cost_per_mw::Float64 = 0.0
    ramp_up_percentage::Float64 = 0.0
    ramp_down_percentage::Float64 = 0.0
    up_time::Int64 = 0
    down_time::Int64 = 0
    electricity_st::Float64 = 0.0
    ng_st::Float64 = 0.0
    h2_st::Float64 = 0.0
    min_output_elec::Float64 = 0.0
    min_output_h2::Float64 = 0.0

    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeTransformationConstraint} =
        [TransformationCapacityConstraint()]
end


time_interval(g::AbstractTransformation) = g.time_interval;
subperiods(g::AbstractTransformation) = g.subperiods;
existing_capacity(g::AbstractTransformation) = g.existing_capacity;
min_capacity(g::AbstractTransformation) = g.min_capacity;
max_capacity(g::AbstractTransformation) = g.max_capacity;
can_expand(g::AbstractTransformation) = g.can_expand;
can_retire(g::AbstractTransformation) = g.can_retire;
new_capacity(g::AbstractTransformation) = g.planning_vars[:new_capacity];
ret_capacity(g::AbstractTransformation) = g.planning_vars[:ret_capacity];
capacity(g::AbstractTransformation) = g.planning_vars[:capacity];
injection(g::AbstractTransformation) = g.operation_vars[:injection];
all_constraints(g::AbstractTransformation) = g.constraints;
start_node(g::AbstractTransformation) = g.tedges[1].start_node;
base_commodity_type(g::AbstractTransformation) = commodity_type(start_node(g));
transformation_id(g::AbstractTransformation) = g.id;
tedges(g::AbstractTransformation) = g.tedges;


# add_variable  functions
function add_planning_variables!(g::AbstractTransformation, model::Model)

    g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(base_commodity_type(g))_$(transformation_id(g))"
    )

    # g.planning_vars[:ret_capacity] = @variable(model, lower_bound = 0.0, base_name = "vRETCAP_$(base_commodity_type(g))_$(transformation_id(g))")

    # g.planning_vars[:capacity] = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(base_commodity_type(g))_$(transformation_id(g))")

    ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
    # @constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    # if !can_expand(g)
    #     fix(new_capacity(g), 0.0; force=true)
    # end

    # if !can_retire(g)
    #     fix(ret_capacity(g), 0.0; force=true)
    # end

    return nothing

end

function add_operation_variables!(g::AbstractTransformation, model::Model)

    n = start_node(g)

    g.operation_vars[:injection] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vINJ_$(base_commodity_type(g))_$(transformation_id(g))"
    )

    for t in time_interval(g)
        add_to_expression!(net_energy_production(n)[t], -injection(g)[t])

        for tedge in edges(g)
            end_node = end_node(tedge)
            flow_direction = flow_direction(tedge)
            st = get_st(g, tedge)   # stoichiometric coefficient
            add_to_expression!(
                net_energy_production(end_node)[t],
                flow_direction * injection(g)[t] * st,
            )
        end
    end

    return nothing
end

function get_st(t::AbstractTransformation, e::AbstractTEdge)
    end_node_commodity_type(e) == Electricity && return t.electricity_st
    end_node_commodity_type(e) == NaturalGas && return t.ng_st
    end_node_commodity_type(e) == Hydrogen && return t.h2_st
end
