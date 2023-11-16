
# add_variable  functions
function add_planning_variables!(g::AbstractResource, model::Model)

    g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(commodity_type(g))_$(resource_id(g))"
    )

    g.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(commodity_type(g))_$(resource_id(g))"
    )

    g.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAP_$(commodity_type(g))_$(resource_id(g))"
    )

    ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
    @constraint(
        model,
        capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g)
    )

    if !can_expand(g)
        fix(new_capacity(g), 0.0; force = true)
    end

    if !can_retire(g)
        fix(ret_capacity(g), 0.0; force = true)
    end

    return nothing

end


function add_planning_variables!(g::SymmetricStorage, model::Model)

    g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAP_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:new_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:ret_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPSTOR_$(commodity_type(g))_$(g.r_id)"
    )

    @constraint(
        model,
        capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g)
    )

    @constraint(
        model,
        capacity_storage(g) ==
        new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g)
    )

    if !g.can_expand
        fix(new_capacity_storage(g), 0.0; force = true)
    end

    if !g.can_retire
        fix(ret_capacity_storage(g), 0.0; force = true)
    end



    return nothing

end

function add_planning_variables!(g::AsymmetricStorage, model::Model)

    g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAP_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:new_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:ret_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPSTOR_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:new_capacity_withdrawal] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAPWDW_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:ret_capacity_withdrawal] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAPWDW_$(commodity_type(g))_$(g.r_id)"
    )

    g.planning_vars[:capacity_withdrawal] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPWDW_$(commodity_type(g))_$(g.r_id)"
    )

    @constraint(
        model,
        capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g)
    )

    @constraint(
        model,
        capacity_storage(g) ==
        new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g)
    )

    @constraint(
        model,
        capacity_withdrawal(g) ==
        new_capacity_withdrawal(g) - ret_capacity_withdrawal(g) +
        existing_capacity_withdrawal(g)
    )

    if !g.can_expand
        fix(new_capacity(g), 0.0; force = true)
        fix(new_capacity_storage(g), 0.0; force = true)
        fix(new_capacity_withdrawal(g), 0.0; force = true)
    end

    if !g.can_retire
        fix(ret_capacity(g), 0.0; force = true)
        fix(ret_capacity_storage(g), 0.0; force = true)
        fix(ret_capacity_withdrawal(g), 0.0; force = true)
    end

    return nothing

end


function add_operation_variables!(g::AbstractResource, model::Model)

    g.operation_vars[:injection] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vINJ_$(commodity_type(g))_$(resource_id(g))"
    )

    return nothing
end


function add_operation_variables!(g::AbstractStorage, model::Model)

    g.operation_vars[:injection] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vINJ_$(commodity_type(g))_$(g.r_id)"
    )
    g.operation_vars[:withdrawal] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vWDW_$(commodity_type(g))_$(g.r_id)"
    )
    g.operation_vars[:storage_level] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(commodity_type(g))_$(g.r_id)"
    )

    time_subperiods = subperiods(g)

    for P in time_subperiods
        @constraint(
            model,
            [t in P[2:end]],
            storage_level(g)[t] ==
            (1 + self_discharge(g)) * storage_level(g)[t-1] +
            efficiency_discharge(g) * injection(g)[t] -
            efficiency_charge(g) * withdrawal(g)[t]
        )
        t_start = first(P)
        t_end = last(P)
        @constraint(
            model,
            storage_level(g)[t_start] ==
            (1 + self_discharge(g)) * storage_level(g)[t_end] +
            efficiency_discharge(g) * injection(g)[t] -
            efficiency_charge(g) * withdrawal(g)[t]
        )
    end

    return nothing


end
